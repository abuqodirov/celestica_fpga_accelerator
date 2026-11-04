// mustaqi.c - reference inference for MustaqiLLM (NeuronLM, 5.17B, Apache-2.0) in the Q4A format written by
// export_q4a.py. This is the golden model for the FPGA: weights are 4-bit codes with an fp16 scale and offset
// per 32 inputs, activations are quantized to int8 per 32 before every matrix multiply, so each group's
// contribution is  s*sx*sum(q*xq) + lo*sx*sum(xq)  (one integer dot product per group); everything else
// (RMSNorm, QK-norm, RoPE, attention, SiLU) is float32. Structure follows llama2.c's runq.c (MIT, Karpathy).
//
// Default arithmetic = the FPGA matvec engine's, bit for bit ("exact"): activations are MXINT8 (per group of 32
// a power-of-two scale 2^e and int8 a, |a| <= 127), fp16 s and lo are split exactly into integer mantissa x 2^exp,
// and every group adds  (m_s*D) << (E_s+e)  and  (m_lo*S) << (E_lo+e)  into a 64-bit fixed-point accumulator with
// ACC_FRAC fractional bits (right shifts floor). One rounding per output: int64 -> float32 (nearest even).
// -legacy selects the earlier float scales (sx = max|x|/127) and float accumulation.
//
// usage: mustaqi model.bin [-n max_new] [-c ctx] [-t temp] [-p top_p] [-r rep_penalty] [-s seed] [-g] [-ppl] [-legacy] [-kv f32|q8|q4] [-hwmath]
//   stdin:  one line of space-separated token ids (the prompt, or with -ppl a text to score)
//   stdout: generated token ids, one per line, flushed as they come (chat_c.py decodes them)
#include <fcntl.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#ifdef __AVX2__
#include <immintrin.h>
#endif

#define GS 32           // quantization group (weights and activations)
#define BLK 20          // bytes per weight block: fp16 scale, fp16 offset, 16 bytes of 4-bit codes
#define IM_END 5

typedef struct { const uint8_t *b; int rows, cols; } Q4A;     // blocks, row-major
typedef struct {
    const float *in_norm, *q_norm, *k_norm, *post_norm;
    Q4A qkv, out, gate_up, down;
} Layer;
typedef struct {
    int dim, layers, heads, kv_heads, head_dim, ffn, vocab, group, maxctx;
    float theta, eps;
    const uint16_t *embed;
    Layer *l;
    const float *norm;
    Q4A lm_head;
} Model;
typedef struct {                       // activations
    float *x, *xb, *xb2, *qkv, *hb, *att, *logits, *kc, *vc, *xs, *inv_freq;
    int8_t *xq;
    int32_t *xsum, *xe;                // per group: sum of a, MXINT8 exponent e
    int ctx;
} State;
static int legacy = 0;
static int kvmode = 0;
static int hwmath = 0;                 // -hwmath: hardware-style exp (table + linear interpolation), 8-way fp32 sums                 // KV cache storage: 0 float32, 8 MXINT8 per 32, 4 = 4-bit asym per head (Q4H)
#define ACC_FRAC 30                    // fixed-point accumulator: value = acc * 2^-ACC_FRAC

static float h2f(uint16_t h) {        // IEEE half -> float (portable; F16C is only a speedup)
#ifdef __F16C__
    return _cvtsh_ss(h);
#else
    uint32_t s = (h >> 15) << 31, e = (h >> 10) & 31, m = h & 1023, u;
    if (e == 0) { float f = ldexpf((float)m, -24); return s ? -f : f; }
    u = e == 31 ? (s | 0x7f800000 | (m << 13)) : (s | ((e + 112) << 23) | (m << 13));
    float f; memcpy(&f, &u, 4); return f;
#endif
}

// ---- model file ---------------------------------------------------------------------------------------------
static const uint8_t *cur;
static const uint8_t *take(size_t n) { const uint8_t *p = cur; cur += n; cur += (64 - ((uintptr_t)cur & 63)) & 63; return p; }
static Q4A takeq(int rows, int cols) { Q4A q = { take((size_t)rows * (cols / GS) * BLK), rows, cols }; return q; }

static void load(Model *m, const char *path) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) { perror(path); exit(1); }
    struct stat st; fstat(fd, &st);
    const uint8_t *base = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
    if (base == MAP_FAILED || memcmp(base, "MQ4A", 4)) { fprintf(stderr, "not a Q4A file\n"); exit(1); }
    const uint32_t *h = (const uint32_t *)base;
    if (h[1] != 1) { fprintf(stderr, "Q4A version %u\n", h[1]); exit(1); }
    m->dim = h[2]; m->layers = h[3]; m->heads = h[4]; m->kv_heads = h[5]; m->head_dim = h[6]; m->ffn = h[7];
    m->vocab = h[8]; m->group = h[9]; m->maxctx = h[10];
    memcpy(&m->theta, h + 11, 4); memcpy(&m->eps, h + 12, 4);
    if (m->group != GS) { fprintf(stderr, "group %d != %d\n", m->group, GS); exit(1); }
    int qkv = (m->heads + 2 * m->kv_heads) * m->head_dim;
    cur = base + 256;
    m->embed = (const uint16_t *)take((size_t)m->vocab * m->dim * 2);
    m->l = calloc(m->layers, sizeof(Layer));
    for (int i = 0; i < m->layers; i++) {
        Layer *L = &m->l[i];
        L->in_norm = (const float *)take(m->dim * 4);
        L->qkv = takeq(qkv, m->dim);
        L->q_norm = (const float *)take(m->head_dim * 4);
        L->k_norm = (const float *)take(m->head_dim * 4);
        L->out = takeq(m->dim, m->heads * m->head_dim);
        L->post_norm = (const float *)take(m->dim * 4);
        L->gate_up = takeq(2 * m->ffn, m->dim);
        L->down = takeq(m->dim, m->ffn);
    }
    m->norm = (const float *)take(m->dim * 4);
    m->lm_head = takeq(m->vocab, m->dim);
    if (cur - base > st.st_size) { fprintf(stderr, "file too short\n"); exit(1); }
}

// ---- kernels ------------------------------------------------------------------------------------------------
// candidate vector-unit math: exp(x) = 2^(x*log2(e)), 2^frac from 64 table entries + linear interpolation
static float hw_exp(float x) {
    static float T[65];
    static int init = 0;
    if (!init) { for (int i = 0; i <= 64; i++) T[i] = exp2f(i / 64.0f); init = 1; }
    if (x < -87.0f) return 0.0f;
    if (x > 88.0f) x = 88.0f;
    float y = x * 1.44269504f, n = floorf(y), p = (y - n) * 64.0f;
    int i = (int)p;
    return ldexpf(T[i] + (T[i + 1] - T[i]) * (p - i), (int)n);
}
// fp32 sum in the order of a pipelined adder with 8 interleaved partial sums, then a fixed tree
static float sum8(const float *x, int n, int squares) {
    float p[8] = {0};
    for (int i = 0; i < n; i++) p[i & 7] += squares ? x[i] * x[i] : x[i];
    return ((p[0] + p[1]) + (p[2] + p[3])) + ((p[4] + p[5]) + (p[6] + p[7]));
}

static void rmsnorm(float *o, const float *x, const float *w, int n, float eps) {
    double ss = 0;
    if (hwmath) ss = sum8(x, n, 1);
    else for (int i = 0; i < n; i++) ss += (double)x[i] * x[i];
    float r = 1.0f / sqrtf((float)(ss / n) + eps);
    for (int i = 0; i < n; i++) o[i] = x[i] * r * w[i];
}

// x -> int8 per group of 32: xq = round(x / sx), sx = max|x| / 127; xsum = sum of the group's xq
static void quantize_act(State *s, const float *x, int n) {
    for (int g = 0; g < n / GS; g++) {
        float amax = 0;
        for (int j = 0; j < GS; j++) amax = fmaxf(amax, fabsf(x[g * GS + j]));
        float sx = amax / 127.0f, inv = sx > 0 ? 1.0f / sx : 0;
        int32_t sum = 0;
        for (int j = 0; j < GS; j++) {
            int8_t q = (int8_t)lrintf(x[g * GS + j] * inv);
            s->xq[g * GS + j] = q; sum += q;
        }
        s->xs[g] = sx; s->xsum[g] = sum;
    }
}

// out[r] = sum over groups g of  s*sx*dot(q, xq) + lo*sx*xsum   (activations already quantized)
static void matmul(float *out, Q4A W, const State *s) {
    int ng = W.cols / GS;
#pragma omp parallel for schedule(static)
    for (int r = 0; r < W.rows; r++) {
        const uint8_t *b = W.b + (size_t)r * ng * BLK;
        float acc = 0;
#ifdef __AVX2__
        __m256 vacc = _mm256_setzero_ps();
        const __m128i m4 = _mm_set1_epi8(0x0f);
        const __m256i ones = _mm256_set1_epi16(1);
#endif
        for (int g = 0; g < ng; g++, b += BLK) {
            uint16_t s16, lo16; memcpy(&s16, b, 2); memcpy(&lo16, b + 2, 2);
            float sx = s->xs[g], ws = h2f(s16) * sx;
            acc += h2f(lo16) * sx * (float)s->xsum[g];
#ifdef __AVX2__
            __m128i c = _mm_loadu_si128((const __m128i *)(b + 4));
            __m128i lo = _mm_and_si128(c, m4), hi = _mm_and_si128(_mm_srli_epi16(c, 4), m4);
            __m256i q = _mm256_set_m128i(_mm_unpackhi_epi8(lo, hi), _mm_unpacklo_epi8(lo, hi));   // e0 e1 e2 ...
            __m256i x = _mm256_loadu_si256((const __m256i *)(s->xq + g * GS));
            __m256i d = _mm256_madd_epi16(_mm256_maddubs_epi16(q, x), ones);                     // 8 x int32
            vacc = _mm256_fmadd_ps(_mm256_cvtepi32_ps(d), _mm256_set1_ps(ws), vacc);
#else
            int32_t d = 0;
            for (int k = 0; k < 16; k++)
                d += (b[4 + k] & 15) * s->xq[g * GS + 2 * k] + (b[4 + k] >> 4) * s->xq[g * GS + 2 * k + 1];
            acc += ws * (float)d;
#endif
        }
#ifdef __AVX2__
        __m128 v = _mm_add_ps(_mm256_castps256_ps128(vacc), _mm256_extractf128_ps(vacc, 1));
        v = _mm_hadd_ps(v, v); v = _mm_hadd_ps(v, v);
        acc += _mm_cvtss_f32(v);
#endif
        out[r] = acc;
    }
}

// ---- exact (FPGA) arithmetic --------------------------------------------------------------------------------
// MXINT8: e = smallest integer with max|x| <= 127 * 2^e, a = round_half_even(x / 2^e) in [-127, 127]
static void quantize_act_mx(State *s, const float *x, int n) {
    for (int g = 0; g < n / GS; g++) {
        float amax = 0;
        for (int j = 0; j < GS; j++) amax = fmaxf(amax, fabsf(x[g * GS + j]));
        int e = -140;                                    // all-zero group: any e, a = 0
        if (amax > 0) {
            e = (int)ceilf(log2f(amax / 127.0f));
            while (amax > ldexpf(127.0f, e)) e++;
            while (amax <= ldexpf(127.0f, e - 1)) e--;
        }
        int32_t sum = 0;
        for (int j = 0; j < GS; j++) {
            long a = lrintf(ldexpf(x[g * GS + j], -e));     // default rounding mode: nearest even
            a = a > 127 ? 127 : a < -127 ? -127 : a;
            s->xq[g * GS + j] = (int8_t)a; sum += a;
        }
        s->xe[g] = e; s->xsum[g] = sum;
    }
}

// fp16 -> signed integer mantissa * 2^exp (exact)
static void h2me(uint16_t h, int32_t *m, int *ex) {
    int e = (h >> 10) & 31, f = h & 1023;
    if (e == 31) { fprintf(stderr, "inf/nan fp16 scale\n"); exit(1); }
    *m = e ? (f | 1024) : f;
    *ex = (e ? e : 1) - 25;
    if (h >> 15) *m = -*m;
}

// v * 2^sh on the accumulator grid: left shifts exact, right shifts floor
static int64_t shl(int64_t v, int sh) {
    if (sh >= 0) {
        if (sh > 62 || (v != 0 && llabs(v) >= (INT64_C(1) << (62 - sh)))) {
            fprintf(stderr, "accumulator overflow (v %lld << %d)\n", (long long)v, sh); exit(1);
        }
        return v * (INT64_C(1) << sh);
    }
    return sh <= -63 ? (v < 0 ? -1 : 0) : (v >> -sh);
}

static void matmul_exact(float *out, Q4A W, const State *s) {
    int ng = W.cols / GS;
#pragma omp parallel for schedule(static)
    for (int r = 0; r < W.rows; r++) {
        const uint8_t *b = W.b + (size_t)r * ng * BLK;
        int64_t acc = 0;
        for (int g = 0; g < ng; g++, b += BLK) {
            uint16_t s16, lo16; memcpy(&s16, b, 2); memcpy(&lo16, b + 2, 2);
            int32_t ms, ml; int es, el;
            h2me(s16, &ms, &es); h2me(lo16, &ml, &el);
            int32_t d;
#ifdef __AVX2__
            const __m128i m4 = _mm_set1_epi8(0x0f);
            __m128i c = _mm_loadu_si128((const __m128i *)(b + 4));
            __m128i lo = _mm_and_si128(c, m4), hi = _mm_and_si128(_mm_srli_epi16(c, 4), m4);
            __m256i q = _mm256_set_m128i(_mm_unpackhi_epi8(lo, hi), _mm_unpacklo_epi8(lo, hi));
            __m256i x = _mm256_loadu_si256((const __m256i *)(s->xq + g * GS));
            __m256i p = _mm256_madd_epi16(_mm256_maddubs_epi16(q, x), _mm256_set1_epi16(1));
            __m128i v = _mm_add_epi32(_mm256_castsi256_si128(p), _mm256_extracti128_si256(p, 1));
            v = _mm_hadd_epi32(v, v); v = _mm_hadd_epi32(v, v);
            d = _mm_cvtsi128_si32(v);
#else
            d = 0;
            for (int k = 0; k < 16; k++)
                d += (b[4 + k] & 15) * s->xq[g * GS + 2 * k] + (b[4 + k] >> 4) * s->xq[g * GS + 2 * k + 1];
#endif
            int e = s->xe[g];
            acc += shl((int64_t)ms * d, es + e + ACC_FRAC);
            acc += shl((int64_t)ml * s->xsum[g], el + e + ACC_FRAC);
        }
        out[r] = ldexpf((float)acc, -ACC_FRAC);
    }
}

static void qa(State *s, const float *x, int n) { if (legacy) quantize_act(s, x, n); else quantize_act_mx(s, x, n); }
static void mm(float *out, Q4A W, const State *s) { if (legacy) matmul(out, W, s); else matmul_exact(out, W, s); }

// ---- simulated KV-cache storage formats (quantize + dequantize in place) --------------------------------------
static float f16_round(float f) {                   // value of the nearest fp16 (F16C or portable)
#ifdef __F16C__
    return _cvtsh_ss(_cvtss_sh(f, 0));
#else
    return f;
#endif
}
static void kv_store(float *v, int n, int hd) {
    if (kvmode == 8) {
        for (int g = 0; g < n / GS; g++) {
            float amax = 0;
            for (int j = 0; j < GS; j++) amax = fmaxf(amax, fabsf(v[g * GS + j]));
            if (amax == 0) continue;
            int e = (int)ceilf(log2f(amax / 127.0f));
            while (amax > ldexpf(127.0f, e)) e++;
            while (amax <= ldexpf(127.0f, e - 1)) e--;
            for (int j = 0; j < GS; j++) {
                long a = lrintf(ldexpf(v[g * GS + j], -e));
                a = a > 127 ? 127 : a < -127 ? -127 : a;
                v[g * GS + j] = ldexpf((float)a, e);
            }
        }
    } else if (kvmode == 4) {
        for (int h = 0; h < n / hd; h++) {
            float *x = v + h * hd, lo = x[0], hi = x[0];
            for (int j = 1; j < hd; j++) { lo = fminf(lo, x[j]); hi = fmaxf(hi, x[j]); }
            float s = f16_round((hi - lo) / 15.0f), l = f16_round(lo);
            for (int j = 0; j < hd; j++) {
                long q = s > 0 ? lrintf((x[j] - l) / s) : 0;
                q = q < 0 ? 0 : q > 15 ? 15 : q;
                x[j] = q * s + l;
            }
        }
    }
}

// rotate adjacent pairs (x0,x1), (x2,x3), ... by pos * inv_freq[i]
static void rope(float *v, int n_heads, int hd, int pos, const float *inv_freq) {
    for (int i = 0; i < hd / 2; i++) {
        float a = pos * inv_freq[i], c = cosf(a), sn = sinf(a);
        for (int h = 0; h < n_heads; h++) {
            float *p = v + h * hd + 2 * i, e = p[0], o = p[1];
            p[0] = e * c - o * sn; p[1] = e * sn + o * c;
        }
    }
}

static float *forward(const Model *m, State *s, int token, int pos) {
    int D = m->dim, HD = m->head_dim, KVD = m->kv_heads * HD, grp = m->heads / m->kv_heads;
    for (int i = 0; i < D; i++) s->x[i] = h2f(m->embed[(size_t)token * D + i]);
    for (int l = 0; l < m->layers; l++) {
        const Layer *L = &m->l[l];
        rmsnorm(s->xb, s->x, L->in_norm, D, m->eps);
        qa(s, s->xb, D);
        mm(s->qkv, L->qkv, s);
        float *q = s->qkv, *k = s->qkv + D, *v = s->qkv + D + KVD;
        for (int h = 0; h < m->heads; h++) rmsnorm(q + h * HD, q + h * HD, L->q_norm, HD, m->eps);
        for (int h = 0; h < m->kv_heads; h++) rmsnorm(k + h * HD, k + h * HD, L->k_norm, HD, m->eps);
        rope(q, m->heads, HD, pos, s->inv_freq);
        rope(k, m->kv_heads, HD, pos, s->inv_freq);
        float *kc = s->kc + ((size_t)l * s->ctx) * KVD, *vc = s->vc + ((size_t)l * s->ctx) * KVD;
        kv_store(k, KVD, HD); kv_store(v, KVD, HD);         // stored format (no-op for float32)
        memcpy(kc + (size_t)pos * KVD, k, KVD * 4);
        memcpy(vc + (size_t)pos * KVD, v, KVD * 4);
        float scale = 1.0f / sqrtf((float)HD);
#pragma omp parallel for schedule(static)
        for (int h = 0; h < m->heads; h++) {
            const float *qh = q + h * HD;
            float *att = s->att + (size_t)h * s->ctx, mx = -INFINITY, sum = 0;
            int kvh = h / grp;
            for (int t = 0; t <= pos; t++) {
                const float *kt = kc + (size_t)t * KVD + kvh * HD;
                float d = 0;
                for (int i = 0; i < HD; i++) d += qh[i] * kt[i];
                att[t] = d * scale; mx = fmaxf(mx, att[t]);
            }
            for (int t = 0; t <= pos; t++) { att[t] = hwmath ? hw_exp(att[t] - mx) : expf(att[t] - mx); sum += att[t]; }
            if (hwmath) sum = sum8(att, pos + 1, 0);
            float *o = s->xb2 + h * HD;
            memset(o, 0, HD * 4);
            for (int t = 0; t <= pos; t++) {
                const float *vt = vc + (size_t)t * KVD + kvh * HD, a = att[t] / sum;
                for (int i = 0; i < HD; i++) o[i] += a * vt[i];
            }
        }
        qa(s, s->xb2, m->heads * HD);
        mm(s->xb, L->out, s);
        for (int i = 0; i < D; i++) s->x[i] += s->xb[i];
        rmsnorm(s->xb, s->x, L->post_norm, D, m->eps);
        qa(s, s->xb, D);
        mm(s->hb, L->gate_up, s);
        for (int i = 0; i < m->ffn; i++) {
            float g = s->hb[i];
            s->hb[i] = (hwmath ? g * (1.0f / (1.0f + hw_exp(-g))) : g / (1.0f + expf(-g))) * s->hb[m->ffn + i];
        }
        qa(s, s->hb, m->ffn);
        mm(s->xb, L->down, s);
        for (int i = 0; i < D; i++) s->x[i] += s->xb[i];
    }
    rmsnorm(s->xb, s->x, m->norm, D, m->eps);
    qa(s, s->xb, D);
    mm(s->logits, m->lm_head, s);
    return s->logits;
}

// ---- sampling -----------------------------------------------------------------------------------------------
static uint64_t rng = 1;
static float frand(void) { rng ^= rng >> 12; rng ^= rng << 25; rng ^= rng >> 27; return ((rng * 0x2545F4914F6CDD1DULL) >> 40) / 16777216.0f; }
typedef struct { float p; int i; } PI;
static int cmp_pi(const void *a, const void *b) { float d = ((const PI *)b)->p - ((const PI *)a)->p; return (d > 0) - (d < 0); }

static int sample(float *lg, int n, const unsigned char *seen, float temp, float top_p, float rep, int greedy, PI *buf) {
    for (int i = 0; i < n; i++)                    // HF-style repetition penalty over every token seen so far
        if (seen[i]) lg[i] = lg[i] > 0 ? lg[i] / rep : lg[i] * rep;
    int best = 0;
    for (int i = 1; i < n; i++) if (lg[i] > lg[best]) best = i;
    if (greedy) return best;
    float mx = lg[best], sum = 0;
    for (int i = 0; i < n; i++) { buf[i].p = expf((lg[i] - mx) / temp); buf[i].i = i; sum += buf[i].p; }
    qsort(buf, n, sizeof(PI), cmp_pi);
    float cum = 0; int k = 0;
    while (k < n && cum < top_p * sum) cum += buf[k++].p;
    float r = frand() * cum, c = 0;
    for (int i = 0; i < k; i++) { c += buf[i].p; if (r < c) return buf[i].i; }
    return buf[k - 1].i;
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s model.bin [-n N] [-c ctx] [-t temp] [-p top_p] [-r rep] [-s seed] [-g] [-ppl]\n", argv[0]); return 1; }
    int max_new = 256, ctx = 2048, greedy = 0, ppl = 0;
    float temp = 0.7f, top_p = 0.9f, rep = 1.05f;
    for (int i = 2; i < argc; i++) {
        if (!strcmp(argv[i], "-g")) greedy = 1;
        else if (!strcmp(argv[i], "-ppl")) ppl = 1;
        else if (!strcmp(argv[i], "-legacy")) legacy = 1;
        else if (!strcmp(argv[i], "-hwmath")) hwmath = 1;
        else if (i + 1 < argc && !strcmp(argv[i], "-kv")) { i++; kvmode = !strcmp(argv[i], "q8") ? 8 : !strcmp(argv[i], "q4") ? 4 : 0; }
        else if (i + 1 < argc && !strcmp(argv[i], "-n")) max_new = atoi(argv[++i]);
        else if (i + 1 < argc && !strcmp(argv[i], "-c")) ctx = atoi(argv[++i]);
        else if (i + 1 < argc && !strcmp(argv[i], "-t")) temp = atof(argv[++i]);
        else if (i + 1 < argc && !strcmp(argv[i], "-p")) top_p = atof(argv[++i]);
        else if (i + 1 < argc && !strcmp(argv[i], "-r")) rep = atof(argv[++i]);
        else if (i + 1 < argc && !strcmp(argv[i], "-s")) rng = strtoull(argv[++i], 0, 10) * 2654435761ULL + 1;
        else { fprintf(stderr, "bad argument %s\n", argv[i]); return 1; }
    }
    Model m; load(&m, argv[1]);
    if (ctx > m.maxctx) ctx = m.maxctx;
    State s = {0};
    int KVD = m.kv_heads * m.head_dim, big = m.ffn > m.dim ? m.ffn : m.dim;
    s.ctx = ctx;
    s.x = calloc(m.dim, 4); s.xb = calloc(m.dim, 4); s.xb2 = calloc(m.dim, 4);
    s.qkv = calloc(m.dim + 2 * KVD, 4); s.hb = calloc(2 * m.ffn, 4); s.logits = calloc(m.vocab, 4);
    s.att = calloc((size_t)m.heads * ctx, 4);
    s.kc = calloc((size_t)m.layers * ctx * KVD, 4); s.vc = calloc((size_t)m.layers * ctx * KVD, 4);
    s.xq = calloc(big, 1); s.xs = calloc(big / GS, 4); s.xsum = calloc(big / GS, 4); s.xe = calloc(big / GS, 4);
    s.inv_freq = calloc(m.head_dim / 2, 4);
    for (int i = 0; i < m.head_dim / 2; i++) s.inv_freq[i] = (float)pow(m.theta, -2.0 * i / m.head_dim);
    if (!s.kc || !s.vc) { fprintf(stderr, "out of memory for ctx %d\n", ctx); return 1; }

    int *ids = malloc(ctx * sizeof(int)), n = 0, tok;
    while (n < ctx && scanf("%d", &tok) == 1) ids[n++] = tok;
    if (!n) { fprintf(stderr, "no prompt tokens on stdin\n"); return 1; }
    unsigned char *seen = calloc(m.vocab, 1);
    PI *buf = malloc(m.vocab * sizeof(PI));
    struct timespec t0, t1, t2;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    double nll = 0;
    float *lg = NULL;
    for (int i = 0; i < n; i++) {
        lg = forward(&m, &s, ids[i], i);
        seen[ids[i]] = 1;
        if (ppl && i + 1 < n) {
            float mx = lg[0], sum = 0;
            for (int j = 1; j < m.vocab; j++) mx = fmaxf(mx, lg[j]);
            for (int j = 0; j < m.vocab; j++) sum += expf(lg[j] - mx);
            nll -= lg[ids[i + 1]] - mx - logf(sum);
        }
    }
    clock_gettime(CLOCK_MONOTONIC, &t1);
    double tp = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) * 1e-9;
    if (ppl) {
        printf("perplexity %.3f over %d tokens (%.2f s/token)\n", exp(nll / (n - 1)), n - 1, tp / n);
        return 0;
    }
    int pos = n, gen = 0;
    while (gen < max_new && pos < ctx) {
        int next = sample(lg, m.vocab, seen, temp, top_p, rep, greedy, buf);
        if (next == IM_END) break;
        printf("%d\n", next); fflush(stdout);
        seen[next] = 1; gen++;
        lg = forward(&m, &s, next, pos++);
    }
    clock_gettime(CLOCK_MONOTONIC, &t2);
    double tg = (t2.tv_sec - t1.tv_sec) + (t2.tv_nsec - t1.tv_nsec) * 1e-9;
    fprintf(stderr, "[prompt %d tokens %.1f s (%.2f s/token); generated %d tokens %.1f s (%.2f tokens/s)]\n",
            n, tp, tp / n, gen, tg, gen ? gen / tg : 0);
    return 0;
}

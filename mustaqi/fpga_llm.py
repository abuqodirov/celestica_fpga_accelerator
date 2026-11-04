"""MustaqiLLM forward pass with every weight matrix multiply on the FPGA's two matvec engines (Q4H weights in the
card's DDR3, half of each matrix's rows per channel, MXINT8 activations), the rest on the PC in float32: RMSNorm,
QK-norm, RoPE, attention over the KV cache, SiLU, sampling. Same model structure as c/mustaqi.c.

Backends (same interface, mv(name, x) -> float32 rows):
    FpgaBackend  the engines (fpga_link.Link)
    CpuBackend   c/q4h_lib.so, bit-exact with the engines (golden.h) - reference for --check and a no-board mode
"""
import ctypes
import json
import math
import os
import struct
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
DIM, LAYERS, HEADS, KV_HEADS, HEAD_DIM, FFN, VOCAB = 3584, 36, 28, 4, 128, 9728, 48000
EPS, THETA, IM_START, IM_END = 1e-5, 500000.0, 4, 5
W_OFF = 64 << 20               # weights start 64 MiB into each channel (the BIOS boot memtest writes the start)
# Model selection (use_model): every function reads these module globals at call time, so the default (MustaqiLLM)
# behaves exactly as before. FFN_K = down_proj's K on the card (FFN padded up to a multiple of 128 with zero
# activations); ROPE_HALF = HF Qwen3 RoPE (pairs i, i + d/2) instead of MustaqiLLM's interleaved pairs (2i, 2i+1).
NAME, HF_DIR, FFN_K, ROPE_HALF, CTX = "MustaqiLLM", os.path.join(HERE, "hf"), 9728, False, 2048
MODELS = {
    "mustaqi": dict(NAME="MustaqiLLM", HF_DIR=os.path.join(HERE, "hf"), OUT=os.path.join(HERE, "out"),
                    DIM=3584, LAYERS=36, HEADS=28, KV_HEADS=4, HEAD_DIM=128, FFN=9728, FFN_K=9728, VOCAB=48000,
                    THETA=500000.0, W_OFF=64 << 20, ROPE_HALF=False, CTX=2048),
    # NeuronUz/NeuronLM-103M-SFT-v1 (Qwen3, 103.5 M params, tied embeddings): ../neuronlm, weights 1.5 GiB into each
    # channel (MustaqiLLM's end at 1.34 GiB: both models stay in DRAM); export: ../neuronlm/export_q4h_neuron.py
    "neuronlm": dict(NAME="NeuronLM-103M", HF_DIR=os.path.join(HERE, "..", "neuronlm", "hf"),
                     OUT=os.path.join(HERE, "..", "neuronlm", "out"),
                     DIM=640, LAYERS=16, HEADS=10, KV_HEADS=5, HEAD_DIM=64, FFN=1728, FFN_K=1792, VOCAB=48000,
                     THETA=10000.0, W_OFF=1536 << 20, ROPE_HALF=True, CTX=1024),
}


def use_model(name):
    globals().update(MODELS[name])

_lib = ctypes.CDLL(os.path.join(HERE, "c", "q4h_lib.so"))
_P = lambda a: a.ctypes.data_as(ctypes.c_void_p)


def quantize(x):
    """float32[K] -> (a int8[K], e int8[K/32], S int16[K/32], engine activation image uint32[9K/32])"""
    x = np.ascontiguousarray(x, np.float32)
    K = len(x)
    a, e, S = np.empty(K, np.int8), np.empty(K // 32, np.int8), np.empty(K // 32, np.int16)
    img = np.empty(K // 4 + K // 32, np.uint32)
    _lib.q4h_quantize(_P(x), K, _P(a), _P(e), _P(S), _P(img))
    return a, e, S, img


def bf16_round(y):
    """float32 -> nearest bfloat16 (ties to even), kept as float32: what the FPGA's packed result reads return"""
    u = y.view(np.uint32).astype(np.uint64)
    return ((u + 0x7FFF + ((u >> 16) & 1)) & 0xFFFF0000).astype(np.uint32).view(np.float32)


# ---- SiLU(gate) * up exactly as the FPGA's FFN unit computes it (hardware-friendly, bit-exact spec) -------------
# Every step is either a float32 multiply/add (IEEE, round to nearest even; numpy float32 does exactly that) or an
# exact bit operation, so the PC reproduces the hardware bit for bit:
#   t = g * C                     C = float32(-log2(e))
#   P = round_even(t * 2^22)      t in fixed point, 16 fraction bits below 2^-6 (exact integer; |t| < 64 here)
#   idx = P >> 16, f = (P & 0xFFFF) / 2^16;  i = idx & 63, n = idx >> 6        (2^t = 2^n * 2^(i/64) * 2^(f/64))
#   m = T[i] + D[i] * f           2^(f/64) by linear interpolation: T[i] = float32(2^(i/64)), D[i] = T[i+1] - T[i]
#   x = 1 + m * 2^n               (scaling by 2^n is exact)
#   x = mx * 2^k, mx in [1, 2):   j = top 6 mantissa bits, fr = the other 17 as a fraction (exact)
#   r = (R[j] + DR[j] * fr) * 2^-k    1/mx by interpolation: R[j] = float32(1 / (1 + j/64)), DR[j] = R[j+1] - R[j]
#   r = 0 if t >= 64 (g < -44: sigmoid ~ 0), r = 1 if t <= -64 (g > 44: sigmoid = 1)
#   h = (g * r) * u
_SILU_C = np.float32(-1.4426950408889634)
_T = np.array([2.0 ** (i / 64) for i in range(65)], np.float32)
_D = (_T[1:] - _T[:-1]).astype(np.float32)          # exact (Sterbenz)
_R = np.array([1.0 / (1 + j / 64) for j in range(65)], np.float32)
_DR = (_R[1:] - _R[:-1]).astype(np.float32)         # exact


def silu_mul_hw(g, u):
    g, u = np.asarray(g, np.float32), np.asarray(u, np.float32)
    t = g * _SILU_C
    hi, lo = t >= 64, t <= -64
    tc = np.where(hi | lo, np.float32(0), t)
    P = np.rint(tc.astype(np.float64) * 2.0 ** 22).astype(np.int64)          # exact: |t| < 64, float32 t
    idx = P >> 16
    f = ((P & 0xFFFF).astype(np.float32) * np.float32(2.0 ** -16)).astype(np.float32)
    m = _T[idx & 63] + _D[idx & 63] * f
    x = np.float32(1) + np.ldexp(m, (idx >> 6).astype(np.int32)).astype(np.float32)
    xb = x.view(np.uint32)
    k = (xb >> 23).astype(np.int32) - 127
    j = (xb >> 17) & 63
    fr = ((xb & 0x1FFFF).astype(np.float32) * np.float32(2.0 ** -17)).astype(np.float32)
    r = np.ldexp(_R[j] + _DR[j] * fr, -k).astype(np.float32)
    r = np.where(hi, np.float32(0), np.where(lo, np.float32(1), r)).astype(np.float32)
    return (g * r) * u


def pad_ffn(h):
    """FFN activations -> down_proj's K on the card (zeros appended when FFN is not a multiple of 128)"""
    return h if FFN_K == FFN else np.concatenate([h, np.zeros(FFN_K - FFN, np.float32)])


def row_words(K):
    ng = K // 128
    return (ng + 15) // 16 + ng


class Index:
    def __init__(self):
        self.ix = json.load(open(os.path.join(OUT, "q4h_index.json")))
        self.mats = self.ix["mats"]

    def halves(self, name):
        return [self.mats[f"{name}.{ch}"] for ch in (0, 1)]


class CpuBackend:
    name = "cpu"

    def __init__(self, index, packed=False):
        """packed: round the results to bfloat16 like FpgaBackend(packed=True)"""
        self.ix, self.packed = index, packed
        self.img = [np.memmap(os.path.join(OUT, f"q4h_ch{c}.bin"), np.uint8, mode="r") for c in (0, 1)]

    def mv_q(self, name, q, raw=False):
        """raw: float32 results even when packed (what the FFN unit sees of gate_up)"""
        a, e, S, _ = q
        outs = []
        for m in self.ix.halves(name):
            y = np.empty(m["rows"], np.float32)
            w = self.img[m["ch"]][m["off"]:m["off"] + m["rows"] * row_words(m["K"]) * 64]
            if _lib.q4h_mv(_P(w), m["rows"], m["K"], _P(a), _P(e), _P(S), _P(y)):
                raise RuntimeError(f"{name}: accumulator overflow")
            outs.append(y)
        y = np.concatenate(outs)
        return bf16_round(y) if self.packed and not raw else y

    def ffn_q(self, layer, q):
        """the FFN as the card's FFN unit does it: gate_up (float32) -> silu_mul_hw -> MXINT8 -> down"""
        hb = self.mv_q(f"{layer}.gate_up", q, raw=True)
        return self.mv_q(f"{layer}.down", quantize(pad_ffn(silu_mul_hw(hb[:FFN], hb[FFN:]))))


class FpgaBackend:
    name = "fpga"

    def __init__(self, index, link, check=None, packed=False):
        """packed: results come back as bfloat16 (half the JTAG reads; link.packed gateware); check must then be a
        CpuBackend(packed=True)"""
        self.ix, self.link, self.check, self.packed = index, link, check, packed
        self.mismatch = 0
        self.compared = 0
        self.ffn_retries = 0
        self.pad_zeroed = False

    def mv_q(self, name, q):
        self.link.set_activation(q[3])
        out = self._run(name)
        if self.check is not None:
            ref = self.check.mv_q(name, q)
            self.compared += out.size
            self.mismatch += int((ref.view(np.uint32) != out.view(np.uint32)).sum())
        return out

    def ffn_q(self, layer, q):
        """the whole FFN of a layer with the card's FFN unit: activations in, gate_up (one run of all 9728 rows per
        engine, results go to the FFN unit, not to the PC), down_proj on the activations the unit wrote; only
        down's results come back"""
        L = self.link
        h0, h1 = self.ix.halves(f"{layer}.gate_up")
        if FFN_K != FFN and not self.pad_zeroed:
            # the FFN unit writes only FFN activations (+ FFN/32 subgroup words); down_proj reads FFN_K: the rest of
            # the engines' activation buffers must hold exact zeros (a = 0, S = 0), so the padded weight columns
            # add nothing. Only K = FFN_K images write there, so once per backend is enough.
            L.set_activation(quantize(np.zeros(FFN_K, np.float32))[3])
            self.pad_zeroed = True
        # Rare FFN-unit failure (2026-11-03 soak on build_pcie4 @ 80 MHz: ~1 per 30,000 runs): its gate/up FIFO
        # overflows (err), the unit never finishes (busy stays 1). Re-arming resets it; the activations are sent
        # again because an overflowed run may have copied a wrong image into the engines. Exact either way (the
        # down results only use a run that ended without err).
        for attempt in range(3):
            L.set_activation(q[3])
            L.ffn_arm(h0["rows"])
            jobs = [(e, (W_OFF + h["off"]) // 64, h["rows"], h["K"]) for e, h in enumerate((h0, h1))]
            if hasattr(L, "start_pair"):                # PCIe: both starts back to back (see start_pair)
                L.start_pair(jobs)
            else:
                for j in jobs:
                    L.start(*j)
            try:
                L.wait(ffn=True, **({"timeout": 1.0} if hasattr(L, "run") else {}))
                break
            except (TimeoutError, RuntimeError):
                self.ffn_retries += 1
                if attempt == 2:
                    raise
                L.wait()                                # the engines themselves must be done before the re-run
        out = self._run(f"{layer}.down")
        if self.check is not None:
            ref = self.check.ffn_q(layer, q)
            self.compared += out.size
            self.mismatch += int((ref.view(np.uint32) != out.view(np.uint32)).sum())
        return out

    def _run(self, name):
        """both engines on their halves of matrix `name` with the activations already in place"""
        h0, h1 = self.ix.halves(name)
        rows, K = h0["rows"], h0["K"]
        assert h1["rows"] == rows and h1["K"] == K
        rw = row_words(K)
        n_runs = -(-rows // 8192)
        chunk = -(-rows // n_runs)
        L = self.link
        y = [np.empty(rows, np.float32), np.empty(rows, np.float32)]
        for r0 in range(0, rows, chunk):
            n = min(chunk, rows - r0)
            if hasattr(L, "run"):                  # PCIe: results read while the engines run (pcie_link.run)
                ys = L.run([(e, (W_OFF + h["off"] + r0 * rw * 64) // 64, n, K) for e, h in enumerate((h0, h1))],
                           packed=self.packed)
                for e in (0, 1):
                    y[e][r0:r0 + n] = ys[e]
                continue
            for e, h in enumerate((h0, h1)):
                L.start(e, (W_OFF + h["off"] + r0 * rw * 64) // 64, n, K)
            L.wait()
            for e in (0, 1):
                y[e][r0:r0 + n] = L.results(e, n, packed=self.packed)
        return np.concatenate(y)


class Model:
    def __init__(self, backend, ctx=2048, ffn_hw=False, ffn_fused=False):
        """ffn_hw: SiLU(gate) * up with the FPGA FFN unit's arithmetic (silu_mul_hw) instead of numpy's exp;
        ffn_fused: the whole FFN through backend.ffn_q (on the card's FFN unit; CpuBackend: same arithmetic)"""
        from export_q4h import SafeTensors
        self.be, self.ctx, self.ffn_hw, self.ffn_fused = backend, ctx, ffn_hw or ffn_fused, ffn_fused
        self.st = SafeTensors(os.path.join(HF_DIR, "model.safetensors"))
        m = self.st.meta["model.embed_tokens.weight"]
        a, b = m["data_offsets"]
        self.embed = np.asarray(self.st.raw[a:b]).view(np.float32).reshape(VOCAB, DIM)      # memmapped
        g = lambda n: self.st.get(n).astype(np.float32)
        self.norms = [dict(inp=g(f"model.layers.{l}.input_layernorm.weight"),
                           post=g(f"model.layers.{l}.post_attention_layernorm.weight"),
                           q=g(f"model.layers.{l}.self_attn.q_norm.weight"),
                           k=g(f"model.layers.{l}.self_attn.k_norm.weight")) for l in range(LAYERS)]
        self.final_norm = g("model.norm.weight")
        self.inv_freq = np.array([math.pow(THETA, -2.0 * i / HEAD_DIM) for i in range(HEAD_DIM // 2)], np.float32)
        self.kc = np.zeros((LAYERS, ctx, KV_HEADS, HEAD_DIM), np.float32)
        self.vc = np.zeros((LAYERS, ctx, KV_HEADS, HEAD_DIM), np.float32)
        self.pos = 0
        self.t_mv = 0.0

    @staticmethod
    def rmsnorm(x, w):
        ss = np.float32(np.dot(x.astype(np.float64), x.astype(np.float64)) / x.shape[-1])
        return x * (np.float32(1.0) / np.sqrt(ss + np.float32(EPS))) * w

    @staticmethod
    def rmsnorm_rows(x, w):                      # per row of [n, d]
        ss = (x.astype(np.float64) ** 2).mean(-1, keepdims=True).astype(np.float32)
        return x * (np.float32(1.0) / np.sqrt(ss + np.float32(EPS))) * w

    def mv(self, name, x):
        t = time.time()
        y = self.be.mv_q(name, quantize(x))
        self.t_mv += time.time() - t
        return y

    def rope(self, v, pos):                       # v [n, HEAD_DIM]: rotate pairs (2i, 2i+1) / HF (i, i + d/2)
        a = np.float32(pos) * self.inv_freq
        c, s = np.cos(a).astype(np.float32), np.sin(a).astype(np.float32)
        if ROPE_HALF:
            h = v.shape[1] // 2
            x1, x2 = v[:, :h].copy(), v[:, h:].copy()
            v[:, :h] = x1 * c - x2 * s
            v[:, h:] = x2 * c + x1 * s
            return
        e, o = v[:, 0::2].copy(), v[:, 1::2].copy()
        v[:, 0::2] = e * c - o * s
        v[:, 1::2] = e * s + o * c

    def forward(self, token, logits=True):
        pos = self.pos
        if pos >= self.ctx:
            raise RuntimeError("context full")
        x = np.array(self.embed[token], np.float32)
        grp, scale = HEADS // KV_HEADS, np.float32(1.0 / math.sqrt(HEAD_DIM))
        QD, KVD = HEADS * HEAD_DIM, KV_HEADS * HEAD_DIM
        for l in range(LAYERS):
            N = self.norms[l]
            qkv = self.mv(f"{l}.qkv", self.rmsnorm(x, N["inp"]))
            q = self.rmsnorm_rows(qkv[:QD].reshape(HEADS, HEAD_DIM), N["q"])
            k = self.rmsnorm_rows(qkv[QD:QD + KVD].reshape(KV_HEADS, HEAD_DIM), N["k"])
            v = qkv[QD + KVD:].reshape(KV_HEADS, HEAD_DIM)
            self.rope(q, pos)
            self.rope(k, pos)
            self.kc[l, pos], self.vc[l, pos] = k, v
            Kc, Vc = self.kc[l, :pos + 1], self.vc[l, :pos + 1]               # [T, 4, 128]
            qg = q.reshape(KV_HEADS, grp, HEAD_DIM)
            att = np.einsum("gjd,tgd->gjt", qg, Kc) * scale                  # [4, 7, T]
            att = np.exp(att - att.max(-1, keepdims=True))
            att /= att.sum(-1, keepdims=True)
            o = np.einsum("gjt,tgd->gjd", att, Vc).reshape(QD).astype(np.float32)
            x = x + self.mv(f"{l}.out", o)
            if self.ffn_fused:
                t = time.time()
                x = x + self.be.ffn_q(l, quantize(self.rmsnorm(x, N["post"])))
                self.t_mv += time.time() - t
                continue
            hb = self.mv(f"{l}.gate_up", self.rmsnorm(x, N["post"]))
            g, u = hb[:FFN], hb[FFN:]
            if self.ffn_hw:
                h = silu_mul_hw(g, u)
            else:
                with np.errstate(over="ignore"):
                    h = (g / (np.float32(1) + np.exp(-g))) * u
            x = x + self.mv(f"{l}.down", pad_ffn(h.astype(np.float32)))
        self.pos += 1
        if not logits:
            return None
        return self.mv("lm_head", self.rmsnorm(x, self.final_norm))


def sample(logits, seen, temp=0.7, top_p=0.9, rep=1.05, greedy=False, rng=None):
    lg = logits.astype(np.float32).copy()
    if seen:
        idx = np.fromiter(seen, int)
        v = lg[idx]
        lg[idx] = np.where(v > 0, v / rep, v * rep)
    if greedy:
        return int(np.argmax(lg))
    p = np.exp((lg - lg.max()) / temp)
    order = np.argsort(-p, kind="stable")
    ps = p[order]
    cum = np.cumsum(ps)
    k = int(np.searchsorted(cum, top_p * cum[-1]) + 1)
    ps = ps[:k] / ps[:k].sum()
    return int(order[(rng or np.random).choice(k, p=ps)])

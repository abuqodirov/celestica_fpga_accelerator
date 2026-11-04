#!/usr/bin/env python3
"""MustaqiLLM (NeuronLM, 5.17B, Apache-2.0) reference forward pass on the PC.

Written from the model's config and modeling code (read, not executed). Weights are memory-mapped from
model.safetensors and converted one matrix at a time, so the whole model is never in RAM (~1-2 GB peak).
--quant simulates the weight format planned for the FPGA (symmetric intN, one scale per --group weights
along the input dimension), so its quality cost can be measured before any hardware exists.

  ref.py chat "Salom! Qalaysiz?"   [--quant q4 --group 32] [--tokens 64] [--greedy] [--seed 1]
  ref.py eval text.txt             [--quant q4 --group 32] [--search] [--asym] [--max 512]
      next-token predictions of --quant vs the original bf16 weights on a text: KL divergence, top-1
      agreement, perplexity of both.

Architecture (per layer, pre-norm, no biases):
  h = RMSNorm(x); q,k,v = split(qkv_proj(h), 3584/512/512); q,k = RMSNorm per 128-wide head (q_norm/k_norm)
  q,k = RoPE (adjacent pairs, theta 500000); 28 query heads share 4 KV heads (7 each); x += out_proj(attn)
  h = RMSNorm(x); gate,up = halves of gate_up_proj(h); x += down_proj(silu(gate) * up)
then final RMSNorm and lm_head (untied). Chat format ChatML; <|im_end|> (id 5) ends a turn.
"""
import argparse
import json
import math
import os
import struct
import sys
import time

import numpy as np
import torch

HERE = os.path.dirname(os.path.abspath(__file__))
HF = os.path.join(HERE, "hf")
DIM, LAYERS, HEADS, KV_HEADS, HEAD_DIM, FFN, VOCAB = 3584, 36, 28, 4, 128, 9728, 48000
EPS, THETA, IM_START, IM_END = 1e-5, 500000.0, 4, 5


class SafeTensors:
    """Zero-copy access to the tensors of a .safetensors file."""

    def __init__(self, path):
        with open(path, "rb") as f:
            n = struct.unpack("<Q", f.read(8))[0]
            self.meta = json.loads(f.read(n))
        self.meta.pop("__metadata__", None)
        self.raw = np.memmap(path, dtype=np.uint8, mode="r", offset=8 + n)

    def get(self, name):
        m = self.meta[name]
        a, b = m["data_offsets"]
        if m["dtype"] == "BF16":
            u16 = self.raw[a:b].view(np.uint16).reshape(m["shape"])
            return torch.from_numpy((u16.astype(np.uint32) << 16).view(np.float32))
        assert m["dtype"] == "F32", m["dtype"]
        return torch.from_numpy(np.array(self.raw[a:b].view(np.float32).reshape(m["shape"])))


def quantize(w, bits, group, search=False, asym=False):
    """intN with one float scale per `group` consecutive inputs of each output row.
    Symmetric: q in [-2^(N-1), 2^(N-1)-1], w = q*s. asym: q in [0, 2^N-1], w = q*s + m (scale + offset).
    search: per group, try shrinking the range (clipping outliers) and keep the lowest squared error."""
    if not bits:
        return w
    out, inp = w.shape
    g = w.reshape(out, inp // group, group)
    best, best_err = None, None
    for f in ([1.0] if not search else [1.0, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7]):
        if asym:
            lo, hi = g.amin(-1, keepdim=True) * f, g.amax(-1, keepdim=True) * f
            s = ((hi - lo) / (2 ** bits - 1)).clamp_min(1e-12)
            r = torch.round((g - lo) / s).clamp(0, 2 ** bits - 1) * s + lo
        else:
            qmax = 2 ** (bits - 1) - 1
            s = (g.abs().amax(-1, keepdim=True) * f / qmax).clamp_min(1e-12)
            r = torch.round(g / s).clamp(-qmax - 1, qmax) * s
        err = (r - g).pow(2).sum(-1, keepdim=True)
        if best is None:
            best, best_err = r, err
        else:
            m = err < best_err
            best = torch.where(m, r, best); best_err = torch.where(m, err, best_err)
    return best.reshape(out, inp)


class Model:
    def __init__(self, bits=0, group=32, search=False, asym=False):
        self.st, self.bits, self.group = SafeTensors(os.path.join(HF, "model.safetensors")), bits, group
        self.search, self.asym = search, asym
        freq = THETA ** (-torch.arange(0, HEAD_DIM, 2, dtype=torch.float64) / HEAD_DIM)
        self.inv_freq = freq.float()

    def w(self, name, quant=True):
        t = self.st.get(name)
        return quantize(t, self.bits, self.group, self.search, self.asym) if quant and t.ndim == 2 else t

    @staticmethod
    def rmsnorm(x, w):
        return x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + EPS) * w

    def rope(self, x, pos):                                # x [n, heads, 128], pos [n]
        ang = pos[:, None].float() * self.inv_freq[None, :]
        cos, sin = ang.cos()[:, None, :], ang.sin()[:, None, :]
        e, o = x[..., 0::2], x[..., 1::2]
        return torch.stack((e * cos - o * sin, e * sin + o * cos), -1).flatten(-2)

    def forward(self, ids, cache, p0):
        """Logits for tokens ids at positions p0.. given the KV cache of positions < p0 (updated)."""
        n = len(ids)
        pos = torch.arange(p0, p0 + n)
        a = self.st.meta["model.embed_tokens.weight"]["data_offsets"][0]       # only the rows needed
        rows = np.stack([self.st.raw[a + 4 * DIM * t: a + 4 * DIM * (t + 1)].view(np.float32) for t in ids])
        x = torch.from_numpy(rows.copy())
        mask = torch.full((n, p0 + n), float("-inf")).triu(p0 + 1)
        for l in range(LAYERS):
            P = f"model.layers.{l}."
            h = self.rmsnorm(x, self.w(P + "input_layernorm.weight"))
            qkv = h @ self.w(P + "self_attn.qkv_proj.weight").T
            q = qkv[:, :DIM].reshape(n, HEADS, HEAD_DIM)
            k = qkv[:, DIM:DIM + 512].reshape(n, KV_HEADS, HEAD_DIM)
            v = qkv[:, DIM + 512:].reshape(n, KV_HEADS, HEAD_DIM)
            q = self.rope(self.rmsnorm(q, self.w(P + "self_attn.q_norm.weight")), pos)
            k = self.rope(self.rmsnorm(k, self.w(P + "self_attn.k_norm.weight")), pos)
            if l < len(cache):
                k = torch.cat((cache[l][0], k)); v = torch.cat((cache[l][1], v))
                cache[l] = (k, v)
            else:
                cache.append((k, v))
            kk = k.repeat_interleave(HEADS // KV_HEADS, dim=1)     # [T, 28, 128]
            vv = v.repeat_interleave(HEADS // KV_HEADS, dim=1)
            att = torch.einsum("nhd,thd->hnt", q, kk) / math.sqrt(HEAD_DIM) + mask
            o = torch.einsum("hnt,thd->nhd", att.softmax(-1), vv).reshape(n, DIM)
            x = x + o @ self.w(P + "self_attn.out_proj.weight").T
            h = self.rmsnorm(x, self.w(P + "post_attention_layernorm.weight"))
            gu = h @ self.w(P + "mlp.gate_up_proj.weight").T
            x = x + (torch.nn.functional.silu(gu[:, :FFN]) * gu[:, FFN:]) @ self.w(P + "mlp.down_proj.weight").T
        x = self.rmsnorm(x, self.w("model.norm.weight"))
        return x @ self.w("lm_head.weight").T


def tokenizer():
    from tokenizers import Tokenizer
    return Tokenizer.from_file(os.path.join(HF, "tokenizer.json"))


def chat(args, model):
    tok = tokenizer()
    ids = [IM_START] + tok.encode(f"user\n{args.text}", add_special_tokens=False).ids + [IM_END] \
        + tok.encode("\n", add_special_tokens=False).ids + [IM_START] \
        + tok.encode("assistant\n", add_special_tokens=False).ids
    g = torch.Generator().manual_seed(args.seed)
    cache, out, t0 = [], [], time.time()
    logits = model.forward(ids, cache, 0)[-1]
    print(f"[prompt {len(ids)} tokens: {time.time() - t0:.1f} s]", flush=True)
    seen = list(ids)
    for _ in range(args.tokens):
        lg = logits.clone()
        if args.rep != 1.0:                                 # HF-style repetition penalty over all seen tokens
            s = torch.tensor(sorted(set(seen)))
            lg[s] = torch.where(lg[s] > 0, lg[s] / args.rep, lg[s] * args.rep)
        if args.greedy:
            nxt = int(lg.argmax())
        else:
            p = (lg / args.temp).softmax(-1)
            sp, si = p.sort(descending=True)
            keep = sp.cumsum(0) - sp < args.top_p
            nxt = int(si[keep][torch.multinomial(sp[keep] / sp[keep].sum(), 1, generator=g)])
        if nxt == IM_END:
            break
        out.append(nxt); seen.append(nxt)
        sys.stdout.write("\r" + tok.decode(out)); sys.stdout.flush()
        logits = model.forward([nxt], cache, len(seen) - 1)[-1]
    dt = time.time() - t0
    print(f"\n[{len(out)} tokens in {dt:.0f} s]")


def evaluate(args):
    tok = tokenizer()
    ids = tok.encode(open(args.text).read(), add_special_tokens=False).ids[:args.max]
    tgt = torch.tensor(ids[1:])
    res = {}
    for name, bits in (("bf16", 0), (args.quant, int(args.quant[1:]))):
        t0 = time.time()
        lp = Model(bits, args.group, args.search, args.asym).forward(ids, [], 0)[:-1].log_softmax(-1)
        res[name] = lp
        ppl = math.exp(-lp.gather(1, tgt[:, None]).mean().item())
        print(f"{name:5s}: perplexity {ppl:8.3f} over {len(tgt)} tokens ({time.time() - t0:.0f} s)", flush=True)
    a, b = res["bf16"], res[args.quant]
    kl = (a.exp() * (a - b)).sum(-1)
    agree = (a.argmax(-1) == b.argmax(-1)).float().mean().item()
    print(f"{args.quant} group {args.group}{' search' if args.search else ''}{' asym' if args.asym else ''} vs bf16: mean KL {kl.mean():.4f} (max {kl.max():.3f}), "
          f"top-1 agreement {100 * agree:.1f}%")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=("chat", "eval"))
    ap.add_argument("text")
    ap.add_argument("--quant", default="q4", help="q4 / q8 (chat: q0 = original bf16)")
    ap.add_argument("--group", type=int, default=32)
    ap.add_argument("--search", action="store_true", help="per-group clipping search (lowest squared error)")
    ap.add_argument("--asym", action="store_true", help="scale + offset per group instead of scale only")
    ap.add_argument("--tokens", type=int, default=64)
    ap.add_argument("--max", type=int, default=512)
    ap.add_argument("--greedy", action="store_true")
    ap.add_argument("--temp", type=float, default=0.7)
    ap.add_argument("--top-p", type=float, default=0.9)
    ap.add_argument("--rep", type=float, default=1.05)
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args()
    torch.set_num_threads(os.cpu_count())
    if args.mode == "chat":
        chat(args, Model(int(args.quant[1:]), args.group, args.search, args.asym))
    else:
        evaluate(args)


if __name__ == "__main__":
    main()

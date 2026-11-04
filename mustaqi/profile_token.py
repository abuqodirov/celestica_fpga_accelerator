#!/usr/bin/env python3
"""Where the work and the time of one MustaqiLLM token go in the FPGA chat (fpga_chat.py).

  profile_token.py work            arithmetic + data moved per token, per kind of calculation (counted, instant)
  profile_token.py pc              the PC's share (norms, RoPE, attention, SiLU, MXINT8 quantize), measured with a
                                   do-nothing matvec backend at several context lengths (no board, ~20 s)
  profile_token.py ppl --results bf16|fp16|fp32 [--max 238] [--ffn hw]
                                   perplexity on eval_uz.txt of the exact FPGA arithmetic (CPU backend, bit-exact
                                   with the engines) when every engine result is rounded to 16 bits before it
                                   crosses the cable: is packing results into half the bytes free? (~8 min, heavy)
"""
import argparse
import cProfile
import math
import os
import pstats
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fpga_llm as F  # noqa: E402

# measured on the card (NOTES.md): engine 4.08 GB/s per DDR3 channel, loader writes 3.17 MB/s at 30 MHz TCK,
# result reads at 15 MHz TCK
ENGINE_BPS, WRITE_BPS, READ_TCK = 4.08e9, 3.17e6, 15e6
MATS = [("qkv", 4608, F.DIM), ("out", F.DIM, F.DIM), ("gate_up", 2 * F.FFN, F.DIM), ("down", F.DIM, F.FFN)]


def mat_work(rows, K):
    """per matrix x vector: MACs, DRAM bytes (both channels), activation bytes out, result bytes in, engine runs"""
    runs = -(-(rows // 2) // 8192)                      # per engine; result memory = 8192 rows per run
    return dict(mac=rows * K, dram=rows * F.row_words(K) * 64, act=2 * 9 * K // 8, res=rows * 4, runs=runs)


def work(args):
    rows = []
    for name, r, K in MATS:
        w = mat_work(r, K)
        rows.append((f"{name} ({r} x {K})", {k: v * F.LAYERS for k, v in w.items()}))
    rows.append((f"lm_head ({F.VOCAB} x {F.DIM})", mat_work(F.VOCAB, F.DIM)))
    tot = {k: sum(r[1][k] for r in rows) for k in rows[0][1]}
    print("Weight matrix x vector products per token (36 layers + lm_head), all on the FPGA engines:\n")
    print(f"{'matrix':28s} {'MACs':>9s} {'%':>5s} {'DRAM read':>10s} {'act. out':>9s} {'results in':>11s}")
    for name, w in rows + [("total", tot)]:
        print(f"{name:28s} {w['mac'] / 1e6:7.0f} M {100 * w['mac'] / tot['mac']:4.1f}% {w['dram'] / 1e6:7.0f} MB "
              f"{w['act'] / 1e6:6.2f} MB {w['res'] / 1e6:8.2f} MB")
    print(f"\n  arithmetic intensity: {tot['mac'] / tot['dram']:.2f} multiply-adds per DRAM byte (every weight is used "
          f"once per token)")
    print(f"\nEverything else per token (on the PC today), at context length T:")
    for T in args.ctx:
        att = F.LAYERS * F.HEADS * T * F.HEAD_DIM * 2
        kv = F.LAYERS * T * F.KV_HEADS * F.HEAD_DIM * 2 * 4
        print(f"  T={T:5d}: attention {att / 1e6:6.0f} M MACs ({100 * att / tot['mac']:4.1f}% of the weight MACs), "
              f"KV cache read {kv / 1e6:5.0f} MB (float32)")
    elem = F.LAYERS * (3 * F.DIM + 3 * F.DIM + 4608 + 2 * 32 * 64 * 3 + 3 * F.FFN) + 2 * F.DIM + F.VOCAB
    print(f"  norms, RoPE, SiLU, residual adds, quantize: ~{elem / 1e6:.1f} M element operations")

    # time model for today's chat (2 engines, JTAG: writes 30 MHz, reads 15 MHz)
    n_runs = tot["runs"]
    t_eng = tot["dram"] / (2 * ENGINE_BPS)
    t_wr = tot["act"] / WRITE_BPS
    t_rd = tot["res"] * 8 / READ_TCK
    print(f"\nTime model per token (FPGA chat today, measured total 3.7 s):")
    print(f"  engines stream {tot['dram'] / 2**30:.2f} GiB of weights          {t_eng:5.2f} s   (2 x {ENGINE_BPS / 1e9} GB/s)")
    print(f"  activations out over JTAG ({tot['act'] / 1e6:.2f} MB, 30 MHz) {t_wr:5.2f} s")
    print(f"  results in over JTAG ({tot['res'] / 1e6:.2f} MB, 15 MHz)      {t_rd:5.2f} s")
    print(f"  sum                                            {t_eng + t_wr + t_rd:5.2f} s   + {n_runs} engine runs x "
          f"(>= 3 USB round trips) + the PC's share (profile_token.py pc)")


class NullBackend:
    """returns zeros instantly: what remains of a forward pass is the PC's own work"""
    name = "null"

    def __init__(self, index):
        self.ix = index

    def mv_q(self, name, q):
        h0, _ = self.ix.halves(name)
        return np.zeros(2 * h0["rows"], np.float32)


def pc(args):
    model = F.Model(NullBackend(F.Index()), ctx=max(args.ctx) + 2)
    groups = [("MXINT8 quantize (C)", ("quantize", "q4h_quantize")), ("RMSNorm + QK-norm", ("rmsnorm", "rmsnorm_rows")),
              ("RoPE", ("rope",)), ("attention dot products", ("einsum",))]
    print("PC share of one token (do-nothing matvec backend; ms per token):")
    for T in args.ctx:
        model.pos = T
        model.forward(1)                                 # warm-up
        n = 5
        pr = cProfile.Profile()
        t0 = time.time()
        pr.enable()
        for _ in range(n):
            model.pos = T
            model.forward(1)
        pr.disable()
        total = (time.time() - t0) / n * 1e3
        st = pstats.Stats(pr).stats
        parts = []
        for label, fn in groups:
            t = sum(v[2] for k, v in st.items() if k[2] in fn or any(f in k[2] for f in fn if f == "einsum")) / n * 1e3
            parts.append(f"{label} {t:.0f}")
        print(f"  T={T:5d}: {total:5.0f} ms total (profiled) = " + ", ".join(parts) + ", rest (softmax, SiLU, adds)")


def ppl(args):
    from tokenizers import Tokenizer
    tok = Tokenizer.from_file(os.path.join(HERE, "hf", "tokenizer.json"))
    ids = tok.encode(open(os.path.join(HERE, "eval_uz.txt")).read(), add_special_tokens=False).ids[:args.max]
    cpu = F.CpuBackend(F.Index())
    amax = {}

    class Rounded:
        name = "cpu-rounded"

        def mv_q(self, name, q):
            y = cpu.mv_q(name, q)
            kind = name.split(".")[-1]
            amax[kind] = max(amax.get(kind, 0.0), float(np.abs(y).max()))
            if args.mats and kind not in args.mats:
                return y
            if args.results == "bf16":                    # round to nearest even, keep the top 16 bits
                return F.bf16_round(y)
            if args.results == "fp16":
                with np.errstate(over="ignore"):
                    return y.astype(np.float16).astype(np.float32)
            return y

    model = F.Model(Rounded(), ctx=len(ids) + 1, ffn_hw=args.ffn == "hw")
    nll, t0 = 0.0, time.time()
    for i in range(len(ids) - 1):
        lg = model.forward(ids[i]).astype(np.float64)
        m = lg.max()
        nll += m + math.log(np.exp(lg - m).sum()) - lg[ids[i + 1]]
        if (i + 1) % 20 == 0:
            print(f"  {i + 1}/{len(ids) - 1} tokens, ppl so far {math.exp(nll / (i + 1)):.3f}, "
                  f"{time.time() - t0:.0f} s", flush=True)
    n = len(ids) - 1
    print(f"results {args.results} ({','.join(args.mats) if args.mats else 'all matrices'}), SiLU {args.ffn}: perplexity {math.exp(nll / n):.3f} over {n} tokens ({time.time() - t0:.0f} s); "
          f"largest |result| per matrix: " + ", ".join(f"{k} {v:.0f}" for k, v in sorted(amax.items())))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    for c in ("work", "pc"):
        p = sub.add_parser(c)
        p.add_argument("--ctx", type=lambda s: [int(v) for v in s.split(",")], default=[16, 512, 2048])
    p = sub.add_parser("ppl")
    p.add_argument("--results", choices=("fp32", "bf16", "fp16"), default="bf16")
    p.add_argument("--max", type=int, default=238)
    p.add_argument("--mats", type=lambda s: s.split(","), default=None, help="round only these, e.g. qkv,gate_up")
    p.add_argument("--ffn", choices=("numpy", "hw"), default="numpy",
                   help="hw: SiLU(gate)*up with the FPGA FFN unit's arithmetic (fpga_llm.silu_mul_hw)")
    args = ap.parse_args()
    dict(work=work, pc=pc, ppl=ppl)[args.cmd](args)


if __name__ == "__main__":
    main()

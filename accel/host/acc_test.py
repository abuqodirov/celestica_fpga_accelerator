#!/usr/bin/env python3
"""Hardware test of the matvec engine with real MustaqiLLM weights, bit-exact against the golden model.

  acc_test.py prep [--rows N] [--vecs V]   layer-0 qkv_proj (first N rows, default all 4608) + the input RMSNorm
                                   of V real tokens -> golden q4h_tool -> data/qkv.{q4h,act,exp}
  acc_test.py run [--rows N] [--vecs V]   (SoC with YPCB_JTAGLOAD + YPCB_ACCEL=B, V <= B) upload weights to DDR3 at
                                   0x48000000 (CRC-checked; the BIOS crc also flushes the L2 cache), load the
                                   activation buffer, run, compare every result bit for bit, report bandwidth.
env YPCB_BUILD = the SoC build directory (default litex/build_acc)."""
import argparse
import os
import struct
import subprocess
import sys
import time
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
os.environ.setdefault("YPCB_BUILD", os.path.join(ROOT, "litex", "build_acc"))
sys.path.insert(0, os.path.join(ROOT, "litex"))
sys.path.insert(0, os.path.join(ROOT, "llm"))
DATA = os.path.join(HERE, "data")
DRAM_CPU, W_ADDR, ACT_ADDR = 0x40000000, 0x48000000, 0xC0000000
RES_ADDR = ACT_ADDR + (1 << 17) * 4
K, SYS_HZ = 3584, 75e6


def name(vecs):                                # data/qkv.* for one vector, data/qkv<V>.* for V vectors
    return "qkv" if vecs == 1 else f"qkv{vecs}"


def prep(rows, vecs):
    sys.path.insert(0, os.path.join(ROOT, "mustaqi"))
    import numpy as np
    from ref import DIM, Model, tokenizer
    os.makedirs(DATA, exist_ok=True)
    m = Model()
    toks = tokenizer().encode("Salom! O'zbekiston haqida gapirib bering", add_special_tokens=False).ids[:vecs]
    a = m.st.meta["model.embed_tokens.weight"]["data_offsets"][0]
    import torch
    x0 = torch.from_numpy(np.stack([m.st.raw[a + 4 * DIM * t: a + 4 * DIM * (t + 1)].view(np.float32) for t in toks]).copy())
    x = m.rmsnorm(x0, m.w("model.layers.0.input_layernorm.weight"))
    w = m.w("model.layers.0.self_attn.qkv_proj.weight", quant=False)[:rows]
    w.numpy().astype(np.float32).tofile(os.path.join(DATA, "w.f32"))
    x.numpy().astype(np.float32).tofile(os.path.join(DATA, "x.f32"))
    subprocess.run([os.path.join(ROOT, "accel", "golden", "q4h_tool"), str(K), str(rows), os.path.join(DATA, "w.f32"),
                    os.path.join(DATA, "x.f32"), os.path.join(DATA, name(vecs)), str(vecs)], check=True)


def run(rows, vecs):
    from bios import Bios, csr
    from chat import upload
    q4h = open(os.path.join(DATA, name(vecs) + ".q4h"), "rb").read()
    act = open(os.path.join(DATA, name(vecs) + ".act"), "rb").read()
    allexp = open(os.path.join(DATA, name(vecs) + ".exp"), "rb").read()
    nv_file = len(allexp) // 4 // (len(q4h) // (30 * 64))
    assert vecs <= nv_file, f"data has {nv_file} vectors, prep with --vecs {vecs}"
    exp = [struct.unpack_from("<I", allexp, 4 * (r * nv_file + v)) [0] for r in range(rows) for v in range(vecs)]
    ng = K // 128
    rw = (ng + 15) // 16 + ng
    q4h = q4h[:rows * rw * 64]
    b = Bios(freq=15e6); b.sync(); b.drain(1.0)
    t = time.time()
    upload(b, W_ADDR, q4h)
    out = b.cmd(f"crc 0x{W_ADDR:08x} {len(q4h)}", timeout=120)
    got = int(out.split()[-1], 16)
    print(f"weights {len(q4h)} B uploaded in {time.time() - t:.1f} s, crc {'OK' if got == zlib.crc32(q4h) else 'MISMATCH'}")
    aw = K + K // 32 * 4                                           # activation image bytes per vector
    for v in range(vecs):
        win = ACT_ADDR + (v << 14) * 4                             # window word address: vector in bits 15:14
        upload(b, win, act[v * aw:v * aw + K])                     # a: K/4 words at engine address 0..
        upload(b, win + 0x1000 * 4, act[v * aw + K:(v + 1) * aw])  # {e, S}: engine address 0x1000 + subgroup
    b.write(csr("mvacc_base"), (W_ADDR - DRAM_CPU) // 64)
    b.write(csr("mvacc_nwords"), rows * rw)
    b.write(csr("mvacc_ng"), ng)
    b.write(csr("mvacc_nrows"), rows)
    b.write(csr("mvacc_start"), 1)
    t0 = time.time()
    while True:
        st = b.read(csr("mvacc_status"))[0]
        if st & 2 or time.time() - t0 > 10:
            break
    cyc, nrow = b.read(csr("mvacc_cycles"))[0], b.read(csr("mvacc_rows"))[0]
    print(f"status busy={st & 1} done={st >> 1 & 1} overflow={st >> 2 & 1}, rows {nrow}/{rows}, {cyc} cycles")
    if cyc:
        nbytes = rows * rw * 64
        print(f"  {nbytes / 1e6:.2f} MB in {cyc / SYS_HZ * 1e3:.2f} ms = {nbytes / (cyc / SYS_HZ) / 1e9:.2f} GB/s "
              f"({rows * rw / cyc * 100:.1f}% of one 64-byte word per clock)")
    res = [0] * (rows * vecs)
    for v in range(vecs):
        for off in range(0, rows, 256):
            vals = b.read(RES_ADDR + ((v << 14) + off) * 4, min(256, rows - off))
            for i, x in enumerate(vals):
                res[(off + i) * vecs + v] = x
    bad = [i for i in range(rows * vecs) if res[i] != exp[i]]
    f = lambda u: struct.unpack("<f", struct.pack("<I", u))[0]
    for i in bad[:8]:
        print(f"  row {i // vecs} vec {i % vecs}: engine {res[i]:08x} ({f(res[i]):.7g}) golden {exp[i]:08x} ({f(exp[i]):.7g})")
    print(f"{rows} rows x {vecs} vectors: {'BIT-EXACT' if not bad else f'{len(bad)} MISMATCHES'}")
    b.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=("prep", "run"))
    ap.add_argument("--rows", type=int, default=4608)
    ap.add_argument("--vecs", type=int, default=1)
    args = ap.parse_args()
    prep(args.rows, args.vecs) if args.mode == "prep" else run(args.rows, args.vecs)


if __name__ == "__main__":
    main()

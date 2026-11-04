#!/usr/bin/env python3
"""Real MustaqiLLM test vectors for the matvec engine testbench (accel/sim/tb --real <file>).
File: int32 K, int32 rows, int32 nvec, float32 w[rows][K], float32 x[nvec][K]   (the testbench quantizes both
with golden.h, exactly as the hardware export will).
  qkv.bin  : layer-0 qkv_proj rows (Q 0..127, K 3584..3647, V 4096..4159), x = input RMSNorm of 4 real tokens
  down.bin : layer-0 down_proj rows 0..127 (K = 9728), x = silu(gate)*up of those tokens (MLP input, outliers)
usage: accel_vectors.py <out dir>"""
import os
import sys

import numpy as np
import torch

from ref import DIM, FFN, HF, Model, tokenizer


def write(path, w, x):
    with open(path, "wb") as f:
        np.array([w.shape[1], w.shape[0], x.shape[0]], np.int32).tofile(f)
        w.astype(np.float32).tofile(f)
        x.astype(np.float32).tofile(f)
    print(f"{path}: K {w.shape[1]}, {w.shape[0]} rows, {x.shape[0]} vectors, |x| max {np.abs(x).max():.1f}")


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    m = Model()
    ids = tokenizer().encode("Salom! O'zbekiston haqida", add_special_tokens=False).ids[:4]
    a = m.st.meta["model.embed_tokens.weight"]["data_offsets"][0]
    x0 = torch.from_numpy(np.stack([m.st.raw[a + 4 * DIM * t: a + 4 * DIM * (t + 1)].view(np.float32) for t in ids]).copy())
    P = "model.layers.0."
    h = m.rmsnorm(x0, m.w(P + "input_layernorm.weight"))
    qkv = m.w(P + "self_attn.qkv_proj.weight", quant=False)
    rows = list(range(0, 128)) + list(range(DIM, DIM + 64)) + list(range(DIM + 512, DIM + 576))
    write(os.path.join(out, "qkv.bin"), qkv[rows].numpy(), h.numpy())
    h2 = m.rmsnorm(x0, m.w(P + "post_attention_layernorm.weight"))
    gu = h2 @ m.w(P + "mlp.gate_up_proj.weight", quant=False).T
    act = torch.nn.functional.silu(gu[:, :FFN]) * gu[:, FFN:]
    write(os.path.join(out, "down.bin"), m.w(P + "mlp.down_proj.weight", quant=False)[:128].numpy(), act.numpy())


if __name__ == "__main__":
    main()

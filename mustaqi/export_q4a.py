#!/usr/bin/env python3
"""Export MustaqiLLM to the "Q4A" file read by the C reference (and later streamed by the FPGA).

Q4A matrix [rows, cols]: rows x (cols/32) blocks of 20 bytes, row-major, one block per 32 consecutive inputs:
    fp16 scale s, fp16 offset lo, 16 bytes of 4-bit codes q (byte k: element 2k in the low nibble, 2k+1 high)
    weight = q * s + lo,  q in 0..15,  s = (max - min) / 15, lo = min of the group  (5 bits per weight)
File: 256-byte header (magic "MQ4A", version, config), then, each tensor 64-byte aligned:
    embed fp16 [vocab, dim]
    per layer: input_norm f32[dim], qkv Q4A[4608, dim], q_norm f32[128], k_norm f32[128], out Q4A[dim, dim],
               post_norm f32[dim], gate_up Q4A[2*ffn, dim] (gate rows first), down Q4A[dim, ffn]
    final norm f32[dim], lm_head Q4A[vocab, dim]
usage: export_q4a.py [out.bin]      (reads hf/model.safetensors one tensor at a time)"""
import os
import struct
import sys
import time

import numpy as np
import torch

from ref import DIM, EPS, FFN, HEAD_DIM, HEADS, HF, KV_HEADS, LAYERS, THETA, VOCAB, SafeTensors

GROUP, MAXCTX = 32, 4096


def q4a(w):
    """[rows, cols] float32 -> bytes of 20-byte blocks (fp16 s, fp16 lo, 16 B codes) in row order."""
    rows, cols = w.shape
    g = w.reshape(rows, cols // GROUP, GROUP)
    lo, hi = g.amin(-1, keepdim=True), g.amax(-1, keepdim=True)
    s16, lo16 = ((hi - lo) / 15).half(), lo.half()       # the codes are chosen against the fp16 values stored
    s, lo = s16.float().clamp_min(1e-12), lo16.float()
    q = torch.round((g - lo) / s).clamp(0, 15).to(torch.uint8)
    codes = (q[..., 0::2] | (q[..., 1::2] << 4)).numpy()  # [rows, groups, 16]
    blk = np.empty((rows, cols // GROUP, 20), np.uint8)
    blk[..., 0:2] = s16.numpy().view(np.uint8).reshape(rows, cols // GROUP, 2)
    blk[..., 2:4] = lo16.numpy().view(np.uint8).reshape(rows, cols // GROUP, 2)
    blk[..., 4:] = codes
    return blk.tobytes()


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "out",
                                                               "mustaqi_q4a.bin")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    st, t0 = SafeTensors(os.path.join(HF, "model.safetensors")), time.time()
    with open(out + ".part", "wb") as f:
        hdr = struct.pack("<4sIIIIIIIIIIff", b"MQ4A", 1, DIM, LAYERS, HEADS, KV_HEADS, HEAD_DIM, FFN, VOCAB, GROUP,
                          MAXCTX, THETA, EPS)
        f.write(hdr.ljust(256, b"\0"))

        def put(data):
            f.write(data)
            f.write(b"\0" * (-f.tell() % 64))

        put(st.get("model.embed_tokens.weight").half().numpy().tobytes())
        for l in range(LAYERS):
            P = f"model.layers.{l}."
            put(st.get(P + "input_layernorm.weight").numpy().tobytes())
            put(q4a(st.get(P + "self_attn.qkv_proj.weight")))
            put(st.get(P + "self_attn.q_norm.weight").numpy().tobytes())
            put(st.get(P + "self_attn.k_norm.weight").numpy().tobytes())
            put(q4a(st.get(P + "self_attn.out_proj.weight")))
            put(st.get(P + "post_attention_layernorm.weight").numpy().tobytes())
            put(q4a(st.get(P + "mlp.gate_up_proj.weight")))
            put(q4a(st.get(P + "mlp.down_proj.weight")))
            print(f"layer {l + 1}/{LAYERS}  {f.tell() / 2**30:.2f} GiB  {time.time() - t0:.0f} s", flush=True)
        put(st.get("model.norm.weight").numpy().tobytes())
        put(q4a(st.get("lm_head.weight")))
    os.replace(out + ".part", out)
    print(f"wrote {out}: {os.path.getsize(out) / 2**30:.2f} GiB in {time.time() - t0:.0f} s")


if __name__ == "__main__":
    main()

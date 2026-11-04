#!/usr/bin/env python3
"""Export NeuronUz/NeuronLM-103M-SFT-v1 (hf/, Qwen3: 16 layers, d 640, FFN 1728, 10 query / 5 KV heads of 64, vocab
48000, tied embeddings) in the FPGA engine's Q4H format, like ../mustaqi/export_q4h.py does for MustaqiLLM: two DRAM
images, one per DDR3 channel, each holding half of every matrix's rows (both engines work on every matrix):

    per layer   ch0: qkv rows 0..639 (= q_proj),         out rows 0..319,   gate (gate_up rows 0..1727),     down rows 0..319
                ch1: qkv rows 640..1279 (= k_proj, v_proj), out rows 320..639, up (gate_up rows 1728..3455), down rows 320..639
    then        ch0: lm_head rows 0..23999,  ch1: lm_head rows 24000..47999   (lm_head = model.embed_tokens: tied)

down_proj has K = 1728, not a multiple of the engines' 128-input groups: it is stored with K = 1792. The 64 padding
columns repeat the same row's columns 1664..1727 (the rest of that 128-group), so the group's min / max - and with it
the quantization of the 64 real weights - is exactly what a 64-wide group would give; on the card the matching
activations are exact zeros (fpga_llm.pad_ffn / FpgaBackend.ffn_q), so the padding adds exactly nothing.
The images go 1.5 GiB into each channel (fpga_llm.MODELS["neuronlm"]["W_OFF"]), above MustaqiLLM's.
Quantizer: --search (default) picks each 128-group's range [lo, hi] by trying clipped ranges (both ends pulled in by
0..24 % of the span, 7 x 7 grid, fp16 rounding of scale/offset included) and keeping the one with the least squared
weight error; --minmax = plain min/max like MustaqiLLM's export (golden.h q4h_quantize_row). Same Q4H format either
way: the engines and the PC reference (q4h_lib) just read the scale / offset / codes.
Output: out/q4h_ch0.bin, out/q4h_ch1.bin, out/q4h_index.json (same format as MustaqiLLM's).
usage: export_q4h_neuron.py [--minmax]"""
import json
import os
import sys
import time
import zlib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "mustaqi"))
from export_q4h import SafeTensors, q4h  # noqa: E402

OUT = os.path.join(HERE, "out")
DIM, LAYERS, FFN, FFN_K, VOCAB, HEADS, KV_HEADS, HEAD_DIM = 640, 16, 1728, 1792, 48000, 10, 5, 64
CHUNK = 16 << 20
SHRINK = np.array([0, 0.02, 0.04, 0.07, 0.11, 0.16, 0.24], np.float32)


def q4h_search(w):
    """[rows, K] float32 -> Q4H bytes, per-group range chosen by least squared error (see the docstring)"""
    rows, K = w.shape
    ng, sw = K // 128, (K // 128 + 15) // 16
    g = w.reshape(rows * ng, 128)
    lo0, hi0 = g.min(-1), g.max(-1)
    span = hi0 - lo0
    best_err = np.full(rows * ng, np.inf, np.float64)
    best_s16 = np.zeros(rows * ng, np.float16)
    best_l16 = np.zeros(rows * ng, np.float16)
    best_q = np.zeros((rows * ng, 128), np.uint8)
    for a in SHRINK:
        for b in SHRINK:
            lo, hi = lo0 + a * span, hi0 - b * span
            s16 = ((hi - lo) / np.float32(15)).astype(np.float16)
            l16 = lo.astype(np.float16)
            s, l = s16.astype(np.float32)[:, None], l16.astype(np.float32)[:, None]
            with np.errstate(divide="ignore", invalid="ignore"):
                q = np.where(s > 0, np.rint((g - l) / s), 0)
            q = np.clip(q, 0, 15)
            err = ((q * s + l - g).astype(np.float64) ** 2).sum(-1)
            better = err < best_err
            best_err[better], best_s16[better], best_l16[better] = err[better], s16[better], l16[better]
            best_q[better] = q[better].astype(np.uint8)
    assert np.isfinite(best_s16.astype(np.float32)).all() and np.isfinite(best_l16.astype(np.float32)).all()
    out = np.zeros((rows, sw + ng, 64), np.uint8)
    sc = out[:, :sw].reshape(rows, sw * 16, 4)
    sc[:, :ng, 0:2] = best_s16.view(np.uint8).reshape(rows, ng, 2)
    sc[:, :ng, 2:4] = best_l16.view(np.uint8).reshape(rows, ng, 2)
    q = best_q.reshape(rows, ng, 128)
    out[:, sw:] = q[..., 0::2] | (q[..., 1::2] << 4)
    return out.tobytes()


def main():
    os.makedirs(OUT, exist_ok=True)
    st, t0 = SafeTensors(os.path.join(HERE, "hf", "model.safetensors")), time.time()
    f = [open(os.path.join(OUT, f"q4h_ch{c}.bin.part"), "wb") for c in (0, 1)]
    index = {"layout": __doc__.split("\n\n")[1], "mats": {}}

    def put(name, ch, w):
        assert w.dtype == np.float32 and w.shape[1] % 128 == 0, (name, w.shape)
        index["mats"][name] = dict(ch=ch, off=f[ch].tell(), rows=w.shape[0], K=w.shape[1])
        f[ch].write((q4h if "--minmax" in sys.argv else q4h_search)(np.ascontiguousarray(w)))

    for l in range(LAYERS):
        P = f"model.layers.{l}."
        q = st.get(P + "self_attn.q_proj.weight")
        kv = np.concatenate([st.get(P + "self_attn.k_proj.weight"), st.get(P + "self_attn.v_proj.weight")])
        assert q.shape == (HEADS * HEAD_DIM, DIM) and kv.shape == (2 * KV_HEADS * HEAD_DIM, DIM)
        o = st.get(P + "self_attn.o_proj.weight")
        gate, up = st.get(P + "mlp.gate_proj.weight"), st.get(P + "mlp.up_proj.weight")
        down = st.get(P + "mlp.down_proj.weight")
        assert down.shape == (DIM, FFN)
        # last 128-group = real columns 1664..1727 + padding: repeat those 64 columns (group min / max unchanged)
        assert FFN % 128 == 64 and FFN_K - FFN == 64
        down = np.concatenate([down, down[:, FFN - 64:FFN]], axis=1)
        assert down.shape == (DIM, FFN_K)
        put(f"{l}.qkv.0", 0, q)
        put(f"{l}.qkv.1", 1, kv)
        for ch in (0, 1):
            put(f"{l}.out.{ch}", ch, o[ch * DIM // 2:(ch + 1) * DIM // 2])
        put(f"{l}.gate_up.0", 0, gate)
        put(f"{l}.gate_up.1", 1, up)
        for ch in (0, 1):
            put(f"{l}.down.{ch}", ch, down[ch * DIM // 2:(ch + 1) * DIM // 2])
    emb = st.get("model.embed_tokens.weight")
    assert emb.shape == (VOCAB, DIM) and "lm_head.weight" not in st.meta
    for ch in (0, 1):
        put(f"lm_head.{ch}", ch, emb[ch * VOCAB // 2:(ch + 1) * VOCAB // 2])
    for c in (0, 1):
        f[c].close()
        p = os.path.join(OUT, f"q4h_ch{c}.bin")
        os.replace(p + ".part", p)
        crcs = []
        with open(p, "rb") as g:
            while True:
                b = g.read(CHUNK)
                if not b:
                    break
                crcs.append(zlib.crc32(b))
        index[f"ch{c}"] = dict(size=os.path.getsize(p), chunk=CHUNK, crc=crcs)
    json.dump(index, open(os.path.join(OUT, "q4h_index.json"), "w"), indent=1)
    print(f"wrote ch0 {index['ch0']['size'] / 2**20:.1f} MiB, ch1 {index['ch1']['size'] / 2**20:.1f} MiB, "
          f"{len(index['mats'])} matrices in {time.time() - t0:.0f} s")


if __name__ == "__main__":
    main()

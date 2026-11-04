#!/usr/bin/env python3
"""Export MustaqiLLM's matrices in the FPGA engine's Q4H format (accel/golden/golden.h), as two DRAM images, one
per DDR3 channel, so both matvec engines work on every matrix at once (each holds half of the rows):

    per layer   ch0: qkv rows 0..2303,    out rows 0..1791,    gate (gate_up rows 0..9727),     down rows 0..1791
                ch1: qkv rows 2304..4607, out rows 1792..3583, up   (gate_up rows 9728..19455), down rows 1792..3583
    then        ch0: lm_head rows 0..23999,  ch1: lm_head rows 24000..47999

Q4H row of K inputs: ceil(K/128/16) scale words + K/128 code words, 64 bytes each; per 128 inputs an fp16 scale s
and fp16 offset lo, weight = q*s + lo, q in 0..15 (asymmetric, s = (max-min)/15 and lo = min, the codes chosen
against the fp16 values) - the same quantizer as golden.h q4h_quantize_row, so layer 0's qkv equals
accel/host/data/qkv.q4h byte for byte (checked at the end).
Everything else the PC needs (embedding, norm weights) is read from hf/model.safetensors at run time.
Output: out/q4h_ch0.bin, out/q4h_ch1.bin, out/q4h_index.json (matrix -> channel, byte offset, rows, K, CRC32
per 16 MiB chunk of each image).
usage: export_q4h.py"""
import json
import os
import struct
import time
import zlib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
DIM, LAYERS, FFN, VOCAB, QKV = 3584, 36, 9728, 48000, 4608
CHUNK = 16 << 20


class SafeTensors:
    def __init__(self, path):
        with open(path, "rb") as f:
            n = struct.unpack("<Q", f.read(8))[0]
            self.meta = json.loads(f.read(n))
        self.meta.pop("__metadata__", None)
        self.raw = np.memmap(path, dtype=np.uint8, mode="r", offset=8 + n)

    def get(self, name, rows=None):
        """float32 tensor (bf16 widened exactly); rows = (r0, r1) reads only those rows of a matrix"""
        m = self.meta[name]
        a, b = m["data_offsets"]
        shape = m["shape"]
        es = 2 if m["dtype"] == "BF16" else 4
        if rows is not None:
            rb = int(np.prod(shape[1:])) * es
            a, b, shape = a + rows[0] * rb, a + rows[1] * rb, [rows[1] - rows[0]] + shape[1:]
        if m["dtype"] == "BF16":
            u16 = np.asarray(self.raw[a:b]).view(np.uint16).reshape(shape)
            return (u16.astype(np.uint32) << 16).view(np.float32)
        assert m["dtype"] == "F32", m["dtype"]
        return np.asarray(self.raw[a:b]).view(np.float32).reshape(shape).copy()


def q4h(w):
    """[rows, K] float32 -> bytes of Q4H rows (golden.h q4h_quantize_row, vectorized)"""
    rows, K = w.shape
    ng, sw = K // 128, (K // 128 + 15) // 16
    g = w.reshape(rows, ng, 128)
    lo, hi = g.min(-1), g.max(-1)
    s16 = ((hi - lo) / np.float32(15)).astype(np.float16)          # float32 divide, round to nearest-even fp16
    lo16 = lo.astype(np.float16)
    assert np.isfinite(s16).all() and np.isfinite(lo16).all()
    s, l = s16.astype(np.float32)[..., None], lo16.astype(np.float32)[..., None]
    with np.errstate(divide="ignore", invalid="ignore"):
        q = np.where(s > 0, np.rint((g - l) / s), 0)                  # rint = round half to even, like lrintf
    q = np.clip(q, 0, 15).astype(np.uint8)
    out = np.zeros((rows, sw + ng, 64), np.uint8)
    sc = out[:, :sw].reshape(rows, sw * 16, 4)
    sc[:, :ng, 0:2] = s16.view(np.uint8).reshape(rows, ng, 2)
    sc[:, :ng, 2:4] = lo16.view(np.uint8).reshape(rows, ng, 2)
    out[:, sw:] = q[..., 0::2] | (q[..., 1::2] << 4)
    return out.tobytes()


def main():
    os.makedirs(OUT, exist_ok=True)
    st, t0 = SafeTensors(os.path.join(HERE, "hf", "model.safetensors")), time.time()
    f = [open(os.path.join(OUT, f"q4h_ch{c}.bin.part"), "wb") for c in (0, 1)]
    index = {"layout": __doc__.split("\n\n")[1], "mats": {}}

    def put(name, ch, tensor, r0, r1):
        w = st.get(tensor, (r0, r1))
        index["mats"][name] = dict(ch=ch, off=f[ch].tell(), rows=r1 - r0, K=w.shape[1])
        f[ch].write(q4h(w))

    for l in range(LAYERS):
        P = f"model.layers.{l}."
        for ch in (0, 1):
            put(f"{l}.qkv.{ch}", ch, P + "self_attn.qkv_proj.weight", ch * QKV // 2, (ch + 1) * QKV // 2)
            put(f"{l}.out.{ch}", ch, P + "self_attn.out_proj.weight", ch * DIM // 2, (ch + 1) * DIM // 2)
            put(f"{l}.gate_up.{ch}", ch, P + "mlp.gate_up_proj.weight", ch * FFN, (ch + 1) * FFN)
            put(f"{l}.down.{ch}", ch, P + "mlp.down_proj.weight", ch * DIM // 2, (ch + 1) * DIM // 2)
        print(f"layer {l + 1}/{LAYERS}  ch0 {f[0].tell() / 2**30:.2f} GiB  ch1 {f[1].tell() / 2**30:.2f} GiB  "
              f"{time.time() - t0:.0f} s", flush=True)
    for ch in (0, 1):
        put(f"lm_head.{ch}", ch, "lm_head.weight", ch * VOCAB // 2, (ch + 1) * VOCAB // 2)
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
    print(f"wrote ch0 {index['ch0']['size'] / 2**30:.3f} GiB, ch1 {index['ch1']['size'] / 2**30:.3f} GiB "
          f"in {time.time() - t0:.0f} s")

    # cross-check against the golden quantizer's file (layer 0 qkv, all 4608 rows, from accel/golden/q4h_tool)
    ref = open(os.path.join(HERE, "..", "accel", "host", "data", "qkv.q4h"), "rb").read()
    mine = b""
    for ch in (0, 1):
        m = index["mats"][f"0.qkv.{ch}"]
        with open(os.path.join(OUT, f"q4h_ch{ch}.bin"), "rb") as g:
            g.seek(m["off"])
            mine += g.read(m["rows"] * 30 * 64)
    print("layer 0 qkv vs golden q4h_tool:", "IDENTICAL" if mine == ref else
          f"DIFFERENT ({len(mine)} vs {len(ref)} B, first diff at "
          f"{next((i for i in range(min(len(mine), len(ref))) if mine[i] != ref[i]), None)})")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""NeuronLM-103M: original float32 weights (ref_neuron.Ref, PyTorch) vs the card (Q4H weights + MXINT8 activations,
engines + FFN unit, bfloat16 results; needs the card on a build_pcie* design with the NeuronLM weights uploaded).
  1. perplexity + top-1 agreement on ../mustaqi/eval_uz.txt (first N tokens)
  2. greedy answers to chat questions, float32 vs card
usage: quality.py [N tokens, default 238] [--cpu]"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "mustaqi"))
import fpga_llm as F  # noqa: E402
import pcie_link as P  # noqa: E402
from ref_neuron import Ref  # noqa: E402
from tokenizers import Tokenizer  # noqa: E402

F.use_model("neuronlm")
tok = Tokenizer.from_file(os.path.join(HERE, "hf", "tokenizer.json"))
enc = lambda s: tok.encode(s, add_special_tokens=False).ids


def nll_of(lg, nxt):
    lg = lg.astype(np.float64)
    m = lg.max()
    return m + math.log(np.exp(lg - m).sum()) - lg[nxt]


def main():
    N = int(next((a for a in sys.argv[1:] if a.isdigit()), 238))
    ids = enc(open(os.path.join(HERE, "..", "mustaqi", "eval_uz.txt")).read())[:N]
    ref = Ref()
    ix = F.Index()
    if "--cpu" in sys.argv:          # the PC's bit-exact copy of the card's arithmetic (c/q4h_lib), no card needed
        L = None
        card = lambda: F.Model(F.CpuBackend(ix, packed=True), ctx=1024, ffn_fused=True)
    else:
        L = P.PcieLink()
        card = lambda: F.Model(F.FpgaBackend(ix, L, packed=L.packed), ctx=1024, ffn_fused=True)

    lg_ref = ref.logits(ids)
    m = card()
    nr = nc = 0.0
    agree = 0
    for i in range(len(ids) - 1):
        lg = m.forward(ids[i])
        nr += nll_of(lg_ref[i], ids[i + 1])
        nc += nll_of(lg, ids[i + 1])
        agree += int(lg.argmax() == lg_ref[i].argmax())
    n = len(ids) - 1
    print(f"eval_uz.txt, {n} predicted tokens: perplexity float32 {math.exp(nr / n):.2f}, card {math.exp(nc / n):.2f}; "
          f"most likely next token the same {agree}/{n} ({agree / n * 100:.1f} %)", flush=True)

    for q in ("Salom! O'zbekistonning poytaxti qaysi shahar?", "Menga Samarqand haqida qisqacha gapirib ber.",
              "3 + 2 nechaga teng?"):
        prompt = [F.IM_START] + enc(f"user\n{q}") + [F.IM_END] + enc("\n") + [F.IM_START] + enc("assistant\n")
        outs = {}
        # float32: whole-sequence forward each step (greedy, no repetition penalty, like the chat's default rep=1.05
        # is NOT applied here: plain argmax on both sides)
        seq = list(prompt)
        for _ in range(60):
            nx = int(ref.logits(seq)[-1].argmax())
            if nx == F.IM_END:
                break
            seq.append(nx)
        outs["float32"] = seq[len(prompt):]
        m = card()
        for t in prompt:
            lg = m.forward(t)
        got = []
        for _ in range(60):
            nx = int(lg.argmax())
            if nx == F.IM_END:
                break
            got.append(nx)
            lg = m.forward(nx)
        outs["card"] = got
        same = next((i for i in range(min(len(got), len(outs["float32"]))) if got[i] != outs["float32"][i]),
                    min(len(got), len(outs["float32"])))
        print(f"\nQ: {q}\n  float32: {tok.decode(outs['float32'])!r}\n  card:    {tok.decode(got)!r}\n"
              f"  identical for the first {same} tokens (float32 {len(outs['float32'])}, card {len(got)})", flush=True)
    if L:
        L.close()


if __name__ == "__main__":
    main()

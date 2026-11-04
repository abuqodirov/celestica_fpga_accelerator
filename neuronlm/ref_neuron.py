#!/usr/bin/env python3
"""Float32 reference for NeuronLM-103M (HF Qwen3 semantics, written independently of ../mustaqi/fpga_llm.py in torch):
whole-sequence forward with a causal mask, rotate_half RoPE, per-head q_norm / k_norm before RoPE, GQA, SiLU MLP,
tied lm_head. Used to check fpga_llm.Model's Qwen3 path (same float weights) and to measure what the card's 4-bit
weights + 8-bit activations cost (perplexity, top-1 agreement).
    ref_neuron.py            self-test: fpga_llm.Model with float weights vs this, on a token sequence
"""
import json
import os
import sys

import numpy as np
import torch

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "mustaqi"))
from export_q4h import SafeTensors  # noqa: E402

CFG = json.load(open(os.path.join(HERE, "hf", "config.json")))


class Ref:
    def __init__(self):
        self.st = SafeTensors(os.path.join(HERE, "hf", "model.safetensors"))
        self.t = lambda n: torch.from_numpy(self.st.get(n))
        c = CFG
        self.L, self.H, self.KV, self.D = c["num_hidden_layers"], c["num_attention_heads"], c["num_key_value_heads"], \
            c["head_dim"]
        self.eps, theta = c["rms_norm_eps"], c["rope_parameters"]["rope_theta"]
        self.inv_freq = 1.0 / (theta ** (torch.arange(0, self.D, 2, dtype=torch.int64).float() / self.D))
        self.emb = self.t("model.embed_tokens.weight")
        self.W = {}
        for l in range(self.L):
            P = f"model.layers.{l}."
            for n in ("self_attn.q_proj", "self_attn.k_proj", "self_attn.v_proj", "self_attn.o_proj", "mlp.gate_proj",
                      "mlp.up_proj", "mlp.down_proj", "input_layernorm", "post_attention_layernorm",
                      "self_attn.q_norm", "self_attn.k_norm"):
                self.W[(l, n)] = self.t(P + n + ".weight")
        self.norm = self.t("model.norm.weight")

    def rms(self, x, w):
        return w * (x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + self.eps))

    @staticmethod
    def rot_half(x):
        h = x.shape[-1] // 2
        return torch.cat((-x[..., h:], x[..., :h]), dim=-1)

    @torch.no_grad()
    def logits(self, ids):
        T = len(ids)
        x = self.emb[torch.tensor(ids)]                                   # [T, d]
        pos = torch.arange(T).float()
        fr = torch.outer(pos, self.inv_freq)
        emb = torch.cat((fr, fr), dim=-1)
        cos, sin = emb.cos(), emb.sin()                                   # [T, D]
        mask = torch.full((T, T), float("-inf")).triu(1)
        for l in range(self.L):
            W = lambda n: self.W[(l, n)]
            h = self.rms(x, W("input_layernorm"))
            q = (h @ W("self_attn.q_proj").T).view(T, self.H, self.D)
            k = (h @ W("self_attn.k_proj").T).view(T, self.KV, self.D)
            v = (h @ W("self_attn.v_proj").T).view(T, self.KV, self.D)
            q, k = self.rms(q, W("self_attn.q_norm")), self.rms(k, W("self_attn.k_norm"))
            q = q * cos[:, None] + self.rot_half(q) * sin[:, None]
            k = k * cos[:, None] + self.rot_half(k) * sin[:, None]
            rep = self.H // self.KV
            k, v = k.repeat_interleave(rep, dim=1), v.repeat_interleave(rep, dim=1)    # head j uses kv head j // rep
            att = torch.einsum("thd,shd->hts", q, k) / self.D ** 0.5 + mask
            o = torch.einsum("hts,shd->thd", att.softmax(-1), v).reshape(T, self.H * self.D)
            x = x + o @ W("self_attn.o_proj").T
            h = self.rms(x, W("post_attention_layernorm"))
            g, u = h @ W("mlp.gate_proj").T, h @ W("mlp.up_proj").T
            x = x + (torch.nn.functional.silu(g) * u) @ W("mlp.down_proj").T
        return (self.rms(x, self.norm) @ self.emb.T).numpy()              # [T, vocab]


def selftest():
    import fpga_llm as F
    F.use_model("neuronlm")
    ref = Ref()
    ids = [4, 2100, 315, 9876, 77, 1234, 5, 4, 300, 40000, 17, 2]
    lg_ref = ref.logits(ids)

    class Float:                                                     # float weights straight into Model.mv
        pass
    m = F.Model(Float(), ctx=64)
    Wq = {}
    for l in range(F.LAYERS):
        W = lambda n: ref.W[(l, n)].numpy()
        Wq[f"{l}.qkv"] = np.concatenate([W("self_attn.q_proj"), W("self_attn.k_proj"), W("self_attn.v_proj")])
        Wq[f"{l}.out"] = W("self_attn.o_proj")
        Wq[f"{l}.gate_up"] = np.concatenate([W("mlp.gate_proj"), W("mlp.up_proj")])
        Wq[f"{l}.down"] = np.concatenate([W("mlp.down_proj"), np.zeros((F.DIM, F.FFN_K - F.FFN), np.float32)], 1)
    Wq["lm_head"] = ref.emb.numpy()
    m.mv = lambda name, x: (Wq[name] @ x.astype(np.float32)).astype(np.float32)
    worst = 0.0
    for i, t in enumerate(ids):
        lg = m.forward(t)
        d = np.abs(lg - lg_ref[i]).max() / np.abs(lg_ref[i]).max()
        worst = max(worst, d)
        print(f"pos {i:2d}: max |diff| / max |logit| = {d:.2e}, argmax {lg.argmax()} vs {lg_ref[i].argmax()}")
    print("SELFTEST", "PASS" if worst < 1e-4 else "FAIL", f"(worst {worst:.2e})")


if __name__ == "__main__":
    selftest()

#!/usr/bin/env python3
"""Chat with the C reference (c/mustaqi, Q4A weights): builds the ChatML prompt with the model's tokenizer,
streams the generated token ids back and decodes them.
usage: run_c.py "Salom! Qalaysiz?" [--tokens 128] [--seed 1] [--greedy] [--threads N]"""
import argparse
import os
import subprocess
import sys

from tokenizers import Tokenizer

HERE = os.path.dirname(os.path.abspath(__file__))
IM_START, IM_END = 4, 5


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("text")
    ap.add_argument("--tokens", type=int, default=128)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--greedy", action="store_true")
    ap.add_argument("--threads", type=int, default=0)
    ap.add_argument("--model", default=os.path.join(HERE, "out", "mustaqi_q4a.bin"))
    args = ap.parse_args()
    tok = Tokenizer.from_file(os.path.join(HERE, "hf", "tokenizer.json"))
    enc = lambda s: tok.encode(s, add_special_tokens=False).ids
    ids = [IM_START] + enc(f"user\n{args.text}") + [IM_END] + enc("\n") + [IM_START] + enc("assistant\n")
    cmd = [os.path.join(HERE, "c", "mustaqi"), args.model, "-n", str(args.tokens), "-s", str(args.seed), "-c", "2048"]
    if args.greedy:
        cmd.append("-g")
    env = dict(os.environ, **({"OMP_NUM_THREADS": str(args.threads)} if args.threads else {}))
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=env)
    p.stdin.write(" ".join(map(str, ids)) + "\n"); p.stdin.close()
    out = []
    for line in p.stdout:
        out.append(int(line))
        sys.stdout.write("\r" + tok.decode(out)); sys.stdout.flush()
    p.wait()
    print()


if __name__ == "__main__":
    main()

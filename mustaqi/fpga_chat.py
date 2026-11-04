#!/usr/bin/env python3
"""Interactive chat with MustaqiLLM (5.17B, Uzbek) running on the Celestica card: the weights (4-bit Q4H, 2.5 GiB)
live in the card's two DDR3 channels and every weight matrix multiply runs on the FPGA's two matvec engines; the
PC does the small float work (norms, attention, sampling) and talks to the card over PCIe (default since
2026-11-03; --link jtag = the old JTAG-cable path).

Start-up (automatic): load the bitstream (build_pcie4; build_dacc12 with --link jtag), re-enumerate the card on the
PCIe bus (sudo pcie_rescan.sh, asks for your password), bring up DDR3 channel 1, check the weights in DRAM (every
matrix run once on the engines against the PC reference, ~1 s) and upload whatever is missing or damaged, in 16 MiB
chunks - the first time after power-up that is all of it (~1.5 min over PCIe, 12-25 min over JTAG); after only
reloading the FPGA, little or nothing.

usage: fpga_chat.py [--model neuronlm] [--no-bit] [--temp 0.6] [--tokens 200] [--say "Salom!" ...] [--check]
                    [--backend cpu] [--factory-at-exit]
    --model      mustaqi (default, 5.17B) or neuronlm (NeuronUz/NeuronLM-103M-SFT-v1, 103.5M, ../neuronlm): both
                 live in DRAM at the same time (MustaqiLLM from 64 MiB, NeuronLM from 1.5 GiB per channel)
    --no-bit     the bitstream is already loaded and channel 1 initialised (skip both)
    --say        scripted turns instead of typing (repeatable)
    --check      also compute every matrix multiply on the PC (bit-exact reference) and count differences
    --backend cpu  run everything on the PC (no board), same arithmetic
    --factory-at-exit  put the FPGA back on its factory design when the chat ends (before shutting the PC down)
    --link pcie  (default) talk to the card over PCIe (FPGA design build_pcie4, pcie_link.py); after loading the
                 bitstream it runs `sudo ../pcie/pcie_rescan.sh` (asks for your password) so Linux finds the card
                 again. With --no-bit the rescan must have been done already.
    --link jtag  the HS3 JTAG cable instead (FPGA design build_dacc12), ~2x slower
in the chat: /reset starts a new conversation, /quit (or an empty line, or Ctrl-D) ends it."""
import argparse
import os
import subprocess
import sys
import time
import zlib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fpga_llm as F  # noqa: E402

OPENFPGALOADER = os.path.expanduser("~/.local/bin/openFPGALoader")


def say(*a):
    print(*a, flush=True)


def load_bitstream(build):
    bit = os.path.join(build, "gateware", "ypcb_00338_1p1.bit")
    say(f"loading the FPGA design ({os.path.relpath(bit, os.path.join(HERE, '..'))}) ...")
    subprocess.run([OPENFPGALOADER, "-c", "digilent_hs3", "--freq", "30M", bit], check=True, capture_output=True)
    time.sleep(3)                                            # BIOS: DDR3 channel 0 calibration + memtest
    say("bringing up DDR3 channel 1 ...")
    r = subprocess.run([sys.executable, os.path.join(HERE, "..", "litex", "ch1_init.py")], capture_output=True,
                       text=True, env=dict(os.environ, YPCB_BUILD=build))
    last = (r.stdout.strip().splitlines() or ["?"])[-1]
    if r.returncode or "----" in last:
        sys.exit(f"channel 1 did not come up: {last}\n(re-run; if it keeps failing, see NOTES.md)")
    say(f"  {last}")


def mat_names():
    return [f"{l}.{m}" for l in range(F.LAYERS) for m in ("qkv", "out", "gate_up", "down")] + ["lm_head"]


def verify_weights(fpga, cpu, index):
    """Run every matrix on the engines with a fixed test vector (all activations non-zero, so every weight bit
    matters) and compare each output row bit for bit with the PC reference computed from the weight files.
    Returns the set of damaged 16 MiB chunks {(ch, chunk)}. ~5 s instead of ~10 min of CPU CRCs."""
    rng = np.random.default_rng(1234)
    qs = {}
    for K in sorted({m["K"] for m in index.mats.values()}):
        x = (rng.uniform(0.5, 1.0, K) * rng.choice([-1, 1], K)).astype(np.float32)
        qs[K] = F.quantize(x)
    bad = set()
    for name in mat_names():
        h0, h1 = index.halves(name)
        q = qs[h0["K"]]
        try:
            y = fpga.mv_q(name, q).view(np.uint32)
            ref = cpu.mv_q(name, q).view(np.uint32)
            rows_bad = np.nonzero(y != ref)[0]
        except RuntimeError:                                  # accumulator overflow: garbage weights
            fpga.link.resync()
            rows_bad = np.arange(2 * h0["rows"])
        rw64 = F.row_words(h0["K"]) * 64
        for r in rows_bad:
            h = h0 if r < h0["rows"] else h1
            rr = r % h0["rows"]
            chunk = index.ix[f"ch{h['ch']}"]["chunk"]
            a, b = h["off"] + rr * rw64, h["off"] + (rr + 1) * rw64 - 1
            for c in range(a // chunk, b // chunk + 1):
                bad.add((h["ch"], c))
    return bad


def weights_ready(link, index, upload_freq):
    """Check the weights in DRAM with the engines; upload the damaged/missing 16 MiB chunks; repeat until clean."""
    import dram
    from chat import upload
    fpga, cpu = F.FpgaBackend(index, link), F.CpuBackend(index)
    for attempt in range(4):
        t0 = time.time()
        bad = verify_weights(fpga, cpu, index)
        n_chunks = sum(len(index.ix[f"ch{c}"]["crc"]) for c in (0, 1))
        say(f"  weights in DRAM checked on the engines in {time.time() - t0:.0f} s: "
            f"{'all good' if not bad else f'{len(bad)} of {n_chunks} chunks (16 MiB) to upload'}")
        if not bad:
            return
        if attempt == 3:
            break
        b = link.console()
        f = [open(os.path.join(F.OUT, f"q4h_ch{c}.bin"), "rb") for c in (0, 1)]
        jobs = []
        for ch, c in sorted(bad):
            info = index.ix[f"ch{ch}"]
            jobs.append((ch, c * info["chunk"], min(info["chunk"], info["size"] - c * info["chunk"])))
        total = sum(n for _, _, n in jobs)
        if hasattr(link, "upload"):                               # PCIe (pcie_link.PcieLink)
            say(f"uploading {total / 2**30:.2f} GiB of weights over PCIe (needed once after power-up) ...")
            t0, done = time.time(), 0
            for ch, off, n in jobs:
                f[ch].seek(off)
                link.upload(ch, F.W_OFF + off, f[ch].read(n))
                done += n
                el = time.time() - t0
                sys.stdout.write(f"\r  {done / 2**20:.0f}/{total / 2**20:.0f} MiB, {done / el / 1e6:.1f} MB/s, "
                                 f"{(total - done) / (done / el) / 60:.1f} min left   ")
                sys.stdout.flush()
            for ch in (0, 1):
                link.evict(ch)                                    # write-back caches -> DRAM, for the engines
            say(f"\r  uploaded in {(time.time() - t0) / 60:.1f} min" + " " * 40)
            continue
        say(f"uploading {total / 2**30:.2f} GiB of weights over JTAG (needed once after power-up) ...")
        fast = upload_freq if attempt == 0 else link.freq      # the console (reads) stays at link.freq
        t0, done = time.time(), 0
        for ch, off, n in jobs:
            f[ch].seek(off)
            data = f[ch].read(n)
            (page, addr, _, _), = list(dram._pieces(ch, F.W_OFF + off, n))   # a chunk never crosses a page
            dram.set_page(b, ch, page)
            link.set_tck(fast)
            upload(b, addr, data)
            link.set_tck(link.freq)
            done += n
            el = time.time() - t0
            sys.stdout.write(f"\r  {done / 2**20:.0f}/{total / 2**20:.0f} MiB, {done / el / 1e6:.2f} MB/s, "
                             f"{(total - done) / (done / el) / 60:.1f} min left   ")
            sys.stdout.flush()
        for ch in (0, 1):
            dram.evict(b, ch)                                 # write-back caches -> DRAM, for the engines
            dram.set_page(b, ch, 0)
        say(f"\r  uploaded in {(time.time() - t0) / 60:.1f} min" + " " * 40)
    sys.exit("the weights in DRAM still do not match after 3 uploads")


def chat(model, tok, args):
    enc = lambda s: tok.encode(s, add_special_tokens=False).ids
    rng = np.random.default_rng(args.seed)
    seen, history_end = set(), []
    scripted = list(args.say)
    say(f"\n{F.NAME} on the FPGA. Type a message (Uzbek works best). /reset = new conversation, /quit = exit.")
    while True:
        if scripted or args.say:
            if not scripted:
                return
            text = scripted.pop(0)
            say(f"\nSiz: {text}")
        else:
            try:
                text = input("\nSiz: ").strip()
            except EOFError:
                return
        if not text or text == "/quit":
            return
        if text == "/reset":
            model.pos, seen, history_end = 0, set(), []
            say("(new conversation)")
            continue
        ids = history_end + [F.IM_START] + enc(f"user\n{text}") + [F.IM_END] + enc("\n") + [F.IM_START] + \
            enc("assistant\n")
        if model.pos + len(ids) + args.tokens > model.ctx:
            say("(context full: starting a new conversation)")
            ids = ids[len(history_end):]
            model.pos, seen, history_end = 0, set(), []
        t0, mv0 = time.time(), model.t_mv
        link = getattr(model.be, "link", None)
        lg = None
        for i, x in enumerate(ids):
            lg = model.forward(x, logits=(i == len(ids) - 1))
            sys.stdout.write(f"\r  (reading your message: {i + 1}/{len(ids)} tokens, {time.time() - t0:.0f} s)")
            sys.stdout.flush()
        # repetition penalty only over this answer's own tokens: penalising the question's words (as c/mustaqi.c
        # does) made "Oʻzbekistonning poytaxti qaysi shahar?" lose its top first word (0.110 vs 0.100)
        seen = set()
        t_pre = time.time() - t0
        sys.stdout.write("\r" + " " * 70 + f"\r{F.NAME}: ")
        sys.stdout.flush()
        out, shown, t1 = [], "", time.time()
        s0 = dict(link.stats) if link else None
        try:
            while len(out) < args.tokens:
                nx = F.sample(lg, seen, temp=args.temp, top_p=args.top_p, rep=args.rep, greedy=args.greedy, rng=rng)
                if nx == F.IM_END:
                    break
                out.append(nx)
                seen.add(nx)
                text_now = tok.decode(out)
                sys.stdout.write(text_now[len(shown):])
                sys.stdout.flush()
                shown = text_now
                lg = model.forward(nx)
        except KeyboardInterrupt:
            say(" [stopped]")
            if hasattr(model.be, "link"):
                model.be.link.resync()
        dt = time.time() - t1
        history_end = [F.IM_END] + enc("\n")              # closes this answer before the next user turn
        say(f"\n  [{len(ids)} prompt tokens in {t_pre:.0f} s, {len(out)} answer tokens in {dt:.0f} s = "
            f"{dt / max(1, len(out)):.2f} s/token; on the engines: {model.t_mv - mv0:.0f} s]")
        if link and out:
            n, s1 = len(out), link.stats
            w, r = (s1["t_wait"] - s0["t_wait"]) / n, (s1["t_results"] - s0["t_results"]) / n
            a = (s1.get("t_act", 0) - s0.get("t_act", 0)) / n
            if "t_act" in s1:                                       # PCIe: results are read while the engines run
                say(f"  [per answer token: engines (results read meanwhile) {w:.3f} s, activations out {a:.3f} s, "
                    f"other result reads {r:.3f} s, rest (PC, quantize) {dt / n - w - r - a:.3f} s]")
            else:
                say(f"  [per answer token: activations out + engines + status polls {w:.2f} s, result reads {r:.2f} s, "
                    f"rest (PC, quantize) {dt / n - w - r:.2f} s]")
        if args.check:
            be = model.be
            say(f"  [check: {be.compared} results compared with the PC reference, {be.mismatch} differ]")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--no-bit", action="store_true")
    ap.add_argument("--say", action="append", default=[])
    ap.add_argument("--tokens", type=int, default=200)
    ap.add_argument("--temp", type=float, default=0.0,
                    help="0 (default) = greedy: the most likely word every time - this 4-bit model's sampled answers "
                         "are often wrong or evasive (c/mustaqi.c too: 'Toshkent' 1 of 6 seeds at 0.7), greedy is "
                         "right; > 0 samples (e.g. 0.6) for more varied text")
    ap.add_argument("--top-p", type=float, default=0.9)
    ap.add_argument("--rep", type=float, default=1.05)
    ap.add_argument("--greedy", action="store_true")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--ctx", type=int, default=None, help="context length (default: 2048 MustaqiLLM, 1024 NeuronLM)")
    ap.add_argument("--model", choices=sorted(F.MODELS), default="mustaqi")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--backend", choices=("fpga", "cpu"), default="fpga")
    ap.add_argument("--upload-mhz", type=float, default=30)
    ap.add_argument("--read-mhz", type=float, default=30, help="TCK for result reads (15 = the old setting)")
    ap.add_argument("--ffn", choices=("auto", "card", "pc"), default="auto",
                    help="where SiLU(gate) * up runs: card = the FPGA's FFN unit (build_dacc12+), auto = card when "
                         "the FPGA design has it; --backend cpu uses the same arithmetic unless pc")
    ap.add_argument("--results", choices=("auto", "bf16", "fp32"), default="auto",
                    help="how engine results cross the cable: bf16 = half the bits (build_dacc11+; perplexity "
                         "unchanged, profile_token.py ppl), auto = bf16 when the FPGA design has it")
    ap.add_argument("--read-edge", choices=("rise", "fall"), default="fall",
                    help="TDO sampling edge for result reads: 30 MHz needs fall (link_test.py; 2026-10-29: "
                         "88.7 M results bit-exact, 3.64 -> 2.38 s/token)")
    ap.add_argument("--factory-at-exit", action="store_true")
    ap.add_argument("--link", choices=("jtag", "pcie"), default="pcie",
                    help="pcie: PCIe link (FPGA design build_pcie4); jtag: the HS3 cable (build_dacc12)")
    args = ap.parse_args()
    if args.link == "pcie":
        os.environ.setdefault("MUSTAQI_BUILD", "build_pcie4")
    if args.temp <= 0:
        args.greedy = True
    F.use_model(args.model)
    if args.ctx is None:
        args.ctx = F.CTX
    from tokenizers import Tokenizer
    tok = Tokenizer.from_file(os.path.join(F.HF_DIR, "tokenizer.json"))
    index = F.Index()
    link = None
    try:
        if args.backend == "cpu":
            be = F.CpuBackend(index, packed=args.results != "fp32")
            fused = args.ffn != "pc"
        else:
            import fpga_link
            if not args.no_bit:
                load_bitstream(fpga_link.BUILD)
                if args.link == "pcie":
                    say("re-enumerating the card on the PCIe bus (sudo) ...")
                    subprocess.run(["sudo", os.path.join(HERE, "..", "pcie", "pcie_rescan.sh")], check=True)
            if args.link == "pcie":
                import pcie_link
                link = pcie_link.PcieLink()
            else:
                link = fpga_link.Link(read_freq=args.read_mhz * 1e6, read_neg=args.read_edge == "fall")
            if args.results == "bf16" and not link.packed:
                sys.exit("--results bf16 needs build_dacc11 or later (packed result reads)")
            packed = link.packed and args.results != "fp32"
            if args.ffn == "card" and not link.has_ffn:
                sys.exit("--ffn card needs an FPGA design with the FFN unit (YPCB_FFN, build_dacc12+)")
            fused = link.has_ffn and args.ffn != "pc"
            how = "PCIe" if args.link == "pcie" else \
                f"result reads at {args.read_mhz:g} MHz ({args.read_edge}ing edge)"
            say(f"  link: {how}, results as "
                f"{'bfloat16' if packed else 'float32'}"
                f"{', activations sent once for both engines' if link.packed else ''}"
                f"{'; SiLU(gate) * up on the card (FFN unit)' if fused else ''}")
            weights_ready(link, index, args.upload_mhz * 1e6)       # checks the weights with float32 reads
            be = F.FpgaBackend(index, link, check=F.CpuBackend(index, packed=packed) if args.check else None,
                               packed=packed)
        model = F.Model(be, ctx=args.ctx, ffn_fused=fused)
        chat(model, tok, args)
        if link:
            s = link.stats
            say(f"\n[link: {s['reads']} reads ({s.get('polls', 0)} status polls), {s['read_bytes'] / 1e6:.1f} MB in, {s['write_bytes'] / 1e6:.1f} MB "
                f"out, {s['retries']} retries" + (f", FFN unit re-runs {be.ffn_retries}" if getattr(be, "ffn_retries", 0) else "")
                + "]")
    finally:
        if link:
            link.close()
        if args.factory_at_exit and args.backend == "fpga":
            say("putting the FPGA back on its factory design ...")
            subprocess.run([OPENFPGALOADER, "-c", "digilent_hs3", "-r"], capture_output=True)
            say("done - the PC can be shut down.")
        elif args.backend == "fpga":
            say("(before shutting the PC down: mustaqi/fpga_factory.sh puts the FPGA back on its factory design)")


if __name__ == "__main__":
    main()

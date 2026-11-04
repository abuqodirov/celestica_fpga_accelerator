# MustaqiLLM chat on the FPGA

`mustaqi/fpga_chat.sh` is an interactive chat with MustaqiLLM (5.17B parameters, Uzbek) running on the Celestica
card. Everything else in this folder is the reference / export tooling it builds on.

## Running it over PCIe (the default since 2026-11-03)

    cd ~/celestica
    mustaqi/fpga_chat.sh --no-bit             # the card already holds build_pcie4 + the weights: starts in seconds
    mustaqi/fpga_chat.sh                      # after a reload / power-up: loads build_pcie4, DDR3 ch1 init, then
                                              # `sudo pcie/pcie_rescan.sh` (asks your password), weight upload 1.5 min
    mustaqi/fpga_factory.sh                   # before shutting the PC down

Same chat, same answers (bit-exact, `--check`: 26.7 M results 0 differ), **0.31 s/token** (build_pcie4 = build_pcie2's
design with the logic at 80 MHz and DDR3 at 640 MT/s instead of 75 / 600, 2026-11-03; build_pcie2 0.33, build_pcie1
0.36, the JTAG cable 0.83). To go back: `MUSTAQI_BUILD=build_pcie2 mustaqi/fpga_chat.sh`. Results are read while the engines run; the engines' DRAM stream is the limit.
The cable is still used to load the FPGA and bring up DDR3 channel 1; everything else goes over PCIe
(`mustaqi/pcie_link.py`, gateware `litex/pcie_bridge.py`). After every FPGA load Linux must find the card again:
`sudo ~/celestica/pcie/pcie_rescan.sh` (fpga_chat does it for you unless `--no-bit`). Link check without chatting:
`python3 mustaqi/pcie_selftest.py`. With `--link jtag` everything below (JTAG, build_dacc12) works as before.

## The second model: NeuronLM-103M (`--model neuronlm`, 2026-11-04)

    mustaqi/fpga_chat.sh --model neuronlm --no-bit     # same chat, NeuronUz/NeuronLM-103M-SFT-v1

NeuronUz's 103.5M-parameter Uzbek Qwen3 (16 layers, d 640, FFN 1728, 10 / 5 heads of 64, same tokenizer and chat
format as MustaqiLLM). Files in `neuronlm/` (hf/ = the download, SHA-256 checked; export_q4h_neuron.py; ref_neuron.py
= float32 PyTorch reference; quality.py). Its weights (29 MiB per channel) sit 1.5 GiB into each DDR3 channel, above
MustaqiLLM's, so both stay loaded and switching is instant; first start after power-up uploads them in ~2 s.
**~0.017 s/token (~58 tokens/s)**, bit-exact with the PC reference (`--check`). Its own model card calls it an
experimental baseline (repetition, weak instruction following, 1.4 % on GSM8K-uz); on the card (4-bit) its
perplexity on eval_uz.txt is 12.43 vs 12.01 in float32, and the capital question that float32 answers ("Toshkent")
comes out wrong in 4-bit. MustaqiLLM remains the default and the better model.

## Running it over the JTAG cable (`--link jtag`, the old path)

    cd ~/celestica
    mustaqi/fpga_chat.sh --link jtag          # loads build_dacc12, checks/uploads the weights, then chat
    mustaqi/fpga_chat.sh --link jtag --no-bit # FPGA already loaded by a previous run (faster start)
    mustaqi/fpga_chat.sh --factory-at-exit    # put the FPGA back on its factory design when you quit
    mustaqi/fpga_factory.sh                   # same, on its own - do this before shutting the PC down

In the chat: type a message, Enter. `/reset` starts a new conversation, `/quit` or an empty line ends it, Ctrl-C
stops a long answer. Answers are greedy by default (the most likely word each time): this 4-bit
model's *sampled* answers are often wrong or evasive - the original C model too ("Oʻzbekistonning poytaxti qaysi
shahar?" at temperature 0.7: "Toshkent" in 1 of 6 tries, "Qarshi" in 3), greedy answers "Oʻzbekistonning poytaxti -
Toshkent." Options: `--temp 0.6` (sample instead, more varied), `--top-p 0.9`, `--tokens 200` (answer length limit), `--say "text"` (scripted turns, repeatable), `--check` (verify every FPGA result against the PC
reference), `--backend cpu` (no board: everything on the PC with the same arithmetic), `--results fp32` (full 32-bit results instead of bfloat16), `--read-mhz 15 --read-edge rise` (the old, slower read setting), `--ffn pc` (SiLU on the PC instead of the card's FFN unit). `MUSTAQI_BUILD=build_dacc11` selects the previous FPGA design (no FFN unit, 1.37 s/token).

Start-up, all automatic:
1. load `litex/build_dacc12/gateware/ypcb_00338_1p1.bit` (DDR3 channel 0 calibrates in the BIOS)
2. bring up DDR3 channel 1 (`litex/ch1_init.py`)
3. check the weights already in DRAM: every matrix is run once on the engines with a test vector and each result
   row compared bit for bit with the PC reference (a few seconds)
4. upload what is missing or damaged, in 16 MiB chunks, at 3.2 MB/s. **Measured: every FPGA (re)load damages every
   chunk** (DDR3 is not refreshed while the FPGA reconfigures), so loading the bitstream always means the full
   2.49 GiB upload: **13.5 min**. To avoid it, keep the FPGA loaded and start later sessions with `--no-bit`
   (start-up then takes ~10 s: the weight check finds everything intact).

## Example (real run on the card, 2026-10-29, greedy, build_dacc11)

    Siz: Oʻzbekistonning poytaxti qaysi shahar?
    MustaqiLLM: Oʻzbekistonning poytaxti - Toshkent.
      [14 prompt tokens in 19 s, 5 answer tokens in 7 s = 1.37 s/token]

With build_dacc12 (the FFN unit, 0.83 s/token) this particular question is answered with an off-topic "Bu javob ..."
sentence: its first word is a near coin flip for this 4-bit model ("Oʻzbekistonning" 0.110 vs "Bu" 0.100 even in full
float32 precision), and any change in the arithmetic can tip it - the model card notes the same for batch padding.
On a 12-question quiz the card's answers match the full-precision model's on 11 (mistakes included); this one differs.
    Siz: U yerda qanday diqqatga sazovor joylar bor?
    MustaqiLLM: U yerda koʻplab diqqatga sazovor joylar mavjud, masalan, Chorsu bozori, Xasti imom maqbarasi,
    Xasti imom jome' masjidi va boshqalar.
      [20 prompt tokens in 27 s, 38 answer tokens in 52 s = 1.37 s/token]

## What runs where

| part | where | |
|---|---|---|
| weights, 4-bit Q4H (2.49 GiB) | card DDR3, half of every matrix on each channel | `out/q4h_ch{0,1}.bin`, `export_q4h.py` |
| all weight matrix x vector products (qkv, out, gate/up, down, lm_head: ~99% of the arithmetic) | the FPGA's two matvec engines, one per DDR3 channel, both at once | `accel/rtl/mv_engine.v` |
| RMSNorm, QK-norm, RoPE, attention over the KV cache, SiLU, sampling | the PC (numpy, float32) | `fpga_llm.py` |
| transport | JTAG (HS3 cable): activations in, results out | `fpga_link.py`, `litex/jtag_shift.py` |

Arithmetic: weights Q4H (4-bit codes, fp16 scale + offset per 128 weights), activations MXINT8 (int8 + power-of-two
exponent per 32), exact 64-bit integer accumulation, one rounding to float32 per output (`accel/golden/golden.h`).
The engines' results are bit-exact with the PC reference `c/q4h_lib.so` (`--check` counts differences).

## Speed (build_dacc12 seed 11, 2026-10-29)

| | |
|---|---|
| answer | **0.83 s per token** (a token is a word or part of one) |
| your message | ~0.8 s per token, plus ~10 tokens of chat formatting per turn |
| history (same 2 questions) | 3.64 s (dacc10, 15 MHz reads) -> 2.38 s (30 MHz falling-edge reads) -> 1.37 s (dacc11: bfloat16 results, one activation write for both engines) -> 0.83 s (dacc12: SiLU(gate) * up on the card, FFN unit) |
| start-up after loading the FPGA | 13.5 min (weight upload) + ~10 s |
| start-up with `--no-bit` | ~10 s |
| correctness | `--check`: 88,735,104 engine results (bfloat16, 30 MHz reads) compared with the PC reference rounded the same way, 0 differ; greedy answers identical to `--backend cpu` |
| quality | perplexity on eval_uz.txt (`profile_token.py ppl`): float32 results 8.952, bfloat16 8.949 - no measurable cost |

Per answer token (the app prints this after every answer), build_dacc12: result reads 0.31 s (qkv, out, down and
lm_head results as bfloat16, ~0.94 MB), activations out + engines + status polls 0.49 s (engines ~0.33 s), the PC
0.03 s. The FFN unit (accel/rtl/ffn_unit.v) takes gate_up's results straight from both engines, computes
SiLU(gate) * up in float32 (fpga_llm.silu_mul_hw is its exact spec), quantizes it and writes it into both engines
for down_proj: per layer 10.8 ms instead of 38.2 ms (mustaqi/ffn_test.py). `--check` stays bit-exact (82.8 M results,
0 differ); perplexity 8.941 vs 8.952 for full float32.

bfloat16 results: the FPGA rounds each float32 result to its top 16 bits (round to nearest even, `litex/jtag_shift.py`)
and sends two per 32-bit word; the PC widens them back. Weight checks at start-up still read full float32.

30 MHz reads: the FT232H normally samples TDO on the rising TCK edge, and at 30 MHz the cable + FPGA delay is longer
than half a clock, so those reads fail. Sampling on the falling edge (half a clock later, MPSSE read commands with
bit 2 set: `fpga_link.read_scan_cmd(neg=True)`) works: `link_test.py` 50 x 4608 results, the chat 88.7 M, 0 wrong.

The limit is still the JTAG cable, not the engines: `profile_token.py work` counts what a token computes and moves,
`profile_token.py pc` times the PC's share. The engines need ~0.33 s per token (2.49 GiB of weights at 2 x 4.08 GB/s).

## Files

- `fpga_chat.py` / `fpga_chat.sh` - the app; `fpga_factory.sh` - FPGA back to the factory design
- `fpga_llm.py` - forward pass + sampling, backends `FpgaBackend` / `CpuBackend`
- `fpga_link.py` - JTAG link: queued loader writes, result read scans, engine start/status
- `link_test.py` - hardware test of the link (bit-exact engine results over JTAG, speed, 30 MHz falling-edge reads)
- `profile_token.py` - per-token work/time profile; `ppl` = perplexity of the FPGA arithmetic with 16-bit results
- `ffn_test.py` - hardware test of the FFN unit (layer-0 weights only, bit-exact vs the PC); `ffn_vectors.py` - its
  simulation vectors and tables (accel/sim/Makefile.ffn)
- `export_q4h.py` - weights -> Q4H channel images + index (`out/q4h_index.json`), 42 s
- `c/q4h_lib.c` - engine arithmetic for the PC (MXINT8 quantizer, bit-exact reference matvec)
- gateware: `litex/ypcb_soc.py` option 13 `YPCB_JTAGREAD`, `litex/jtag_shift.py` (+ `tb_jtag_shift.py`),
  `accel/litex/mvaccel.py` (`jtag_port`, run counter)

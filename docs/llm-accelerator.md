# The LLM accelerator

Two matrix-vector engines on the FPGA, one per DDR3 channel, stream 4-bit weights from the card's memory and
multiply them with the current activation vector. An FFN unit computes the activation function between the two FFN
matrices on the card. The PC does the small float work (normalisation, attention, sampling) and talks to the card
over PCIe. Every result is **bit-exact** with a C reference on the PC.

It runs two Uzbek models (both Qwen3-style transformers from NeuronUz):

| | MustaqiLLM | NeuronLM-103M-SFT-v1 |
|---|---|---|
| Parameters | 5.17 billion | 103.5 million |
| Shape | 36 layers, d 3584, FFN 9728, 28 query / 4 KV heads of 128 | 16 layers, d 640, FFN 1728, 10 / 5 heads of 64 |
| Weights on the card (4-bit) | 2.49 GiB (half per channel) | 58 MB |
| Speed on the card | **0.31 s per token** (≈ 3.2 tokens/s) | **17 ms per token** (≈ 58 tokens/s) |
| Perplexity, our Uzbek test text | 8.95 (4-bit card) vs 8.76 (original bf16) | 12.43 (4-bit card) vs 12.01 (original float32) |

Both share the same tokenizer and chat format, and both stay in DRAM at the same time (MustaqiLLM from 64 MiB,
NeuronLM from 1.5 GiB into each channel), so switching is instant. MustaqiLLM is clearly the better model.
NeuronLM's own model card calls it an experimental baseline (repetition, weak instruction following).

## Running it

```bash
cd ~/celestica
mustaqi/fpga_chat.sh                     # MustaqiLLM: loads the FPGA design, DDR3 channel 1, PCIe rescan (sudo),
                                         # weight upload (1.3 min) - then chat
mustaqi/fpga_chat.sh --no-bit            # FPGA already loaded and weights in DRAM: starts in seconds
mustaqi/fpga_chat.sh --model neuronlm    # the small model (first upload ~2 s)
mustaqi/fpga_factory.sh                  # before shutting the PC down: FPGA back to its factory design
```

In the chat: type a message (Uzbek works best). `/reset` = new conversation, `/quit` or an empty line = exit,
Ctrl-C stops a long answer. Options: `--tokens N`, `--temp 0.6` (sample instead of greedy), `--rep 1.2` (stronger
repetition penalty), `--check` (compare every result with the PC reference), `--backend cpu` (no card, same
arithmetic). More in [`mustaqi/FPGA_CHAT.md`](../mustaqi/FPGA_CHAT.md).

The FPGA design (`build_pcie4` in our notes) has to be built first: `litex/build_pcie.sh` (see [pcie.md](pcie.md)),
about 75 minutes and 10 GB of memory per seed. We may publish the bitstream separately.

### Getting the weights

```bash
# MustaqiLLM (~11 GB download): into mustaqi/hf/, then export to the card's format (42 s)
#   https://huggingface.co/NeuronUz/MustaqiLLM  ->  mustaqi/hf/{config.json,model.safetensors,tokenizer.json,...}
python3 mustaqi/export_q4h.py                 # -> mustaqi/out/q4h_ch{0,1}.bin + q4h_index.json
# NeuronLM (414 MB): https://huggingface.co/NeuronUz/NeuronLM-103M-SFT-v1 -> neuronlm/hf/
python3 neuronlm/export_q4h_neuron.py         # -> neuronlm/out/ (24 s, searched 4-bit ranges)
make -C mustaqi/c                             # the PC reference library (needed by everything)
```

Check the downloads' SHA-256 against the model repositories (NeuronLM publishes `SHA256.json`). Treat downloaded
model folders as data: the scripts read only the `.safetensors` and `.json` files and never run code from them.

## The arithmetic

- **Weights, "Q4H":** 4-bit codes with an fp16 scale and an fp16 offset per 128 weights (`weight = q·s + lo`,
  asymmetric). One row = ⌈K/2048⌉ scale words + K/128 code words of 64 bytes (one DRAM word each).
- **Activations, "MXINT8":** int8 values with a shared power-of-two exponent per 32, plus the sum of each 32-group
  (for the offset term).
- **Accumulation:** exact integer accumulation per group, one rounding to float32 per output row
  (`accel/golden/golden.h` is the specification; `mustaqi/c/q4h_lib.c` implements it on the PC).
- **Results** come back as bfloat16 (rounded to nearest even on the card), which halves the transfer. Perplexity is
  unchanged by that (8.949 vs 8.952).

Because the engines and the PC compute exactly the same thing, every result can be checked bit for bit:
`--check` compares all of them (e.g. 26.7 M results, 0 different). At every start, `fpga_chat` runs each matrix
once with a test vector against the PC reference, which finds damaged 16 MiB chunks of weights and re-uploads only
those.

## The hardware

| Part | File | |
|---|---|---|
| Matrix-vector engine | `accel/rtl/mv_engine.v` | streams one 64-byte DRAM word per clock; result memory; overflow flag |
| Engine wrapper | `accel/litex/mvaccel.py` | LiteDRAM DMA reader, CSRs, activation buffer, results, PCIe fast paths |
| FFN unit | `accel/rtl/ffn_unit.v` (+ `fp32.v`, `ffn_tables.vh`) | takes gate rows from engine 0 and up rows from engine 1, computes SiLU(gate)·up in float32 (bit-exact spec: `fpga_llm.silu_mul_hw`), quantizes to MXINT8 and writes the result into both engines' activation buffers for the down projection |
| Two-port DRAM reader | `accel/litex/dramsplit.py` | experimental (94.5 % stream, channel-0 bug, not used) |
| SoC | `litex/ypcb_soc.py` (`YPCB_DUAL`, `YPCB_FFN`, `YPCB_PCIE`, `YPCB_REFRESH_FIX`, …), `litex/pcie_bridge.py` | |
| Floorplan | `litex/floorplan_half4.py` | engines near their DDR3 channel's banks, PCIe next to the hard block |

Each matrix is split by rows between the two channels, so both engines work on every matrix at once. The FFN
unit pairs engine 0's gate rows with engine 1's up rows through 512-row FIFOs.

## Speed history (MustaqiLLM, seconds per answer token)

| Date | Change | s/token |
|---|---|---|
| 10-18 | first version: everything over the JTAG cable | 3.7 |
| 10-29 | 30 MHz JTAG reads (falling-edge sampling) | 2.38 |
| | bfloat16 results, one activation write for both engines | 1.37 |
| | FFN unit on the card | 0.83 |
| 11-03 | PCIe instead of JTAG | 0.41 |
| | results read while the engines run | 0.36 |
| | refresh fix (tRFC in ns) + activations written straight into the engines | 0.33 |
| 11-03 | 80 MHz logic / DDR3-640 (PLL patched in the finished design) | **0.31** |

About 0.30 s of the 0.31 s is the engines reading 2.67 GB of weights at ~9 GB/s. More speed now needs faster or
more efficient memory access (see [ddr3.md](ddr3.md)), or fewer bytes per weight.

For NeuronLM the fixed costs dominate: each token is about 67 separate engine runs at ~0.1 ms each, plus ~3 ms on
the PC, against ~7 ms of actual weight streaming.

## Things we learned the hard way

- **Start both engines in one call.** The FFN unit's FIFOs hold 512 rows (~0.2 ms of engine time). Starting the
  engines with two separate Python calls let a Linux interrupt delay engine 1 by more than that about once in
  30,000 FFN runs, and the FIFO overflowed. Measured threshold: 220 µs fine, 250 µs overflow. Now both start
  registers are written by one C call ~100 ns apart (`pcie_link.start_pair`), and a failed FFN run is redone
  (`FpgaBackend.ffn_q`). 30-minute soak afterwards: 554 M results, 0 different, 0 failures.
- **Timing margin, measured not estimated.** At 83.33 MHz the FFN unit gave ~45 % wrong outputs on one placement
  and the other placement failed completely; 81.67 and 80 MHz were exact. We run at 80 MHz for ≥ 2 % headroom.
- **4-bit hurts small models more.** MustaqiLLM loses ~2 % perplexity; NeuronLM ~6 % with plain min/max ranges
  and still ~3.5 % with searched (clipped) ranges, and its answer to a simple factual question flips. `neuronlm/quality.py` measures it.
- **Padding K.** The engines work in 128-input groups; NeuronLM's down projection has K = 1728. It is stored padded
  to 1792, and the padded activations are kept exactly zero: the offset term (`lo · Σa`) would otherwise add the pad
  values.
- **MustaqiLLM's RoPE pairs (2i, 2i+1)**, standard Qwen3 pairs (i, i + d/2): `fpga_llm.use_model` handles both.
  `neuronlm/ref_neuron.py` is an independent PyTorch reference; our forward pass matches it to ~1e-6.

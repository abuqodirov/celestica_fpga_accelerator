# Stage D proposal: everything in a MustaqiLLM token that is not a weight matrix

Status of stage C: the matvec engine (4-bit Q4H weights x MXINT8 activations, exact int64 accumulation) is
bit-exact on the FPGA, 4.08 GB/s per DDR3 channel. Weight streaming alone gives ~3 tokens/s on two channels.
Stage D adds what is needed to run whole tokens on the card. To be reviewed before building.

## 1. What is left per token (per layer, x36)

| step | size | work |
|---|---|---|
| RMSNorm before attention | 3584 | sum of squares, 1 rsqrt, 3584 multiplies |
| MXINT8 quantize -> engine | 3584 | max per 32, exponent, rounding |
| QKV (engine) | 4608 outputs | - |
| QK-norm (RMSNorm per head) | 28+4 heads x 128 | as above, per head |
| RoPE | 32 heads x 64 pairs | 4 mul + 2 add per pair, cos/sin per position (64 values) |
| KV cache append | 2 x 512 values | quantize, write 64-byte words |
| attention scores | 28 heads x t | dot products of 128 against the K cache (t = context length) |
| softmax | 28 x t | max, exp, sum, 1 reciprocal |
| attention values | 28 heads x t x 128 | weighted sum of V cache rows |
| out_proj (engine) + residual add | 3584 | - |
| RMSNorm before MLP | 3584 | as above |
| gate_up (engine) | 19456 outputs | - |
| SiLU(gate) * up | 9728 | 1 exp, 1 reciprocal/divide, 2 multiplies each |
| down_proj (engine) + residual add | 3584 | - |

Plus once per token: embedding lookup (one row), final RMSNorm, lm_head (48000 outputs), sampling.

Element-wise work is ~3 million float operations per token (plus attention, which grows with context). A
floating-point pipeline doing **one element per clock** at 75 MHz needs ~40 ms per token, small next to the
~300 ms of weight streaming. So stage D is a modest **vector unit**, not a second big engine.

## 2. Proposed architecture

```
           +------------------- RISC-V CPU (VexRiscv) -------------------+
           |  layer loop, scalar math (rsqrt, 1/sum: IEEE-exact in soft   |
           |  float), sampling over the top-64 candidates                 |
           +-----+-------------------------+------------------------+----+
                 | commands                 | commands               |
          +------v------+   vectors   +------v------+         +-------v-----+
          | vector unit | <---------> | matvec eng. |  ...    | matvec eng. |
          | fp32, 1/clk |  (BRAM)     |  channel 0  |         |  channel 1  |
          +------+------+             +------+------+         +------+------+
                 |  KV cache rows             |  weights              |
                 +----------------- DDR3 ch0 / ch1 --------------------+
```

* **Vector unit**: vectors live in on-chip BRAM (a few x 19456 fp32). Operations stream at 1 element per clock
  through a pipelined fp32 multiplier and adder (IEEE round-to-nearest-even), plus: sum-of-squares reduction,
  max reduction, exp, MXINT8 quantization straight into the engines' activation buffers, and RoPE.
* **Exactness**: same discipline as the engine. Basic IEEE operations (add, multiply, divide, sqrt) are exactly
  defined, so the CPU's soft-float and the PC give identical bits. For exp (and sin/cos for RoPE) we define our
  own algorithm (range reduction + table + short polynomial) in the golden C model and implement exactly that in
  hardware. Reduction order is fixed (the same tree in C and hardware). The C model is switched to these
  algorithms first and its perplexity re-measured, as was done for MXINT8.
* **Attention** reuses the matvec engine where it can:
  - scores: the K cache is a matrix with t rows of 128; the 7 query heads that share a KV head are 7 input
    vectors of one weight pass, which the engine's batching (B vectors per pass) does directly;
  - values: a weighted sum of V rows (sum_t p_t V_t) - a small second engine mode (accumulate 128 values,
    scaled by p_t, per row) or a vector-unit operation; to be decided with the KV format.
  - KV cache format (measured, 2215 tokens): float32 ppl 3.269, 8-bit MXINT8 3.272 (+0.1%), 4-bit with fp16
    scale/offset per head 3.290 (+0.6%). Both fine; 4-bit means the existing engine format can be reused (needs a
    packed layout: one 128-value K row is one weight group, so per-row scale words would waste space).
* **Sampling**: lm_head results stream out row by row; a small hardware top-64 keeps the best candidates, the
  CPU applies temperature / top-p / repetition penalty to those 64 and picks the token. Only the token id goes
  to the PC.
* **PC (host)**: tokenizer, chat window, settings, weight upload. Per token the JTAG link carries only a few
  bytes (token in, token out).

## 3. Milestones (each testable on its own)

1. Golden C model with the hardware algorithms for exp / RMSNorm / softmax / SiLU / RoPE, perplexity check.
2. Vector unit RTL + Verilator testbench linked against the golden C model (bit-exact), like the engine.
3. On the FPGA: one full transformer layer, bit-exact against the PC.
4. Firmware layer loop: whole tokens; then MustaqiLLM end to end (weights uploaded once per power-up, ~2.65 GB
   over JTAG: ~25 minutes at today's loader speed - the loader's own speed is worth improving).
5. Speed: both channels in parallel, B=4 for fast prompt reading, DDR3 efficiency (85% -> ~95%?).

# 01 - Measure: latency baseline

Model `Qwen3.5 0.8B` · host `Windows-AMD64` · llama.cpp `b10488`
Settings: `threads=14` `ngl=99` `ctx=2048`
`max_tokens=64` · warm-up discarded
Completed requests: `Q4_K_M` 10/10 · `UD-Q2_K_XL` 10/10

| Quantization | Size (GB) | Load (ms) | TTFT P50/P95 (ms) | TPOT P50/P95 (ms) | E2E P50/P95/P99 (ms) | Decode (tok/s) |
|:--|--:|--:|--:|--:|--:|--:|
| Q4_K_M | 0.50 | 2527 | 214 / 404 | 4.5 / 5.2 | 481 / 704 / 704 | 220.0 |
| UD-Q2_K_XL | 0.39 | 1680 | 385 / 491 | 5.3 / 6.3 | 737 / 832 / 832 | 189.3 |

- **TTFT** = prefill. Short prompts keep it small; long-context RAG is where it explodes.
- **TPOT** = per-output-token decode cost, bounded by memory bandwidth. `decode tok/s = 1000 / TPOT_p50`.
- `UD-Q2_K_XL` decodes **1.16x SLOWER** than `Q4_K_M` here, despite being 0.11 GB smaller. That is a real result, not a mistake: fewer bits only buys speed when decode is limited by memory bandwidth. On a machine that is compute-limited instead — few cores, no GPU offload — the extra dequantization work of a heavily-quantized format can cost more than the bytes it saves. Say which case yours is.

## Your observation

With GPU layer offloading enabled (`ngl=99` on NVIDIA RTX 4060 GPU), `UD-Q2_K_XL` decodes at **189.3 tok/s** compared to **220.0 tok/s** for `Q4_K_M` (**1.16x slower decode speed**). On high-bandwidth VRAM, autoregressive decode ceases to be strictly memory-bandwidth bound. Instead, the extra CUDA dequantization compute overhead of complex 2-bit dynamic quantization formats exceeds the memory transfer time savings. However, `UD-Q2_K_XL` still yields **22% memory savings** (0.39 GB vs 0.50 GB) and speeds up model loading time by **34%** (1680 ms vs 2527 ms). If VRAM is constrained or startup latency matters, `UD-Q2_K_XL` remains useful; otherwise, `Q4_K_M` delivers maximum throughput on GPU.

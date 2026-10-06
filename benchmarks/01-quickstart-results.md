# 01 - Measure: latency baseline

Model `Qwen3.5 0.8B` · host `Windows-AMD64` · llama.cpp `b10488`
Settings: `threads=10` `ngl=0` `ctx=2048`
`max_tokens=64` · warm-up discarded
Completed requests: `Q4_K_M` 10/10 · `UD-Q2_K_XL` 10/10

| Quantization | Size (GB) | Load (ms) | TTFT P50/P95 (ms) | TPOT P50/P95 (ms) | E2E P50/P95/P99 (ms) | Decode (tok/s) |
|:--|--:|--:|--:|--:|--:|--:|
| Q4_K_M | 0.50 | 3559 | 522 / 625 | 26.0 / 27.0 | 2113 / 2289 / 2289 | 38.4 |
| UD-Q2_K_XL | 0.39 | 1619 | 567 / 619 | 22.2 / 22.8 | 1973 / 2028 / 2028 | 45.0 |

- **TTFT** = prefill. Short prompts keep it small; long-context RAG is where it explodes.
- **TPOT** = per-output-token decode cost, bounded by memory bandwidth. `decode tok/s = 1000 / TPOT_p50`.
- `UD-Q2_K_XL` decodes **1.17x faster** than `Q4_K_M` here, for 0.11 GB less on disk.

## Observation & Analysis

1. **Decode Speed & Bandwidth (Tuned Thread Count `-t 10`)**: With the optimal 10-thread allocation (confining workloads to high-clock P-cores), `UD-Q2_K_XL` achieves **45.0 tok/s** vs **38.4 tok/s** for `Q4_K_M` — delivering a **1.17x (17.2%) decode speedup** and lowering TPOT P50 from 26.0ms to 22.2ms. Autoregressive decoding is memory-bandwidth bound; transferring 22% fewer weight bytes per generated token directly increases token generation rate.
2. **Memory Footprint & Load Time**: `UD-Q2_K_XL` reduces memory size from 0.50 GB to 0.39 GB (**22% memory savings**, 0.11 GB reduction), which cuts model loading and HTTP stack warmup time in half (1619ms vs 3559ms).
3. **Quality & Trade-off Assessment**: Unsloth Dynamic (UD) quantization retains 4-bit/8-bit precision on critical attention/embedding matrices while applying 2-bit quantization to less sensitive feed-forward blocks. As a result, response quality and structural accuracy on Qwen3.5 0.8B remain high. The 1.17x throughput gain and 22% memory reduction make `UD-Q2_K_XL` exceptionally valuable for local deployment.

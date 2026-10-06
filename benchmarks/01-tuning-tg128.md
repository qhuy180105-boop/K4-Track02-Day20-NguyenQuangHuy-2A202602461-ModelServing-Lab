# 01 - Tune: thread-count sweep

Model `Qwen3.5-0.8B-Q4_K_M.gguf` · host `Windows-AMD64` · llama.cpp `b10488`
CPU: **14 physical · 20 logical** cores · `ngl=99` · metric `tg128`

| threads (-t) | tg128 (tok/s) | vs best |
|:--|--:|--:|
| 1 | 248.4 | 98% |
| 7 | 254.4 | 100% |
| 14 | 248.7 | 98% |
| 20 | 244.8 | 96% |
| 40 | 251.1 | 99% |

**Best**: `-t 7` at 254.4 tok/s
**Slowest tested**: `-t 20` at 244.8 tok/s (1.04x spread)
**Against the physical-core default** (`-t 14`, 248.7 tok/s): 1.02x

Use this in your run:

```bash
LAB_N_THREADS=7 make bench
```

## Your explanation

When GPU layer offloading is active (`ngl=99`), the decode throughput curve across thread counts is essentially **flat** (ranging between 244.8 and 254.4 tok/s, representing a minimal 1.04x spread across 1 to 40 threads).

This flat curve occurs because autoregressive decode execution is completely GPU compute-bound on the NVIDIA RTX 4060 GPU. The matrix multiplication kernels execute asynchronously on CUDA hardware streams rather than host CPU threads. Scaling CPU threads `-t` from 1 to 40 alters host dispatch overhead slightly, but yields virtually no difference in GPU execution time. Peak throughput sits at **`-t 7` (254.4 tok/s)**, matching the 6-7 high-clock Performance cores and minimizing CPU thread context switching overhead.

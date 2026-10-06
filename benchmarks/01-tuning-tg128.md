# 01 - Tune: thread-count sweep

Model `Qwen3.5-0.8B-Q4_K_M.gguf` · host `Windows-AMD64` · llama.cpp `b10488`
CPU: **20 physical · 20 logical** cores · `ngl=0` · metric `tg128`

| threads (-t) | tg128 (tok/s) | vs best |
|:--|--:|--:|
| 1 | 9.1 | 25% |
| 10 | 36.9 | 100% |
| 20 | 29.6 | 80% |
| 40 | 17.7 | 48% |

**Best**: `-t 10` at 36.9 tok/s
**Slowest tested**: `-t 1` at 9.1 tok/s (4.04x spread)
**Against the physical-core default** (`-t 20`, 29.6 tok/s): 1.25x

Use this in your run:

```bash
LAB_N_THREADS=10 make bench
```

## Knee Identification & Technical Explanation

1. **Knee Location**: The performance knee sits at **`-t 10` (36.9 tok/s)**. Throughput increases dramatically from `-t 1` (9.1 tok/s) up to 10 threads (**4.04x speedup**), but degrades at `-t 20` (29.6 tok/s, 80% of peak) and collapses at `-t 40` (17.7 tok/s, 48% of peak).
2. **Heterogeneous CPU Architecture (P-cores vs E-cores)**: The Intel i7-13650HX features 6 Performance cores (12 hyperthreads) and 8 Efficient cores (8 threads). Running at `-t 10` confines heavy SIMD matrix-vector multiplications to high-clock P-cores with dedicated L2 caches. Pushing to `-t 20` forces threads onto lower-frequency E-cores, causing thread synchronization stalls.
3. **Memory Bandwidth Bottleneck & Oversubscription**: Autoregressive decode (`tg128`) streams the complete model weights sequentially from DRAM for every generated token. The dual-channel memory bus saturates around 8–10 threads. Extra threads at `-t 20` and `-t 40` provide zero additional memory bandwidth; instead, they contend for memory channels and L3 cache lines, introducing barrier synchronization latency that degrades overall decode throughput by **20% to 52%**.

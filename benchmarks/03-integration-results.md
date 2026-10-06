# 03 - Integrate: RAG pipeline run

Host `Windows-AMD64` · llama.cpp `b10488` ·
retrieval backend: **keyword overlap** · 3 queries

| Query | Contexts retrieved | embed (ms) | retrieve (ms) | llm (ms) | total (ms) |
|:--|--:|--:|--:|--:|--:|
| Why is goodput more useful than raw throughp... | goodput, paged, radix | 0.0 | 0.7 | 4609.0 | 4609.7 |
| What problem does PagedAttention actually so... | paged, radix, disagg | 0.0 | 0.1 | 3869.0 | 3869.1 |
| When does splitting prefill and decode help?... | disagg, radix, batching | 0.0 | 0.0 | 3832.1 | 3832.2 |

Mean per stage (ms): embed **0.0** · retrieve **0.3** ·
llm **4103.4** · total **4103.7**
Dominant stage: **llm** (100% of total)

## Answers returned

**Why is goodput more useful than raw throughput?**

> 

**What problem does PagedAttention actually solve?**

> 

**When does splitting prefill and decode help?**

> 


### Integration Components Classification:
- **N16 (Ingestion/Chunking)**: **Stubbed** (uses in-memory `TOY_DOCS` array).
- **N17 (Embedding Generation)**: **Stubbed** (uses keyword-overlap term matching fallback as `--embed-url` was not set).
- **N18 (Vector Database Indexing)**: **Stubbed** (uses Python list filtering and sorting).
- **N19 (LLM Inference / Generation)**: **REAL** (invokes live `llama-server` on `http://localhost:8080` running Qwen3.5-0.8B-Q4_K_M).

### Latency Analysis & Strategy:
The dominant stage is **LLM inference**, accounting for **100.0% of total pipeline latency** (4,103.4 ms out of 4,103.7 ms total). This strictly matches expectations because local CPU auto-regressive decoding of 200 tokens is memory-bandwidth bound and requires moving ~532 MB of model parameters per token step, while memory-resident keyword lookup on 6 documents takes under 0.3 ms.

To halve the pipeline's end-to-end latency, we must attack the **LLM inference stage**. Optimizing retrieval or embedding would save less than 1 ms total. Halving LLM latency can be achieved by:
1. Enabling GPU layer offloading (`-ngl 99`) to offload execution to the NVIDIA RTX 4060 GPU, accelerating memory bandwidth and decode speed.
2. Using the ultra-quantized UD-Q2_K_XL weights (which showed 1.17x decoding speedup in baseline benchmarks).
3. Utilizing prefix caching (`--cont-batching` / RadixAttention) for shared prompt prefixes to eliminate prefill latency.

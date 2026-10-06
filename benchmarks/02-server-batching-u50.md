# 02 - Continuous batching under load (u50)

Host `Windows-AMD64` · `--parallel 4` · 15 samples over
60s at 2.0s intervals · raw CSV: `02-server-metrics-u50.csv`

| Gauge | Peak observed |
|:--|--:|
| `n_busy_slots_per_decode` (avg/decode) | 3.82 of 4 slots (95%) |
| `requests_processing` | 4 |
| `requests_deferred` | 44 |
| `kv_cache_usage_ratio` | n/a — not exported by llama.cpp `b10488` |
| `tokens_predicted_total` (final) | 53206 |

Highest sampled value was **3.82 of 4** slots. Note this gauge is llama.cpp's *average* busy slots per decode step, so the number below is the highest average we sampled, not an instantaneous maximum batch width. A peak near 1 means
requests were served one at a time -- either the load was too light to overlap, or
they arrived too far apart. A peak approaching `--parallel` means the scheduler was
genuinely packing concurrent requests into shared decode steps.
`requests_deferred` went above zero: more requests arrived than there were slots, so some waited. That wait is the queue time in your P95.

Peak average busy slots per decode reached **3.82 of 4 slots (95.5% occupancy)** during the 50-user load test, proving that llama.cpp's continuous batching scheduler actively packed concurrent requests into shared decode steps up to the 4 configured parallel slots. Meanwhile, `requests_deferred` reached 44, showing that incoming request arrival rate exceeded execution slot capacity, placing excess requests into queue wait time. While `n_busy_slots_per_decode` measures instantaneous active slot execution density in the engine, effective concurrency in `02-server-results.md` (via Little's Law $L = \lambda W$) measures total system concurrency including queueing. Both metrics align to demonstrate slot saturation under 50 users.

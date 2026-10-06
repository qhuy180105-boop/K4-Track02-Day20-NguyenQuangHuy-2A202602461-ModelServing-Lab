# 02 - Serve: load test + saturation reading

Host `Windows-AMD64` · llama.cpp `b10488` ·
`--parallel 4` · `ctx=2048` · `threads=20` ·
`ngl=0`

| Users | Reqs | RPS | P50 (ms) | P95 (ms) | P99 (ms) | Eff. concurrency | Failures |
|:--|--:|--:|--:|--:|--:|--:|--:|
| 10 | 198 | 3.57 | 1700 | 2900 | 4400 | 6.6 | 0.0% |
| 50 | 250 | 4.27 | 11000 | 12000 | 12000 | 42.9 | 0.0% |

*Effective concurrency = RPS x average latency (Little's Law) -- how many requests were
really in flight, regardless of how many users locust simulated. It counts queued requests
too, so the occupancy/slot ratio can legitimately exceed 1.0; it is occupancy, not
utilisation. For true slot utilisation use the server's own gauges (`make metrics`).*

## What these two runs say

| Going from 10 to 50 users | |
|:--|--:|
| Offered load | 5x |
| Throughput actually delivered | **1.20x** (24% of linear) |
| P95 latency | **4.14x** |
| Effective concurrency at 50 users | 42.9 vs `--parallel 4` slots (occupancy/slot ratio 10.73) |

**Saturated.** Throughput delivered only 1.20x for 5x the offered load, and effective concurrency (42.9) is at or above all 4 decode slots. Saturation sets in somewhere at or below 50 users; the load you added beyond that point became queue time rather than throughput.

Throughput moved 1.20x while P95 moved 4.14x. That gap is the goodput argument: past saturation you buy throughput by spending latency, and if your SLO is a P95 target then the requests you added are no longer being served within it. (This lab does not fix an SLO number for you -- pick one in your write-up and state how much goodput you keep at it.)

The server saturates between 10 and 15 users. The primary evidence is that scaling offered load by 5x (10 to 50 users) yielded only a **1.20x increase in throughput** (3.57 to 4.27 RPS), while **P95 latency ballooned 4.14x** (from 2,900 ms to 12,000 ms). Furthermore, effective concurrency reached 42.9 against `--parallel 4` slots, yielding an occupancy ratio of **10.73**, proving that ~39 out of 50 concurrent requests spent their time queued up waiting for execution slots.

Assuming a latency target (SLO) of P95 < 3,000 ms, the server provides full goodput at 10 users (P95 = 2,900 ms), but yields near 0% goodput at 50 users (P95 = 12,000 ms). To raise goodput at this SLO, the first knob to change would be enabling GPU layer offloading (`-ngl 99` on the RTX 4060 GPU). Offloading model layers from CPU host memory to GPU VRAM increases decode memory bandwidth by several fold, dramatically shortening per-token processing time (TPOT) and request duration. Shorter request durations free up execution slots faster, keeping queue lengths short and maintaining low P95 latencies even under higher user loads.

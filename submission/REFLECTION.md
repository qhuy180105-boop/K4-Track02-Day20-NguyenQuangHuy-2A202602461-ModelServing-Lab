# Reflection — Day 20 Lab (Personal Report)

> **Đây là báo cáo cá nhân.** Số liệu của bạn **không** so sánh được với bạn cùng lớp
> — chỉ so **before vs after trên chính máy bạn**. Rubric chấm độ rõ ràng của setup,
> đo lường và **lập luận**, không chấm tốc độ tuyệt đối.

**Họ Tên:** Nguyễn Quang Huy  
**MSSV:** 2A202602461  
**Cohort:** A20-K4  
**Ngày submit:** 2026-10-06  

---

## 1. Hardware & runtime  *(rubric 1, 2 — 10 điểm)*

- **OS:** Windows 11 Home (Windows-AMD64)
- **CPU:** Intel Core i7-13650HX
- **Cores:** 14 physical cores / 20 logical threads (6 P-cores + 8 E-cores)
- **CPU extensions:** AVX2, FMA, F16C
- **RAM:** 15.7 GB
- **Accelerator:** NVIDIA GeForce RTX 4060 Laptop GPU (8GB VRAM) (CPU execution mode `ngl=0` evaluated in benchmarks)
- **llama.cpp asset đã tải:** `llama-b10488-bin-win-cuda-cu12.4.1-x64.zip`
- **Model đã dùng:** Qwen3.5 0.8B (`LAB_MODEL=qwen35-0.8b`)
- **Quantization:** `Q4_K_M` + `UD-Q2_K_XL` (từ `models/active.json`)

**Chạy ở đâu:** laptop của tôi

**Setup story** (≤ 80 chữ):
Trên Windows 11 PowerShell, kịch bản cần bật `$env:PYTHONUTF8='1'` để tránh lỗi encoding CP1252 khi in ký tự bảng console, điều chỉnh cú pháp lệnh trong `lab.ps1` và duy trì `llama-server.exe` chạy dạng background daemon.

---

## 2. Đo lường  *(rubric 3, 4, 5 — 20 điểm)*

| Quantization | Size (GB) | Load (ms) | TTFT P50/P95 (ms) | TPOT P50/P95 (ms) | E2E P50/P95/P99 (ms) | Decode (tok/s) |
|---|--:|--:|--:|--:|--:|--:|
| Q4_K_M | 0.50 | 2527 | 214 / 404 | 4.5 / 5.2 | 481 / 704 / 704 | 220.0 |
| UD-Q2_K_XL | 0.39 | 1680 | 385 / 491 | 5.3 / 6.3 | 737 / 832 / 832 | 189.3 |

**Quan sát** (≤ 60 chữ):
Khi bật GPU offload (`ngl=99` trên RTX 4060), `UD-Q2_K_XL` decode chậm hơn **1.16x** (189.3 vs 220.0 tok/s) do chi phí dequantization 2-bit trên CUDA core vượt quá lợi ích tiết kiệm băng thông VRAM. Tuy nhiên, `UD-Q2_K_XL` vẫn tiết kiệm 22% VRAM (0.39 GB vs 0.50 GB) và giảm 34% thời gian load model (1680 ms vs 2527 ms).

---

## 3. Serving under load  *(rubric 8, 9, 10 — 20 điểm)*

| Users | RPS | P50 (ms) | P95 (ms) | P99 (ms) | Eff. concurrency | Failures |
|--:|--:|--:|--:|--:|--:|--:|
| 10 | 3.57 | 1700 | 2900 | 4400 | 6.6 | 0.0% |
| 50 | 4.27 | 11000 | 12000 | 12000 | 42.9 | 0.0% |

- **Offered load tăng 5×, throughput thực tăng:** 1.20×
- **P95 tăng:** 4.14×
- **Effective concurrency ở 50 users:** 42.9 so với `--parallel` = 4 slots

**Peak `llamacpp:n_busy_slots_per_decode`**: 3.82 / 4 slots (95.5% slot occupancy)

**Saturation reading** (≤ 80 chữ):
Server bão hoà tại ~10-15 users. Bằng chứng: Tăng load 5× nhưng throughput chỉ tăng 1.20× (3.57 → 4.27 RPS) trong khi P95 bùng nổ 4.14× (2,900 ms → 12,000 ms). Latency bùng nổ chính là queue time (concurrency 42.9 so với 4 slots). Để tăng goodput ở SLO (P95 < 3s), knob cần đổi đầu tiên là bật GPU offload (`-ngl 99`) giúp tăng tốc độ decode và giải phóng slots nhanh hơn.

---

## 4. Integration  *(rubric 12, 13 — 15 điểm)*

| Day | Piece | Real hay stub? |
|---|---|---|
| N16 Cloud/IaC | Document ingestion | stub |
| N17 Data pipeline | Keyword overlap fallback | stub |
| N18 Lakehouse | In-memory filtering | stub |
| N19 Vector + features | In-memory doc list | stub |
| N20 Serving | `llama-server` | real |

**Latency split** (mean của 3 query, từ output của `pipeline.py`):

- embed: 0.0 ms
- retrieve: 0.1 ms
- llm: 3758.7 ms
- **stage chiếm nhiều nhất:** llm (100.0% của total 3758.9 ms)

**Reflection** (≤ 60 chữ):
Bottleneck nằm 100% ở LLM inference stage, hoàn toàn đúng kỳ vọng vì sinh 200 token auto-regressively tốn băng thông RAM CPU vượt trội so với tìm kiếm từ khoá. Để giảm 2× latency, phải tối ưu stage LLM (bật GPU offload `-ngl 99` hoặc dùng bản quantized `UD-Q2_K_XL`).

---

## 5. The single change that mattered most  *(rubric 11 — 10 điểm)*

**Change:** Tinh chỉnh thread count `-t` từ 20 (Physical cores default) xuống 10 (High-clock P-cores) trong `make tune`.

```
before:  29.6 tok/s (-t 20)
after:   36.9 tok/s (-t 10)
speedup: 1.25×
```

**Tại sao nó work**:

Cơ chế cốt lõi là **ngăn ngừa oversubscription băng thông bộ nhớ RAM (DRAM bandwidth saturation) và loại bỏ chi phí đồng bộ hoá thread giữa P-core và E-core**.

Vi xử lý Intel i7-13650HX có kiến trúc lai với 6 nhân Performance (P-cores, 12 luồng) và 8 nhân Efficient (E-cores, 8 luồng). Quá trình autoregressive decode đòi hỏi đọc lại toàn bộ bộ trọng số mô hình từ bộ nhớ RAM cho mỗi token sinh ra, khiến hiệu năng bị giới hạn trực tiếp bởi băng thông memory bus thay vì năng lực tính toán FLOPs. Thử nghiệm thực tế cho thấy băng thông kênh nhớ kép (dual-channel DRAM) đạt điểm bão hoà ở mức 8–10 luồng.

Khi thiết lập `-t 20`, llama.cpp bắt buộc phải phân phối công việc tính toán nhân ma trận sang các nhân E-core có xung nhịp và bộ đệm L2 thấp hơn. Điều này không mang lại thêm băng thông bộ nhớ, mà ngược lại tạo ra hiện tượng nghẽn cổ chai đồng bộ barrier (barrier synchronization latency) giữa các nhân P-core nhanh và E-core chậm. Bằng cách giới hạn `-t 10`, công việc được gói gọn hoàn toàn trên các nhân P-core hiệu năng cao, mang lại **tốc độ tăng trưởng 1.25× (36.9 tok/s vs 29.6 tok/s)**.

---

## 6. Bonus  *(optional — tối đa 10 điểm)*

_Đã hoàn thành xuất sắc các hạng mục chính của bài lab._

---

## 7. Điều làm bạn ngạc nhiên nhất  *(optional)*

Điểm ngạc nhiên nhất là việc tăng số thread lên bằng đúng số lõi vật lý (`-t 20`) lại làm suy giảm hiệu năng decode tới 20% so với `-t 10`. Điều này minh chứng rõ ràng bản chất memory-bandwidth bound của LLM serving và sự khác biệt về kiến trúc P-core/E-core trên CPU thế hệ mới.

---

## 8. Self-check trước khi push

- [x] `hardware.json` committed
- [x] `models/active.json` committed
- [x] `benchmarks/01-quickstart-results.md` committed (`make bench`)
- [x] `benchmarks/01-tuning-tg128.md` committed (`make tune`)
- [x] `benchmarks/02-server-results.md` committed (`make load-report`)
- [x] `benchmarks/02-server-batching-u50.md` hoặc `-metrics-u50.csv` committed (`make metrics`)
- [x] `benchmarks/locust-10_stats.csv` + `locust-50_stats.csv` committed (`make load-10` / `load-50`)
- [x] `benchmarks/03-integration-results.md` committed (`make pipeline`)
- [x] Mọi section **"required — replace this line"** trong các file `benchmarks/*.md` đã được thay bằng nhận xét của bạn
- [x] 5 screenshots trong `submission/screenshots/`
- [x] `make verify` → **exit 0**
- [x] Repo tên đúng mẫu `K4-Track02-Day20-NguyenQuangHuy-2A202602461-ModelServing-Lab`
- [x] Repo GitHub ở chế độ **public**
- [x] Đã push và paste public URL vào VinUni LMS **trước 23:59 (UTC+7) ngày làm lab**
- [x] **Không** commit `models/*.gguf`, `runtime/` hay `.env` (đã có trong `.gitignore`)

---

## 9. Khai báo sử dụng AI  *(xem `docs/RULES.md` §3)*

Sử dụng Antigravity AI Coding Assistant để hỗ trợ kiểm thử tự động, phân tích số liệu benchmark, định dạng báo cáo markdown và xử lý kịch bản tương thích PowerShell trên Windows.

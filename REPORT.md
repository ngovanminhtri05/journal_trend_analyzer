# Journal Trend Analyzer — Báo cáo Lab2 (PRM393)

> Bản thảo gọn nhẹ. Chèn ảnh chụp màn hình vào các mục `[ẢNH]` rồi export ra PDF
> (VD: VS Code extension *Markdown PDF*, hoặc `pandoc REPORT.md -o report.pdf`).

**Nhóm:** _<điền tên thành viên + MSSV>_
**Repo:** `PRM393_Lab2_<StudentID>`

---

## 1. Tổng quan

Ứng dụng mobile **Flutter** phân tích xu hướng nghiên cứu học thuật, lấy dữ liệu
**động** từ **OpenAlex API** (không backend, không auth, không database). App gọi
API trực tiếp từ client và trực quan hoá bằng biểu đồ + dashboard.

## 2. Cấu trúc source code

Kiến trúc phân lớp rõ ràng, dữ liệu chảy một chiều: `API → services → state → UI`.

```
lib/
├── models/      # Work, Author, Source, GroupByItem (+ fromJson thủ công)
├── services/    # OpenAlexService (HTTP+parse), exceptions, abstract_decoder
├── state/       # ViewState enum + 3 ChangeNotifier provider
├── screens/     # home_shell + search/detail/trend/dashboard + topic_sync
├── widgets/     # paper_card, stat_card, year_bar_chart, ranked_count_list,
│                #   state_views (loading/error/empty), responsive_body
└── main.dart    # MultiProvider + MaterialApp
test/            # 34 unit/widget test
```

| Lớp | Trách nhiệm |
|-----|-------------|
| **models** | Khuôn dữ liệu, parse JSON null-safe, fallback `display_name→title`, `doi→ids.doi` |
| **services** | Gọi OpenAlex, dựng URL, map lỗi thành exception có kiểu, giải mã abstract |
| **state** | Quản lý trạng thái `loading/success/empty/error` bằng Provider |
| **screens/widgets** | Giao diện chỉ đọc từ Provider, không gọi API trực tiếp |

## 3. Kỹ thuật sử dụng

- **State management:** `provider` (ChangeNotifier) — mỗi màn hình 1 provider,
  có enum `ViewState { idle, loading, success, empty, error }`.
- **HTTP & async:** package `http`, `Future`/`async-await`, `Future.wait` để tải
  song song (Trend/Dashboard), **timeout 15s** chống treo.
- **OpenAlex aggregation:** dùng `group_by` (theo năm / journal / author) để server
  thống kê sẵn → nhẹ cho client; `sort=cited_by_count:desc` cho top papers;
  `meta.count` cho tổng số; `mailto` (polite pool) cho rate limit ổn định.
- **Abstract decode:** OpenAlex trả `abstract_inverted_index` (từ → vị trí),
  hàm `reconstructAbstract` ghép lại đúng thứ tự thành văn bản.
- **Error handling:** exception có kiểu `NetworkException` / `RateLimitException`
  (HTTP 429) / `ParseException`; UI hiện thông báo + nút **Retry**.
- **Charts:** `fl_chart` (BarChart số bài/năm). **DOI:** `url_launcher`.
- **Responsive:** `ResponsiveBody` giới hạn bề rộng trên màn lớn; dashboard grid
  2↔3 cột; text ellipsis khi tràn.
- **Testing:** 34 test (`MockClient` cho service, widget test cho luồng search).
- **Design system (UI):** hệ "editorial minimalism" — nền warm off-white,
  chữ charcoal (không đen tuyệt đối), viền 1px phẳng (bỏ shadow nặng), tương phản
  typography: serif `Fraunces` cho tiêu đề, sans `Manrope` cho body, mono
  `JetBrains Mono` cho số liệu; accent pastel dùng tiết chế. Tập trung ở
  `lib/theme/app_theme.dart` (qua `google_fonts`).
- **Clean code:** đã chạy AI code review, fix 4 issue (xem `AI_CODE_REVIEW.md`).

## 4. API integration

| Chức năng | Endpoint OpenAlex |
|-----------|-------------------|
| FR-1 Search | `/works?search={kw}&per-page=50&mailto=…` |
| FR-4 Top cited | `…&sort=cited_by_count:desc` |
| FR-3 Trend/năm | `…&group_by=publication_year` |
| FR-5 Top journals | `…&group_by=primary_location.source.id` |
| FR-6 Top authors | `…&group_by=authorships.author.id` |
| FR-7 Tổng số | đọc `meta.count` |

## 5. Ảnh chụp các màn hình chính

Ảnh chụp thực tế trên Android emulator (topic mẫu: *blockchain*) đã lưu trong thư
mục `Lab2/`:

- `emulator_home.png` — Search, trạng thái idle (chưa nhập topic)
- `screen_search_results.png` — Search, kết quả (title/year/citations/journal)
- `screen_detail.png` — Detail: authors, DOI, abstract đã decode
- `screen_trends.png` — Trends: biểu đồ theo năm + top journals
- `screen_dashboard.png` — Dashboard: 6 thẻ chỉ số

> Có thể chụp thêm trạng thái empty (topic vô nghĩa) và error+retry (tắt mạng) để minh hoạ.

## 6. AI Code Review

Đã rà soát và sửa **4 vấn đề** (xem chi tiết `AI_CODE_REVIEW.md`):
timeout mạng, rò rỉ HTTP client, lộ thông tin exception ra UI, trùng lặp code.
- [ẢNH] Kết quả công cụ AI review (CodeRabbit/SonarQube/Copilot)

## 7. Build & Run

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Hướng dẫn cài & chạy trên thiết bị thật / emulator: `RUN.md`

## 8. Challenges & Lessons learned

- **Abstract dạng inverted index** — phải tự reconstruct, không có text sẵn.
- **Giảm tải client** — dùng `group_by` của OpenAlex thay vì kéo toàn bộ record.
- **Quản lý trạng thái nhất quán** — enum `ViewState` + widget dùng chung giúp
  mọi màn hình xử lý loading/empty/error đồng nhất.
- **Tách lớp + test** — service inject `http.Client` nên test được không cần mạng.

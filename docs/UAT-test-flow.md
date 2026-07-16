# Journal Trend Analyzer — Luồng test (UAT)

App Flutter tra cứu công bố khoa học qua **OpenAlex API** (gọi trực tiếp từ máy,
không backend). Dùng tài liệu này để test hết tính năng trong **một mạch liên
tục**. Đánh dấu ✅/❌ vào cột Kết quả.

## 0. Chuẩn bị

- Thiết bị/emulator **Android**, **có Internet** (app gọi API trực tiếp).
- Cài file `journal_trend_analyzer-release.apk`:
  - Copy APK sang điện thoại → mở để cài → bật "Cài từ nguồn không xác định" nếu được hỏi; **hoặc**
  - `adb install -r journal_trend_analyzer-release.apk`
- Mở app. Thanh điều hướng dưới có **5 tab**: **Search · Trends · Compare · Dashboard · Saved**.

---

## 1. Search + Detail (FR-1, FR-2)

| # | Bước | Kết quả mong đợi | KQ |
|---|------|------------------|----|
| 1.1 | Tab **Search**, gõ `attention is all you need`, nhấn tìm | Hiện danh sách bài báo (tiêu đề, journal, năm, số trích dẫn) | |
| 1.2 | Đang tải | Có spinner "Searching OpenAlex…" | |
| 1.3 | Gõ từ vô nghĩa `zzzqqq123` rồi tìm | Hiện trạng thái rỗng "No publications found" | |
| 1.4 | Tìm lại `attention is all you need`, **tap 1 bài** | Mở màn **Publication detail**: tiêu đề, năm, citations, tác giả, DOI, abstract | |
| 1.5 | Tap link **DOI** | Mở trình duyệt tới trang DOI | |

## 2. Trends (FR-3/4/5/6) + phân loại xu hướng (FR-9)

| # | Bước | Kết quả mong đợi | KQ |
|---|------|------------------|----|
| 2.1 | Sau khi đã search ở mục 1, sang tab **Trends** | Chart **publications theo năm** + Top journals + Top authors + Top cited papers | |
| 2.2 | Nhìn badge cạnh tiêu đề (Search/Dashboard) | Badge màu **Đang lên / Bão hòa / Đang giảm**; chạm/giữ → tooltip giải thích | |
| 2.3 | Test nhóm khác: search `deep learning` (Đang lên), `fortran` (Đang giảm) | Badge đổi theo chủ đề | |

## 3. Dashboard (FR-7)

| # | Bước | Kết quả mong đợi | KQ |
|---|------|------------------|----|
| 3.1 | Tab **Dashboard** (với topic đã search) | 5 thẻ: tổng publications, avg citations, năm sôi động nhất, top journal, top author + "Most influential paper" | |
| 3.2 | Cạnh "Topic:" | Có badge xu hướng (FR-9) | |

## 4. Bộ lọc phân loại 4 tầng (FR-13)

| # | Bước | Kết quả mong đợi | KQ |
|---|------|------------------|----|
| 4.1 | Tab **Search** → mở **"Filter by topic taxonomy"** | 3 dropdown: Domain → Field → Subfield | |
| 4.2 | Chọn **Domain = Physical Sciences** | Dropdown **Field** chỉ hiện field thuộc domain đó | |
| 4.3 | Chọn **Field = Computer Science** | Dropdown **Subfield** hiện spinner rồi nạp danh sách (gọi /subfields) | |
| 4.4 | Chọn 1 **Subfield** → kết quả search lọc lại | Danh sách thu hẹp theo phân loại | |
| 4.5 | Sang **Trends/Dashboard** | Cùng bộ lọc được áp dụng | |
| 4.6 | Bấm **Clear filters** | 3 filter reset; **keyword search vẫn còn**, chỉ bỏ lọc | |
| 4.7 | Đổi **Domain** | Field/Subfield reset theo | |

## 5. So sánh chủ đề (FR-8)

| # | Bước | Kết quả mong đợi | KQ |
|---|------|------------------|----|
| 5.1 | Tab **Compare**, nhập 2 chủ đề: `deep learning`, `reinforcement learning` | 2 ô nhập | |
| 5.2 | Bấm **Add topic**, nhập ô thứ 3: `computer vision` | Tối đa 3 ô (nút Add mờ khi đủ 3) | |
| 5.3 | Bấm **Compare** | **1 chart đa đường** (mỗi chủ đề 1 màu + legend) | |
| 5.4 | Xem bảng dưới chart | Mỗi hàng 1 chủ đề: Total / Avg cites / Peak year + badge xu hướng | |
| 5.5 | Test lỗi độc lập: 1 chủ đề thật + `zzzqqq` | Chủ đề thật vẫn lên chart; chủ đề kia hiện "no data" — màn **không sập** | |
| 5.6 | Giảm còn 2 ô (nút xoá) | Nút xoá mờ khi còn 2 | |

## 6. Bookmark offline (FR-10)

| # | Bước | Kết quả mong đợi | KQ |
|---|------|------------------|----|
| 6.1 | Mở 1 Publication detail → bấm icon **bookmark** (AppBar) | Icon đổi sang trạng thái đã lưu | |
| 6.2 | Tab **Trends** → bấm bookmark vài **Top journals / Top authors** | Lưu journal/author | |
| 6.3 | Tab **Saved** | Hiện 3 nhóm: Publications / Journals / Authors | |
| 6.4 | **Quan trọng (persist):** đóng hẳn app rồi mở lại → tab **Saved** | Bookmark **vẫn còn** (lưu trên máy) | |
| 6.5 | Trong Saved, tap 1 publication | Mở lại detail (offline) | |
| 6.6 | Bấm nút **xoá** 1 mục | Mục biến mất; mở lại app vẫn đúng trạng thái | |

## 7. Xuất trích dẫn (FR-14)

| # | Bước | Kết quả mong đợi | KQ |
|---|------|------------------|----|
| 7.1 | Publication detail → AppBar bấm **⤴ (Export citation)** | Bottom sheet, chọn **BibTeX / RIS / APA** | |
| 7.2 | Chọn **BibTeX** | Hiện `@article{...}` đủ field; bấm **Copy** / **Share** | |
| 7.3 | Đổi sang **RIS** rồi **APA** | Nội dung đổi định dạng tương ứng | |
| 7.4 | Nếu bài thiếu journal → có nút **Improve metadata** | Bấm → đổi sang bản nhiều trích dẫn nhất có journal | |
| 7.5 | Tab **Saved** → bấm **Export all publications (N) — BibTeX** | Sheet hiện nhiều `@article{...}` nối nhau → Copy/Share | |
| 7.6 | Dán BibTeX vào Zotero/Mendeley (hoặc bibtex.org/Validator) | Parse hợp lệ | |

## 8. Mạng trích dẫn + research gap (FR-15)

| # | Bước | Kết quả mong đợi | KQ |
|---|------|------------------|----|
| 8.1 | Mở 1 paper nổi tiếng (vd `attention is all you need`) → detail | Có 2 mục **References (N)** và **Cited by (N)** | |
| 8.2 | Mở rộng **References** | Lazy load: hiện các bài bài này tham khảo (title / tác giả+năm / citations) | |
| 8.3 | Mở rộng **Cited by** | Các bài trích dẫn nó (mới nhất trước) | |
| 8.4 | Tap 1 item trong danh sách | Mở detail của bài đó (đệ quy); nút **back** quay lại | |
| 8.5 | AppBar detail bấm icon **cây 🌳 (Citation tree)** | Màn cây; root mở sẵn cấp 1 | |
| 8.6 | Bấm mũi tên các node để xuống cấp 2–3 | Cây lồng nhau, thụt lề theo độ sâu (1 request mỗi lần mở) | |
| 8.7 | Chuyển nút **References ↔ Cited by** | Cây dựng lại theo chiều đã chọn | |
| 8.8 | Ở **Cited by**: xem badge **"Emerging"** + dòng tóm tắt xanh | Bài mới + ít trích dẫn được đánh dấu = gợi ý **research gap** | |
| 8.9 | Ở **Cited by**: dải **Sort** → bấm **Most cited** | Sắp lại theo số trích dẫn giảm dần; bấm **Newest** để về mới-nhất | |
| 8.10 | Menu ⋮ trên 1 node | Có **Open / Bookmark / Export citation** | |

## 9. Tổng quát (UI/UX)

| # | Bước | Kết quả mong đợi | KQ |
|---|------|------------------|----|
| 9.1 | Tắt mạng → search | Báo lỗi thân thiện + nút **Retry** (không crash) | |
| 9.2 | Xoay ngang / phóng to cỡ chữ hệ thống | Layout không vỡ, không tràn (overflow) | |
| 9.3 | Chuyển qua lại các tab nhiều lần | State mỗi tab được giữ, mượt | |

---

## Ghi chú cho người test
- Tất cả dữ liệu lấy **trực tiếp từ OpenAlex** → cần mạng; số liệu có thể thay đổi theo thời gian.
- OpenAlex đôi khi có nhiều bản ghi trùng 1 bài (năm/journal khác nhau) — đó là lý do có nút **Improve metadata** ở bước 7.4.
- Báo lỗi kèm: bước số mấy, thiết bị/Android version, ảnh chụp màn hình.

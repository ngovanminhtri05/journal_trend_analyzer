# Hướng dẫn cài đặt & test — Journal Trend Analyzer (Android)

> Ứng dụng PRM393 Lab 03 — phân tích xu hướng nghiên cứu từ dữ liệu **OpenAlex**, tích hợp **Firebase**.
> File cài: **`JournalTrendAnalyzer.apk`** (~55 MB).

---

## 1. Yêu cầu thiết bị
- **Android 6.0 trở lên** (API 23+).
- Có **Google Play Services** (điện thoại phổ thông đều có; máy không có Google như một số máy nội địa TQ sẽ không đăng nhập Google / không nhận thông báo được).
- **Kết nối Internet** (Wi-Fi hoặc 4G) — app lấy dữ liệu trực tiếp từ OpenAlex.
- Một **tài khoản Google** để đăng nhập.

## 2. Cài đặt APK
1. Chép file `JournalTrendAnalyzer.apk` vào điện thoại (qua cáp USB, Zalo, Google Drive, v.v.).
2. Mở file `.apk` bằng trình quản lý file.
3. Android sẽ hỏi cho phép **cài từ nguồn không xác định** → bấm **Cài đặt / Settings** → bật **Cho phép từ nguồn này** → quay lại và bấm **Cài đặt (Install)**.
4. Cài xong → bấm **Mở (Open)**.

> Nếu Google Play Protect cảnh báo "ứng dụng không rõ nguồn gốc": đây là app tự cài (không qua CH Play), bấm **Vẫn cài đặt (Install anyway)**.

---

## 3. Kịch bản test (làm theo thứ tự — có ô ✅ để đánh dấu)

### TC1 — Đăng nhập Google
1. Mở app → màn **Login** ("Journal Trend Analyzer").
2. Bấm **Continue with Google** → chọn tài khoản Google.
3. (Android 13+) Cho phép thông báo khi được hỏi → **Allow**.
- ✅ **Kết quả:** vào màn **Home** với 4 tab dưới đáy: Home · Journals · Keywords · Profile.

### TC2 — Tìm kiếm chủ đề (Home)
1. Ở tab **Home**, gõ một chủ đề, ví dụ **machine learning** → bấm mũi tên tìm.
- ✅ Hiện biểu đồ **"Publications over time"**, các chỉ số (tổng bài, trung bình trích dẫn, năm sôi động nhất…), nhãn xu hướng (Emerging/Mature/Declining), và nút **Export PDF report**.

### TC3 — Chi tiết bài báo
1. Kéo xuống, bấm vào **"Most influential publication"**.
- ✅ Màn chi tiết hiện: tiêu đề, **Authors**, **Abstract**, link **DOI** (bấm mở trình duyệt).

### TC4 — Journals (tạp chí)
1. Tab **Journals** → gõ **robotics** → tìm.
- ✅ Danh sách tạp chí xếp hạng + thống kê. Bấm một tạp chí → chi tiết (tổng bài, bài được trích dẫn nhiều).

### TC5 — Keywords (từ khóa)
1. Tab **Keywords** → gõ **genomics** → tìm.
- ✅ Danh sách từ khóa. Bấm một từ khóa → biểu đồ theo năm + **top tác giả**.

### TC6 — Remote Config
1. Tab **Profile** → thẻ **Remote Config**.
- ✅ Hiện **Max journals = 15**, **Max keywords = 20** (giá trị lấy từ máy chủ Firebase).

### TC7 — Xuất báo cáo PDF + Firebase Storage
1. Về **Home** (đã tìm chủ đề) → bấm **Export PDF report**.
- ✅ Mở **cửa sổ chia sẻ (share)** kèm file `report_<chủ đề>_….pdf` (lưu / gửi được).
- ✅ Sau đó hiện hộp **"Report uploaded"** kèm đường link Firebase Storage → bấm **Copy link**.

### TC8 — Crashlytics
1. Profile → thẻ **Crashlytics** → **Log handled error**.
- ✅ Hiện thông báo nhỏ "Handled error sent to Crashlytics".
2. **Force test crash** → **Crash** → app đóng → **mở lại app**.
- ✅ Báo cáo lỗi được gửi lên Firebase (kiểm ở Firebase Console).

### TC9 — Thông báo đẩy (FCM Push)
1. Profile → **Notifications** → bấm **Copy token** (lấy FCM token của máy).
2. Người quản trị vào **Firebase Console → Messaging → gửi test message** → dán token → gửi.
- ✅ App đang mở → **banner trượt xuống** + tin vào **Notification Center**.
- ✅ App đang ở nền/tắt → thông báo ở **khay hệ thống**; bấm vào → mở app, tin vào danh sách.

### TC10 — Theo dõi tác giả/tạp chí → báo bài mới
1. Tab **Journals** (hoặc Keywords) → tìm → bấm **icon bookmark** để **theo dõi** 1 tạp chí (hoặc 1 tác giả trong Keyword detail).
2. Profile → **Notifications** → bấm **icon 🔄 (refresh)** góc trên phải.
- ✅ Hiện **banner "New paper — <tên>"** + tin vào Notification Center (báo bài mới nhất của mục đã theo dõi).
- Lần sau chỉ báo khi có bài **mới hơn** thật sự; hoặc tự kiểm tra mỗi lần **mở lại app**.

### TC11 — Đăng xuất & giữ phiên
1. Profile → **Sign out** → ✅ quay lại màn **Login**.
2. Đăng nhập lại → **tắt hẳn app → mở lại** → ✅ vào thẳng **Home** (không phải đăng nhập lại).

---

## 4. Bảng tổng hợp (đánh dấu khi test)

| # | Chức năng | Đạt? | Ghi chú |
|---|-----------|:----:|---------|
| TC1 | Đăng nhập Google | ☐ | |
| TC2 | Tìm kiếm + tổng quan (biểu đồ, chỉ số) | ☐ | |
| TC3 | Chi tiết bài báo (Authors/Abstract/DOI) | ☐ | |
| TC4 | Journals + chi tiết tạp chí | ☐ | |
| TC5 | Keywords + chi tiết từ khóa | ☐ | |
| TC6 | Remote Config (15 / 20) | ☐ | |
| TC7 | Export PDF + upload Storage | ☐ | |
| TC8 | Crashlytics (handled + crash) | ☐ | |
| TC9 | FCM push (mở / nền / tắt) | ☐ | |
| TC10 | Theo dõi → báo bài mới | ☐ | |
| TC11 | Đăng xuất + giữ phiên | ☐ | |

---

## 5. Xử lý sự cố thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| Không đăng nhập Google được | Máy phải có **Google Play Services** + đã đăng nhập 1 tài khoản Google + có mạng. |
| Danh sách/biểu đồ không tải | Kiểm tra **Internet**. Bấm nút **Retry** trên màn báo lỗi. |
| Export PDF báo lỗi upload | Cần **mạng**; phần chia sẻ file cục bộ vẫn hoạt động dù không có mạng. |
| Không nhận được push | Kiểm tra đã **cho phép quyền thông báo** (Cài đặt → Ứng dụng → Journal Trend Analyzer → Thông báo); máy có Play Services; đúng **token**. |
| "Không có bài mới" khi bấm 🔄 | Đúng — chỉ báo khi mục theo dõi có bài **mới hơn** lần kiểm tra trước. |
| Play Protect chặn cài | Bấm **Vẫn cài đặt (Install anyway)** — app tự phân phối, không qua CH Play. |

---

## 6. Ghi chú kỹ thuật (cho người chấm)
- **Nền tảng:** Flutter (Dart), kiến trúc **MVVM**, quản lý trạng thái bằng **Provider**.
- **Dữ liệu:** OpenAlex API (gọi trực tiếp từ client, không backend riêng).
- **Firebase:** Authentication (Google), Analytics (7 sự kiện), Remote Config, Crashlytics, Cloud Storage, Cloud Messaging (FCM).
- **Bonus:** thông báo bài mới cho tác giả/tạp chí đã theo dõi (client-side); banner khi foreground; mọi thông báo vào Notification Center.
- Bản APK này ký bằng **debug keystore** (đủ để cài & test; không phải bản ký phát hành CH Play).

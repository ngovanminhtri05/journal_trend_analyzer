# Kịch bản Demo cho khách hàng — Journal Trend Analyzer

> Thời lượng gợi ý: **8–10 phút**. Mục tiêu: cho khách thấy app biến **hàng triệu bài báo** thành **insight xem được ngay**, và giữ chân người dùng bằng thông báo + báo cáo.

---

## 0. Chuẩn bị trước khi demo (làm trước, đừng để khách chờ)
- Điện thoại có **mạng ổn định** + **đã đăng nhập sẵn** (để phần đăng nhập nhanh, hoặc đăng xuất sẵn nếu muốn demo cả bước login).
- **Theo dõi sẵn 1 tạp chí** (vd arXiv) để phần "thông báo bài mới" chạy ngay.
- Chuẩn bị 2–3 **chủ đề đẹp** cho biểu đồ: `machine learning`, `large language models`, `CRISPR`.
- Âm lượng bật (để nghe tiếng thông báo). Xoay dọc, độ sáng cao.
- Mở sẵn tab **Firebase Console → Messaging** trên laptop (để bắn push khi cần).

---

## 1. Mở đầu (30 giây) — nêu vấn đề & giá trị
> *"Mỗi năm có hàng triệu bài báo khoa học được xuất bản. Nhà nghiên cứu, sinh viên, hay bộ phận R&D không thể đọc hết để biết một lĩnh vực đang nóng hay nguội, ai là tác giả dẫn đầu, tạp chí nào uy tín. Journal Trend Analyzer giải quyết đúng việc đó: gõ một chủ đề, có ngay bức tranh xu hướng — trực quan, dữ liệu thật, cập nhật liên tục."*

---

## 2. Kịch bản theo từng cảnh

### Cảnh 1 — Đăng nhập (15s) · *Thông điệp: nhanh & bảo mật*
- Thao tác: mở app → **Continue with Google** → chọn tài khoản → vào Home.
- Lời thoại: *"Đăng nhập một chạm bằng Google — an toàn, không cần tạo mật khẩu mới."*

### Cảnh 2 — Tổng quan xu hướng (90s) · ⭐ *Điểm nhấn chính (WOW)*
- Thao tác: tab **Home** → gõ **`machine learning`** → tìm.
- Chỉ vào **biểu đồ số bài theo năm**, con số **tổng bài**, **trung bình trích dẫn**, **năm sôi động nhất**.
- Lời thoại: *"Chỉ 1 giây, thay vì đọc 4 triệu bài, ta thấy ngay lĩnh vực này bùng nổ từ 2018, đỉnh 2024… Tất cả là dữ liệu thật từ OpenAlex, không phải số liệu tĩnh."*
- Chỉ vào **nhãn xu hướng** (Emerging/Mature/Declining): *"App tự phân loại chủ đề đang lên hay đang chững."*

### Cảnh 3 — Đào sâu 1 bài (30s) · *Thông điệp: từ tổng quan tới chi tiết*
- Thao tác: bấm **"Most influential publication"** → xem tiêu đề, tác giả, **abstract**, bấm **DOI** mở bài gốc.
- Lời thoại: *"Thấy bài đáng chú ý? Một chạm để đọc tóm tắt và mở bài gốc."*

### Cảnh 4 — Tạp chí & Từ khóa (60s) · *Thông điệp: nhiều góc nhìn*
- Thao tác: tab **Journals** → gõ `machine learning` → chỉ **top tạp chí**; bấm 1 tạp chí → chi tiết.
- Thao tác: tab **Keywords** → gõ `machine learning` → bấm 1 từ khóa → chỉ **top tác giả**.
- Lời thoại: *"Muốn biết nên đăng ở đâu, hợp tác với ai? App xếp hạng tạp chí và tác giả dẫn đầu theo chủ đề."*

### Cảnh 5 — Theo dõi & thông báo bài mới (75s) · ⭐ *Điểm nhấn giữ chân người dùng*
- Thao tác: ở danh sách Journals, bấm **icon bookmark** để **theo dõi** 1 tạp chí.
- Vào **Profile → Notifications → bấm 🔄** → **banner "New paper — …" hiện lên**.
- Lời thoại: *"Người dùng theo dõi tác giả/tạp chí quan tâm, app tự báo khi có bài mới — đây là thứ khiến họ quay lại mỗi ngày."*

### Cảnh 6 — Thông báo đẩy thật (45s) · *Thông điệp: kết nối realtime*
- Trên laptop: **Firebase Console → Messaging → gửi test** (đã có token) → điện thoại **kêu + hiện banner**.
- Lời thoại: *"Hệ thống có thể chủ động gửi thông báo tới người dùng — cho tin tức, nhắc nhở, chiến dịch."*

### Cảnh 7 — Xuất báo cáo PDF + Cloud (45s) · ⭐ *Điểm nhấn giá trị công việc*
- Thao tác: về **Home** (đã tìm) → **Export PDF report** → hiện **cửa sổ chia sẻ** + hộp **"Report uploaded"** với link.
- Lời thoại: *"Một chạm để xuất báo cáo PDF gọn gàng — chia sẻ ngay hoặc lưu đám mây để dùng lại."*

### Cảnh 8 — Độ tin cậy (20s, nói nhanh) · *Thông điệp: sẵn sàng vận hành*
- Thao tác: lướt **Profile** cho thấy **Remote Config** (điều chỉnh từ xa) + **Crashlytics** (giám sát lỗi).
- Lời thoại: *"Về mặt vận hành: cấu hình chỉnh từ xa không cần cập nhật app, và mọi lỗi được giám sát tự động."*

---

## 3. Chốt demo (30s)
> *"Tóm lại: Journal Trend Analyzer biến dữ liệu học thuật khổng lồ thành insight xem-được-ngay, giữ chân người dùng bằng theo dõi + thông báo, và tạo ra báo cáo chia sẻ được. Toàn bộ chạy trên nền tảng Google/Firebase, mở rộng dễ dàng."*
> Call to action: *"Anh/chị muốn em cho chạy thử với đúng lĩnh vực của mình không?"* → gõ chủ đề của khách để cá nhân hóa.

---

## 4. Mẹo trình bày
- **Bắt đầu bằng Cảnh 2** (biểu đồ) nếu muốn gây ấn tượng ngay — đăng nhập để sẵn.
- Luôn dùng chủ đề **có nhiều dữ liệu** (chart đẹp): machine learning, cancer, LLM… tránh chủ đề quá hẹp (chart trống).
- Nói theo **giá trị/lợi ích**, đừng đọc tên nút.
- Để **âm lượng bật** cho tiếng thông báo — tạo hiệu ứng "wow".

## 5. Phương án dự phòng (khi có sự cố)
| Sự cố | Xử lý |
|---|---|
| Mạng chậm, biểu đồ lâu tải | Nói "đang lấy dữ liệu realtime"; chuẩn bị sẵn 1 chủ đề đã tải cache trước đó. |
| Đăng nhập Google trục trặc | Đăng nhập sẵn **trước** demo; đừng demo login live nếu không chắc mạng. |
| Push không tới ngay | FCM có thể trễ vài giây; dùng nút **🔄 theo dõi** (Cảnh 5) làm phương án chắc ăn cho "thông báo". |
| Export báo cáo lỗi upload | Phần **chia sẻ file PDF cục bộ** vẫn chạy — nhấn mạnh cái đó. |

## 6. Câu hỏi khách hay hỏi & cách trả lời
- **"Dữ liệu ở đâu ra?"** → OpenAlex, cơ sở dữ liệu học thuật mở, hàng trăm triệu bài, cập nhật liên tục.
- **"Có iOS không?"** → Có, đã dựng nền tảng iOS; build ra được (cần máy Mac/CI để phát hành).
- **"Bảo mật thế nào?"** → Đăng nhập Google, dữ liệu người dùng (báo cáo) lưu riêng theo tài khoản trên Firebase Storage với luật truy cập theo chủ sở hữu.
- **"Mở rộng được không?"** → Nền tảng Firebase, thêm được thông báo theo lịch (server), gợi ý AI, xuất nhiều định dạng…

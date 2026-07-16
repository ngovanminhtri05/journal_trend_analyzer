# HANDOFF — PRM393 Journal Trend Analyzer (Lab 03)

> Dán file này vào một phiên Claude Code mới để tiếp tục. Đây là nguồn ngữ cảnh
> duy nhất: trạng thái, quyết định, kiến trúc, môi trường, việc còn lại.
> **Cập nhật:** 2026-07-17 · **Nhánh:** `main` (đã merge PR #3) & `feat/lab03-firebase`.

---

## 1. App là gì
Ứng dụng **Flutter (Android + iOS)** phân tích xu hướng nghiên cứu từ **OpenAlex API**
(gọi trực tiếp từ client, không backend riêng), tích hợp đầy đủ **Firebase**.
- Code + comment **tiếng Anh**. Thư mục dự án: **`d:\PRM393\Lab2`** (đây là gốc repo git).
- GitHub: `ngovanminhtri05/journal_trend_analyzer`. **Lab 03 đã merge vào `main`** (PR #3, 34 commit).
- Firebase project: **`journal-analyzer-3c319`** (gói **Blaze**, đã bật billing).
- Android app id: **`com.prm393.journal_trend_analyzer`** · iOS bundle: **`com.prm393.journalTrendAnalyzer`**.

## 2. Trạng thái: HOÀN TẤT phần code
- ✅ **121 unit/widget test xanh** (`flutter test`), `flutter analyze` **sạch**.
- ✅ **MVVM**: `models / services / firebase / viewmodels / screens / widgets / utils`. State bằng **Provider**.
  Mọi SDK Firebase nằm sau interface (`AuthApi`, `AnalyticsApi`, `RemoteConfigApi`, `CrashReporterApi`,
  `ReportStorageApi`, `MessagingApi`, `LocalNotifierApi`) → dễ test.
- ✅ **6 dịch vụ Firebase — đã verify chạy thật trên emulator/thiết bị:**
  - Auth (Google Sign-In) + AuthGate.
  - Analytics: 7 sự kiện (login, search_topic, view_publication/journal/keyword, export_pdf, logout).
  - Remote Config: `max_journals=15` / `max_keywords=20` (áp vào danh sách + hiện ở Profile).
  - Crashlytics: handled error + force test crash.
  - **Storage** (Blaze): export PDF → upload `reports/{uid}/…` → hiện link (rule owner-only đã deploy).
  - FCM: quyền + token + foreground/background handler.
- ✅ **Tính năng mở rộng (bonus):**
  - Banner khi foreground (`flutter_local_notifications`) + mọi tin vào Notification Center.
  - **Theo dõi author/journal → báo bài mới** (plan A, client-side): "follow" = bookmark author/journal;
    khi mở app + nút 🔄 trong Notifications → so bài mới nhất với lần trước → local notification.
    (`FollowUpdatesService`, `checkFollowUpdates`, `OpenAlexService.recentWorksByEntity`).
- ✅ **iOS**: đã `flutter create --platforms=ios`, Firebase iOS (GoogleService-Info.plist, GIDClientID,
  URL scheme), Podfile iOS 15. **CI build `.ipa` không cần Mac**: `.github/workflows/ios-unsigned-ipa.yml`
  (macos-15 + Xcode 16) → artifact `.ipa` chưa ký → **Sideloadly** ký & cài (đã chạy thật trên iPhone).
- ✅ **Patrol E2E (Phase 10)**: 11 case ở `integration_test/` (auth/publication/journal/keyword/profile/export)
  + smoke `app_test.dart`. **Đã chạy XANH trên Windows** (xem gotcha Patrol bên dưới).
- ✅ **CodeRabbit** (PR #3): 15 finding → sửa 6 + thêm `storage.rules`.

## 3. Việc CÒN LẠI (thủ công — cần người/thiết bị, không phải code)
1. **Đổi tên repo** `PRM393_Lab03_<StudentID>` — cần **StudentID** (R4).
2. **Chèn screenshot** vào `docs/REPORT-Lab03.md` + điền tên/StudentID → **xuất PDF** (5–10 trang).
3. **Quay video demo** 5–10 phút (dùng `docs/KICH-BAN-DEMO-KHACH-HANG.md`).
4. (Tùy chọn) Cho các **TC feature Patrol** (TC2–TC10) chạy xanh — cần mạng emulator ổn định +
   có thể nới timeout chờ mạng trong test (hiện fail do timeout mạng, KHÔNG phải lỗi code).
5. (Tùy chọn) Enable Analytics **DebugView** để chụp 7 sự kiện cho báo cáo.

## 4. Chạy Patrol E2E (đã hoạt động — LƯU Ý quan trọng)
- Bản dùng được: **`patrol` 4.7.1** (pubspec) + **`patrol_cli` 4.5.1** (`D:\PubCache\bin\patrol.bat`).
  `MainActivityTest.java` dùng `@RunWith(Parameterized.class)` (patrol 4.7 đổi API).
- Lệnh: `patrol test --target integration_test/app_test.dart --device emulator-5554`
  (thêm `PATH` = `D:\flutter\bin;D:\Android\Sdk\platform-tools;D:\PubCache\bin`).
- **Gotcha #1 — dung lượng emulator:** debug/test APK rất nặng → hay gặp
  `INSTALL_FAILED_INSUFFICIENT_STORAGE` (0 test chạy). Fix: **wipe emulator**
  (`emulator -avd prm393_pixel -gpu swiftshader_indirect -no-snapshot-load -wipe-data`).
- **Gotcha #2 — mạng:** emulator mới boot/wipe hay mất DNS → toggle `adb shell svc wifi disable/enable`;
  các test có gọi OpenAlex cần mạng ổn định, nếu không sẽ timeout.
- Lỗi lịch sử đã fix: `StandardFileSystem only supports file:* URIs` / `Invalid depfile` (đường dẫn
  `d:/` chữ thường) là bug patrol_cli cũ — đã hết sau khi nâng patrol/cli + sửa MainActivityTest.

## 5. Kiến trúc & quy ước
- `services/` = tầng dữ liệu: **`OpenAlexService` là HTTP client DUY NHẤT** — thêm method, đừng tạo client mới.
  Cũng chứa `report_builder` (PDF ASCII-safe), `report_file_saver`, `follow_updates_service`, `trend_classifier`…
- `firebase/` = wrapper SDK sau interface; mỗi `*.instance` resolve lazy → test không cần Firebase.
- Reuse: `LogScreenView` (log view 1 lần), `ViewState` enum (loading/success/error/empty).
- Mỗi thay đổi phải giữ **analyze sạch** + thêm **unit test** cho logic thuần.

## 6. Môi trường (Windows) — gotcha
- Flutter **`D:\flutter`** (3.41.9 / Dart 3.11). Android SDK **`D:\Android\Sdk`** (`adb`, `emulator` KHÔNG trên PATH → gọi full path).
- Emulator AVD **`prm393_pixel`** (ảnh `google_apis_playstore` → có Google Play Services). GPU cứng → **màn hình đen**,
  luôn chạy `-gpu swiftshader_indirect -no-snapshot-load`. Máy offline → `adb kill-server; adb start-server`.
- Cold start hay đứng ở **splash ~20–40s** vì `RemoteConfig.fetchAndActivate` (timeout 10s) chạy trước `runApp` — bình thường.
- **Google Sign-In**: `serverClientId` (web OAuth client) set trong `main.dart`; SHA-1 debug đã đăng ký Firebase.
- **Build APK**: debug `flutter build apk --debug` (~200MB); release `flutter build apk --release`
  → `build/app/outputs/flutter-apk/app-release.apk` (~55MB, ký debug-key, Sign-In vẫn chạy).
- **Commit trên PowerShell**: here-string `-m` dễ hỏng, `Out-File -Encoding utf8` thêm BOM → dùng file message
  (`[System.IO.File]::WriteAllText(...)` rồi `git commit -F`) hoặc dùng Bash tool. Cảnh báo `LF→CRLF` vô hại.

## 7. Tài liệu & sản phẩm (trong repo `docs/` và trên Desktop)
- `docs/REPORT-Lab03.md` — báo cáo (có chỗ chèn screenshot).
- `docs/HUONG-DAN-TEST-ANDROID.md` — hướng dẫn cài + test 11 chức năng cho người dùng.
- `docs/KICH-BAN-DEMO-KHACH-HANG.md` — kịch bản demo khách hàng (lời thoại, mẹo).
- `docs/FIREBASE-SETUP.md`, `PLANS-Lab03.md`, `AI_CODE_REVIEW.md`.
- Trên Desktop: `JournalTrendAnalyzer-Android\` = APK release + 2 file hướng dẫn.
  `JournalTrendAnalyzer-ios\` = `.ipa` chưa ký (để Sideloadly).

## 8. Git
- Đã merge `feat/lab03-firebase` → **`main`** (PR #3). Nhánh feature vẫn giữ.
- Conventional Commits. CodeRabbit auto-review khi mở PR (`.coderabbit.yaml`).
- `google-services.json` / `firebase_options.dart` / `GoogleService-Info.plist` (client keys) commit được;
  KHÔNG commit service-account private key (không cần cho lab).

---

**Việc đầu tiên khi vào phiên mới:** đọc `PLANS-Lab03.md`, `git status`, `git log --oneline -5`.
Code đã xong + merge main; việc còn lại chủ yếu **thủ công** (StudentID/rename, screenshot+PDF báo cáo,
video demo) và **tùy chọn** cho các TC Patrol feature chạy xanh.

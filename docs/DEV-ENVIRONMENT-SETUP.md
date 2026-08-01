# Hướng dẫn dựng môi trường dev (PC mới, chưa có gì)

> Cài đầy đủ để code **full-stack** dự án **Journal Trend Analyzer**:
> **Flutter (Android)** + **Firebase backend** (Cloud Functions TypeScript,
> Firestore rules, Auth/Storage/Messaging/Remote Config/Analytics/Crashlytics).
> Hướng dẫn cho **Windows 11**. macOS/Linux ghi chú ở cuối.

---

## 0. Bức tranh tổng thể — cần cài gì

| Thành phần | Dùng để | Phiên bản nên dùng |
|---|---|---|
| **Git** | Tải mã nguồn, quản lý phiên bản | mới nhất |
| **VS Code** (hoặc Android Studio) | IDE viết code | mới nhất + extension Flutter/Dart |
| **JDK 17** | Biên dịch Android/Gradle | **17** (LTS) |
| **Flutter SDK** | Toàn bộ app (Dart) | **3.41.x** (Dart 3.11+) |
| **Android Studio + SDK** | SDK Android, `adb`, `emulator`, máy ảo | Giotto trở lên |
| **Node.js** | Cloud Functions + test rules | **20 LTS** (22 cũng chạy) |
| **Firebase CLI** | Deploy functions/rules, chạy emulator | mới nhất |
| **Patrol CLI** *(tùy chọn)* | Chạy E2E test | 4.7.x |

> Ổ đĩa dự án hiện tại đặt Flutter ở `D:\flutter`, Android SDK ở `D:\Android\Sdk`.
> Trên PC mới bạn đặt đâu cũng được, chỉ cần thêm vào **PATH** cho đúng.

---

## 1. Git

```powershell
winget install --id Git.Git -e
```
Kiểm tra: `git --version`. Đăng nhập GitHub (dùng khi push):
```powershell
git config --global user.name "Tên bạn"
git config --global user.email "email@github"
```

## 2. VS Code + extension

```powershell
winget install --id Microsoft.VisualStudioCode -e
```
Mở VS Code → Extensions (Ctrl+Shift+X) → cài **Flutter** (tự kéo theo **Dart**).
(Nếu thích Android Studio: `winget install --id Google.AndroidStudio -e` — nó cũng cài sẵn Android SDK, tiện ở bước 5.)

## 3. JDK 17

```powershell
winget install --id Microsoft.OpenJDK.17 -e
```
Kiểm tra: `java -version` (phải thấy `17`). Nếu máy có nhiều JDK, trỏ Flutter dùng đúng 17:
```powershell
flutter config --jdk-dir "C:\Program Files\Microsoft\jdk-17..."
```

## 4. Flutter SDK

1. Tải bản ổn định: https://docs.flutter.dev/get-started/install/windows → giải nén vào ví dụ `C:\src\flutter` (tránh thư mục có dấu cách / cần quyền admin).
   Hoặc dùng git:
   ```powershell
   git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter
   ```
2. Thêm `C:\src\flutter\bin` vào **PATH** (Windows → "Edit environment variables" → Path → New).
3. Mở terminal mới, kiểm tra:
   ```powershell
   flutter --version   # cần Flutter 3.41.x / Dart 3.11+
   ```

## 5. Android Studio + SDK + máy ảo

1. Cài Android Studio (nếu chưa ở bước 2):
   ```powershell
   winget install --id Google.AndroidStudio -e
   ```
2. Mở Android Studio → **More Actions → SDK Manager**:
   - Tab **SDK Platforms**: tick **Android 14 (API 34)** trở lên.
   - Tab **SDK Tools**: tick **Android SDK Platform-Tools**, **Android SDK Command-line Tools**, **Android Emulator**.
3. Thêm vào **PATH** (đường dẫn SDK xem trong SDK Manager, thường `%LOCALAPPDATA%\Android\Sdk`):
   - `...\Android\Sdk\platform-tools` (cho `adb`)
   - `...\Android\Sdk\emulator` (cho `emulator`)
4. Tạo máy ảo: **Device Manager → Create Device** → chọn Pixel + system image **có Google Play** (ví dụ `google_apis_playstore`, cần cho Google Sign-In & FCM).
5. Chấp nhận license:
   ```powershell
   flutter doctor --android-licenses
   ```

## 6. Node.js + Firebase CLI (backend)

```powershell
winget install --id OpenJS.NodeJS.LTS -e     # Node 20 LTS
node --version    # v20.x
npm --version
```
Firebase CLI — không cần cài global, dùng qua `npx firebase-tools ...`. Nếu muốn cài global:
```powershell
npm install -g firebase-tools
firebase --version
```

## 7. (Tùy chọn) Patrol CLI — chạy E2E test

```powershell
dart pub global activate patrol_cli
```
Thêm `%LOCALAPPDATA%\Pub\Cache\bin` vào PATH nếu `patrol` báo "not recognized".

---

## 8. Kiểm tra tổng thể

```powershell
flutter doctor
```
Mọi mục **Flutter / Android toolchain / Android Studio** phải ✓. (Mục iOS/Xcode chỉ có trên macOS — bỏ qua trên Windows.)

---

## 9. Lấy mã nguồn & cài phụ thuộc

```powershell
git clone https://github.com/ngovanminhtri05/journal_trend_analyzer.git
cd journal_trend_analyzer

# App (Flutter)
flutter pub get

# Cloud Functions (backend)
cd functions
npm install
cd ..

# Test Firestore rules (tùy chọn)
cd firestore-rules-test
npm install
cd ..
```

## 10. Cấu hình Firebase

Repo đã kèm **client config** của project gốc (`android/app/google-services.json`,
`lib/firebase_options.dart`) — đây là client key (không phải server secret), nên app
**build & chạy được ngay**.

Muốn trỏ sang **Firebase project của bạn** (khuyến nghị nếu tự triển khai):
```powershell
dart pub global activate flutterfire_cli
flutterfire configure          # sinh lại 2 file config cho project của bạn
```
Chi tiết bật từng dịch vụ (Auth Google + SHA-1, Storage, Remote Config, Firestore…):
xem [`FIREBASE-SETUP.md`](FIREBASE-SETUP.md).

> **Bảo mật:** KHÔNG commit `functions/serviceAccountKey.json` (khoá riêng, đã nằm
> trong `.gitignore`). Chỉ dùng nó cục bộ khi chạy `scripts/set-admin-claim.js`.

---

## 11. Các lệnh thường dùng

```powershell
# Chạy app trên máy ảo (bật máy ảo từ Device Manager trước)
flutter run

# Phân tích & test
flutter analyze                         # phải "No issues found!"
flutter test                            # unit/widget test
cd functions; npm test; cd ..           # test Cloud Functions (jest)
cd firestore-rules-test; npm test; cd ..# test Firestore rules (emulator)

# Build APK phát hành
flutter build apk --release
# → build\app\outputs\flutter-apk\app-release.apk

# Deploy backend (cần firebase login 1 lần, mở trình duyệt)
npx firebase-tools login
npx firebase-tools deploy --only functions --project journal-analyzer-3c319
npx firebase-tools deploy --only firestore:rules --project journal-analyzer-3c319

# Cấp quyền admin cho 1 tài khoản (sau khi tài khoản đã đăng nhập app 1 lần)
cd functions
$env:GOOGLE_APPLICATION_CREDENTIALS = ".\serviceAccountKey.json"
node scripts/set-admin-claim.js <email-hoặc-uid>
```

> Repo **không có `.firebaserc`**, nên các lệnh Firebase phải kèm
> `--project journal-analyzer-3c319`.

---

## 12. Lỗi hay gặp (gotcha)

| Triệu chứng | Cách xử lý |
|---|---|
| `flutter`/`adb`/`emulator` "not recognized" | Chưa thêm vào PATH — mở lại terminal sau khi sửa PATH. |
| Máy ảo **màn hình đen** | Chạy kèm cờ: `emulator -avd <tên> -gpu swiftshader_indirect -no-snapshot-load`. |
| Máy ảo **mất mạng** sau khi boot | `adb shell svc wifi disable` rồi `adb shell svc wifi enable`. |
| Google Sign-In lỗi `ApiException: 10` | Thiếu **SHA-1** trên Firebase Console (xem FIREBASE-SETUP.md mục 5). |
| `INSTALL_FAILED_INSUFFICIENT_STORAGE` khi test | Wipe máy ảo (Device Manager → Wipe Data) — APK debug/test rất nặng. |
| Build lỗi liên quan JDK | Đảm bảo **JDK 17**; trỏ đúng bằng `flutter config --jdk-dir`. |
| Lỗi native sau khi thêm dependency | Dừng và chạy lại `flutter run` (hot reload không nạp plugin native mới). |
| `firebase login` không mở được qua terminal của agent | Phải tự chạy trong terminal thật (cần trình duyệt). |

---

## 13. macOS / Linux (khác biệt chính)

- Cài công cụ bằng **Homebrew** (`brew install git node openjdk@17`) thay cho `winget`; tải Flutter/Android Studio từ trang chủ.
- Biến môi trường đặt trong `~/.zshrc` / `~/.bashrc` (thêm `export PATH="$HOME/flutter/bin:$PATH"` …).
- **Chỉ macOS** mới build được iOS (cần Xcode). Windows/Linux chỉ build Android.
- Đổi cú pháp env khi chạy script: `GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json node scripts/set-admin-claim.js <id>`.

---

## Thứ tự tối thiểu để chạy được app
1) Git → 2) Flutter (+PATH) → 3) JDK 17 → 4) Android Studio + SDK + máy ảo →
5) `flutter doctor` sạch → 6) `flutter pub get` → 7) `flutter run`.

Backend (Node + Firebase CLI + functions/npm install) chỉ cần khi bạn **sửa/deploy Cloud Functions hoặc rules**.

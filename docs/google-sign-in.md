# Đăng nhập Google trên mobile

Mobile dùng API Google hiện có của backend. Bản cập nhật này bổ sung cấu hình presenter Android cho bộ xác thực Google ở backend theo sự cho phép của chủ dự án; không thay đổi frontend hoặc hợp đồng API:

- `POST /auth/google/challenge` lấy Web Client ID, nonce và cookie dùng một lần.
- Đối chiếu Web Client ID trong cấu hình mobile với challenge, rồi mở trình chọn tài khoản Google của Android/iOS với đúng nonce và server Client ID.
- `POST /auth/google` gửi `credential`, `rememberMe` và cookie của lần xác thực đó.
- Lưu access/refresh token của organicfood trong secure storage. Không lưu Google ID token hoặc cookie challenge.
- Chỉ nhận tài khoản CUSTOMER. Tài khoản mới được hướng dẫn bổ sung số điện thoại.
- Tài khoản đã có email/mật khẩu có thể vào **Tài khoản → Liên kết Google**. API liên kết yêu cầu xác nhận mật khẩu hiện tại và email Google trùng email hồ sơ.

Mỗi lần mở Google tạo một platform instance mới để dùng nonce mới, thay vì khởi tạo lại singleton của `google_sign_in`. Việc hủy chọn tài khoản không tạo phiên đăng nhập.

## Android

Web Client ID hiện được khai báo trực tiếp trong `lib/core/config/google_auth_config.dart`, tại `GoogleAuthConfig.webClientId`. Giá trị mặc định được đối chiếu với challenge của backend đang chạy trên máy phát triển. Đây là ID công khai; không sao chép Client Secret vào app và không cần thêm Firebase.

SDK nhận ID này qua `serverClientId`. App vẫn gọi challenge để lấy nonce/cookie mới và kiểm tra ID khớp với backend. Khi chuyển backend/project Google, sửa giá trị mặc định trong file trên hoặc chạy:

```powershell
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=WEB_CLIENT_ID.apps.googleusercontent.com
```

Stop rồi Run lại sau khi sửa cấu hình; hot reload không thay đổi giá trị compile-time. Nếu mobile và backend không cùng Web Client ID, app báo rõ cấu hình chưa khớp trước khi mở Google.

Trong **cùng dự án Google Cloud** đang dùng cho backend/frontend, vẫn cần có OAuth Client loại **Android** khớp:

- Package: `vn.huit.organic_mobile`.
- SHA-1 của chứng thư ký APK đang chạy. Lấy SHA-1 của bản debug bằng PowerShell:

```powershell
& "$env:JAVA_HOME\bin\keytool.exe" -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Nếu chưa có OAuth Android, vào Google Cloud → Google Auth Platform → Clients → Create client → Android, nhập package và SHA-1 trên. Bản release/Google Play dùng chứng thư ký tương ứng, cần đăng ký SHA-1 tương ứng. Khi consent screen còn Testing, tài khoản thử phải có trong danh sách test users nếu Google yêu cầu.

Chạy bằng cấu hình **Organic Android USB** hoặc **Organic Android Emulator**. Cả hai đều sử dụng Web Client ID mặc định trong dự án; chỉ cần `--dart-define` cho Google khi đổi sang môi trường khác.

Không tự bỏ kiểm tra nonce, chữ ký, audience hoặc presenter khi Google từ chối đăng nhập. Backend chỉ nhận presenter là Web Client ID hoặc Android Client ID được khai báo rõ trong allowlist. Điền Android Client ID trong phần `app.auth.google.android-client-ids` đã có của `organic_backend/src/main/resources/application.yml`, hoặc đặt biến môi trường `GOOGLE_ANDROID_CLIENT_IDS`, rồi khởi động lại backend. Web Client ID hiện có của backend và mobile vẫn phải trùng nhau; không cần file cấu hình Google riêng.

### Chọn Gmail xong vẫn quay lại form đăng nhập

Log máy ảo ngày 06/11/2026 có `UNREGISTERED_ON_API_CONSOLE`, sau đó `[16] Account reauth failed`. Lỗi xảy ra trong Google Play services, trước khi SDK trả ID token. Việc thêm tài khoản Gmail vào máy ảo không thay thế bước đăng ký OAuth cho ứng dụng Android.

Vào Google Cloud Console → chọn **cùng project đang chứa Web Client ID mà backend sử dụng** → **Google Auth Platform → Clients** (hoặc **APIs & Services → Credentials**). Tạo hoặc đối chiếu OAuth Client loại **Android** với bản debug hiện tại:

```text
Package name: vn.huit.organic_mobile
SHA-1: EF:F8:4F:72:53:0E:F9:C8:FC:A2:56:34:2F:98:84:66:3E:D3:DD:13
```

Fingerprint trên được đọc từ debug keystore trên máy phát triển này, không dùng cho một máy hoặc chứng thư release khác. Bản UAT có package `vn.huit.organic_mobile.uat` cần đăng ký riêng nếu muốn dùng Google. Android SDK nhận **Web Client ID** trong cấu hình mobile, có đối chiếu với challenge; không thay `serverClientId` bằng Android Client ID và không đưa Client Secret vào mobile.

Sau khi lưu cấu hình Google Cloud và đợi cấu hình cập nhật, mở lại app để thử Google. Nếu chưa được, xem lỗi mới trong `adb logcat`; không tự kết luận tài khoản cần mật khẩu organicfood. SDK có thể trả `canceled` cả khi lỗi cấu hình; mobile hiện thông báo nếu Google trả rõ lỗi reauth/configuration, và nhắc đăng nhập chưa hoàn tất khi không có credential. App không thể khắc phục việc Google chưa đăng ký ứng dụng bằng cách bỏ kiểm tra token ở backend.

### Backend báo thông tin Google không hợp lệ hoặc hết hạn

Thông báo này khác lỗi `UNREGISTERED_ON_API_CONSOLE`: credential đã được gửi tới API nhưng backend từ chối. Đặt cùng Web Client ID vào mobile không đảm bảo giải quyết mọi nguyên nhân xác thực.

Bản debug ghi một dòng `[GoogleAuth] Backend rejected credential; unverified checks: ...` nếu API trả 401. Dòng này chỉ chứa các cờ boolean, không chứa ID token, email, mã tài khoản hoặc nonce:

- `audienceMatches`: audience có khớp Web Client ID của challenge.
- `presenterMatchesWebClient`: presenter có bằng Web Client ID (hoặc không có `azp`). Giá trị `false` có thể hợp lệ với Android khi backend đã cấu hình Android Client ID tương ứng. Bản debug trước khi cập nhật backend gọi cờ này là `presenterMatchesBackendPolicy`.
- `nonceMatches`: nonce có khớp lần challenge hiện tại.
- `notExpired`: thời hạn token theo đồng hồ thiết bị.

Đây chỉ là đọc payload chưa xác thực để chẩn đoán, không kiểm tra chữ ký và không tạo phiên đăng nhập. Backend vẫn là nơi quyết định xác thực. Nếu audience/nonce/thời hạn đúng nhưng presenter khác Web Client ID, kiểm tra Android Client ID trong allowlist của backend: token Android có thể có presenter là Android Client ID dù audience là Web Client ID, theo tài liệu OpenID Connect của Google. Mobile không thể sửa các claim Google đã ký.

Lần thử trên máy ảo ngày 06/11/2026 sau khi cài bản có Web Client ID trong mobile đã ghi nhận:

```text
readable: true
audienceMatches: true
presenterMatchesBackendPolicy: false
nonceMatches: true
notExpired: true
```

API vẫn trả lỗi token không hợp lệ/hết hạn. Token của lần thử này không đáp ứng điều kiện presenter cũ của backend; đưa cùng Web Client ID vào mobile không thay đổi kết quả. Sau khi chủ dự án cho phép chỉnh phần Google ở backend, bộ xác thực được bổ sung allowlist `app.auth.google.android-client-ids` trong file `organic_backend/src/main/resources/application.yml`, hoặc biến môi trường `GOOGLE_ANDROID_CLIENT_IDS`. Cần điền chính xác Android Client ID lấy từ Google Cloud và khởi động lại backend để kích hoạt; không nhận mọi Client ID hoặc chỉ đối chiếu tiền tố project.

## iOS

Adapter iOS đã có nhưng chưa build trên Windows. Tạo OAuth Client iOS khớp bundle ID thực tế, chạy với `--dart-define=GOOGLE_IOS_CLIENT_ID=IOS_CLIENT_ID`, và thêm URL scheme đảo ngược của Client ID đó vào `ios/Runner/Info.plist` theo hướng dẫn chính thức bên dưới. Không dùng Web Client ID thay cho iOS Client ID. Cần macOS/Xcode để kiểm tra bản iOS.

## Nguồn

- [Thiết lập Google Sign-In Android](https://pub.dev/packages/google_sign_in_android).
- [Thiết lập Google Sign-In iOS và URL scheme](https://pub.dev/packages/google_sign_in_ios).
- [Nonce và quy tắc khởi tạo Google Sign-In](https://pub.dev/documentation/google_sign_in/latest/google_sign_in/GoogleSignIn/initialize.html).
- [Google OpenID Connect: audience và authorized presenter](https://developers.google.com/identity/openid-connect/openid-connect).
- Logo G lấy từ [Google Identity](https://developers.google.com/identity/images/g-logo.png).

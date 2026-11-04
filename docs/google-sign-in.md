# Đăng nhập Google trên mobile

Mobile dùng API Google hiện có của backend, không thay đổi backend hoặc frontend:

- `POST /auth/google/challenge` lấy Web Client ID, nonce và cookie dùng một lần.
- Mở trình chọn tài khoản Google của Android/iOS với đúng nonce và server Client ID.
- `POST /auth/google` gửi `credential`, `rememberMe` và cookie của lần xác thực đó.
- Lưu access/refresh token của organicfood trong secure storage. Không lưu Google ID token hoặc cookie challenge.
- Chỉ nhận tài khoản CUSTOMER. Tài khoản mới được hướng dẫn bổ sung số điện thoại.
- Tài khoản đã có email/mật khẩu có thể vào **Tài khoản → Liên kết Google**. API liên kết yêu cầu xác nhận mật khẩu hiện tại và email Google trùng email hồ sơ.

Mỗi lần mở Google tạo một platform instance mới để dùng nonce mới, thay vì khởi tạo lại singleton của `google_sign_in`. Việc hủy chọn tài khoản không tạo phiên đăng nhập.

## Android

Web Client ID được lấy từ backend, không sao chép Client Secret vào app và không cần thêm Firebase. Trong **cùng dự án Google Cloud** đang dùng cho backend/frontend, cần có OAuth Client loại **Android** khớp:

- Package: `vn.huit.organic_mobile`.
- SHA-1 của chứng thư ký APK đang chạy. Lấy SHA-1 của bản debug bằng PowerShell:

```powershell
& "$env:JAVA_HOME\bin\keytool.exe" -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Nếu chưa có OAuth Android, vào Google Cloud → Google Auth Platform → Clients → Create client → Android, nhập package và SHA-1 trên. Bản release/Google Play dùng chứng thư ký tương ứng, cần đăng ký SHA-1 tương ứng. Khi consent screen còn Testing, tài khoản thử phải có trong danh sách test users nếu Google yêu cầu.

Chạy bằng cấu hình **Organic Android USB** hoặc **Organic Android Emulator**. Android dùng server Client ID do challenge API trả về; không cần `--dart-define` cho Google.

Không tự bỏ kiểm tra nonce, chữ ký, audience hoặc presenter khi Google từ chối đăng nhập. Nếu backend từ chối ID token, kiểm tra cấu hình OAuth với chủ backend; app hiển thị lỗi API, không sửa chính sách máy chủ.

## iOS

Adapter iOS đã có nhưng chưa build trên Windows. Tạo OAuth Client iOS khớp bundle ID thực tế, chạy với `--dart-define=GOOGLE_IOS_CLIENT_ID=IOS_CLIENT_ID`, và thêm URL scheme đảo ngược của Client ID đó vào `ios/Runner/Info.plist` theo hướng dẫn chính thức bên dưới. Không dùng Web Client ID thay cho iOS Client ID. Cần macOS/Xcode để kiểm tra bản iOS.

## Nguồn

- [Thiết lập Google Sign-In Android](https://pub.dev/packages/google_sign_in_android).
- [Thiết lập Google Sign-In iOS và URL scheme](https://pub.dev/packages/google_sign_in_ios).
- [Nonce và quy tắc khởi tạo Google Sign-In](https://pub.dev/documentation/google_sign_in/latest/google_sign_in/GoogleSignIn/initialize.html).
- Logo G lấy từ [Google Identity](https://developers.google.com/identity/images/g-logo.png).

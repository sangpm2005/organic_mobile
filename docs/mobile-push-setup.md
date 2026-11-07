# Cấu hình thông báo đẩy

## Android

1. Dùng cùng Firebase project với Firebase Admin của backend. Trong **Project settings → Your apps**, thêm ứng dụng Android package `vn.huit.organic_mobile`.
2. Tải `google-services.json`, đặt ở `android/app/google-services.json` (Git đã bỏ qua). Không đặt private service-account backend vào app hoặc dùng file Web thay Android.
3. Code chỉ bật Google Services khi file tồn tại. Bản chưa cấu hình vẫn dùng được cửa hàng, nhưng chưa đăng ký được push.
4. Chạy `flutter pub get`, dừng và build/run lại; hot reload không nạp cấu hình Android.
5. Backend mới cho CUSTOMER dùng `PUT/DELETE /api/v1/notifications/devices`; cần migration push inbox và khóa Firebase Admin riêng phía backend.
6. Khách vào **Tài khoản → Thông báo trên điện thoại → Bật thông báo**, chấp thuận quyền hệ điều hành.

Chỉ xin quyền sau thao tác Bật. Token gắn với tài khoản đăng nhập, được cập nhật khi đổi; Tắt/đăng xuất gỡ đăng ký và thu hồi token. Adapter giữ FCM registration token để khớp backend hiện tại, chưa chuyển sang Firebase Installation ID.

## Kiểm tra thủ công

1. Bật thông báo, đưa app xuống nền bằng nút Home.
2. Nhân viên trên web cập nhật đơn hoặc trả lời phản hồi/đổi trả của đúng khách.
3. Chờ job backend và FCM, chạm thông báo để mở đúng chi tiết. API vẫn kiểm tra quyền sở hữu.
4. Khi foreground, inbox cập nhật và app hiện thông báo nhỏ. Nhận push không tự đánh dấu đã đọc.
5. Đổi tài khoản: payload cũ không mở dữ liệu tài khoản mới. Payload cần `type=CUSTOMER_INBOX`, `accountId`, `notificationId`, `target` thuộc đường dẫn khách hàng.

Force stop trên Android chặn nhận cho đến khi mở lại app. Không có Firebase không ảnh hưởng inbox.

## iOS và UAT

iOS cần `GoogleService-Info.plist` đúng bundle ID, APNs key trên Firebase, Push Notifications capability và Background Modes trong Xcode. Đặt `FirebaseMessagingAutoInitEnabled=false` trong Info.plist để không tự đăng ký trước khi người dùng chọn Bật. Chưa nghiệm thu iOS trên Windows.

UAT dùng package `vn.huit.organic_mobile.uat`, cần ứng dụng Firebase/cấu hình riêng khớp package; file app thường không dùng được cho UAT.

Tham khảo: [Firebase Flutter](https://firebase.google.com/docs/flutter/setup), [FCM Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), [nhận và mở thông báo](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).

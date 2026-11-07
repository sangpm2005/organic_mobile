# Hoàn thiện mobile theo luồng khách hàng

Đã đối chiếu đề cương CNTT-KLCN085, trang 2, 3 và 5: tìm/xem sản phẩm; mua/theo dõi đơn; tích và dùng điểm; thông báo/ưu đãi. Trang 4 nêu đổi mật khẩu trong nhóm chức năng cơ bản. Quản trị nhân viên, nhà cung cấp, kho, thanh lý và báo cáo thuộc website.

## Phần bổ sung

| Chức năng | Kết quả |
| --- | --- |
| Sản phẩm giảm giá | Đọc `home.discountedProducts`, tối đa 8 sản phẩm, không trùng; chỉ hiển thị khi giá gốc lớn hơn giá bán. Giữ các chức năng tìm kiếm, danh mục, ảnh, quy cách, nguồn gốc và chứng nhận đang có. |
| Mật khẩu | Quên mật khẩu tại đăng nhập, Đổi mật khẩu trong tài khoản. Gửi OTP email, xác thực, đặt mật khẩu, xóa phiên sau khi backend xác nhận. OTP, quyền đổi và mật khẩu chỉ ở bộ nhớ màn hình. |
| Thanh toán | Chi tiết đơn tự đối chiếu giao dịch đang chờ khi mở/quay lại và định kỳ lúc đang xem. Không tạo giao dịch mới khi polling. PayPal capture qua backend, vẫn cần khách chấp thuận trên cổng PayPal. Thành công chỉ từ backend. |
| Thông báo | Inbox đơn hàng mở đúng chi tiết, không cộng trùng thông báo tổng hợp cùng đơn. Chuẩn bị Firebase Messaging, bật/tắt theo thiết bị, token đổi, gỡ khi đăng xuất, mở đúng màn hình từ push và bỏ qua payload khác chủ tài khoản. |
| Release | Yêu cầu khóa riêng qua `android/key.properties`, không tiếp tục ký release bằng debug key. Debug vẫn dành cho demo. |
| Chính sách | Sáu trang tích điểm, đổi trả, giao hàng, bảo mật, phương thức thanh toán và hướng dẫn mua hàng đọc ngay trong app. Nội dung lấy từ chính sách hiện tại của website, không mở sang trình duyệt. |

Giữ quy tắc ưu đãi công khai + voucher; voucher và điểm trừ trực tiếp loại trừ nhau. Giá, tồn, điểm và điều kiện hậu mãi vẫn do backend quyết định. Giữ phản hồi/ảnh/video, đổi trả và đánh giá hiện có; phê duyệt, nhận kho và chuyển tiền thuộc nhân viên trên web.

## Demo thủ công

### Đổi/quên mật khẩu

1. Backend đã chạy bản có `/auth/password/*`, SendGrid gửi email được. Dùng tài khoản có email bạn nhận được thư; tài khoản có địa chỉ `example.com` không nhận được OTP thực tế.
2. Khách mở **Tài khoản → Đổi mật khẩu → Gửi mã xác thực**.
3. Nhập 6 số trong email, nhập mật khẩu mới hai lần: ít nhất 8 ký tự, tối đa 72 byte UTF-8; không dùng lại mật khẩu hiện tại.
4. Sau khi lưu thành công, đăng nhập lại bằng mật khẩu mới.
5. Thử OTP sai/hết hạn, mật khẩu xác nhận không khớp và mất mạng: không báo lưu thành công nếu backend từ chối.
6. **Quên mật khẩu?** dùng email đăng ký. Phản hồi không tiết lộ email có tài khoản hay không.

### Mua hàng, điểm và hậu mãi

1. Chọn sản phẩm còn tồn; đối chiếu ảnh, giá, quy cách với website.
2. Chọn địa chỉ, mã công khai/voucher và xem tổng giá từ preview. Thử voucher + điểm trực tiếp phải bị chặn.
3. Đặt đơn sandbox, sang cổng thanh toán; sau khi chấp thuận/thanh toán, quay lại app. Chi tiết tự đối chiếu; hủy trên cổng không được hiển thị đã trả tiền.
4. Nhân viên giao và hoàn tất trên web. Kiểm tra trạng thái, giờ giao dự kiến và điểm của khách trên mobile.
5. Gửi đổi trả đủ điều kiện kèm ảnh, nhận và xác nhận phương án; theo dõi tiền hoàn thực tế, đối chiếu điểm và tiền với web/database.

### Thông báo

Xem [cấu hình push](mobile-push-setup.md). Thiếu cấu hình, nút Bật phải hiển thị lý do và inbox vẫn dùng được; không báo đã bật thành công.

## Giới hạn nghiệm thu

- Push thật chưa nghiệm thu vì chưa có cấu hình Firebase Android. Email thật cần SendGrid. Không gửi email/push thật trong unit/widget test.
- Backend chưa có nghiệp vụ chiến dịch push khuyến mãi hàng loạt; ưu đãi vẫn đọc từ API khi dùng app.
- Thanh toán, giao, hoàn tiền và vòng đời điểm cần người dùng kiểm thử thủ công bằng sandbox/UAT. Mock test/build không chứng minh giao dịch đầu cuối.
- Chưa có deep link thanh toán riêng, khách quay lại app để đối chiếu tự động. Push có điều hướng riêng khi mở từ thông báo.
- iOS cần macOS/Xcode/APNs; chưa build trên Windows. Yêu thích còn lưu local vì backend chưa có API đồng bộ.
- Không đổi backend, SQL hoặc dữ liệu kinh doanh trong lần bổ sung mobile này.

## Kiểm chứng trên máy phát triển

- `flutter analyze --no-pub`: không có lỗi hoặc cảnh báo.
- `flutter test --concurrency=2`: 132 kiểm tra đạt. Các yêu cầu HTTP và Firebase trong test được giả lập, không tạo đơn, thanh toán, gửi OTP/push hoặc thay tồn kho thật.
- Có kiểm tra giao diện ba bước mật khẩu ở kích thước 390×844 và hồi quy giao diện sản phẩm ở 320/390px với cỡ chữ lớn trong suite đang có.
- Kiểm tra hủy đơn được cập nhật để phân biệt đối chiếu thanh toán tự động với thao tác hủy: chọn Giữ đơn không được gọi API hủy.
- APK debug đã build thành công ngày 06-11-2026 tại `build/app/outputs/flutter-apk/app-debug.apk`, bằng `scripts/build-debug.ps1`. Bản này mặc định kết nối backend qua địa chỉ dành cho Android Emulator `http://10.0.2.2:8088/api/v1`; dùng điện thoại thật cần build với địa chỉ máy chủ phù hợp theo README.

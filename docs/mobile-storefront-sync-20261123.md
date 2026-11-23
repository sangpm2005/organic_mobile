# Đồng bộ mobile với cửa hàng web — 23/11/2026

Phạm vi là ứng dụng khách hàng. Các nghiệp vụ nhân viên, kho, thu mua và phê duyệt tiếp tục thực hiện trên website. Đợt này chỉ chỉnh mobile, dùng API backend hiện có; không thêm cột/bảng database hoặc thay cấu hình Firebase, cổng thanh toán, kiểm tra điện thoại 9–10 số.

## Những phần được hoàn thiện

- **Hạn sử dụng:** chỉ hiện một dòng “Hạn sử dụng” trong chi tiết, không có bộ chọn nhiều ngày, không hiện trên thẻ ở trang chủ/danh sách. Ngày lấy từ lô đủ điều kiện và còn lượng trống do backend cung cấp. Khi hết lô, lần tải lại nhận ngày tương ứng lô tiếp theo.
- **Hàng thường và ưu đãi:** tự chọn một ưu đãi trực tiếp đang bán. Nếu hết ưu đãi, trang sản phẩm trở về hàng thường, backend xuất lô theo FEFO. Ngày hiển thị không biến thành yêu cầu khóa lô trong đơn hàng thường. Giỏ/đơn ưu đãi cũ, combo và dòng giỏ cũ có ngày vẫn giữ đúng giá/ngày/khóa lựa chọn.
- **Thẻ sản phẩm:** giá và lượng còn mua lấy theo ưu đãi hiện tại; hàng đã xác nhận hết được ẩn. Thêm nhanh kiểm tra lại tồn, giữ đúng mã ưu đãi; giá/chương trình hoặc phiên đăng nhập vừa thay đổi thì không tự thêm giỏ. Trường hợp chỉ có combo mở chi tiết để xem combo.
- **Trang chủ:** lấy thêm `/home/discounted-stock`, gộp với sản phẩm giảm giá hiện tại theo ID, ưu tiên thông tin ưu đãi mới. Danh mục tối đa 8 mục, xếp theo số sản phẩm giảm dần, loại danh mục combo.
- **Mua kèm:** gọi `/products/{id}/cross-sell?k=3`. Top-K được tính tại backend từ đơn đã hoàn tất; app chỉ hiển thị các sản phẩm trả về. Không có kết quả thì ẩn mục, không tự tạo gợi ý.
- **Mô tả:** tách đoạn/tiêu đề theo nội dung đã lưu, không tự thêm thông tin nhãn hàng, công dụng hoặc chứng nhận.
- **Giao hàng:** hiển thị giờ đến, quãng đường, số phút và đếm ngược từ kết quả backend. Hiểu thời gian không có offset là giờ Việt Nam. Dừng đếm khi app ở nền, trang bị che hoặc chuyến giao đã kết thúc; quay lại đọc đúng giờ hiện tại. Hết giờ chỉ báo đang chờ xác nhận kết quả giao, không tự đánh dấu đã giao. Không hiện dòng “Dữ liệu tuyến đường”.

## Những luồng đã có và được kiểm tra lại

Đăng nhập/Google/OTP, địa chỉ và xác định vị trí, giỏ khách/tài khoản, thanh toán và đối chiếu, điểm/voucher, thông báo, phản hồi kèm ảnh, đổi trả và xác nhận phương án, đánh giá/xóa đánh giá, yêu thích và chính sách. Bộ kiểm thử dùng HTTP/secure-storage mô phỏng, không chuyển tiền, tạo đơn kinh doanh hoặc thay tồn thật.

## Cách xem trên app

1. Khởi động backend mới; chạy lại Flutter hoặc cài APK debug mới. Bản mặc định dùng `http://10.0.2.2:8088/api/v1` trên giả lập Android. Điện thoại thật cần URL/IP truy cập được từ thiết bị.
2. Xem trang chủ: không quá 8 danh mục, có ưu đãi thực; thẻ không hiện hạn dùng.
3. Mở chi tiết: xem một dòng hạn dùng, đổi khối lượng và đối chiếu giá/tồn. Không có nút chọn hạn dùng.
4. Thêm nhanh và thêm từ chi tiết; kiểm tra đúng quy cách và ưu đãi trong giỏ. Khi ưu đãi hết, giỏ cũ không được tự đổi thành hàng thường.
5. Xem mục Gợi ý mua kèm nếu có lịch sử mua phù hợp; bấm mở đúng sản phẩm.
6. Mở đơn đang giao có kết quả tính giờ từ backend: có đếm ngược. Đưa app xuống nền rồi mở lại; thời gian phải cập nhật theo giờ thật. Với chuyến chưa tính được giờ, app hiển thị thông báo chờ cập nhật.

Tự xác nhận các khoản thanh toán sandbox, push trên điện thoại và dịch vụ bản đồ thật vẫn cần nghiệm thu với tài khoản/cấu hình triển khai. Build và test không thay thế những bước này.

## Kết quả kiểm tra

- Trước chỉnh sửa: 160 kiểm thử đạt. Sau chỉnh sửa: toàn bộ 170 kiểm thử đạt, bao gồm chặn thêm nhanh khi giá/phiên thay đổi, giữ khóa giỏ, ngày hiển thị tách khỏi điều kiện đặt hàng, dữ liệu Top-K và thời gian giao theo múi giờ Việt Nam.
- `flutter analyze --no-pub`: không có vấn đề.
- `flutter build apk --debug --no-pub`: thành công. APK mới nằm tại `build/app/outputs/flutter-apk/app-debug.apk`, mặc định dành cho giả lập kết nối `10.0.2.2:8088`.
- Đã xem ảnh kiểm tra bố cục hạn dùng ở chiều rộng 320 px, cỡ chữ 1.5 lần. Chưa cài APK mới hoặc thực hiện giao dịch thật trong đợt này.

## Căn chỉnh thẻ sản phẩm

- Căn đều ảnh, tên, quy cách, giá, tồn và nút giữa các thẻ; giữ nguyên tên đầy đủ.
- 9 tình huống bố cục ở chiều rộng 320/390/768 px và cỡ chữ 1/1.5/2 lần đạt; 22 kiểm thử giao diện liên quan đạt. Phân tích mã và build APK debug thành công sau thay đổi bố cục.

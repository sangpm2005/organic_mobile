# Bổ sung trải nghiệm mobile — 07/11/2026

Phạm vi: đồng bộ các điểm còn thiếu đã được người dùng duyệt trong báo cáo đối chiếu mobile/web. Dùng API hiện tại; không sửa SQL, không thêm bảng và không thay đổi cấu hình riêng của backend. Giữ nguyên kiểm tra điện thoại 9–10 chữ số trong hồ sơ theo yêu cầu. Việc thông báo đẩy đã được người dùng thử thành công, không làm lại luồng FCM.

## Những phần đã bổ sung

| Phần | Cách sử dụng và giới hạn |
| --- | --- |
| Vị trí giao hàng | Chọn địa chỉ đầy đủ hoặc mở thanh toán với địa chỉ mặc định: app tự tìm vị trí. Chỉ tự chọn khi có duy nhất một kết quả chính xác. Nếu nhiều kết quả/chưa rõ, khách chọn lại; không tự đặt tọa độ hay giờ giao giả. Có thể dùng liên kết Google Maps, tọa độ và mở bản đồ để đối chiếu. |
| Cập nhật sản phẩm | Trang chủ, danh sách và chi tiết cập nhật nền mỗi 30 giây khi màn hình đang được xem; cập nhật khi quay lại. Không tải định kỳ cho tab ẩn, màn hình bị che hoặc khi app ở nền. Lỗi mạng giữ nội dung hiện có. Máy chủ vẫn kiểm tra tồn khi thêm giỏ/đặt hàng. |
| Tìm đơn cũ | Tìm mã đơn/tên sản phẩm, lọc trạng thái và khoảng ngày. API hiện chỉ phân trang nên app tải đủ các trang trước khi đưa ra kết quả tìm kiếm, không chỉ lọc trang đầu. Với lịch sử rất lớn nên bổ sung tìm kiếm phía máy chủ trong một đợt sau. |
| Phản hồi | Tìm mã/chủ đề, lọc loại và trạng thái; tìm kiếm và phân trang gửi về máy chủ. Giữ gợi ý chủ đề đã bổ sung trước đó. |
| Danh mục | Chọn lần lượt cha → con, có quay lại và chọn tất cả sản phẩm của cấp hiện tại. Tải đủ các trang danh mục. |
| Thẻ sản phẩm | Yêu thích, số có thể mua của quy cách mặc định và thêm một sản phẩm theo quy cách đang hiển thị. Nếu chưa có quy cách mặc định, mở chi tiết để chọn. Giới hạn tối đa ba yêu cầu tải tồn đồng thời và lưu tạm 30 giây; số không đọc được không được coi là còn hàng. |
| Chi tiết sản phẩm | Có sản phẩm liên quan và combo chứa chính sản phẩm đang xem, lấy từ dữ liệu công khai. Không tự tạo điều kiện giảm hoặc sản phẩm gợi ý giả. |
| Trợ lý mua sắm | Nút hội thoại trên trang chủ mở Trợ lý Organic Food. Hỏi sản phẩm/giá/tồn và đơn của tài khoản đang đăng nhập. Dùng `/shopping-chat` hiện tại; cần backend đã cấu hình AI. Chỉ tra cứu/gợi ý, không đặt hay sửa đơn. Hội thoại xóa khi đổi phiên tài khoản. |
| Đồng ý phương án | Chỉ đọc nội dung và bấm xác nhận; không còn ô ghi chú. Vẫn gửi đúng phiên bản phương án và xử lý xung đột. Các thao tác cần giải thích như đề nghị xét lại vẫn có lý do. |
| Hồ sơ | Chọn ngày sinh bằng lịch; bàn phím email/điện thoại đúng loại. Giữ nguyên quy tắc điện thoại 9–10 số của người dùng. |
| Đăng ký/đăng nhập | OTP gồm sáu số, đếm 60 giây khi gửi lại thành công; lời chào sau đăng nhập thường/Google và xác thực thành công. Không nới giới hạn gửi OTP của máy chủ. |
| Điểm thưởng | Hiển thị tổng số dư, khả dụng, đang giữ và thay đổi giữ/giải phóng điểm trong lịch sử. Không tự tính số dư chính thức. |
| Nhận tại cửa hàng | Bật yêu cầu nhận tại cửa hàng; địa chỉ cửa hàng điền sẵn, cửa hàng xác nhận lịch nhận. Email nhận hóa đơn là yêu cầu tùy chọn. Hai thông tin lưu trong ghi chú đơn giống website; không phải hệ thống xuất hóa đơn điện tử hoặc lịch nhận tự động mới. |
| Banner | Tự chuyển sau sáu giây; vuốt để xem thêm. Dừng tự chuyển khi đang chạm/di chuột, app ở nền, tab bị ẩn hoặc thiết bị yêu cầu giảm chuyển động. Có đường dẫn xem toàn bộ ưu đãi. |
| Đánh giá | Thêm biểu đồ phân bố 1–5 sao từ tổng hợp của máy chủ; giữ lọc sao, sắp xếp, quyền đánh giá và xóa hiện tại. |
| Chứng nhận | Hiển thị ảnh xem trước thật nếu hồ sơ có ảnh hoặc tài liệu dạng ảnh; có thể phóng to. Chi tiết sản phẩm ghép ảnh công khai theo đúng ID và số chứng nhận. Hồ sơ chỉ có PDF mà chưa có ảnh xem trước vẫn mở tài liệu gốc; không tạo ảnh chứng nhận giả. |

## Trở về ứng dụng sau thanh toán

App tiếp tục đối chiếu trạng thái thanh toán với máy chủ khi quay lại từ cổng. Không lấy `00`, `paid` hay tham số URL làm chứng cứ đã thanh toán.

Đã bổ sung đường dẫn mở lại app Android:

```text
organicfood://payment-return?orderId=<UUID đơn hàng>
```

Đường dẫn chỉ điều hướng tới chi tiết đơn. App yêu cầu đăng nhập và backend kiểm tra quyền xem đơn, sau đó tải/đối chiếu giao dịch hiện có. Tham số trạng thái trên URL không cập nhật thanh toán và không tạo phiên thu tiền mới.

**Cấu hình triển khai còn cần:** API khởi tạo thanh toán hiện nhận `orderId` và `gateway`, chưa nhận đường dẫn riêng cho từng thiết bị. Vì vậy thêm đường dẫn mở app không tự thay địa chỉ trả về đang cấu hình tại cổng/backend. Trang kết quả HTTPS khi triển khai cần có nút “Quay lại ứng dụng” với đường dẫn trên, dùng UUID đơn đã được tài khoản xác minh. Không tự thay cấu hình cổng đang dùng cho website. Một số cổng yêu cầu URL HTTPS; không đặt URI riêng của app thay webhook/IPN. Đây cũng chưa phải Android App Links đã xác minh tên miền. Bản iOS vẫn dùng quay lại app và đối chiếu khi tiếp tục; chưa đăng ký URI scheme riêng cho iOS trong đợt này.

Có thể kiểm tra mở app trên giả lập bằng lệnh sau, thay UUID bằng đơn của tài khoản đang đăng nhập:

```powershell
adb shell am start -a android.intent.action.VIEW -d "organicfood://payment-return?orderId=<UUID đơn hàng>" vn.huit.organic_mobile
```

Không dùng lệnh này để suy ra giao dịch đã thành công. Đơn không thuộc tài khoản phải bị backend từ chối.

## Kịch bản kiểm tra thủ công

1. Đăng nhập khách hàng; phải thấy lời chào. Đăng ký riêng: thử OTP thiếu số, nhập chữ, gửi lại và xem đếm ngược.
2. Vào hồ sơ: chọn ngày sinh trên lịch; thử số điện thoại 10 chữ số và chuỗi quá 10 chữ số. Quy tắc 9–10 số không bị mở rộng.
3. Vào sản phẩm: chọn danh mục cha, danh mục con, quay lại, chọn tất cả của cấp hiện tại. Tìm kiếm và đổi trang vẫn hoạt động.
4. Lưu yêu thích trên thẻ; thêm quy cách đang hiển thị vào giỏ. Thử sản phẩm hết hàng hoặc mất mạng; không được hiển thị một số tồn tự tạo. Thay tồn trên web, đợi khoảng 30 giây hoặc quay lại app để đối chiếu.
5. Mở chi tiết: đổi quy cách và kiểm tra giá/tồn. Xem sản phẩm liên quan, combo thực có, phân bố sao và ảnh chứng nhận có nguồn thật.
6. Ở thanh toán: chọn một địa chỉ cụ thể. Kiểm tra thông báo tự xác định vị trí; mở “Xác nhận vị trí” nếu còn nhiều kết quả. Thử dán tọa độ/link Google Maps và mở bản đồ đối chiếu. Giá trị tọa độ chỉ là vị trí; giờ giao được backend tính khi ghi nhận xuất phát giao hàng.
7. Bật yêu cầu nhận tại cửa hàng, thêm email nhận hóa đơn và ghi chú. Kiểm tra địa chỉ/ghi chú của đơn sau khi tự đặt thử. Tắt yêu cầu phải trả lại địa chỉ giao trước đó. Đây là yêu cầu để cửa hàng xác nhận.
8. Thanh toán bằng cổng thử nghiệm đang cấu hình. Hoàn thành tại cổng rồi quay lại app; đợi trạng thái backend cập nhật. Không bấm tạo thanh toán mới chỉ để kiểm tra. Nếu triển khai nút trở về app, thử cả khi app đang mở và đã đóng.
9. Tìm một đơn ở trang cũ bằng mã/tên sản phẩm; thử lọc trạng thái và khoảng ngày, sau đó bỏ bộ lọc ngày.
10. Tìm phản hồi theo chủ đề và lọc Sản phẩm/Giao hàng/Thanh toán. Mở hồ sơ, trả lời, tải lại và đối chiếu nội dung. Với đổi trả, bấm đồng ý phương án mà không nhập ghi chú; nếu phiên bản đã đổi phải yêu cầu xem lại.
11. Xem lịch sử điểm của một đơn đang giữ điểm và một đơn hủy/hoàn tất: dòng giữ/giải phóng điểm phải dễ hiểu dù biến động số dư bằng 0.
12. Trang chủ: banner tự chuyển sau sáu giây; vuốt và giữ tay để thử. Mở trợ lý, hỏi sản phẩm/đơn; đăng xuất hoặc đổi tài khoản phải không còn hội thoại riêng của tài khoản trước.

## Kiểm chứng

Kiểm thử tự động dùng HTTP giả lập và dữ liệu kiểm thử; không tạo đơn thật, gửi OTP thật, thay dữ liệu kinh doanh hay giao dịch tiền. Kết quả phân tích mã, toàn bộ test và bản APK ghi ở cuối sau khi chạy hoàn tất. Các thao tác thanh toán, định vị từ HeiGIT và nhận push thật vẫn cần nghiệm thu với tài khoản/cấu hình đang sử dụng.


Kết quả đã chạy:

- `flutter analyze --no-pub`: không có vấn đề.
- `flutter test --no-pub --reporter expanded`: 149 test đạt; 12 test bổ sung cũng được chạy lại sau chỉnh sửa cuối của cơ chế cập nhật nền và đều đạt.
- `git diff --check`: đạt.
- Build APK debug của toàn bộ mã cuối cùng đã thành công (179,5 giây). Tệp: `build/app/outputs/flutter-apk/app-debug.apk`. Bản này cấu hình cho giả lập Android với API `http://10.0.2.2:8088/api/v1`; nếu dùng điện thoại thật, build lại theo địa chỉ LAN/HTTPS trong README. Cài lại APK hoặc dừng/chạy lại ứng dụng đầy đủ để nhận thay đổi Android; hot reload không cập nhật cấu hình đường dẫn native.

Không dùng các kết quả trên để kết luận đã nghiệm thu chuyển tiền thật, định vị của mọi địa chỉ hoặc mọi thiết bị Firebase. Các bước đó thuộc kịch bản thử với hệ thống đang chạy.

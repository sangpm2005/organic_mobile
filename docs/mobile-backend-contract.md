# Đồng bộ mobile với backend và website

Ba repo đang nằm cạnh nhau: `organic_mobile`, `organic_backend`, `organic_frontend`. Backend là nguồn dữ liệu dùng chung; mobile không sao chép toàn bộ màn hình website. Dữ liệu giỏ/đơn/voucher thuộc tài khoản CUSTOMER; không gửi customerId hoặc giá do client tự tính để quyết định giao dịch.

| Luồng mobile | API dưới `/api/v1` | Tương ứng website |
| --- | --- | --- |
| Phiên, đăng ký OTP | `/auth/*` | AuthContext, trang đăng nhập/đăng ký |
| Trang chủ, danh mục, sản phẩm | `/home`, `/categories`, `/products`, `/products/{id}`, `/products/{id}/availability`, `/products/{id}/reviews` | catalogService, HomePage |
| Hồ sơ, địa chỉ | `/customers/me`, `/customers/me/addresses` | customerService |
| Giỏ | `/cart`, `/cart/items`, `/cart/items/batch` | cartService, ShopContext |
| Vị trí giao hàng | `/checkout/delivery-locations`, `/checkout/delivery-location-from-map` | checkoutService |
| Preview, đặt/hủy/xem đơn | `/checkout/preview`, `/orders`, `/orders/{id}`, `/orders/{id}/cancel` | checkoutService, CartPage, chi tiết đơn |
| Cổng thanh toán | `/payments/methods`, `/payments/initiate`, `/payments/{id}/sync`, `/payments/{id}/paypal/capture` | checkoutService, PaymentReturnPage |
| Điểm, lịch sử | `/customers/me/rewards`, `/customers/me/reward-transactions` | trang thành viên |
| Đổi/ví voucher | `/customers/me/voucher-offers`, `/customers/me/vouchers`, `/customers/me/vouchers/exchange` | trang thành viên, CartPage |
| Ưu đãi/combo công khai | `/home/promotions` | storefront promotion feed, ComboCarousel |
| Inbox | `/inbox`, `PATCH /inbox/{id}/read` | trang thông báo khách hàng |

## Quy tắc giao dịch

- Đặt hàng và đổi voucher phải có `Idempotency-Key`. Khi timeout, lỗi mạng, 5xx, 408 hoặc 429, giữ nguyên key và payload. Không tự tạo yêu cầu mới khi chưa rõ kết quả.
- Đổi voucher gửi `promotionId`, `expectedPointsCost`, `expectedOfferVersion` lấy từ ưu đãi hiện tại. Không suy ra giá trị/version ở client.
- Có thể kết hợp mã khuyến mãi công khai với voucher. Voucher và trừ điểm trực tiếp loại trừ nhau. Quote phải trả đúng voucher yêu cầu và giảm giá dương trước khi xác nhận đơn.
- Điểm trực tiếp tuân thủ số dư khả dụng, `redeemLimit` và giới hạn 50 trong DTO backend. Giá và quyền sử dụng được backend kiểm tra lại.
- Sau đặt hàng, chỉ xóa dòng giỏ nếu quantity hiện tại bằng quantity đã mua. Redis so sánh/xóa nguyên tử; lệch số lượng trả 409, giữ dòng và tải lại giỏ. DELETE thường không có tham số vẫn xóa như trước.
- Thêm combo dùng `/cart/items/batch`; backend kiểm tra toàn bộ trước khi cập nhật. Mã khuyến mãi chỉ được chọn sau khi thêm thành công.
- Thanh toán dùng đúng gateway backend bật. Chỉ mở HTTPS trên danh sách host chính thức giống website, không có userInfo trong URL. Link mở thành công không có nghĩa đã trả tiền. Trạng thái trả tiền lấy từ backend; PayPal chỉ capture sau xác nhận người dùng.
- Có kiểm tra phiên để phản hồi muộn không đưa dữ liệu tài khoản trước vào tài khoản sau. Dừng polling khi app không hoạt động; tải lại khi quay về.

## Thông báo và giới hạn phạm vi

Inbox có phân trang và endpoint đánh dấu đọc phía backend. Cập nhật đơn/ưu đãi được tổng hợp từ dữ liệu khách hàng, lưu key đọc trong secure storage của phiên. Màn hình chỉ mở các route mobile biết trước; không điều hướng URL tùy ý do nội dung inbox gửi về.

`/notifications` và đăng ký thiết bị FCM hiện phục vụ ADMIN/WAREHOUSE_STAFF. Không sử dụng các endpoint này cho khách hàng hoặc nhúng thông tin xác thực nhân viên. Để có push nền khách hàng cần bổ sung luồng đăng ký thiết bị, phát sự kiện đơn/khuyến mãi và cấu hình Firebase của ứng dụng.

Không triển khai các chức năng quản trị/kho, đánh giá riêng tư, phản hồi hoặc đổi trả trong đợt này. Nội dung inbox có thể nhắc phản hồi/đổi trả do website tạo, nhưng mobile chỉ hiển thị nội dung và đánh dấu đọc.

## Kiểm chứng

Các test Flutter dùng HTTP mock và secure storage mock để kiểm tra hợp đồng, lỗi mạng, phân trang/giao diện, thay phiên và idempotency. Backend `CartIntegrationTests` dùng H2 và prefix Redis riêng, không tạo đơn kinh doanh. Frontend chạy các test giỏ/checkout liên quan.

Kiểm tra với tài khoản thật vẫn cần: giá/tồn kho hiện tại, voucher đủ/thiếu điều kiện, tọa độ, đồng bộ giỏ web/mobile, luồng thanh toán sandbox của từng gateway và trạng thái giao hàng. Build APK thành công và mock test không thay thế nghiệm thu giao dịch thật. Harness integration hiện cần bridge UAT ngoài repo.

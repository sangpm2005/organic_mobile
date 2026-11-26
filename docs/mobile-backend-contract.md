# Đồng bộ mobile với backend và website

Ba repo đang nằm cạnh nhau: `organic_mobile`, `organic_backend`, `organic_frontend`. Backend là nguồn dữ liệu dùng chung; mobile không sao chép toàn bộ màn hình website. Dữ liệu giỏ/đơn/voucher thuộc tài khoản CUSTOMER; không gửi customerId hoặc giá do client tự tính để quyết định giao dịch.

## Đồng bộ giao diện cửa hàng ngày 26/11/2026

- Banner ưu đãi trên trang chủ và combo trong chi tiết sản phẩm lướt mỗi 4 giây. Chạm phần nội dung một lần để chuyển, hai lần để mở đúng ưu đãi; có nút xem chi tiết riêng và hỗ trợ vuốt. Nút/ô nhập không bị thao tác chuyển slide chiếm sự kiện. Dừng tự chuyển khi đang chạm, app chạy nền, màn hình chi tiết khác đang mở hoặc bật giảm chuyển động.
- Banner và chi tiết combo có ảnh sản phẩm, số lượng và giá tạm tính. Đổi quy cách sẽ tính lại tiền hàng, tiền giảm và tiền còn lại; áp dụng điều kiện đơn tối thiểu, giảm tối đa và không giảm quá tiền hàng. Không thay thế kết quả kiểm tra ở checkout.
- Ảnh danh mục ưu tiên `imageUrl`, tiếp đến sản phẩm cùng danh mục trong `/home`; nếu thiếu thì lấy một sản phẩm qua `/products?categoryId=...&includeDescendants=false&size=1`. Lỗi ảnh không chặn trang chủ. Giữ tối đa 8 danh mục theo số sản phẩm và loại danh mục combo.
- Trang chủ có các nhóm Còn hàng, Chọn lọc, Mới, Có chứng nhận và bộ lọc danh mục; khu sản phẩm giảm giá vẫn tách riêng. Hạn sử dụng vẫn chỉ hiện trong chi tiết, không thêm lên thẻ sản phẩm.
- Không đổi API giao dịch, schema SQL hoặc cấu hình Firebase. Không đưa các màn hình phân quyền nhân viên của web quản trị vào ứng dụng khách hàng.

| Luồng mobile | API dưới `/api/v1` | Tương ứng website |
| --- | --- | --- |
| Phiên, đăng ký OTP | `/auth/*` | AuthContext, trang đăng nhập/đăng ký |
| Quên/đổi mật khẩu | `/auth/password/{forgot,change}/{request,verify,complete}` | OTP email, đặt mật khẩu và đăng nhập lại |
| Thiết bị thông báo khách hàng | `PUT/DELETE /notifications/devices` | Bật/tắt push của tài khoản đăng nhập |
| Trang chủ, danh mục, sản phẩm | `/home`, `/categories`, `/products`, `/products/{id}`, `/products/{id}/availability`, `/products/{id}/reviews` | catalogService, HomePage |
| Hồ sơ, địa chỉ | `/customers/me`, `/customers/me/addresses` | customerService |
| Giỏ | `/cart`, `/cart/items`, `/cart/items/batch` | cartService, ShopContext |
| Vị trí giao hàng | `/checkout/delivery-locations`, `/checkout/delivery-location-from-map` | checkoutService |
| Preview, đặt/hủy/xem đơn | `/checkout/preview`, `/orders`, `/orders/{id}`, `/orders/{id}/cancel` | checkoutService, CartPage, chi tiết đơn |
| Cổng thanh toán | `/payments/methods`, `/payments/initiate`, `/payments/{id}/sync`, `/payments/{id}/paypal/capture` | checkoutService, PaymentReturnPage |
| Điểm, lịch sử | `/customers/me/rewards`, `/customers/me/reward-transactions` | trang thành viên |
| Đổi/ví voucher | `/customers/me/voucher-offers`, `/customers/me/vouchers`, `/customers/me/vouchers/exchange` | trang thành viên, CartPage |
| Ưu đãi/combo công khai | `/home/promotions` | storefront promotion feed, ComboCarousel |
| Phản hồi & trao đổi | `/feedbacks`, `/feedbacks/me`, `/feedbacks/{id}`, `/feedbacks/{id}/messages`, `/feedbacks/{id}/media`, `/close`, `/reopen` | feedbackService, FeedbackPage |
| Đổi trả khách hàng | `/return-requests/eligible-items`, `/return-requests`, `/return-requests/me`, `/return-requests/{id}`, `/histories`, `/cancel`, `/accept`, `/decline`, `/submit-information` | returnService, ReturnRequestsPage |
| Tiến độ đổi trả | `/return-requests/{id}/execution`, `/warehouse-progress`, `/receipts` | bảng tiến độ khách hàng |
| Đánh giá | `/reviews/eligible-items`, `/reviews/me`, `/reviews/{id}`, `/reviews/submission` | reviewService, MyReviewsPage |
| Avatar | `/customers/me/avatar` | profileService |
| Thông tin cửa hàng | `/home/content` | homeService, trang giới thiệu/liên hệ |
| Inbox | `/inbox`, `PATCH /inbox/{id}/read` | trang thông báo khách hàng |

## Quy tắc giao dịch

### Lựa chọn hàng theo hạn sử dụng

- Mobile đọc `saleOptions` từ `/products/{id}/availability`, dùng giá, giá gốc và tồn kho của API. Chi tiết tự chọn một ưu đãi giảm trực tiếp còn hiệu lực, nếu không có thì gộp hàng thường để backend phân bổ FEFO. Không còn bộ chọn ngày. Một dòng “Hạn sử dụng” lấy từ `nearestExpiryDate` của hàng thường hoặc `expiryDate` của ưu đãi; không hiển thị ngày trên thẻ ở trang chủ/danh sách.
- Định danh dòng giỏ là `selectionKey` (hoặc `variantId~expiryDate~salePromotionId`); giỏ cũ không có ngày vẫn dùng `variantId`. Thêm giỏ và checkout gửi `variantId`, `quantity`, `expiryDate`, `salePromotionId`. Tăng, giảm, xóa và dọn giỏ sau mua dùng đúng khóa lựa chọn, giữ điều kiện so sánh số lượng hiện tại.
- Voucher preview giữ nguyên từng lựa chọn hạn dùng và ghép dữ liệu giỏ theo khóa đầy đủ. Checkout chặn quote làm mất/đổi hạn dùng hoặc chương trình đã yêu cầu. Đơn chờ do lỗi mạng giữ nguyên payload và idempotency key.
- Combo theo hạn dùng có thể có nhiều lựa chọn cùng quy cách; mỗi lựa chọn có khóa riêng, hiển thị ngày của từng sản phẩm, gửi ngày và chương trình theo từng dòng. Không dùng mã khuyến mãi thường để thay cho `salePromotionId`.
- Khi một ưu đãi hết, khám phá sản phẩm trở về hàng thường; giỏ/đơn cũ không được đổi ngày hoặc giá thay khách. Nút thêm nhanh đọc lại tồn; giá/chương trình vừa thay đổi thì mở chi tiết để khách kiểm tra, không tự gửi thêm giỏ.
- Hàng thường gửi `variantId` và `quantity`, không gửi ngày chỉ dùng hiển thị thành điều kiện khóa lô. Giỏ có ngày từ phiên bản trước và combo vẫn giữ nguyên khóa đầy đủ. Chi tiết đơn hiển thị hạn dùng đã cam kết nếu có.
- Kiểm tra thủ công: bật backend mới, xem hạn dùng ở chi tiết; xác nhận trang chủ/danh sách không có ngày. Đặt hết lượng ưu đãi rồi tải lại; giá/tồn của sản phẩm đổi về hàng thường, dòng giỏ ưu đãi cũ được kiểm tra độc lập. Không tự tạo đơn hay điều chỉnh tồn trong quá trình chạy test Flutter.

- Đặt hàng và đổi voucher phải có `Idempotency-Key`. Khi timeout, lỗi mạng, 5xx, 408 hoặc 429, giữ nguyên key và payload. Không tự tạo yêu cầu mới khi chưa rõ kết quả.
- Đổi voucher gửi `promotionId`, `expectedPointsCost`, `expectedOfferVersion` lấy từ ưu đãi hiện tại. Không suy ra giá trị/version ở client.
- Có thể kết hợp mã khuyến mãi công khai với voucher. Voucher và trừ điểm trực tiếp loại trừ nhau. Quote phải trả đúng voucher yêu cầu và giảm giá dương trước khi xác nhận đơn.
- Điểm trực tiếp tuân thủ số dư khả dụng, `redeemLimit` và giới hạn 50 trong DTO backend. Giá và quyền sử dụng được backend kiểm tra lại.
- Sau đặt hàng, chỉ xóa dòng giỏ nếu quantity hiện tại bằng quantity đã mua. Redis so sánh/xóa nguyên tử; lệch số lượng trả 409, giữ dòng và tải lại giỏ. DELETE thường không có tham số vẫn xóa như trước.
- Thêm combo dùng `/cart/items/batch`; backend kiểm tra toàn bộ trước khi cập nhật. Mã khuyến mãi chỉ được chọn sau khi thêm thành công.
- Thanh toán dùng đúng gateway backend bật. Chỉ mở HTTPS trên danh sách host chính thức giống website, không có userInfo trong URL. Link mở thành công không có nghĩa đã trả tiền. Chi tiết đơn tự sync giao dịch đang chờ; PayPal capture qua backend và vẫn cần khách chấp thuận trên cổng PayPal, không cần thêm xác nhận thủ công trong app.
- Có kiểm tra phiên để phản hồi muộn không đưa dữ liệu tài khoản trước vào tài khoản sau. Dừng polling khi app không hoạt động; tải lại khi quay về.

## Thông báo và giới hạn phạm vi

Inbox có phân trang và endpoint đánh dấu đọc phía backend. Cập nhật đơn/ưu đãi được tổng hợp từ dữ liệu khách hàng, lưu key đọc trong secure storage của phiên. Màn hình chỉ mở các route mobile biết trước; không điều hướng URL tùy ý do nội dung inbox gửi về.

`/notifications` vẫn là danh sách cảnh báo nhân viên. Riêng `PUT/DELETE /notifications/devices` ở backend mới cho phép CUSTOMER đăng ký/gỡ thiết bị của mình; mobile không cần quyền nhân viên. Inbox và job FCM khách hàng đã có. Push thật cần Firebase Android/iOS và Firebase Admin; xem `mobile-push-setup.md`. Chưa có chiến dịch push khuyến mãi hàng loạt.

Đã triển khai màn hình khách hàng cho phản hồi, đổi trả và đánh giá. Inbox mở chi tiết theo `feedbackId`/`returnRequestId`, không dùng URL quản trị do dữ liệu gửi kèm. Khách hàng chỉ xem tiến độ hoàn tiền, thu hồi và đơn đổi; thao tác duyệt, nhập kho, xác nhận chuyển tiền và giao hàng vẫn thuộc nhân viên trên backend/website.

## Kiểm chứng

Các test Flutter dùng HTTP mock và secure storage mock để kiểm tra hợp đồng, lỗi mạng, phân trang/giao diện, thay phiên và idempotency. Backend `CartIntegrationTests` dùng H2 và prefix Redis riêng, không tạo đơn kinh doanh. Frontend chạy các test giỏ/checkout liên quan.

Kiểm tra với tài khoản thật vẫn cần: giá/tồn kho hiện tại, voucher đủ/thiếu điều kiện, tọa độ, đồng bộ giỏ web/mobile, luồng thanh toán sandbox của từng gateway và trạng thái giao hàng. Build APK thành công và mock test không thay thế nghiệm thu giao dịch thật. Harness integration hiện cần bridge UAT ngoài repo.

## Hợp đồng hậu mãi

- Phản hồi và tin nhắn chưa có idempotency backend: không tự gửi lại POST khi timeout/5xx. Nội dung được gửi một lần trước các tệp; thử lại tệp thất bại đã xác định không gửi lại nội dung hoặc tệp đã xác nhận. Khi kết quả chưa rõ, kiểm tra nội dung đã lưu trước khi gửi thêm.
- Đổi trả dùng multipart `request` JSON và `images` (1–5 ảnh JPEG/PNG/WebP, mỗi ảnh ≤5 MB), `Idempotency-Key` cố định. Lần gửi đang chờ giữ payload, thứ tự và byte ảnh; Android/iOS lưu ảnh trong thư mục riêng, chỉ gửi sau khi lưu được bản ghi thử lại. Đăng xuất xóa dữ liệu riêng đang chờ.
- Yêu cầu đổi trả gửi `orderDetailId` lấy từ eligibility, không dùng `variantId` hoặc tự suy ra từ dòng checkout. Số lượng nguyên nằm trong `availableQuantity`; eligibility và quyền thao tác do backend kiểm tra lại.
- Chấp nhận/từ chối phương án gửi `proposalVersion` đang hiển thị. 409 phải tải lại và yêu cầu khách xem phương án mới, không tự đồng ý phiên bản mới.
- Đánh giá gửi multipart `review` JSON và `files` ảnh/video trong một lần; hỗ trợ xem/xóa, không dùng các endpoint chỉnh sửa bị backend cấm. Tối đa 5 ảnh (5 MB/ảnh) và 1 video MP4/WebM (50 MB).
- Avatar dùng multipart `file`, đúng một ảnh JPEG/PNG/WebP ≤5 MB. Endpoint không thay đổi khi đổi tên cửa hàng.
- Yêu thích lưu local theo tài khoản, backend hiện chưa có API để đồng bộ với website. Bản nháp đánh giá lưu phần chữ trong secure storage, ảnh chọn lại khi mở màn hình mới.
- Tên hiển thị là `organicfood`; application ID, endpoint và khóa lưu phiên cũ được giữ để tương thích dữ liệu cài đặt trước.


## Bổ sung UX ngày 07/11/2026

- Không có migration SQL cho đợt này. Mobile dùng các endpoint đang có; không chỉnh `application.yml`.
- `/feedbacks/me` gửi `search`, `feedbackType`, `status`, `page` và `size` để lọc và phân trang trên server.
- `/orders` chưa có bộ lọc tìm kiếm: khi tìm/lọc, mobile đọc đủ các trang (100 bản ghi/yêu cầu), loại trùng theo ID và bỏ kết quả khi phiên thay đổi. Không coi trang đầu là toàn bộ lịch sử.
- `/categories` đọc đủ các trang; hiển thị cây theo `parentId`. Lọc sản phẩm theo danh mục vẫn dùng `categoryId`, backend xử lý các danh mục con theo mặc định.
- `/checkout/delivery-locations?address=...` chỉ được tự chọn nếu trả đúng một vị trí và `precise=true`. `/checkout/delivery-location-from-map` nhận liên kết; tọa độ nhập trực tiếp được kiểm tra khoảng vĩ/kinh độ rồi gửi trong payload thanh toán.
- `/products/{id}/availability` là nguồn số khả dụng cho thẻ/chi tiết. Thẻ dùng cache 30 giây và tối đa ba yêu cầu đồng thời; trường không đọc được không tự chuyển thành một số tồn.
- `/shopping-chat` nhận `message` tối đa 1.200 ký tự và tối đa tám lượt lịch sử, mỗi lượt tối đa 2.000 ký tự. Gửi token khi có phiên đăng nhập, không lưu hội thoại của tài khoản cũ khi đổi phiên; API không được dùng để sửa đơn.
- `organicfood://payment-return?orderId=<UUID>` chỉ mở chi tiết đơn Android để tải và đối chiếu dữ liệu với server. Không ghi nhận đã trả tiền từ URL; không thay webhook/IPN. Trang trả về HTTPS và cấu hình cổng cần nối với URI này khi triển khai; xem `mobile-ux-completion-20261107.md`.
- Nhận tại cửa hàng/email hóa đơn lưu thành yêu cầu trong `note` giống website, không thêm trường JSON ngoài hợp đồng. Payload và khóa thử lại đơn đang chờ được giữ nguyên.

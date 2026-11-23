**Cập nhật sau khi được duyệt — 07/11/2026:** Các đề xuất phù hợp đã được triển khai trong mobile. Giữ nguyên quy tắc điện thoại 9–10 chữ số theo yêu cầu người dùng. Bảng dưới đây giữ lại hiện trạng trước khi sửa để đối chiếu. Xem [phần đã bổ sung và hướng dẫn kiểm tra](mobile-ux-completion-20261107.md), gồm giới hạn cấu hình trở về app sau thanh toán và ảnh chứng nhận chỉ dùng dữ liệu thật.

**Đối chiếu trải nghiệm mobile với website — 07-11-2026**

Phạm vi: các chức năng dành cho khách hàng của `organic_frontend` ở commit `bb9a123`, `organic_mobile` ở commit `711fede` cùng thay đổi local hiện tại. Đối chiếu thêm backend `166efda` khi cần xác định quy tắc dữ liệu. Không coi nghiệp vụ quản trị, kho, thu mua hay phân quyền nhân viên là chức năng bắt buộc của app khách hàng.

Đây là rà soát mã nguồn và luồng giao diện, không phải chứng nhận đã kiểm thử mọi giao dịch thật. Không tạo đơn, gửi phản hồi, chuyển tiền, thay tồn kho hoặc thay database để thực hiện báo cáo này. Người dùng cho biết phần thông báo đã thử ổn; không thay đổi phần thông báo trong lần này.

**Phần được sửa theo yêu cầu: ô nhập tài khoản**

Người dùng xác nhận đang gõ trên giả lập Android bằng bàn phím máy tính có UniKey/EVKey. Trong code đăng nhập không thấy bộ lọc hoặc listener tự cắt `customer` thành `us…`. Khả năng xung đột giữa bộ gõ Windows và thao tác bàn phím gửi vào giả lập phù hợp với tình huống mô tả, nhưng chưa tái hiện trực tiếp trên máy người dùng để kết luận nguyên nhân duy nhất.

Đã cấu hình các ô định danh và mật khẩu trong đăng nhập, đăng ký, quên/đổi mật khẩu và liên kết Google: tắt tự sửa/gợi ý ở các trường phù hợp, dùng kiểu bàn phím nhập chuỗi nguyên văn cho tên đăng nhập/mật khẩu, tránh thay dấu nháy và gạch nối trong thông tin xác thực. Không thêm bộ lọc loại bỏ dấu tiếng Việt hoặc ghi đè controller trong lúc đang gõ. Trường họ tên vẫn giữ khả năng nhập tiếng Việt.

Giới hạn: cấu hình Flutter không thể bật/tắt UniKey/EVKey đang chạy trên Windows hoặc khôi phục ký tự đã bị bộ gõ bên ngoài gửi lệnh xóa. Khi demo bằng bàn phím máy tính, chuyển biểu tượng bộ gõ từ **V sang E** khi nhập `customer`, email và mật khẩu. Để nhập nội dung tiếng Việt trên giả lập, có thể dùng bàn phím ảo tiếng Việt của Android, hoặc dán đoạn chữ đã soạn. Trên điện thoại thật cần kiểm tra với bàn phím đang dùng, không suy ra mọi bàn phím đều có lỗi giống giả lập.

Kiểm chứng: 27 test nhóm xác thực đạt; có test giữ nguyên các giá trị đang soạn `c`, `cu`, `cus`, `customer`, gửi đúng tên đăng nhập/mật khẩu và giữ nguyên vùng composing của họ tên tiếng Việt. `flutter analyze --no-pub` không báo vấn đề. Test dùng dữ liệu giả lập, không mô phỏng toàn bộ tiến trình UniKey/EVKey của Windows.

Căn cứ: [đăng nhập](D:/oragnic-pro/organic_mobile/lib/features/auth/presentation/login_screen.dart:112), [đăng ký](D:/oragnic-pro/organic_mobile/lib/features/auth/presentation/register_screen.dart:152), [test nhập liệu](D:/oragnic-pro/organic_mobile/test/features/auth/credential_input_test.dart).

**Các chênh lệch cần xem trước khi quyết định sửa**

Ngoài phần nhập tài khoản trên, các mục dưới đây chỉ được kiểm tra và đề xuất, chưa triển khai.

| Mục | Website hiện có | Mobile hiện tại và tác động | Đề xuất |
| --- | --- | --- | --- |
| 1. Xác định vị trí giao hàng | Tự tìm vị trí sau khi địa chỉ đầy đủ; tự chọn nếu chỉ có một kết quả chính xác; cho đổi bằng liên kết hoặc tọa độ. | Phải mở màn hình Xác nhận vị trí, bấm Tìm vị trí và chọn kết quả. Đổi địa chỉ xóa vị trí cũ nhưng chưa tự xác định lại. Người dùng dễ bỏ qua bước cần cho giờ giao dự kiến. | Ưu tiên cao: tự xác định sau khi chọn địa chỉ; chỉ hỏi khách khi chưa rõ. Cho xem vị trí trên bản đồ. Dùng API sẵn có. |
| 2. Cập nhật danh sách và tồn kho | Danh sách tự tải lại khi quay lại tab và định kỳ 30 giây. | Catalog chỉ tải khi mở/chuyển bộ lọc/trang hoặc kéo xuống; chi tiết lấy tồn lúc tải. Timer tài khoản không đồng thời tải lại catalog. Có thể thấy dữ liệu cũ khi kho hoặc khách khác vừa làm thay đổi tồn. | Ưu tiên cao: cập nhật nền khi quay lại màn hình và đúng chu kỳ. Backend vẫn kiểm tra tồn lúc thao tác; không kết luận giao diện cũ cho phép bán vượt tồn. |
| 3. Tìm đơn hàng cũ | Có tìm theo mã đơn/tên sản phẩm, tab trạng thái, khoảng ngày. | Có danh sách, xem đơn cũ hơn, kéo cập nhật, nhưng chưa có các bộ lọc trên. Nhiều đơn sẽ khó tìm. | Thêm tìm kiếm và lọc trạng thái/ngày, bảo đảm áp dụng trên đủ dữ liệu chứ không chỉ trang đầu. |
| 4. Tìm phản hồi | Có tìm mã/chủ đề và lọc loại phản hồi, trạng thái. | Hiện chỉ lọc trạng thái và giới hạn theo đơn nếu mở từ đơn. Không có ô tìm hoặc lọc Sản phẩm/Giao hàng/Thanh toán. | Thêm bộ lọc và tìm kiếm; dữ liệu/phân trang vẫn lấy từ backend. Gợi ý chủ đề khi tạo đã được bổ sung trong công việc trước. |
| 5. Danh mục nhiều cấp | Menu thể hiện quan hệ cha/con và đường dẫn danh mục. | Danh mục là các nút ngang, chưa thể hiện cây; danh sách lấy tối đa 100 bản ghi một lần. Khó phân biệt các loại trùng tên thuộc cha khác nhau. | Dùng bộ chọn danh mục cha/con phù hợp màn hình điện thoại, tải đủ danh mục. Backend mặc định đã lọc cả danh mục con; không cần sửa SQL để hiển thị cây. |
| 6. Thao tác trên thẻ sản phẩm | Có số lượng còn mua, trái tim, thêm vào giỏ và xem sản phẩm. | Thẻ chủ yếu có ảnh/tên/quy cách/giá và mở chi tiết. Muốn xem tồn, lưu yêu thích hoặc thêm giỏ phải đi thêm một màn hình. | Cân nhắc nút yêu thích và mua nhanh; quy cách chưa rõ thì yêu cầu chọn trước. Nếu hiện tồn, phải lấy số khả dụng thật của quy cách, không suy từ trạng thái còn hàng. |
| 7. Gợi ý ở chi tiết sản phẩm | Có Có thể bạn cũng thích và combo liên quan sản phẩm đang xem. | Chi tiết có thông tin, quy cách, nguồn gốc, chứng nhận, đánh giá nhưng chưa có hai khối gợi ý này. App có combo ở màn hình ưu đãi riêng, không phải thiếu toàn bộ combo. | Thêm gợi ý liên quan và ưu đãi mua kèm ở cuối chi tiết nếu muốn đồng bộ web. Dùng dữ liệu hiện có, không bịa sản phẩm hay điều kiện giảm. |
| 8. Trợ lý AI | Có hộp Trợ lý Organic Food gọi `/shopping-chat`. | Chưa có màn hình/thành phần tương ứng hoặc lời gọi endpoint này trong `lib`. | Thêm nếu cần demo AI trên app. API backend đã có; phải giữ giới hạn quyền xem đơn của tài khoản. Không cần tạo bảng chỉ để thêm giao diện chat. |
| 9. Đồng ý phương án đổi trả | Hộp xác nhận đã bỏ ô nhập ghi chú, gửi phiên bản phương án. | Không bắt nhập nhưng vẫn hiện Ghi chú (không bắt buộc). Khác với mong muốn chỉ xác nhận đã thống nhất trên web. | Dùng hộp xác nhận không có ô ghi chú riêng cho thao tác đồng ý. Giữ lý do ở các thao tác thực sự cần giải thích như đề nghị xét lại. |
| 10. Nhập hồ sơ | Có lịch chọn ngày sinh; điện thoại cho phép 9–15 chữ số theo backend. | Ngày sinh phải gõ `yyyy-MM-dd`; điện thoại trong ProfileScreen chỉ cho 9–10 chữ số và chưa dùng bàn phím điện thoại/email chuyên biệt. Trong khi màn địa chỉ của mobile đã cho 9–15. | Thống nhất kiểm tra số điện thoại với backend, thêm lịch chọn ngày và bàn phím đúng loại. Đây là chênh lệch thực tế có thể chặn dữ liệu hợp lệ. |
| 11. OTP đăng ký và phản hồi sau đăng nhập | OTP đăng ký giới hạn 6 số; gửi lại có đếm 60 giây; đăng nhập có lời chào thành công. | Luồng đăng ký chỉ kiểm tra OTP không trống, chưa giới hạn 6 số hoặc có đếm gửi lại; đăng nhập thành công đóng màn hình nhưng không có lời chào. Luồng quên/đổi mật khẩu riêng đã có xử lý OTP chặt hơn. | Bổ sung kiểm tra dễ hiểu, đếm thời gian theo quy tắc server và thông báo thành công trên app. Đây là giao diện, không cần Firebase cho lời chào. Không nới giới hạn gửi OTP của backend. |
| 12. Điểm đang giữ trong lịch sử | Lịch sử cho thấy cả `pointsDelta` và `reservedDelta`, tổng quan có tổng số dư. | Có số khả dụng/đang giữ, đổi voucher, ví và lịch sử; từng dòng chỉ hiện `pointsDelta`. Khi giữ điểm mà số này bằng 0, khách khó hiểu điều gì vừa thay đổi. | Hiện rõ Tích/Trừ/Giữ/Hoàn điểm và thay đổi điểm đang giữ. Dữ liệu đã có; không tính lại số dư chính thức ở app. |
| 13. Quay về sau thanh toán | Có trang nhận kết quả thanh toán trên website. | App mở cổng ngoài (payOS ưu tiên trình duyệt trong app), tự đối chiếu khi khách quay lại. Chưa có App Links/deep link thanh toán riêng để tự dẫn về app. | Ghi hướng dẫn quay lại app rõ ràng; nếu cần tự chuyển về thì thiết kế đường dẫn trả về, cấu hình app và backend/cổng. Không lấy mã trên URL làm căn cứ duy nhất xác nhận đã trả tiền. |
| 14. Yêu cầu nhận tại cửa hàng | Checkout có lựa chọn nhận tại cửa hàng và email nhận hóa đơn dạng yêu cầu. | Mobile chưa có hai lựa chọn tương ứng. | Chỉ thêm nếu cần demo cùng web. Lưu ý website hiện ghi chúng vào ghi chú đơn; đây chưa phải quy trình nhận tại cửa hàng/xuất hóa đơn điện tử hoàn chỉnh. Nếu muốn nghiệp vụ độc lập thực sự thì cần bàn thêm backend. |

**Những khác biệt thiên về trình bày, có thể làm sau**

- Banner ưu đãi: web có carousel tự chuyển 6 giây; mobile xếp banner thành danh sách, chỉ đưa 3 ưu đãi đầu lên trang chủ và có nút xem tất cả. Không phải các ưu đãi còn lại bị mất, nhưng chưa đồng bộ cách khám phá.
- Đánh giá sản phẩm: mobile đã có điểm trung bình, tổng lượt, lọc sao và sắp xếp; thiếu biểu đồ phân bố 1–5 sao như web. Không nên ghi nhận nhầm là mobile chưa có bộ lọc đánh giá.
- Chứng nhận: mobile đã đọc hồ sơ và mở tài liệu gốc nhưng trình bày chủ yếu bằng biểu tượng/thông tin, chưa có thẻ ảnh xem trước như web. Chỉ dùng ảnh/tài liệu gắn với hồ sơ thật.
- Ghi nhớ đăng nhập: web cho chọn; mobile luôn gửi `rememberMe: true` và lưu phiên trong secure storage. Đây có thể là lựa chọn UX hợp lý cho app cá nhân; không mặc định là lỗi hay tự thay đổi quy tắc phiên.

**Những nhóm đã hiện diện trên cả hai nền tảng**

| Nhóm | Kết luận ở mức mã nguồn |
| --- | --- |
| Tài khoản | Có đăng nhập, đăng ký/xác thực email, Google, liên kết Google, quên/đổi mật khẩu, hồ sơ và avatar. Chưa coi lời chào thành công là đã có trên mobile. |
| Sản phẩm | Có tìm kiếm, phân trang, ảnh, chọn quy cách/khối lượng, giá gốc/giá bán, tồn ở chi tiết, nguồn gốc, chứng nhận và đánh giá. Backend công khai lọc sản phẩm còn bán/còn hàng cho cả hai. |
| Giỏ hàng | Có giỏ khách, giỏ tài khoản, số lượng, chọn dòng để thanh toán và đồng bộ theo tài khoản. Không cần đưa màn quản lý kho vào mobile. |
| Ưu đãi | Có mã công khai, combo, ví voucher, đổi điểm lấy voucher, đề xuất voucher và loại trừ voucher với trừ điểm trực tiếp. Giá cuối cùng do backend xác nhận. |
| Đơn và thanh toán | Có đặt/xem/hủy theo điều kiện, các gateway backend cho phép, tự đối chiếu giao dịch chờ và lịch giao dự kiến do backend trả về. Không thiếu toàn bộ thanh toán chỉ vì chưa có deep link. |
| Đánh giá | Có sản phẩm đủ điều kiện đánh giá, gửi ảnh/video, tiêu đề theo sản phẩm/quy cách, xem/xóa và không cung cấp nút sửa nội dung. Ràng buộc quyền do backend. |
| Phản hồi | Có gửi nội dung, ảnh/video, trao đổi, đóng/mở lại theo quyền và đọc thông báo. Gợi ý chủ đề mobile đã được bổ sung trước lần rà soát này. |
| Đổi trả | Có gửi yêu cầu kèm ảnh, xem phương án, đồng ý/đề nghị xét lại, lịch sử, tiền hoàn và đơn đổi. Nhân viên duyệt/xử lý kho/chuyển tiền trên web, không phải thiếu chức năng của app khách hàng. |
| Cửa hàng và hỗ trợ | Có thông tin liên hệ, nguồn gốc/chứng nhận và 6 trang chính sách/hướng dẫn. |
| Thông báo | Có inbox, đã đọc, đường dẫn đến hồ sơ và tích hợp FCM; người dùng báo phần thông báo đã thử ổn. Không suy ra đã nghiệm thu mọi thiết bị/hệ điều hành. |
| Yêu thích | Cả hai có lưu yêu thích cục bộ. Chưa đồng bộ danh sách giữa web và app vì backend chưa có API tương ứng; đây là giới hạn chung, không chỉ mobile. |

**Căn cứ để kiểm tra lại**

| Mục | Web | Mobile / backend |
| --- | --- | --- |
| Vị trí giao hàng | [CheckoutDeliveryLocation](D:/oragnic-pro/organic_frontend/src/components/checkout/CheckoutDeliveryLocation.jsx:12) | [chọn vị trí](D:/oragnic-pro/organic_mobile/lib/features/checkout/presentation/checkout_screen.dart:134), [màn tìm vị trí](D:/oragnic-pro/organic_mobile/lib/features/checkout/presentation/widgets/delivery_location_picker.dart:18) |
| Cập nhật catalog | [tải lại định kỳ](D:/oragnic-pro/organic_frontend/src/hooks/useStoreCatalogRefresh.js:4) | [catalog](D:/oragnic-pro/organic_mobile/lib/features/catalog/presentation/catalog_screen.dart:44), [tải tồn chi tiết](D:/oragnic-pro/organic_mobile/lib/features/catalog/presentation/product_screen.dart:30) |
| Lọc đơn | [OrderHistoryPage](D:/oragnic-pro/organic_frontend/src/pages/client/OrderHistoryPage.jsx:25) | [OrdersScreen](D:/oragnic-pro/organic_mobile/lib/features/orders/presentation/orders_screen.dart:15) |
| Lọc phản hồi | [FeedbackPage](D:/oragnic-pro/organic_frontend/src/pages/shared/FeedbackPage.jsx:28) | [FeedbackListScreen](D:/oragnic-pro/organic_mobile/lib/features/feedback/presentation/feedback_list_screen.dart:23) |
| Danh mục | [cây danh mục](D:/oragnic-pro/organic_frontend/src/lib/storeCategoryTree.js:28) | [nút danh mục](D:/oragnic-pro/organic_mobile/lib/features/catalog/presentation/catalog_screen.dart:130), [tải danh mục](D:/oragnic-pro/organic_mobile/lib/app/state/organic_store.dart:285) |
| Thẻ/chi tiết sản phẩm | [ProductCard](D:/oragnic-pro/organic_frontend/src/components/products/ProductCard.jsx:17), [gợi ý](D:/oragnic-pro/organic_frontend/src/pages/client/ProductDetailPage.jsx:73) | [ProductTile](D:/oragnic-pro/organic_mobile/lib/features/catalog/presentation/widgets/product_tile.dart:7), [ProductScreen](D:/oragnic-pro/organic_mobile/lib/features/catalog/presentation/product_screen.dart:249) |
| AI | [ShoppingChat](D:/oragnic-pro/organic_frontend/src/components/layout/ShoppingChat.jsx:41) | [API backend](D:/oragnic-pro/organic_backend/src/main/java/vn/huit/nhom1/controller/ShoppingChatController.java) |
| Xác nhận phương án | [payload xác nhận](D:/oragnic-pro/organic_frontend/src/pages/shared/ReturnRequestsPage.jsx:51) | [gọi hộp ghi chú](D:/oragnic-pro/organic_mobile/lib/features/returns/presentation/return_detail_screen.dart:40), [ô ghi chú](D:/oragnic-pro/organic_mobile/lib/shared/widgets/note_dialog.dart:25) |
| Hồ sơ | [ProfilePanel](D:/oragnic-pro/organic_frontend/src/components/customers/ProfilePanel.jsx:53) | [ProfileScreen](D:/oragnic-pro/organic_mobile/lib/features/account/presentation/profile_screen.dart:85), [quy tắc backend](D:/oragnic-pro/organic_backend/src/main/java/vn/huit/nhom1/dto/request/customer/CustomerProfileRequest.java:9) |
| Đăng ký/OTP | [AuthPage](D:/oragnic-pro/organic_frontend/src/pages/auth/AuthPage.jsx:53) | [RegisterScreen](D:/oragnic-pro/organic_mobile/lib/features/auth/presentation/register_screen.dart:43) |
| Điểm | [RewardsPage](D:/oragnic-pro/organic_frontend/src/pages/client/RewardsPage.jsx:15) | [RewardsScreen](D:/oragnic-pro/organic_mobile/lib/features/rewards/presentation/rewards_screen.dart:166) |
| Thanh toán | [PaymentResultPage](D:/oragnic-pro/organic_frontend/src/pages/client/PaymentResultPage.jsx) | [mở cổng](D:/oragnic-pro/organic_mobile/lib/features/orders/presentation/payment_launcher.dart:10), [đối chiếu khi quay lại](D:/oragnic-pro/organic_mobile/lib/features/orders/presentation/order_screen.dart:62) |
| Nhận tại cửa hàng | [ghi yêu cầu vào ghi chú](D:/oragnic-pro/organic_frontend/src/lib/checkoutForm.js:5) | [CheckoutScreen](D:/oragnic-pro/organic_mobile/lib/features/checkout/presentation/checkout_screen.dart:118) |
| Trình bày | [carousel](D:/oragnic-pro/organic_frontend/src/components/promotions/ComboCarousel.jsx:4), [biểu đồ sao](D:/oragnic-pro/organic_frontend/src/components/products/ProductReviews.jsx:21) | [HomeBanners](D:/oragnic-pro/organic_mobile/lib/features/home/presentation/widgets/home_banners.dart:14), [ProductReviews](D:/oragnic-pro/organic_mobile/lib/features/reviews/presentation/widgets/product_reviews.dart:79) |

**Thứ tự nên cân nhắc nếu chốt làm tiếp**

1. Vị trí giao hàng tự động, cập nhật tồn khi quay lại, thống nhất nhập hồ sơ và xác nhận phương án không ghi chú: giảm lỗi và bước thừa trong demo.
2. Tìm/lọc đơn và phản hồi, danh mục nhiều cấp: dễ tìm khi dữ liệu nhiều.
3. Thẻ sản phẩm, gợi ý liên quan/combo, lịch sử điểm dễ hiểu và xác nhận thao tác thành công.
4. Trợ lý AI trên mobile nếu muốn trình bày chức năng mới trên cả hai nền tảng.
5. Sau cùng cân nhắc trình bày banner/chứng nhận/đánh giá, yêu cầu nhận tại cửa hàng và deep link thanh toán.

Không bổ sung API/schema hoặc triển khai các đề xuất trên trong lần rà soát này. Không push Git hay build/cài APK mới trong lần này.

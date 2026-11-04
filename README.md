# organicfood mobile

Ứng dụng Flutter dành cho khách hàng của hệ thống organicfood. App dùng chung tài khoản CUSTOMER, sản phẩm, giỏ hàng, đơn hàng và điểm thưởng với website thông qua API Spring Boot.

## Lấy mã và chuẩn bị môi trường

```sh
git clone https://github.com/sangpm2005/organic_mobile.git
cd organic_mobile
flutter --version
flutter doctor -v
flutter pub get
```

Môi trường đã kiểm tra: **Flutter 3.47.7 stable / Dart 3.13.5**, Android Emulator API 35 và JDK 21. `pubspec.yaml` yêu cầu Dart `^3.13.5`; SDK cũ hơn sẽ không giải quyết được dependencies. Cài Android Studio/Android SDK, hoàn tất các mục Android trong `flutter doctor` và mở máy ảo trước khi chạy app. Repo giữ `pubspec.lock` để cả nhóm dùng cùng phiên bản package.

Backend phải chạy riêng, có PostgreSQL/Redis và dữ liệu sản phẩm/tồn kho. Đây là repo mobile; không chứa backend, database hoặc khóa dịch vụ. Repo tham chiếu của nhóm: [backend](https://github.com/trongvi0807/organic_backend_version1.1), [website](https://github.com/trongvi0807/organic_frontend).

## Chạy trên Android

```sh
flutter devices
flutter run -d <ANDROID_DEVICE_ID>
```

Thay `<ANDROID_DEVICE_ID>` bằng ID từ `flutter devices`, ví dụ `emulator-5554`.

Nếu Android Emulator bị crash ở luồng `raster` với `bad_alloc` hoặc báo texture tối đa `0 × 0`, thử chọn **Organic Android Emulator** trong danh sách cấu hình Run của IntelliJ, chọn thiết bị Android rồi bấm Run. Cấu hình trong `.run/Organic_Android_Emulator.run.xml` dùng `--no-enable-impeller --enable-software-rendering` để tránh bộ vẽ GPU đang lỗi trên máy ảo với Flutter 3.47.7. Chế độ này có thể chậm hơn; thiết bị thật kết nối backend qua USB dùng cấu hình **Organic Android USB** bên dưới.

Nếu cả màn hình Android cũng đen hoặc không phản hồi, tắt máy ảo và khởi động lại với Software Graphics, giữ nguyên dữ liệu:

```sh
emulator -avd Organic_API_35 -gpu software -no-snapshot-load
```

- Android Emulator mặc định gọi `http://10.0.2.2:8088/api/v1`. `10.0.2.2` là máy Windows/macOS/Linux đang chạy backend, không phải máy ảo.
- Máy Android thật: dùng địa chỉ LAN của máy chạy backend hoặc backend HTTPS mà nhóm có thể truy cập; `localhost` trên điện thoại là chính điện thoại.
- Đổi API ở lúc chạy/build, luôn giữ hậu tố `/api/v1`:

```sh
flutter run -d <ANDROID_DEVICE_ID> --dart-define=API_BASE_URL=https://YOUR_BACKEND/api/v1
```

App chỉ cho phép tài khoản **CUSTOMER**. Tạo tài khoản qua OTP hoặc dùng tài khoản phát triển do nhóm cung cấp. SendGrid, Cloudinary, JWT và các khóa thanh toán nằm phía backend; không đưa vào Dart, assets hoặc `--dart-define`.

Mobile có đăng nhập và liên kết Google qua API sẵn có. Xem [cấu hình OAuth Android/iOS](docs/google-sign-in.md); Web Client ID của backend chưa thay thế đăng ký package/SHA-1 cho Android.

VietQR và PayPal là hai lựa chọn riêng trong bước đặt hàng. VietQR mở trang QR của payOS bằng trình duyệt trong ứng dụng (hoặc trình duyệt ngoài nếu thiết bị không hỗ trợ); PayPal mở trang chấp thuận PayPal riêng. Mobile dùng đường dẫn thanh toán API trả về, không tự tạo mã chuyển khoản hoặc tự đánh dấu đã thu tiền. Khi hủy đơn, app giữ nguyên lỗi API để người dùng đọc và chỉ cập nhật thành đã hủy sau phản hồi thành công từ máy chủ.

### Điện thoại Android thật qua USB

Bật Developer options và USB debugging trên điện thoại, dùng cáp có truyền dữ liệu, rồi chấp thuận hộp thoại cho phép gỡ lỗi USB. Backend vẫn chạy trên máy tính ở cổng 8088. Trong PowerShell:

```powershell
& "D:\Android\Sdk\platform-tools\adb.exe" devices
& "D:\Android\Sdk\platform-tools\adb.exe" -s "ID_DIEN_THOAI" reverse tcp:8088 tcp:8088
```

Thay `ID_DIEN_THOAI` bằng serial thật từ lệnh đầu, không chọn `emulator-5554`. Trong IntelliJ chọn cấu hình **Organic Android USB**, chọn điện thoại rồi Run. Cấu hình dùng `http://127.0.0.1:8088/api/v1` qua kết nối USB; không dùng địa chỉ `10.0.2.2` của máy ảo hoặc các cờ software rendering dành riêng cho máy ảo. Nếu kết nối USB/điện thoại được khởi động lại và app không gọi được backend, chạy lại lệnh `reverse`.

Hai cấu hình Android của IntelliJ dùng cache package tại `$PROJECT_DIR$/.pub-cache` (đã được Git bỏ qua), để tránh đường dẫn cache Windows chứa khoảng trắng như `C:/Users/Trong Vi`. Khi chạy bằng PowerShell, dùng cùng cache trước khi gọi Flutter:

```powershell
$env:PUB_CACHE = Join-Path (Get-Location).Path '.pub-cache'
flutter pub get
flutter run -d ID_DIEN_THOAI --dart-define=API_BASE_URL=http://127.0.0.1:8088/api/v1
```

Chạy các lệnh trên trong thư mục gốc `organic_mobile`. Sau khi thay đổi cấu hình `.run`, mở lại project nếu IntelliJ chưa cập nhật biến môi trường. Giữ đường dẫn dự án không có khoảng trắng; không chỉnh trực tiếp `package_config.json` vì Pub sẽ tạo lại tệp này.

Build APK debug:

```sh
flutter build apk --debug
```

APK ở `build/app/outputs/flutter-apk/app-debug.apk`. HTTP được cho phép trong Android debug; bản release cần HTTPS và cấu hình ký riêng. Cấu hình release hiện dùng khóa debug của template, chưa dùng để phát hành lên store. iOS mới có scaffold, chưa được build/kiểm tra trên Windows.

## Chạy trên trình duyệt

```sh
flutter run -d chrome --web-port=5180 --dart-define=API_BASE_URL=http://localhost:8088/api/v1
```

Backend cần cho phép CORS origin `http://localhost:5180`. Khi không truyền `API_BASE_URL`, bản web gọi `/api/v1` cùng origin nên cần reverse proxy. Repo mobile không kèm proxy/backend hoặc bộ lệnh mở dịch vụ dành riêng cho máy tác giả.

## Cấu trúc và luồng dữ liệu

```text
lib/
  main.dart                       # Khởi động ứng dụng
  app/
    organic_app.dart              # MaterialApp, locale, theme
    navigation/shop_shell.dart    # Điều hướng 5 tab
    state/organic_store.dart      # Phiên và dữ liệu dùng chung giữa các tab
  core/
    network/                      # HTTP, refresh token, lỗi API
    utils/                        # Đọc JSON, tiền tệ, ngày giờ
  features/
    auth/presentation/            # Đăng nhập, đăng ký OTP
    home/presentation/            # Trang chủ
    catalog/domain/               # Model sản phẩm
    catalog/presentation/         # Tìm kiếm, lọc, chi tiết sản phẩm
    cart/presentation/            # Giỏ đồng bộ với website
    checkout/data/                # Hợp đồng preview, đặt hàng, vị trí giao
    checkout/presentation/        # Đặt hàng, voucher, vị trí, bảng giá
    orders/data/                  # Đơn và đối chiếu/capture thanh toán
    orders/domain/                # Trạng thái, điều kiện hủy/trả tiền
    orders/presentation/          # Danh sách, chi tiết, vận chuyển
    rewards/data/                 # Đổi điểm, ví voucher, lịch sử
    rewards/presentation/         # Điểm / Đổi voucher / Ví voucher
    promotions/data/              # Feed ưu đãi công khai
    promotions/presentation/      # Sản phẩm ưu đãi, chọn biến thể combo
    notifications/data/           # Inbox khách hàng
    notifications/presentation/   # Inbox, cập nhật đơn, ưu đãi
    account/presentation/         # Hồ sơ, ảnh đại diện và sổ địa chỉ
    feedback/data/, presentation/ # Phản hồi, tin nhắn, ảnh/video, đóng/mở lại
    returns/data/, domain/, presentation/ # Yêu cầu đổi trả, phương án, hoàn/đổi
    reviews/data/, presentation/  # Đánh giá đã mua, ảnh/video, xem/xóa/viết lại
    favorites/presentation/       # Sản phẩm yêu thích trên ứng dụng
    store_info/presentation/      # Thông tin cửa hàng, liên hệ và FAQ
  shared/
    navigation/                   # Mở màn hình và thông báo ngắn
    state/                        # Cấp store cho cây widget
    theme/                        # Giao diện chung
    widgets/                      # Phân trang, trạng thái tải/lỗi, panel
test/                             # Unit/widget tests theo nhóm chức năng
integration_test/, test_driver/    # Nghiệm thu với backend UAT riêng
docs/mobile-backend-contract.md    # Phạm vi và hợp đồng đồng bộ 3 dự án
```

Không gom màn hình mới vào một file `customer.dart` hoặc `shop.dart`. Đặt màn hình ở `features/<tên>/presentation`, widget riêng của chức năng trong `presentation/widgets`; endpoint mới trong `data`; quy tắc nghiệp vụ phía client trong `domain`. Chỉ đưa thành phần thực sự dùng chung vào `shared`.

Các màn hình mới gọi repository của chức năng; `OrganicStore` điều phối phiên và dữ liệu dùng chung. HTTP và refresh token dùng duy nhất `OrganicApi`. Backend quyết định giá, tồn kho, quyền truy cập, ưu đãi và trạng thái thanh toán. Không đọc trực tiếp database hoặc nhập mã React/Spring vào Flutter.

Token, checkout, lần đổi voucher và yêu cầu đổi trả chưa rõ kết quả được lưu bằng `flutter_secure_storage`. Khi thử lại, app giữ nguyên payload và `Idempotency-Key`, kể cả sau khi khởi động lại. Dữ liệu riêng bị xóa khi đăng xuất/chuyển tài khoản. Làm mới tài khoản mỗi 30 giây khi app hoạt động; chi tiết đơn mỗi 20 giây và khi quay lại app. Đây là cập nhật trong app, chưa phải push nền.

## Chức năng đã đồng bộ

- Tìm kiếm/lọc sản phẩm, biến thể, tồn khả dụng, nguồn gốc/chứng nhận và đánh giá công khai.
- Giỏ chung web/mobile; preview giá, khuyến mãi, voucher hoặc trừ điểm; địa chỉ và xác nhận tọa độ giao hàng.
- COD và các cổng đang bật do backend trả về: VNPay, Stripe, PayPal, PayOS/VietQR. Mở trang thanh toán chính thức, quay lại xem đơn và chọn **Đã thanh toán / Kiểm tra kết quả**. PayPal có bước xác nhận để backend đối chiếu và capture giao dịch đã được chấp thuận.
- Theo dõi đơn: ảnh sản phẩm, giảm giá từng loại, hạn thanh toán, vận đơn, người giao và thời gian đến dự kiến nếu backend có dữ liệu.
- Điểm khả dụng/đang giữ, lịch sử phân trang; đổi điểm lấy voucher, ví voucher và chọn voucher khi đặt hàng.
- Ưu đãi công khai và combo: chọn biến thể, thêm toàn bộ combo bằng một thao tác nguyên tử; chỉ ghi nhớ mã sau khi thêm thành công.
- Inbox khách hàng, trạng thái đọc được lưu phía backend; cập nhật đơn và ưu đãi với trạng thái đọc riêng theo tài khoản.
- Phản hồi & hỗ trợ: tạo phản hồi chung hoặc theo đơn, xem danh sách/trạng thái, trao đổi tin nhắn, chọn ảnh/video từ điện thoại, xem/xóa tệp khi được phép, đóng/mở lại theo quyền backend.
- Đổi trả & hoàn tiền: kiểm tra điều kiện và số lượng còn được yêu cầu, chọn sản phẩm/lý do/hình thức hỗ trợ, bắt buộc ảnh minh chứng; xem/chấp nhận/đề nghị xét lại phương án, bổ sung thông tin, hủy khi được phép; theo dõi nhận hàng thu hồi, tiền đã hoàn và đơn giao hàng đổi.
- Đánh giá: danh sách sản phẩm đã mua/nhận đủ điều kiện, viết đánh giá kèm ảnh/video, lưu nháp phần chữ, xem trước, xem/xóa đánh giá của mình để viết lại; đọc/lọc/phân trang đánh giá công khai và tệp đính kèm trên sản phẩm.
- Hồ sơ có tải/xóa ảnh đại diện và xóa địa chỉ. Sản phẩm yêu thích lưu riêng theo tài khoản trên ứng dụng; backend hiện không có API yêu thích để đồng bộ danh sách này với trình duyệt.
- Thông báo phản hồi/đổi trả mở trực tiếp màn hình mobile tương ứng bằng ID, đánh dấu đọc theo luồng trên backend.

Phạm vi ứng dụng khách hàng đã được mở rộng theo yêu cầu thành viên: sản phẩm, mua/theo dõi đơn, điểm/voucher, thông báo/ưu đãi, hồ sơ/địa chỉ, yêu thích, đánh giá, phản hồi và đổi trả. Các màn hình quản trị, kho, nhân viên, báo cáo không thuộc mobile.

## Hợp đồng API cần đồng bộ với backend

Xem [bảng API và giới hạn kiểm chứng](docs/mobile-backend-contract.md). Mobile và website dùng cùng backend `/api/v1`, không cần cùng thư mục để chạy và cũng không tự đồng bộ mã nguồn qua việc đặt cạnh nhau.

Backend trong thư mục `../organic_backend` có thay đổi hỗ trợ `DELETE /cart/items/{variantId}?expectedQuantity=N`: so sánh và xóa nguyên tử trong Redis. Website `../organic_frontend` cũng đã gửi điều kiện này khi dọn giỏ sau đặt hàng. Khi chuyển máy/triển khai, cần đưa cả thay đổi backend và frontend vào nhánh tương ứng; chỉ chuyển repo mobile sẽ chưa đủ.

## Kiểm tra trước khi đẩy thay đổi

```sh
flutter analyze
flutter test
```

Đợt cập nhật ngày 05/11/2026 có 39 test Flutter: khôi phục checkout/voucher/đổi trả, giữ nguyên ảnh và mã yêu cầu sau lỗi mạng, kiểm tra phiên, gửi tệp sau refresh token, phương án đổi trả có phiên bản, phản hồi không gửi trùng nội dung, thông báo mở màn hình mobile và giao diện rộng 390px. Bộ test giỏ backend đã kiểm tra ở đợt trước: 12/12; frontend giỏ/checkout: 31/31. Các con số này là kiểm tra tự động, không phải kết quả giao dịch tiền thật.

Đợt nghiệm thu local ngày 28–29/10/2026 ghi nhận 15 unit/widget test đạt; đã kiểm tra OTP thật, tìm kiếm/lọc, giỏ đồng bộ web, COD, trạng thái đơn, hủy đơn, tích/hoàn điểm, refresh/thu hồi phiên và khôi phục sau tắt app. Một số lượt harness cần chạy lại do locator hoặc thiếu bộ nhớ; không coi toàn bộ lượt integration test đều đạt.

`integration_test/acceptance_test.dart` cần API UAT, bridge điều khiển dữ liệu/lỗi và các giá trị `API_BASE_URL`, `UAT_BRIDGE`, `UAT_TOKEN` truyền lúc chạy. Bridge/fixture và dữ liệu nghiệm thu nằm ngoài repo này; harness không chạy độc lập chỉ bằng `flutter test integration_test`. Không dùng dữ liệu kinh doanh cho các ca tạo/hủy đơn tự động. Driver hiện ghi ảnh/log về `../.local/acceptance/20261028-uat/artifacts`.

## Giới hạn và phần triển khai tiếp

- Push cho khách hàng khi app chạy nền/bị đóng và push khuyến mãi: backend hiện có luồng thiết bị FCM cho kho/nhân viên; chưa có hợp đồng push khách hàng. Mobile hiện dùng inbox và cập nhật khi app hoạt động.
- Thanh toán có giao diện mở cổng và đối chiếu/capture; chưa nghiệm thu thanh toán tiền thật đầu cuối. Chưa có deep link riêng quay thẳng về app; sau khi thanh toán, người dùng quay lại app và kiểm tra kết quả. Thành công chỉ dựa trên phản hồi backend.
- Các luồng mới đã có kiểm thử hợp đồng/giao diện; nghiệm thu đầu cuối với tài khoản UAT, tệp thật và Cloudinary vẫn cần thực hiện trên môi trường của nhóm. Chọn ảnh/video qua trình chọn tệp hệ thống; ảnh/video trong bản nháp đánh giá cần chọn lại khi mở màn hình mới.
- Release signing, thiết bị thật và iOS chưa được nghiệm thu. Không dùng khóa debug để phát hành store.

## Làm việc nhóm

Repo công khai cho phép mọi thành viên clone. Thành viên đã được chủ repo thêm làm collaborator có thể đẩy nhánh trực tiếp; nếu chưa có quyền ghi, fork repo và mở pull request từ fork.

Tạo nhánh riêng cho từng việc, ví dụ `git switch -c feature/customer-push`, commit rồi mở pull request về `main`. Trước khi bắt đầu việc mới, cập nhật `main` bằng `git pull --ff-only`. Tránh thay `pubspec.lock` hoặc format hàng loạt khi không liên quan tới công việc.

Font Be Vietnam Pro và Lora kèm giấy phép trong `assets/fonts/*-OFL.txt`. Các file cấu hình máy, khóa ký, build, dữ liệu và log local đã được loại khỏi Git.

## Kiểm tra các chức năng khách hàng mới

Tên hiển thị của ứng dụng là **organicfood** trên Flutter, Android, iOS và bản web. Sau khi đổi tên Android/iOS, Stop rồi Run/build lại; hot reload không cập nhật tên dưới biểu tượng. Giữ nguyên application ID và khóa phiên cũ để tài khoản hiện có không bị đăng xuất chỉ vì đổi thương hiệu.

1. **Tài khoản → Phản hồi & hỗ trợ**: gửi nội dung, thêm ảnh/video, mở chi tiết để đọc/trả lời và xem trạng thái. Trong chi tiết đơn, chọn **Phản hồi về đơn hàng** để gắn đúng đơn.
2. **Chi tiết đơn → Yêu cầu đổi trả / hoàn tiền**: chọn sản phẩm/số lượng còn được yêu cầu, nhập mô tả và thêm ảnh. Backend quyết định đơn có đủ điều kiện; đơn đã thanh toán bị hủy chỉ đề nghị hoàn tiền.
3. **Tài khoản → Đổi trả & hoàn tiền**: xem phương án và từng dòng sản phẩm; chỉ đồng ý phương án đang hiển thị, hoặc yêu cầu xét lại/bổ sung/hủy theo quyền trả về. Thông tin được duyệt và tiền hoàn dự kiến khác với khoản hoàn đã thành công; app hiển thị riêng.
4. Mất mạng khi gửi đổi trả: vào lại **Đổi trả & hoàn tiền → Kiểm tra yêu cầu chưa rõ kết quả**. Ảnh được lưu trong vùng riêng của app trên Android/iOS để thử lại cùng nội dung và key. Không thay nội dung khi lần gửi trước chưa rõ kết quả. Bản web chỉ giữ ảnh đang chờ trong bộ nhớ, cần đối chiếu danh sách trước khi tải lại trang/gửi mới.
5. **Tài khoản → Đánh giá của tôi → Sản phẩm đã nhận**: viết đánh giá đủ điều kiện, chọn sao và gửi ảnh/video cùng lần gửi. Đánh giá đã gửi không sửa nội dung; có thể xóa rồi viết lại theo điều kiện backend.
6. Chạm trái tim trong chi tiết sản phẩm để lưu yêu thích; vào **Tài khoản → Sản phẩm yêu thích**. Danh sách này lưu trên ứng dụng, riêng cho từng tài khoản.
7. **Thông tin cá nhân**: tải/xóa ảnh đại diện. **Địa chỉ nhận hàng**: thêm/sửa/chọn mặc định qua form/xóa. **Thông tin & liên hệ cửa hàng** đọc địa chỉ, số liên hệ và FAQ do backend quản lý.

API ảnh/video và avatar cần cấu hình Cloudinary phía backend giống website. Không đặt khóa dịch vụ trong mobile. Các màn hình trao đổi tải lại khi mở/refresh và khi app hoạt động; push nền vẫn cần backend khách hàng/FCM bổ sung.

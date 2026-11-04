# Mộc Organic mobile

Ứng dụng Flutter dành cho khách hàng của hệ thống Mộc Organic. App dùng chung tài khoản CUSTOMER, sản phẩm, giỏ hàng, đơn hàng và điểm thưởng với website thông qua API Spring Boot.

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

Nếu Android Emulator bị crash ở luồng `raster` với `bad_alloc` hoặc báo texture tối đa `0 × 0`, thử chọn **Organic Android Emulator** trong danh sách cấu hình Run của IntelliJ, chọn thiết bị Android rồi bấm Run. Cấu hình trong `.run/Organic_Android_Emulator.run.xml` dùng `--no-enable-impeller --enable-software-rendering` để tránh bộ vẽ GPU đang lỗi trên máy ảo với Flutter 3.47.7. Chế độ này có thể chậm hơn; thiết bị thật dùng cấu hình `main.dart` thông thường.

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

### Điện thoại Android thật qua USB

Bật Developer options và USB debugging trên điện thoại, dùng cáp có truyền dữ liệu, rồi chấp thuận hộp thoại cho phép gỡ lỗi USB. Backend vẫn chạy trên máy tính ở cổng 8088. Trong PowerShell:

```powershell
& "D:\Android\Sdk\platform-tools\adb.exe" devices
& "D:\Android\Sdk\platform-tools\adb.exe" -s "ID_DIEN_THOAI" reverse tcp:8088 tcp:8088
```

Thay `ID_DIEN_THOAI` bằng serial thật từ lệnh đầu, không chọn `emulator-5554`. Trong IntelliJ chọn cấu hình **Organic Android USB**, chọn điện thoại rồi Run. Cấu hình dùng `http://127.0.0.1:8088/api/v1` qua kết nối USB; không dùng địa chỉ `10.0.2.2` của máy ảo hoặc các cờ software rendering dành riêng cho máy ảo. Nếu kết nối USB/điện thoại được khởi động lại và app không gọi được backend, chạy lại lệnh `reverse`.

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
    account/presentation/         # Hồ sơ và sổ địa chỉ
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

Token, checkout và lần đổi voucher chưa rõ kết quả được lưu bằng `flutter_secure_storage`. Khi thử lại, app giữ nguyên payload và `Idempotency-Key`, kể cả sau khi khởi động lại. Dữ liệu riêng bị xóa khi đăng xuất/chuyển tài khoản. Làm mới tài khoản mỗi 30 giây khi app hoạt động; chi tiết đơn mỗi 20 giây và khi quay lại app. Đây là cập nhật trong app, chưa phải push nền.

## Chức năng đã đồng bộ

- Tìm kiếm/lọc sản phẩm, biến thể, tồn khả dụng, nguồn gốc/chứng nhận và đánh giá công khai.
- Giỏ chung web/mobile; preview giá, khuyến mãi, voucher hoặc trừ điểm; địa chỉ và xác nhận tọa độ giao hàng.
- COD và các cổng đang bật do backend trả về: VNPay, Stripe, PayPal, PayOS/VietQR. Mở trang thanh toán chính thức, quay lại xem đơn và chọn **Đã thanh toán / Kiểm tra kết quả**. PayPal có bước xác nhận để backend đối chiếu và capture giao dịch đã được chấp thuận.
- Theo dõi đơn: ảnh sản phẩm, giảm giá từng loại, hạn thanh toán, vận đơn, người giao và thời gian đến dự kiến nếu backend có dữ liệu.
- Điểm khả dụng/đang giữ, lịch sử phân trang; đổi điểm lấy voucher, ví voucher và chọn voucher khi đặt hàng.
- Ưu đãi công khai và combo: chọn biến thể, thêm toàn bộ combo bằng một thao tác nguyên tử; chỉ ghi nhớ mã sau khi thêm thành công.
- Inbox khách hàng, trạng thái đọc được lưu phía backend; cập nhật đơn và ưu đãi với trạng thái đọc riêng theo tài khoản.

Phạm vi giữ đúng ứng dụng khách hàng: sản phẩm, mua/theo dõi đơn, điểm/voucher, thông báo/ưu đãi; hồ sơ và địa chỉ phục vụ các luồng này. Các màn hình quản trị, kho, nhân viên, báo cáo không thuộc mobile.

## Hợp đồng API cần đồng bộ với backend

Xem [bảng API và giới hạn kiểm chứng](docs/mobile-backend-contract.md). Mobile và website dùng cùng backend `/api/v1`, không cần cùng thư mục để chạy và cũng không tự đồng bộ mã nguồn qua việc đặt cạnh nhau.

Backend trong thư mục `../organic_backend` có thay đổi hỗ trợ `DELETE /cart/items/{variantId}?expectedQuantity=N`: so sánh và xóa nguyên tử trong Redis. Website `../organic_frontend` cũng đã gửi điều kiện này khi dọn giỏ sau đặt hàng. Khi chuyển máy/triển khai, cần đưa cả thay đổi backend và frontend vào nhánh tương ứng; chỉ chuyển repo mobile sẽ chưa đủ.

## Kiểm tra trước khi đẩy thay đổi

```sh
flutter analyze
flutter test
```

Đợt đồng bộ ngày 05/11/2026: 24 test Flutter đạt, gồm khôi phục checkout/đổi voucher, đổi phiên, điều kiện voucher, danh sách cổng thanh toán và giao diện rộng 390px. Bộ test giỏ backend: 12/12; các test giỏ/checkout liên quan của frontend: 31/31. Các con số này là kiểm tra tự động, không phải kết quả thanh toán tiền thật.

Đợt nghiệm thu local ngày 28–29/10/2026 ghi nhận 15 unit/widget test đạt; đã kiểm tra OTP thật, tìm kiếm/lọc, giỏ đồng bộ web, COD, trạng thái đơn, hủy đơn, tích/hoàn điểm, refresh/thu hồi phiên và khôi phục sau tắt app. Một số lượt harness cần chạy lại do locator hoặc thiếu bộ nhớ; không coi toàn bộ lượt integration test đều đạt.

`integration_test/acceptance_test.dart` cần API UAT, bridge điều khiển dữ liệu/lỗi và các giá trị `API_BASE_URL`, `UAT_BRIDGE`, `UAT_TOKEN` truyền lúc chạy. Bridge/fixture và dữ liệu nghiệm thu nằm ngoài repo này; harness không chạy độc lập chỉ bằng `flutter test integration_test`. Không dùng dữ liệu kinh doanh cho các ca tạo/hủy đơn tự động. Driver hiện ghi ảnh/log về `../.local/acceptance/20261028-uat/artifacts`.

## Giới hạn và phần triển khai tiếp

- Push cho khách hàng khi app chạy nền/bị đóng và push khuyến mãi: backend hiện có luồng thiết bị FCM cho kho/nhân viên; chưa có hợp đồng push khách hàng. Mobile hiện dùng inbox và cập nhật khi app hoạt động.
- Thanh toán có giao diện mở cổng và đối chiếu/capture; chưa nghiệm thu thanh toán tiền thật đầu cuối. Chưa có deep link riêng quay thẳng về app; sau khi thanh toán, người dùng quay lại app và kiểm tra kết quả. Thành công chỉ dựa trên phản hồi backend.
- Upload avatar, viết đánh giá, phản hồi/đổi trả không nằm trong đợt đồng bộ này. App vẫn đọc đánh giá và nội dung inbox khách hàng.
- Release signing, thiết bị thật và iOS chưa được nghiệm thu. Không dùng khóa debug để phát hành store.

## Làm việc nhóm

Repo công khai cho phép mọi thành viên clone. Thành viên đã được chủ repo thêm làm collaborator có thể đẩy nhánh trực tiếp; nếu chưa có quyền ghi, fork repo và mở pull request từ fork.

Tạo nhánh riêng cho từng việc, ví dụ `git switch -c feature/customer-push`, commit rồi mở pull request về `main`. Trước khi bắt đầu việc mới, cập nhật `main` bằng `git pull --ff-only`. Tránh thay `pubspec.lock` hoặc format hàng loạt khi không liên quan tới công việc.

Font Be Vietnam Pro và Lora kèm giấy phép trong `assets/fonts/*-OFL.txt`. Các file cấu hình máy, khóa ký, build, dữ liệu và log local đã được loại khỏi Git.

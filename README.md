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

- Android Emulator mặc định gọi `http://10.0.2.2:8088/api/v1`. `10.0.2.2` là máy Windows/macOS/Linux đang chạy backend, không phải máy ảo.
- Máy Android thật: dùng địa chỉ LAN của máy chạy backend hoặc backend HTTPS mà nhóm có thể truy cập; `localhost` trên điện thoại là chính điện thoại.
- Đổi API ở lúc chạy/build, luôn giữ hậu tố `/api/v1`:

```sh
flutter run -d <ANDROID_DEVICE_ID> --dart-define=API_BASE_URL=https://YOUR_BACKEND/api/v1
```

App chỉ cho phép tài khoản **CUSTOMER**. Tạo tài khoản qua OTP hoặc dùng tài khoản phát triển do nhóm cung cấp. SendGrid, Cloudinary, JWT và các khóa thanh toán nằm phía backend; không đưa vào Dart, assets hoặc `--dart-define`.

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

| Vị trí | Vai trò |
| --- | --- |
| `lib/main.dart` | Khởi tạo store, theme và 5 tab chính |
| `lib/core/api.dart` | HTTP, timeout, Authorization và refresh token |
| `lib/core/store.dart` | Phiên, secure storage, giỏ, đơn, điểm và checkout đang chờ |
| `lib/core/models.dart` | Đọc JSON, model và định dạng dữ liệu |
| `lib/ui/shop.dart` | Trang chủ, tìm kiếm, danh mục, chi tiết sản phẩm và giỏ |
| `lib/ui/auth.dart` | Đăng nhập, đăng ký, tiếp tục xác thực OTP |
| `lib/ui/checkout.dart` | Preview giá, đặt hàng và thử lại giao dịch chưa rõ kết quả |
| `lib/ui/customer.dart` | Hồ sơ, địa chỉ, đơn hàng, điểm và thông báo trong app |
| `test/` | Unit/widget tests không cần backend thật |
| `integration_test/`, `test_driver/` | Harness nghiệm thu Android với backend UAT riêng |

Luồng chính: giao diện → `OrganicStore`/`OrganicApi` → API backend → cập nhật store → dựng lại giao diện. Token và checkout đang chờ được lưu bằng `flutter_secure_storage`. Các module tài khoản được làm mới định kỳ 30 giây khi đang sử dụng app; đây chưa phải push nền. Checkout giữ cùng `Idempotency-Key` và payload khi mất phản hồi để tránh tạo đơn lặp.

## Hợp đồng API cần đồng bộ với backend

Các nhóm endpoint gồm `/auth`, `/home`, `/categories`, `/products`, `/customers/me`, `/cart`, `/checkout/preview`, `/orders`, `/promotions` và `/payments`. Đường dẫn cụ thể nằm ngay trong `lib/core/` và `lib/ui/`.

Hai thay đổi backend trong đợt nghiệm thu local cần được đồng bộ với nhánh backend của nhóm:

- `GET /products/{id}/availability` cho phép đọc tồn khả dụng công khai. Bản backend cũ có thể chưa cho phép truy cập endpoint này.
- `DELETE /cart/items/{variantId}?expectedQuantity=N` chỉ xóa khi số lượng hiện tại bằng `N`. Điều kiện phải được xử lý nguyên tử phía Redis/backend; bỏ qua tham số này có thể xóa giỏ vừa được thiết bị khác cập nhật sau checkout. DELETE không truyền điều kiện vẫn dùng cho thao tác xóa giỏ thông thường.

Không mặc định rằng clone backend gốc sẽ có các sửa đổi local này. Khi thay API, kiểm tra cả website và mobile dùng chung dữ liệu.

## Kiểm tra trước khi đẩy thay đổi

```sh
flutter analyze
flutter test
```

Đợt nghiệm thu local ngày 28–29/10/2026 ghi nhận 15 unit/widget test đạt; đã kiểm tra OTP thật, tìm kiếm/lọc, giỏ đồng bộ web, COD, trạng thái đơn, hủy đơn, tích/hoàn điểm, refresh/thu hồi phiên và khôi phục sau tắt app. Một số lượt harness cần chạy lại do locator hoặc thiếu bộ nhớ; không coi toàn bộ lượt integration test đều đạt.

`integration_test/acceptance_test.dart` cần API UAT, bridge điều khiển dữ liệu/lỗi và các giá trị `API_BASE_URL`, `UAT_BRIDGE`, `UAT_TOKEN` truyền lúc chạy. Bridge/fixture và dữ liệu nghiệm thu nằm ngoài repo này; harness không chạy độc lập chỉ bằng `flutter test integration_test`. Không dùng dữ liệu kinh doanh cho các ca tạo/hủy đơn tự động. Driver hiện ghi ảnh/log về `../.local/acceptance/20261028-uat/artifacts`.

## Phần còn thiếu

- Push cho khách hàng khi app chạy nền/bị đóng và push khuyến mãi.
- Thanh toán online đầu cuối trên Android: deep link/return, capture và khôi phục kết quả, đặc biệt PayPal. COD đã được kiểm tra; mở link thanh toán chưa đủ để công nhận luồng online hoàn tất.
- Upload avatar, viết đánh giá/ảnh, phản hồi/đổi trả trên mobile. App hiện đọc đánh giá công khai; liên hệ cửa hàng qua ứng dụng điện thoại.
- Email OTP phía backend đang thiếu subject và có thể vào Spam; cần nhóm sửa template/miền gửi.
- Release signing, thiết bị thật và iOS chưa được nghiệm thu.

## Làm việc nhóm

Tạo nhánh riêng cho từng việc, ví dụ `git switch -c feature/customer-push`, commit rồi mở pull request về `main`. Trước khi bắt đầu việc mới, cập nhật `main` bằng `git pull --ff-only`. Tránh thay `pubspec.lock` hoặc format hàng loạt khi không liên quan tới công việc.

Font Be Vietnam Pro và Lora kèm giấy phép trong `assets/fonts/*-OFL.txt`. Các file cấu hình máy, khóa ký, build, dữ liệu và log local đã được loại khỏi Git.

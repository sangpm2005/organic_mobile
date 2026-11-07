# Quy cách, ảnh sản phẩm và địa chỉ mobile

Mobile dùng sản phẩm cha từ `/products`; các mức khối lượng/dung tích lấy từ `variants` của `/products/{id}`. Không tách từng variant thành thẻ sản phẩm và không gộp sản phẩm khác ID bằng tên gần giống. Nhãn quy cách ở chi tiết và giỏ kết hợp `variantName`, `netQuantity`, `unitId`, tránh lặp khối lượng nếu tên đã chứa. Chỉ chọn quy cách `active`, giá và khối lượng lớn hơn 0, giống frontend. Giá, giá gốc, tồn kho và `variantId` gửi vào giỏ thay đổi theo quy cách; đổi quy cách đặt số lượng về 1.

Ảnh sản phẩm hiển thị trọn khung bằng `BoxFit.contain`. Bộ ảnh lấy toàn bộ `images`, ưu tiên `isPrimary`, sau đó `sortOrder`, loại URL trùng. Có vuốt, ảnh thu nhỏ và màn hình phóng to bằng hai ngón tay. Nếu API chỉ cung cấp một ảnh/quy cách, ứng dụng chỉ hiển thị một; cần bổ sung dữ liệu sản phẩm tại hệ thống quản lý nếu muốn thêm góc chụp/quy cách.

Địa chỉ có hai cấp Tỉnh/Thành phố và Phường/Xã. Danh sách có tìm kiếm không dấu và tìm theo tên cũ. Dữ liệu trong `assets/data/address/vietnam.json` được giữ nguyên từ frontend, gồm 34 tỉnh/thành và 3.321 phường/xã; nguồn tinhthanhpho.com, giấy phép CC BY 4.0 (siêu dữ liệu nằm trong tệp). Đổi tỉnh xóa phường đã chọn. Địa chỉ giao hàng ghép số nhà/tên đường, phường/xã, tỉnh/thành phố; chọn vị trí bản đồ chỉ bổ sung tọa độ.

API sổ địa chỉ hiện vẫn bắt buộc `district`. Mobile giữ giá trị cũ khi sửa cùng phường, hoặc đối chiếu quận/huyện cũ duy nhất từ dữ liệu. Nếu có nhiều kết quả, mobile chặn lưu và báo lỗi thay vì tự đoán, giống frontend. Checkout không cần trường này. Không thay đổi hợp đồng backend.

Kiểm tra: `flutter analyze`, `flutter test`. Các ca mới kiểm tra đổi quy cách/giá/tồn kho/giỏ khách, thư viện ảnh và màn hình phóng to, tra cứu tên địa chỉ cũ, đổi tỉnh, lưu địa chỉ đúng API và chọn địa chỉ trong checkout.

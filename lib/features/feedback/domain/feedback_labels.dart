const feedbackTypes = {
  'product': 'Sản phẩm',
  'delivery': 'Giao hàng',
  'payment': 'Thanh toán',
  'service': 'Dịch vụ',
  'other': 'Góp ý khác',
};

const feedbackSubjectSuggestions = {
  'product': [
    'Chất lượng sản phẩm',
    'Thông tin sản phẩm',
    'Cách bảo quản sản phẩm',
  ],
  'delivery': [
    'Giao hàng chậm',
    'Giao thiếu hoặc nhầm hàng',
    'Tình trạng hàng khi nhận',
  ],
  'payment': [
    'Thanh toán chưa cập nhật',
    'Thanh toán không thành công',
    'Hỏi về số tiền thanh toán',
  ],
  'service': ['Hỗ trợ đơn hàng', 'Góp ý cách phục vụ', 'Cần nhân viên tư vấn'],
  'other': [
    'Góp ý cho cửa hàng',
    'Đề xuất sản phẩm mới',
    'Nội dung hỗ trợ khác',
  ],
};

const feedbackStates = {
  'pending': 'Chờ tiếp nhận',
  'processing': 'Đang xử lý',
  'waiting_customer': 'Chờ bạn bổ sung',
  'resolved': 'Đã giải quyết',
  'closed': 'Đã đóng',
};

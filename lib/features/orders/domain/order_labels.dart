String orderStatus(dynamic status) =>
    const {
      'pending_payment': 'Chờ thanh toán',
      'confirmed': 'Đã xác nhận',
      'paid': 'Đã thanh toán',
      'preparing': 'Đang chuẩn bị',
      'shipping': 'Đang giao hàng',
      'shipped': 'Đang giao hàng',
      'delivered': 'Đã giao hàng',
      'completed': 'Hoàn tất',
      'cancelled': 'Đã hủy',
      'expired': 'Hết thời gian',
      'pending': 'Đang xử lý',
      'unpaid': 'Chưa thanh toán',
      'refunded': 'Đã hoàn tiền',
      'partially_refunded': 'Đã hoàn một phần',
      'refund_pending': 'Đang hoàn tiền',
      'booked': 'Đã đặt giao hàng',
      'picked_up': 'Đã nhận hàng từ cửa hàng',
      'in_transit': 'Đang vận chuyển',
      'delivery_failed': 'Giao chưa thành công',
      'failed': 'Thất bại',
    }[status] ??
    '$status';

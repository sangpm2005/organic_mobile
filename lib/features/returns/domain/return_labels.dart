import 'dart:convert';

import '../../../core/utils/json.dart';
import '../../../core/utils/formatters.dart';

const returnTypes = {
  'return_refund': 'Trả hàng và hoàn tiền',
  'refund': 'Hoàn tiền không thu hồi',
  'exchange': 'Đổi sản phẩm',
};
const returnReasons = {
  'damaged': 'Sản phẩm hư hỏng',
  'expired': 'Sản phẩm hết hạn',
  'wrong_product': 'Giao sai sản phẩm',
  'missing_product': 'Giao thiếu sản phẩm',
  'quality_issue': 'Vấn đề chất lượng',
  'other': 'Lý do khác',
};
const returnStates = {
  'pending': 'Chờ tiếp nhận',
  'reviewing': 'Đang xét duyệt',
  'waiting_customer': 'Chờ bạn bổ sung',
  'approved': 'Chờ bạn xác nhận phương án',
  'processing': 'Đã đồng ý · Đang thực hiện',
  'completed': 'Đã hoàn tất xử lý',
  'rejected': 'Đã từ chối',
  'cancelled': 'Đã hủy yêu cầu',
};
const refundStates = {
  'pending': 'Đang chờ',
  'processing': 'Đang xử lý',
  'succeeded': 'Đã hoàn tiền',
  'failed': 'Chưa hoàn thành',
  'requires_review': 'Đang đối soát',
  'cancelled': 'Đã hủy',
};
const historyActions = {
  'created': 'Tạo yêu cầu',
  'submitted': 'Gửi yêu cầu',
  'claimed': 'Tiếp nhận',
  'approved': 'Duyệt phương án',
  'rejected': 'Từ chối',
  'cancelled': 'Hủy yêu cầu',
  'customer_accepted': 'Bạn đồng ý',
  'customer_declined': 'Yêu cầu xét lại',
  'proposal_accepted': 'Bạn đồng ý',
  'proposal_declined': 'Yêu cầu xét lại',
  'information_requested': 'Yêu cầu bổ sung',
  'information_submitted': 'Bổ sung thông tin',
  'goods_received': 'Nhận hàng',
  'goods_inspected': 'Kiểm tra hàng',
  'goods_restocked': 'Hoàn tất nhập lại',
  'goods_disposed': 'Đã xử lý hàng',
  'refund_succeeded': 'Đã hoàn tiền',
  'refund_requested': 'Đang xử lý hoàn tiền',
  'replacement_created': 'Tạo đơn đổi hàng',
  'execution_completed': 'Hoàn tất hồ sơ',
};
String supportHistoryText(String text) {
  final start = text.indexOf('{');
  if (start >= 0) {
    try {
      final data = object(jsonDecode(text.substring(start)));
      if (data.containsKey('proposal') ||
          data.containsKey('receiptItemId') ||
          data.containsKey('execution')) {
        return '${data['note'] ?? 'Đã ghi nhận xử lý.'}${data['proposal'] == null ? '' : '\nPhương án lần ${data['proposalVersion']}: tiền hoàn dự kiến ${money(object(data['proposal'])['approvedRefundAmount'])}.'}';
      }
    } catch (_) {
      return 'Đã ghi nhận lịch sử xử lý. Xem chi tiết phương án để đối chiếu.';
    }
  }
  final labels = {
    ...returnStates,
    ...returnTypes,
    'waiting_customer': 'Chờ bạn bổ sung',
    'resolved': 'Đã giải quyết',
    'closed': 'Đã đóng',
  };
  return text.replaceAllMapped(
    RegExp(
      r'\b(waiting_customer|return_refund|processing|reviewing|approved|pending|resolved|closed|rejected|cancelled|completed|exchange|refund)\b',
    ),
    (m) => labels[m[0]] ?? m[0]!,
  );
}

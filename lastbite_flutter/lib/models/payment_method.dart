/// Phương thức thanh toán (BMC: MoMo, VNPay, ZaloPay, PayOS + VietQR).
/// Tất cả đều GIẢ LẬP cho bản demo theo quy tắc dựng lại: không SDK thật,
/// không tài khoản merchant thật, không trừ tiền thật. Khi vận hành thật,
/// thay màn MockPaymentScreen bằng SDK/webview của cổng và xác thực
/// callback từ cổng, còn danh sách phương thức này giữ nguyên.
class PaymentMethod {
  final String id;
  final String name;
  final String emoji;
  final bool isQr; // true: hiện mã QR giả lập; false: hiện ví giả lập
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.emoji,
    required this.isQr,
  });

  static const List<PaymentMethod> all = [
    PaymentMethod(id: 'momo', name: 'MoMo', emoji: '💗', isQr: false),
    PaymentMethod(id: 'vnpay', name: 'VNPay', emoji: '💳', isQr: true),
    PaymentMethod(id: 'zalopay', name: 'ZaloPay', emoji: '💙', isQr: false),
    PaymentMethod(id: 'payos', name: 'PayOS', emoji: '⚡', isQr: true),
    PaymentMethod(id: 'vietqr', name: 'VietQR', emoji: '📱', isQr: true),
  ];

  static PaymentMethod byId(String? id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return all.last; // vietqr mặc định
  }
}

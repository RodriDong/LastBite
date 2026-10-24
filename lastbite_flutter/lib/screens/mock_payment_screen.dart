import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/mock_data.dart';
import '../models/payment_method.dart';
import '../services/api_service.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';

/// Màn thanh toán GIẢ LẬP (BMC: MoMo / VNPay / ZaloPay / PayOS / VietQR).
/// Không gọi SDK thật, không trừ tiền thật, không cần tài khoản ngân hàng
/// hay merchant thật: người dùng bấm "Tôi đã thanh toán" là server chuyển
/// đơn sang PAID. Khi vận hành thật, thay màn này bằng SDK/webview của
/// cổng thanh toán và xác thực callback từ cổng.
class MockPaymentScreen extends StatefulWidget {
  final String orderId;
  final int amount;
  final PaymentMethod method;
  final void Function(BuildContext ctx) onPaid;
  const MockPaymentScreen({
    super.key,
    required this.orderId,
    required this.amount,
    required this.method,
    required this.onPaid,
  });

  @override
  State<MockPaymentScreen> createState() => _MockPaymentScreenState();
}

class _MockPaymentScreenState extends State<MockPaymentScreen> {
  bool _paying = false;

  Future<void> _confirmPaid() async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      await OrderService.confirmFakePayment(widget.orderId);
      if (!mounted) return;
      widget.onPaid(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.method;
    return Scaffold(
      backgroundColor: AppColors.app,
      appBar: AppBar(
        title: const Text('Thanh toán'),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                Text('${m.emoji} ${m.name}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(AppData.formatVnd(widget.amount),
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.price)),
                const Text('Số tiền cần thanh toán',
                    style: TextStyle(color: AppColors.mute, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (m.isQr)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  QrImageView(
                    data:
                        'LASTBITE|${widget.orderId}|${widget.amount}|${m.id}',
                    size: 200,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Quét mã bằng app ngân hàng hoặc ví (giả lập)',
                    style: TextStyle(color: AppColors.mute, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ví ${m.name} •••• 8888',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Số dư khả dụng: 1.250.000đ (giả lập)',
                      style: TextStyle(color: AppColors.mute, fontSize: 12)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Đây là thanh toán giả lập cho bản demo — không trừ tiền thật, '
              'không cần tài khoản ngân hàng hay merchant thật.',
              style: TextStyle(fontSize: 12.5, color: AppColors.greenDark),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _confirmPaid,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _paying ? 'Đang xử lý…' : 'Tôi đã thanh toán',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Để sau (thanh toán từ chi tiết đơn)'),
          ),
        ],
      ),
    );
  }
}

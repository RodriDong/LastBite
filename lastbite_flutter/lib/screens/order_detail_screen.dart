import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/chat.dart';
import '../models/mock_data.dart';
import '../models/order.dart';
import '../services/chat_service.dart';
import '../services/complaint_service.dart';
import '../services/order_service.dart';
import '../models/payment_method.dart';
import 'mock_payment_screen.dart';
import '../services/review_service.dart';
import 'chat_screen.dart';

/// Chi tiết đơn hàng (bản Hoàn thiện): mã QR, khung giờ nhận, bảng giá
/// (giá gốc → giá đã khóa → đã tiết kiệm), trạng thái, và các hành động
/// theo trạng thái (chat với quán, hủy đơn, đánh giá).
class OrderDetailScreen extends StatefulWidget {
  final FirestoreOrder order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _busy = false;

  String get _statusLabel {
    switch (widget.order.status) {
      case 'PENDING':
        return 'Đang chờ lấy';
      case 'COMPLETED':
        return 'Đã nhận hàng';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return widget.order.status;
    }
  }

  Color get _statusColor {
    switch (widget.order.status) {
      case 'COMPLETED':
        return AppColors.green;
      case 'CANCELLED':
        return AppColors.hot;
      default:
        return AppColors.price;
    }
  }

  Future<void> _openChat() async {
    try {
      final threadId = await ChatService.ensureThread(
        storeId: widget.order.storeId,
        storeName: widget.order.storeName,
      );
      if (!mounted) return;
      final uid = ChatService.myUid ?? '';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            thread: ChatThread(
              id: threadId,
              buyerUid: uid,
              buyerName: '',
              storeId: widget.order.storeId,
              storeName: widget.order.storeName,
              lastMessage: '',
              lastAt: null,
              buyerUnread: 0,
              sellerUnread: 0,
            ),
            asSeller: false,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không mở được chat: $e')),
      );
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hủy đơn này?'),
        content: const Text(
            'Suất sẽ được trả lại quầy cho khách khác. Bạn vẫn có thể đặt lại sau.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ đơn'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await OrderService.cancelOrder(widget.order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã hủy đơn.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review() async {
    int stars = 5;
    final commentCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Đánh giá suất ăn'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setDialogState(() => stars = i + 1),
                    child: Text(
                      i < stars ? '★' : '☆',
                      style: const TextStyle(
                        fontSize: 32,
                        color: AppColors.price,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Suất ăn thế nào, đóng gói ra sao...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Để sau'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Gửi đánh giá'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ReviewService.submit(
        orderId: widget.order.id,
        rating: stars,
        comment: commentCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cảm ơn đánh giá của bạn!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final saved = o.originalTotal - o.amountPaid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
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
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(o.dealIcon, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.dealTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            o.storeName,
                            style: const TextStyle(
                              color: AppColors.mute,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        _statusLabel,
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                _row('Số lượng', '× ${o.quantity}'),
                _row('Khung giờ nhận', o.pickupSlot),
                _row('Thanh toán',
                    o.paymentMethod == 'gift'
                        ? 'Tặng miễn phí'
                        : o.paymentStatus == 'PAID'
                            ? 'Đã thanh toán qua ${PaymentMethod.byId(o.paymentMethod).name}'
                        : o.paymentStatus == 'REFUNDED'
                            ? 'Đã hoàn tiền'
                            : o.paymentStatus == 'PAID_ON_PICKUP'
                                ? 'Đã trả khi nhận'
                                : 'Chờ thanh toán'),
                const SizedBox(height: 8),
                _row('Giá gốc',
                    AppData.formatVnd(o.originalTotal), muted: true),
                _row('Giá đã khóa',
                    AppData.formatVnd(o.totalLockedPrice),
                    bold: true),
                _row('Bạn đã tiết kiệm', AppData.formatVnd(saved),
                    bold: true, valueColor: AppColors.greenDark),
                if (o.voucherDiscount > 0) ...[
                  _row('Ưu đãi đã dùng',
                      '-${AppData.formatVnd(o.voucherDiscount)}'),
                  _row('Thực trả khi nhận',
                      AppData.formatVnd(o.amountPaid),
                      bold: true),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (o.status == 'PENDING' && o.paymentStatus == 'UNPAID') ...[
            GestureDetector(
              onTap: _payNow,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Thanh toán ngay — ${AppData.formatVnd(o.amountPaid > 0 ? o.amountPaid : o.totalLockedPrice)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 16),
          if (o.status == 'PENDING') ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  const Text(
                    'Đưa mã này cho quán khi nhận hàng',
                    style: TextStyle(color: AppColors.mute, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  QrImageView(data: o.pickupCode, size: 180),
                  const SizedBox(height: 12),
                  Text(
                    o.pickupCode,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _openChat,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              child: const Text('Chat với quán',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          if (o.status == 'PENDING')
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _busy ? null : _cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.hot,
                  side: const BorderSide(color: AppColors.hot),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                child: const Text('Hủy đơn'),
              ),
            ),
          if (o.status == 'COMPLETED' && !o.reviewed) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _review,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.greenDark,
                  side: const BorderSide(color: AppColors.greenDark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                child: const Text('Đánh giá suất ăn này'),
              ),
            ),
          ],
          if (o.status == 'COMPLETED') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _complaint,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.hot,
                  side: const BorderSide(color: AppColors.hot),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                child: const Text('Báo cáo vấn đề'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Khiếu nại đơn đã nhận (BMC "đổi trả, xử lý khiếu nại").
  Future<void> _complaint() async {
    const reasons = ['Chất lượng món', 'Sai món', 'Vệ sinh', 'Khác'];
    var reason = reasons[0];
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Báo cáo vấn đề'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: reason,
                isExpanded: true,
                items: reasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setD(() => reason = v ?? reasons[0]),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Chi tiết (không bắt buộc)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Gửi'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ComplaintService.reportComplaint(
          widget.order.id, reason, noteCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã gửi khiếu nại, quán sẽ xử lý và báo lại bạn.'),
            backgroundColor: AppColors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  /// Thanh toán bù cho đơn PENDING+UNPAID: xong thì pop về danh sách
  /// (danh sách nghe stream nên tự tươi trạng thái mới).
  Future<void> _payNow() async {
    final o = widget.order;
    final amount = o.amountPaid > 0 ? o.amountPaid : o.totalLockedPrice;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MockPaymentScreen(
          orderId: o.id,
          amount: amount,
          method: PaymentMethod.byId(o.paymentMethod),
          onPaid: (ctx) {
            Navigator.pop(ctx);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  Widget _row(String label, String value,
      {bool muted = false, bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: muted ? AppColors.mute : AppColors.ink,
                  fontSize: 13.5)),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13.5,
                color: valueColor,
              )),
        ],
      ),
    );
  }
}

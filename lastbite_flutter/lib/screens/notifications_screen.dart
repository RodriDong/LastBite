import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import '../models/order.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'order_detail_screen.dart';

/// Trung tâm thông báo (bản Hoàn thiện): đơn mới/hủy/hoàn thành,
/// đánh giá mới, kết quả duyệt chứng nhận. Bấm vào thông báo đơn hàng
/// để mở chi tiết đơn; bấm "Đã đọc tất cả" để xóa badge.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    try {
      _sub = NotificationService.stream().listen((list) {
        if (mounted) setState(() => _items = list);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'order_new':
        return Icons.receipt_long;
      case 'order_cancelled':
        return Icons.cancel_outlined;
      case 'order_completed':
        return Icons.check_circle_outline;
      case 'review_new':
        return Icons.star_border;
      case 'cert_result':
        return Icons.verified_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Future<void> _open(AppNotification n) async {
    try {
      await NotificationService.markRead(n.id);
    } catch (_) {}
    if (!mounted) return;
    if (n.orderId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(n.orderId)
            .get();
        if (!mounted) return;
        if (doc.exists) {
          final order = FirestoreOrder.fromFirestore(doc);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(order: order),
            ),
          );
          return;
        }
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được đơn hàng này nữa.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.read).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                try {
                  await NotificationService.markAllRead();
                } catch (_) {}
              },
              child: const Text(
                'Đã đọc tất cả',
                style: TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ),
        ],
      ),
      body: _items.isEmpty
          ? LTheme.emptyState(
              emoji: '🔔',
              title: 'Chưa có thông báo nào',
              subtitle:
                  'Khi đơn hàng thay đổi, có đánh giá mới hay chứng nhận được duyệt, thông báo sẽ hiện ở đây.',
            )
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.line),
              itemBuilder: (context, i) {
                final n = _items[i];
                return ListTile(
                  tileColor:
                      n.read ? AppColors.card : AppColors.greenLight,
                  leading: Icon(
                    _iconFor(n.type),
                    color: AppColors.greenDark,
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight:
                          n.read ? FontWeight.w600 : FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    n.body,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: n.read
                      ? null
                      : Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: AppColors.hot,
                            shape: BoxShape.circle,
                          ),
                        ),
                  onTap: () => _open(n),
                );
              },
            ),
    );
  }
}

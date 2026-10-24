import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';

/// Thông báo trong app (bản Hoàn thiện): server ghi doc vào `notifications`
/// mỗi khi đơn đổi trạng thái, có đánh giá mới, hoặc chứng nhận được duyệt.
/// Cần composite index notifications(userId ASC, createdAt DESC).
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? orderId;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.orderId,
    required this.read,
    this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final ts = d['createdAt'];
    return AppNotification(
      id: doc.id,
      type: (d['type'] ?? '').toString(),
      title: (d['title'] ?? '').toString(),
      body: (d['body'] ?? '').toString(),
      orderId: (d['orderId'] as String?)?.isNotEmpty == true
          ? d['orderId'] as String
          : null,
      read: d['read'] == true,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class NotificationService {
  NotificationService._();

  static final _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Stream<List<AppNotification>> stream() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(AppNotification.fromDoc).toList());
  }

  static Stream<int> unreadCount() {
    return stream().map((list) => list.where((n) => !n.read).length);
  }

  static Future<void> markRead(String id) async {
    await ApiService.post('/api/markNotificationsRead', {
      'notificationId': id,
    });
  }

  static Future<void> markAllRead() async {
    await ApiService.post('/api/markNotificationsRead', {});
  }
}

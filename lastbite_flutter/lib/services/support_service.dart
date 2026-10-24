import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';

/// Yêu cầu hỗ trợ (CSKH, BMC): người dùng gửi, admin trả lời + đóng.
class SupportTicket {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String status; // open | closed
  final String? adminReply;
  final DateTime? createdAt;

  const SupportTicket({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.status,
    required this.adminReply,
    required this.createdAt,
  });

  static DateTime? _asDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory SupportTicket.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return SupportTicket(
      id: doc.id,
      userId: (d['userId'] ?? '').toString(),
      title: (d['title'] ?? '').toString(),
      message: (d['message'] ?? '').toString(),
      status: (d['status'] ?? '').toString(),
      adminReply: d['adminReply']?.toString(),
      createdAt: _asDate(d['createdAt']),
    );
  }
}

List<SupportTicket> _sortedTickets(List<SupportTicket> list) {
  list.sort((a, b) {
    final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bt.compareTo(at);
  });
  return list;
}

class SupportService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> createTicket(String title, String message) async {
    await ApiService.post(
        '/api/createSupportTicket', {'title': title, 'message': message});
  }

  static Future<void> replyTicket(String id, String reply) async {
    await ApiService.post(
        '/api/replySupportTicket', {'ticketId': id, 'reply': reply});
  }

  static Stream<List<SupportTicket>> myTickets(String uid) {
    return _db
        .collection('supportTickets')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) => _sortedTickets(s.docs.map(SupportTicket.fromDoc).toList()));
  }

  static Stream<List<SupportTicket>> openTickets() {
    return _db
        .collection('supportTickets')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((s) => _sortedTickets(s.docs.map(SupportTicket.fromDoc).toList()));
  }
}

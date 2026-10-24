import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';

/// Khiếu nại (BMC "đổi trả, xử lý khiếu nại"): buyer báo, quán/admin xử lý.
class Complaint {
  final String id;
  final String orderId;
  final String buyerId;
  final String storeId;
  final String dealTitle;
  final String reason;
  final String note;
  final String status; // open | resolved
  final String? resolution;
  final DateTime? createdAt;

  const Complaint({
    required this.id,
    required this.orderId,
    required this.buyerId,
    required this.storeId,
    required this.dealTitle,
    required this.reason,
    required this.note,
    required this.status,
    required this.resolution,
    required this.createdAt,
  });

  static DateTime? _asDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory Complaint.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return Complaint(
      id: doc.id,
      orderId: (d['orderId'] ?? '').toString(),
      buyerId: (d['buyerId'] ?? '').toString(),
      storeId: (d['storeId'] ?? '').toString(),
      dealTitle: (d['dealTitle'] ?? '').toString(),
      reason: (d['reason'] ?? '').toString(),
      note: (d['note'] ?? '').toString(),
      status: (d['status'] ?? '').toString(),
      resolution: d['resolution']?.toString(),
      createdAt: _asDate(d['createdAt']),
    );
  }
}

List<Complaint> _sortedComplaints(List<Complaint> list) {
  list.sort((a, b) {
    final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bt.compareTo(at);
  });
  return list;
}

class ComplaintService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> reportComplaint(
      String orderId, String reason, String note) async {
    await ApiService.post('/api/reportComplaint',
        {'orderId': orderId, 'reason': reason, 'note': note});
  }

  static Future<void> resolveComplaint(
      String id, String resolution) async {
    await ApiService.post('/api/resolveComplaint',
        {'complaintId': id, 'resolution': resolution});
  }

  static Stream<List<Complaint>> storeComplaints(String storeId) {
    return _db
        .collection('complaints')
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map((s) => _sortedComplaints(s.docs.map(Complaint.fromDoc).toList()));
  }

  static Stream<List<Complaint>> allComplaints() {
    return _db
        .collection('complaints')
        .snapshots()
        .map((s) => _sortedComplaints(s.docs.map(Complaint.fromDoc).toList()));
  }
}

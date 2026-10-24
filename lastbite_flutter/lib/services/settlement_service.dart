import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';

/// Đối soát hoa hồng (BMC): quán báo đã chuyển khoản, admin duyệt trừ nợ.
class Settlement {
  final String id;
  final String storeId;
  final int amount;
  final String status; // pending | approved | rejected
  final String? reviewNote;
  final DateTime? createdAt;

  const Settlement({
    required this.id,
    required this.storeId,
    required this.amount,
    required this.status,
    required this.reviewNote,
    required this.createdAt,
  });

  static int _asInt(dynamic v, int f) => v is num ? v.round() : f;
  static DateTime? _asDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory Settlement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return Settlement(
      id: doc.id,
      storeId: (d['storeId'] ?? '').toString(),
      amount: _asInt(d['amount'], 0),
      status: (d['status'] ?? '').toString(),
      reviewNote: d['reviewNote']?.toString(),
      createdAt: _asDate(d['createdAt']),
    );
  }
}

class Ledger {
  final int recorded;
  final int paid;
  const Ledger({required this.recorded, required this.paid});
  int get owed => recorded - paid;
}

List<Settlement> _sortedSettlements(List<Settlement> list) {
  list.sort((a, b) {
    final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bt.compareTo(at);
  });
  return list;
}

class SettlementService {
  static final _db = FirebaseFirestore.instance;

  /// Sổ công nợ: tổng hoa hồng dailyStats - tổng đã duyệt.
  static Future<Ledger> loadLedger(String storeId) async {
    final stats = await _db
        .collection('stores')
        .doc(storeId)
        .collection('dailyStats')
        .get();
    var recorded = 0;
    for (final d in stats.docs) {
      recorded += (d.data()['commission'] as num?)?.round() ?? 0;
    }
    final paidDocs = await _db
        .collection('stores')
        .doc(storeId)
        .collection('settlements')
        .where('status', isEqualTo: 'approved')
        .get();
    var paid = 0;
    for (final d in paidDocs.docs) {
      paid += (d.data()['amount'] as num?)?.round() ?? 0;
    }
    return Ledger(recorded: recorded, paid: paid);
  }

  static Stream<List<Settlement>> mySettlements(String storeId) {
    return _db
        .collection('stores')
        .doc(storeId)
        .collection('settlements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Settlement.fromDoc).toList());
  }

  static Stream<List<Settlement>> pendingSettlements() {
    return _db
        .collectionGroup('settlements')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => _sortedSettlements(
            s.docs.map((d) {
              final data = d.data() as Map<String, dynamic>? ?? {};
              final storeId = d.reference.parent.parent?.id ?? '';
              return Settlement(
                id: d.id,
                storeId: storeId,
                amount: (data['amount'] as num?)?.round() ?? 0,
                status: (data['status'] ?? '').toString(),
                reviewNote: data['reviewNote']?.toString(),
                createdAt: data['createdAt'] is Timestamp
                    ? (data['createdAt'] as Timestamp).toDate()
                    : null,
              );
            }).toList()));
  }

  static Future<void> reportSettlement(int amount) async {
    await ApiService.post('/api/reportSettlement', {'amount': amount});
  }

  static Future<void> confirmSettlement(
      String storeId, String id, bool approve, String note) async {
    await ApiService.post('/api/confirmSettlement', {
      'storeId': storeId,
      'settlementId': id,
      'approve': approve,
      'note': note,
    });
  }

  /// Gia hạn gian hàng 1 tháng — 99.000đ (giả lập, không cần admin duyệt).
  static Future<void> renewShopFee() async {
    await ApiService.post('/api/renewShopFee', {});
  }
}

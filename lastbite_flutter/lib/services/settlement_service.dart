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

/// Giai đoạn phí gian hàng (Gói Túi + Phí) — cùng mốc với server
/// (pricing.ts), "tháng" tính tròn 30 ngày:
///   GĐ1: tuổi < 60 ngày  → phí 0đ, hoa hồng 5%
///   GĐ2: 60 ≤ tuổi < 180 → phí 99.000đ/tháng, hoa hồng 10%
///   GĐ3: tuổi ≥ 180 ngày → phí 149.000đ/tháng, hoa hồng 10%
/// Quán chưa có ngày tạo (dữ liệu cũ) tính như GĐ3, khớp server.
class FeeStage {
  FeeStage._();

  static int stageOf(DateTime? createdAt, DateTime now) {
    if (createdAt == null) return 3;
    final ageDays = now.difference(createdAt).inDays;
    if (ageDays < 60) return 1;
    if (ageDays < 180) return 2;
    return 3;
  }

  static int amountForStage(int stage) {
    if (stage == 2) return 99000;
    if (stage == 3) return 149000;
    return 0;
  }

  static int commissionPercentForStage(int stage) =>
      stage == 1 ? 5 : 10;

  static String nameForStage(int stage) => 'Giai đoạn $stage';

  /// Toàn bộ biểu phí — hiện ở dialog gia hạn để quán biết trước
  /// cả lộ trình, không bị tăng giá bất ngờ.
  static const String scheduleText =
      'Biểu phí gian hàng:\n'
      '• Giai đoạn 1 (2 tháng đầu): miễn phí + hoa hồng 5%.\n'
      '• Giai đoạn 2 (tháng 3–6): 99.000đ/tháng + hoa hồng 10%.\n'
      '• Giai đoạn 3 (từ tháng 7): 149.000đ/tháng + hoa hồng 10%.';
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

  /// Gia hạn gian hàng 1 tháng (giả lập, không cần admin duyệt).
  /// Số tiền theo giai đoạn lúc gia hạn (server chốt): GĐ2 = 99.000đ,
  /// GĐ3 = 149.000đ; GĐ1 đang miễn phí thì server báo lỗi.
  /// Trả về map của server ({feeExpiresAt, stage, amount}).
  static Future<Map<String, dynamic>> renewShopFee() async {
    return await ApiService.post('/api/renewShopFee', {});
  }
}

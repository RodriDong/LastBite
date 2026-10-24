import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';

/// Quảng bá (BMC "phí ưu tiên hiển thị"): quán đăng ký, admin duyệt,
/// suất lên băng chuyền Nổi bật ở trang chủ trong N ngày.
class Promotion {
  final String id;
  final String storeId;
  final String dealId;
  final int days;
  final int fee;
  final String status; // pending | active | rejected
  final DateTime? endAt;
  final DateTime? createdAt;
  final String? reviewNote;

  const Promotion({
    required this.id,
    required this.storeId,
    required this.dealId,
    required this.days,
    required this.fee,
    required this.status,
    required this.endAt,
    required this.createdAt,
    required this.reviewNote,
  });

  static int _asInt(dynamic v, int f) => v is num ? v.round() : f;
  static DateTime? _asDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory Promotion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return Promotion(
      id: doc.id,
      storeId: (d['storeId'] ?? '').toString(),
      dealId: (d['dealId'] ?? '').toString(),
      days: _asInt(d['days'], 1),
      fee: _asInt(d['fee'], 0),
      status: (d['status'] ?? '').toString(),
      endAt: _asDate(d['endAt']),
      createdAt: _asDate(d['createdAt']),
      reviewNote: d['reviewNote']?.toString(),
    );
  }

  bool get isActiveNow =>
      status == 'active' && endAt != null && endAt!.isAfter(DateTime.now());
}

List<Promotion> _sorted(List<Promotion> list) {
  list.sort((a, b) {
    final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bt.compareTo(at);
  });
  return list;
}

class PromotionService {
  static final _db = FirebaseFirestore.instance;

  /// Id các deal đang được quảng bá (lọc hết hạn ở client, không cần cron).
  static Stream<Set<String>> activeDealIds() {
    return _db
        .collection('promotions')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((s) => s.docs
            .map(Promotion.fromDoc)
            .where((p) => p.isActiveNow)
            .map((p) => p.dealId)
            .toSet());
  }

  static Stream<List<Promotion>> myPromotions(String storeId) {
    return _db
        .collection('promotions')
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map((s) => _sorted(s.docs.map(Promotion.fromDoc).toList()));
  }

  static Stream<List<Promotion>> pendingPromotions() {
    return _db
        .collection('promotions')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => _sorted(s.docs.map(Promotion.fromDoc).toList()));
  }

  static Future<void> requestPromotion(String dealId, int days) async {
    await ApiService.post(
        '/api/requestPromotion', {'dealId': dealId, 'days': days});
  }

  static Future<void> reviewPromotion(
      String id, bool approve, String note) async {
    await ApiService.post('/api/reviewPromotion',
        {'promotionId': id, 'approve': approve, 'note': note});
  }
}

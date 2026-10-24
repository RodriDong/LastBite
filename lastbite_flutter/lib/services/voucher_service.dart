import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';

/// Ưu đãi đổi điểm xanh (bản Hoàn thiện): nằm ở
/// users/{uid}/vouchers, chỉ server ghi (rules khóa write phía client).
class Voucher {
  final String id;
  final String tier;
  final int amount;
  final int minOrder;
  final String status; // unused | used
  final DateTime? expiresAt;

  const Voucher({
    required this.id,
    required this.tier,
    required this.amount,
    required this.minOrder,
    required this.status,
    required this.expiresAt,
  });

  static int _asInt(dynamic v, int f) => v is num ? v.round() : f;
  static DateTime? _asDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory Voucher.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return Voucher(
      id: doc.id,
      tier: (d['tier'] ?? '').toString(),
      amount: _asInt(d['amount'], 0),
      minOrder: _asInt(d['minOrder'], 0),
      status: (d['status'] ?? '').toString(),
      expiresAt: _asDate(d['expiresAt']),
    );
  }

  bool get isUsable {
    if (status != 'unused') return false;
    if (expiresAt == null) return false;
    return expiresAt!.isAfter(DateTime.now());
  }
}

class VoucherService {
  static Stream<List<Voucher>> myVouchers(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('vouchers')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Voucher.fromDoc).toList());
  }

  static Future<void> exchange(String tier) async {
    await ApiService.post('/api/exchangeVoucher', {'tier': tier});
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Thống kê theo ngày của một cửa hàng (`stores/{storeId}/dailyStats/{yyyyMMdd}`),
/// do Cloud Function `confirmPickup` ghi khi đơn hoàn thành. Khóa ngày theo
/// Asia/Ho_Chi_Minh (xem functions/src/orders.ts `dailyStatsKey`).
class DailyStat {
  final String dayKey; // yyyyMMdd
  final int revenue;
  final int orders;
  final int commission;
  final int rescuedMeals;

  const DailyStat({
    required this.dayKey,
    this.revenue = 0,
    this.orders = 0,
    this.commission = 0,
    this.rescuedMeals = 0,
  });

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return 0;
  }

  factory DailyStat.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return DailyStat(
      dayKey: doc.id,
      revenue: _asInt(d['revenue']),
      orders: _asInt(d['orders']),
      commission: _asInt(d['commission']),
      rescuedMeals: _asInt(d['rescuedMeals']),
    );
  }

  /// Ngày của bản ghi (giờ địa phương) để vẽ biểu đồ/nhãn thứ.
  DateTime get date {
    final y = int.tryParse(dayKey.substring(0, 4)) ?? 1970;
    final m = int.tryParse(dayKey.substring(4, 6)) ?? 1;
    final d = int.tryParse(dayKey.substring(6, 8)) ?? 1;
    return DateTime(y, m, d);
  }
}

/// Đọc dailyStats của cửa hàng (chỉ chủ cửa hàng đọc được — xem firestore.rules).
class StatsService {
  StatsService._();

  /// Khóa ngày hôm nay dạng yyyyMMdd theo giờ máy (máy demo ở VN nên
  /// trùng Asia/Ho_Chi_Minh — cùng khóa mà server dùng).
  static String dayKeyOf(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}$mm$dd';
  }

  static String todayKey() => dayKeyOf(DateTime.now());

  /// Stream tối đa [days] ngày gần nhất, mới nhất trước.
  static Stream<List<DailyStat>> recentStats(String storeId, {int days = 30}) {
    if (storeId.isEmpty) return Stream.value(const []);
    return FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('dailyStats')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(days)
        .snapshots()
        .map((s) => s.docs.map(DailyStat.fromDoc).toList());
  }

  /// Stream thống kê của riêng hôm nay (cho ô "Hôm nay" ở tab Tổng quan).
  static Stream<DailyStat> todayStats(String storeId) {
    final key = todayKey();
    if (storeId.isEmpty) return Stream.value(DailyStat(dayKey: key));
    return FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('dailyStats')
        .doc(key)
        .snapshots()
        .map((s) => s.exists ? DailyStat.fromDoc(s) : DailyStat(dayKey: key));
  }
}

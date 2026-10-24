import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';

/// Đánh giá của buyer cho 1 đơn đã hoàn thành (collection `reviews`,
/// doc id = orderId — 1 đơn 1 đánh giá). Xem docs/firestore-schema.md.
///
/// Ghi CHỈ qua API `submitReview` của server (nó còn cập nhật điểm
/// trung bình của cửa hàng trong cùng transaction). Client chỉ đọc.
class StoreReview {
  final String orderId;
  final String storeId;
  final String buyerName;
  final int rating; // 1..5
  final String comment;
  final DateTime? createdAt;

  const StoreReview({
    required this.orderId,
    required this.storeId,
    required this.buyerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  static StoreReview fromFirestore(Map<String, dynamic> d) {
    final ts = d['createdAt'];
    return StoreReview(
      orderId: (d['orderId'] ?? '').toString(),
      storeId: (d['storeId'] ?? '').toString(),
      buyerName: (d['buyerName'] ?? '').toString(),
      rating: (d['rating'] as num?)?.round() ?? 0,
      comment: (d['comment'] ?? '').toString(),
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class ReviewService {
  ReviewService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Gửi đánh giá cho 1 đơn COMPLETED của mình. Ném ApiException
  /// (message tiếng Việt) khi lỗi — VD đơn đã được đánh giá.
  static Future<void> submit({
    required String orderId,
    required int rating,
    String comment = '',
  }) async {
    await ApiService.post('/api/submitReview', {
      'orderId': orderId,
      'rating': rating,
      'comment': comment,
    });
  }

  /// Các đánh giá mới nhất của 1 cửa hàng (đọc 1 lần cho trang chi tiết
  /// deal — cố ý không stream để tránh vòng lặp rebuild ở màn hình có
  /// đồng hồ đếm ngược; cần composite index reviews(storeId, createdAt)).
  static Future<List<StoreReview>> recentForStore(
    String storeId, {
    int limit = 5,
  }) async {
    if (storeId.isEmpty) return const [];
    final snap = await _db
        .collection('reviews')
        .where('storeId', isEqualTo: storeId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => StoreReview.fromFirestore(d.data())).toList();
  }
}

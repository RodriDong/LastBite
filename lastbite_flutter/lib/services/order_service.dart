import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order.dart';

/// Đọc đơn từ Firestore + gọi các callable order của Phase 4.
///
/// - Buyer: [myOrders] — stream đơn của mình theo trạng thái;
///   [createOrder] / [cancelOrder] gọi Cloud Functions.
/// - Seller: [storeOrders], [storePendingCount] — stream đơn của cửa hàng;
///   [confirmPickup] xác nhận giao qua pickupCode.
///
/// Mọi ghi nghiệp vụ đi qua Cloud Functions (client không ghi trực tiếp,
/// đúng Security Rules). Functions ở region asia-southeast1.
class OrderService {
  OrderService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get myUid => FirebaseAuth.instance.currentUser?.uid;

  /// Stream đơn của buyer đang đăng nhập theo [status]
  /// ('PENDING' | 'COMPLETED' | 'CANCELLED'), mới nhất trước.
  /// Dùng composite index orders(buyerId, status, createdAt DESC).
  static Stream<List<FirestoreOrder>> myOrders(String status) {
    final uid = myUid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('orders')
        .where('buyerId', isEqualTo: uid)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FirestoreOrder.fromFirestore).toList());
  }

  /// Stream đơn của một cửa hàng theo [status], mới nhất trước.
  /// Dùng composite index orders(storeId, status, createdAt DESC).
  static Stream<List<FirestoreOrder>> storeOrders(
    String storeId,
    String status,
  ) {
    if (storeId.isEmpty) return Stream.value(const []);
    return _db
        .collection('orders')
        .where('storeId', isEqualTo: storeId)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FirestoreOrder.fromFirestore).toList());
  }

  /// Số đơn PENDING của cửa hàng (cho thẻ "Cần xử lý" ở tab Tổng quan).
  static Stream<int> storePendingCount(String storeId) {
    return storeOrders(storeId, 'PENDING').map((list) => list.length);
  }

  /// Đặt deal. Server khóa giá + trừ kho + sinh pickupCode.
  /// Trả về map kết quả của function (orderId, pickupCode,
  /// unitLockedPrice, totalLockedPrice, discountPercent, saleEndAt).
  /// Ném ApiException (message tiếng Việt) khi lỗi.
  static Future<Map<String, dynamic>> createOrder({
    required String dealId,
    required int quantity,
    required String pickupSlot,
    String? voucherId,
    String paymentMethod = 'vietqr',
  }) async {
    return ApiService.post('/api/createOrder', {
      'dealId': dealId,
      'quantity': quantity,
      'pickupSlot': pickupSlot,
      'paymentMethod': paymentMethod,
      if (voucherId != null && voucherId.isNotEmpty) 'voucherId': voucherId,
    });
  }

  /// Xác nhận thanh toán GIẢ LẬP (server chỉ chuyển trạng thái sang PAID).
  static Future<void> confirmFakePayment(String orderId) async {
    await ApiService.post('/api/confirmFakePayment', {'orderId': orderId});
  }

  /// Buyer hủy đơn PENDING của mình (server hoàn kho).
  static Future<void> cancelOrder(String orderId) async {
    await ApiService.post('/api/cancelOrder', {'orderId': orderId});
  }

  /// Seller xác nhận giao hàng: đơn COMPLETED + ghi nhận thanh toán
  /// khi nhận + hoa hồng 10%. Trả về map (orderId, totalLockedPrice,
  /// commissionAmount).
  static Future<Map<String, dynamic>> confirmPickup(String pickupCode) async {
    return ApiService.post('/api/confirmPickup', {'pickupCode': pickupCode});
  }
}

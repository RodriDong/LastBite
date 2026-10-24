import 'package:cloud_firestore/cloud_firestore.dart';

/// Đơn hàng trong Firestore (collection `orders`) — xem
/// docs/firestore-schema.md §4.
///
/// Khác model mock `OrderModel` ở mock_data.dart: đơn này có các field
/// denormalize (dealTitle, dealIcon, storeName, saleEndAt) do Cloud
/// Function `createOrder` ghi sẵn để màn Đơn hàng hiển thị trực tiếp.
class FirestoreOrder {
  final String id;
  final String dealId;
  final String storeId;
  final String buyerId;
  final String buyerName;
  final String dealTitle;
  final String dealIcon;
  final String storeName;
  final int quantity;
  final int unitLockedPrice;
  final int totalLockedPrice;
  final int originalTotal;
  final String pickupCode;
  final String pickupSlot;
  final String status; // PENDING | COMPLETED | CANCELLED
  final String paymentStatus; // UNPAID | PAID | REFUNDED (PAID_ON_PICKUP: đơn cũ thời tiền mặt)
  final String paymentMethod; // momo | vnpay | zalopay | payos | vietqr
  final int commissionAmount;
  final int voucherDiscount;
  final int amountPaid;
  final DateTime? saleEndAt;
  final DateTime? createdAt;
  final DateTime? completedAt;

  /// Phase 6: buyer đã đánh giá đơn này chưa + số sao đã cho
  /// (do API submitReview ghi; reviewed=false khi chưa đánh giá).
  final bool reviewed;
  final int reviewRating;

  const FirestoreOrder({
    required this.id,
    required this.dealId,
    required this.storeId,
    required this.buyerId,
    required this.buyerName,
    required this.dealTitle,
    required this.dealIcon,
    required this.storeName,
    required this.quantity,
    required this.unitLockedPrice,
    required this.totalLockedPrice,
    required this.originalTotal,
    required this.pickupCode,
    required this.pickupSlot,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod = '',
    required this.commissionAmount,
    this.voucherDiscount = 0,
    this.amountPaid = 0,
    required this.saleEndAt,
    required this.createdAt,
    required this.completedAt,
    this.reviewed = false,
    this.reviewRating = 0,
  });

  static int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.round();
    return fallback;
  }

  static DateTime? _asDate(dynamic v) =>
      v is Timestamp ? v.toDate() : null;

  factory FirestoreOrder.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? <String, dynamic>{};
    return FirestoreOrder(
      id: doc.id,
      dealId: (d['dealId'] ?? '').toString(),
      storeId: (d['storeId'] ?? '').toString(),
      buyerId: (d['buyerId'] ?? '').toString(),
      buyerName: (d['buyerName'] ?? '').toString(),
      dealTitle: (d['dealTitle'] ?? '').toString(),
      dealIcon: (d['dealIcon'] ?? '📦').toString(),
      storeName: (d['storeName'] ?? '').toString(),
      quantity: _asInt(d['quantity'], 1),
      unitLockedPrice: _asInt(d['unitLockedPrice'], 0),
      totalLockedPrice: _asInt(d['totalLockedPrice'], 0),
      originalTotal: _asInt(d['originalTotal'], 0),
      pickupCode: (d['pickupCode'] ?? '').toString(),
      pickupSlot: (d['pickupSlot'] ?? '').toString(),
      status: (d['status'] ?? '').toString(),
      paymentStatus: (d['paymentStatus'] ?? 'UNPAID').toString(),
      paymentMethod: (d['paymentMethod'] ?? '').toString(),
      commissionAmount: _asInt(d['commissionAmount'], 0),
      voucherDiscount: _asInt(d['voucherDiscount'], 0),
      amountPaid: _asInt(
          d['amountPaid'],
          _asInt(d['totalLockedPrice'], 0) -
              _asInt(d['voucherDiscount'], 0)),
      saleEndAt: _asDate(d['saleEndAt']),
      createdAt: _asDate(d['createdAt']),
      completedAt: _asDate(d['completedAt']),
      reviewed: d['reviewed'] == true,
      reviewRating: _asInt(d['reviewRating'], 0),
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isCompleted => status == 'COMPLETED';

  /// Giây còn lại đến hết giờ bán của deal (để hiển thị đếm ngược).
  int get remainingSeconds {
    if (saleEndAt == null) return 0;
    final diff = saleEndAt!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }
}

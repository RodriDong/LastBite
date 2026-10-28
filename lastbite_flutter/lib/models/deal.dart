import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'mock_data.dart';

/// Deal trong Firestore (collection `deals`) — xem docs/firestore-schema.md §3.
///
/// UI vẫn dùng [SurpriseBox] (giữ nguyên 100% thiết kế màn hình);
/// [Deal.toSurpriseBox] là cầu nối: đọc deal từ Firestore rồi chuyển sang
/// model UI mà các màn hình đang dùng.
class Deal {
  final String id;
  final String storeId;
  final String storeName;
  final String storeAddress;
  final double? storeLat;
  final double? storeLng;
  final String title;
  final String description;
  final String icon;
  final String category;
  final String? imageUrl;
  final int originalPrice;
  final int minPrice;
  final int maxDiscountPercent;
  final int remainingQty;
  final int totalQty;
  final DateTime saleEndAt;
  final String pickupWindow;
  final List<String> pickupSlots;
  final String status; // active | paused | expired | soldout
  final bool isGift;
  final DateTime? createdAt;
  // Gói Túi + Phí: 'bag' = túi bất ngờ (giá cố định 50%), 'retail' = lẻ.
  final String dealType;
  final int originalValue;
  final int bagPrice;
  final List<String> possibleCategories;
  final String allergyNote;

  const Deal({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.storeAddress,
    required this.storeLat,
    required this.storeLng,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.imageUrl,
    required this.originalPrice,
    required this.minPrice,
    required this.maxDiscountPercent,
    required this.remainingQty,
    required this.totalQty,
    required this.saleEndAt,
    required this.pickupWindow,
    required this.pickupSlots,
    required this.status,
    required this.createdAt,
    this.isGift = false,
    this.dealType = 'retail',
    this.originalValue = 0,
    this.bagPrice = 0,
    this.possibleCategories = const [],
    this.allergyNote = '',
  });

  static int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return fallback;
  }

  static double? _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return null;
  }

  factory Deal.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? <String, dynamic>{};
    final saleEndAt = d['saleEndAt'];
    return Deal(
      id: doc.id,
      storeId: (d['storeId'] ?? '').toString(),
      storeName: (d['storeName'] ?? '').toString(),
      storeAddress: (d['storeAddress'] ?? '').toString(),
      storeLat: _asDouble(d['storeLat']),
      storeLng: _asDouble(d['storeLng']),
      title: (d['title'] ?? '').toString(),
      description: (d['description'] ?? '').toString(),
      icon: (d['icon'] ?? '📦').toString(),
      category: (d['category'] ?? 'Khác').toString(),
      imageUrl: (d['imageUrl'] as String?)?.isNotEmpty == true
          ? d['imageUrl'] as String
          : null,
      originalPrice: _asInt(d['originalPrice'], 0),
      minPrice: _asInt(d['minPrice'], 0),
      maxDiscountPercent: _asInt(d['maxDiscountPercent'], 60),
      remainingQty: _asInt(d['remainingQty'], 0),
      totalQty: _asInt(d['totalQty'], 0),
      saleEndAt: saleEndAt is Timestamp
          ? saleEndAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      pickupWindow: (d['pickupWindow'] ?? '').toString(),
      pickupSlots: ((d['pickupSlots'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      status: (d['status'] ?? '').toString(),
      isGift: d['isGift'] == true,
      dealType: (d['dealType'] ?? 'retail').toString(),
      originalValue: _asInt(d['originalValue'], _asInt(d['originalPrice'], 0)),
      bagPrice: _asInt(d['bagPrice'], 0),
      possibleCategories: ((d['possibleCategories'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      allergyNote: (d['allergyNote'] ?? '').toString(),
      createdAt:
          d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : null,
    );
  }

  bool get isActive => status == 'active';

  int get remainingSeconds {
    final diff = saleEndAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  bool get isUrgent => remainingSeconds < 7200;

  bool get isBag => dealType == 'bag';

  /// % giảm giá — túi cố định 50%; lẻ theo bảng giờ (cùng công thức
  /// với server pricing.ts), chỉ dùng để PREVIEW; createOrder luôn
  /// tính lại ở server.
  int get currentDiscountPercent {
    if (isBag) return isGift ? 100 : 50;
    final rem = remainingSeconds;
    if (rem > 10800) return 20;
    if (rem > 3600) return 40;
    return maxDiscountPercent;
  }

  /// Giá bán hiện tại: túi = bagPrice cố định; lẻ = làm tròn nghìn
  /// đồng, KHÔNG thấp hơn minPrice (đúng hợp đồng §1).
  int get currentDynamicPrice {
    if (isBag) return bagPrice;
    final factor = (100 - currentDiscountPercent) / 100.0;
    final discounted = ((originalPrice * factor) / 1000).round() * 1000;
    return discounted < minPrice ? minPrice : discounted;
  }

  double get stockRatio =>
      totalQty > 0 ? (remainingQty / totalQty).clamp(0.0, 1.0) : 0.0;

  /// Điểm tham chiếu để ước tính khoảng cách (trung tâm Cầu Giấy —
  /// cùng tọa độ bản đồ mặc định của tab Khám phá).
  static const LatLng _referencePoint = LatLng(21.0368, 105.7900);
  static final Distance _distance = Distance();

  String get distanceKm => distanceKmFrom(_referencePoint);

  /// Khoảng cách tới 1 điểm bất kỳ (Phase 9: vị trí thật của buyer
  /// khi được cấp quyền; mặc định là điểm tham chiếu Cầu Giấy).
  String distanceKmFrom(LatLng point) {
    if (storeLat == null || storeLng == null) return '—';
    final m = _distance(point, LatLng(storeLat!, storeLng!));
    return '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// Chuyển sang model UI mà các màn hình đang dùng (giữ nguyên giao diện).
  SurpriseBox toSurpriseBox({LatLng? from}) {
    return SurpriseBox(
      id: id,
      emoji: icon,
      title: title,
      category: category,
      description: description,
      storeName: storeName,
      storeId: storeId,
      address: storeAddress,
      distanceKm: distanceKmFrom(from ?? _referencePoint),
      imageUrl: imageUrl,
      lat: storeLat ?? _referencePoint.latitude,
      lng: storeLng ?? _referencePoint.longitude,
      originalPrice: originalPrice,
      maxDiscountPercent: maxDiscountPercent,
      remainingQty: remainingQty,
      totalQty: totalQty,
      pickupWindow: pickupWindow,
      pickupSlots: pickupSlots,
      isGift: isGift,
      isBag: isBag,
      bagPrice: bagPrice,
      possibleCategories: possibleCategories,
      allergyNote: allergyNote,
      createdAt: createdAt ?? DateTime.now(),
      expiredAt: saleEndAt,
      isActive: isActive,
    );
  }
}

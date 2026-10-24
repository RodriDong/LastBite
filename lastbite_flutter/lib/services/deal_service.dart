import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/deal.dart';

/// Đọc deal từ Firestore + gọi các callable deal của Phase 3.
///
/// - Người mua: [activeDeals] — stream deal đang bán.
/// - Seller: [storeDeals] — stream deal của cửa hàng mình;
///   [createDeal] / [pauseDeal] gọi Cloud Functions (server validate +
///   ghi qua Admin SDK, client không ghi trực tiếp).
class DealService {
  DealService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// storeId của seller đang đăng nhập.
  /// Demo: 1 seller = 1 cửa hàng, id cửa hàng = uid
  /// (do `grantSellerRole` tạo `stores/{uid}`).
  static String? get myStoreId => FirebaseAuth.instance.currentUser?.uid;

  /// Stream deal đang bán (status=active, chưa hết giờ),
  /// xếp theo giờ kết thúc gần nhất. Dùng composite index
  /// deals(status ASC, saleEndAt ASC) trong firestore.indexes.json.
  static Stream<List<Deal>> activeDeals() {
    return _db
        .collection('deals')
        .where('status', isEqualTo: 'active')
        .where('saleEndAt', isGreaterThan: Timestamp.now())
        .orderBy('saleEndAt')
        .snapshots()
        .map((s) => s.docs.map(Deal.fromFirestore).toList());
  }

  /// Stream deal của một cửa hàng (active + paused), mới nhất trước.
  /// Dùng composite index deals(storeId ASC, status ASC, saleEndAt DESC).
  static Stream<List<Deal>> storeDeals(String storeId) {
    return _db
        .collection('deals')
        .where('storeId', isEqualTo: storeId)
        .where('status', whereIn: ['active', 'paused'])
        .orderBy('saleEndAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Deal.fromFirestore).toList());
  }

  /// Seller đăng deal mới. Server validate theo backend-contract.md §2.4
  /// (saleEndAt tương lai, minPrice ≤ originalPrice, totalQty ≥ 1,
  /// 1 ≤ maxDiscountPercent ≤ 90) và denormalize tên/địa chỉ cửa hàng.
  /// Trả về dealId khi thành công; ném ApiException
  /// (message tiếng Việt) khi không đạt.
  static Future<String> createDeal({
    required String title,
    required int originalPrice,
    required int minPrice,
    required int totalQty,
    required DateTime saleEndAt,
    String description = '',
    String icon = '📦',
    String category = 'Bánh ngọt',
    int maxDiscountPercent = 60,
    String pickupWindow = '',
    List<String> pickupSlots = const [],
    Uint8List? imageBytes,
    bool isGift = false,
  }) async {
    final storeId = myStoreId;
    if (storeId == null || storeId.isEmpty) {
      throw StateError('Chưa đăng nhập.');
    }
    final res = await ApiService.post('/api/createDeal', {
      'storeId': storeId,
      'title': title,
      'description': description,
      'icon': icon,
      'category': category,
      'originalPrice': originalPrice,
      'minPrice': minPrice,
      'maxDiscountPercent': maxDiscountPercent,
      'totalQty': totalQty,
      'saleEndAt': saleEndAt.toUtc().toIso8601String(),
      'pickupWindow': pickupWindow,
      'pickupSlots': pickupSlots,
      'isGift': isGift,
      // Phase 8: ảnh deal (server lưu lên Vercel Blob).
      if (imageBytes != null) 'imageBase64': base64Encode(imageBytes),
    });
    return (res['dealId'] ?? '').toString();
  }

  /// Phase 8: chọn ảnh cho deal (nén giống ảnh chứng nhận Phase 7).
  /// Null khi người dùng hủy chọn.
  static Future<Uint8List?> pickDealImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > 2500000) {
      throw const ApiException(
        'invalid-argument',
        'Ảnh quá lớn sau khi nén. Hãy chọn ảnh khác nhỏ hơn.',
      );
    }
    return bytes;
  }

  /// Seller tắt (paused=true) / mở lại (paused=false) deal của mình.
  static Future<void> pauseDeal({
    required String dealId,
    required bool paused,
  }) async {
    await ApiService.post('/api/pauseDeal', {'dealId': dealId, 'paused': paused});
  }

  /// Seller sửa deal đang bán/tạm dừng (bản Hoàn thiện): chỉ tên, mô tả,
  /// danh mục, ảnh. Giá/số lượng/giờ bán không sửa được (đã khóa theo
  /// đơn đang chờ) — muốn đổi thì tắt deal cũ và đăng deal mới.
  static Future<void> updateDeal({
    required String dealId,
    String? title,
    String? description,
    String? category,
    Uint8List? imageBytes,
  }) async {
    await ApiService.post('/api/updateDeal', {
      'dealId': dealId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (imageBytes != null) 'imageBase64': base64Encode(imageBytes),
    });
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

/// Hồ sơ cửa hàng (document stores/{storeId}) — xem docs/firestore-schema.md.
///
/// Đọc trực tiếp Firestore (rules cho đọc công khai). Ghi CHỈ qua API
/// `updateStoreProfile` của server — rules chặn client ghi trực tiếp.
class StoreProfile {
  final String id;
  final String name;
  final String address;
  final String? phone;
  final String? openHours;

  /// Điểm trung bình (0 khi chưa có đánh giá nào).
  final double rating;
  final int ratingCount;
  final bool isApproved;

  /// Phase 7 — giấy chứng nhận an toàn thực phẩm:
  /// certStatus: 'none' | 'pending' | 'approved' | 'rejected'.
  final String certStatus;
  final String? certUrl;
  final String? certReviewNote;

  /// Phí duy trì gian hàng (BMC): hạn duy trì + trạng thái.
  final DateTime? feeExpiresAt;
  final String feeStatus;

  const StoreProfile({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.openHours,
    required this.rating,
    required this.ratingCount,
    required this.isApproved,
    required this.certStatus,
    required this.certUrl,
    required this.certReviewNote,
    required this.feeExpiresAt,
    required this.feeStatus,
  });

  static StoreProfile fromFirestore(
    String id,
    Map<String, dynamic> d,
  ) {
    return StoreProfile(
      id: id,
      name: (d['name'] ?? '').toString(),
      address: (d['address'] ?? '').toString(),
      phone: d['phone']?.toString(),
      openHours: d['openHours']?.toString(),
      rating: (d['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (d['ratingCount'] as num?)?.round() ?? 0,
      isApproved: d['isApproved'] == true,
      certStatus: (d['certStatus'] ?? 'none').toString(),
      certUrl: d['certUrl']?.toString(),
      certReviewNote: d['certReviewNote']?.toString(),
      feeExpiresAt: d['feeExpiresAt'] is Timestamp
          ? (d['feeExpiresAt'] as Timestamp).toDate()
          : null,
      feeStatus: (d['feeStatus'] ?? '').toString(),
    );
  }
}

class StoreService {
  StoreService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// storeId của seller đang đăng nhập (= uid theo thiết kế 1 seller = 1 quán).
  static String? get myStoreId => FirebaseAuth.instance.currentUser?.uid;

  /// Stream hồ sơ cửa hàng của seller hiện tại (null khi chưa có doc).
  static Stream<StoreProfile?> myStore() {
    final id = myStoreId;
    if (id == null) return Stream.value(null);
    return _db.collection('stores').doc(id).snapshots().map(
          (s) => s.exists
              ? StoreProfile.fromFirestore(s.id, s.data() ?? {})
              : null,
        );
  }

  /// Đọc 1 lần hồ sơ của 1 cửa hàng bất kỳ (trang chi tiết deal).
  static Future<StoreProfile?> getStore(String storeId) async {
    if (storeId.isEmpty) return null;
    final s = await _db.collection('stores').doc(storeId).get();
    if (!s.exists) return null;
    return StoreProfile.fromFirestore(s.id, s.data() ?? {});
  }

  /// Cập nhật hồ sơ cửa hàng của mình qua server. Chỉ gửi các trường
  /// khác null. Ném ApiException (message tiếng Việt) khi lỗi.
  static Future<void> updateProfile({
    String? name,
    String? address,
    String? phone,
    String? openHours,
  }) async {
    await ApiService.post('/api/updateStoreProfile', {
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (openHours != null) 'openHours': openHours,
    });
  }

  /// Phase 7: mở thư viện chọn ảnh giấy chứng nhận ATTP (tự nén nhỏ).
  /// Trả về bytes của ảnh, hoặc null nếu người dùng hủy chọn.
  static Future<Uint8List?> pickCertificateImage() async {
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

  /// Phase 7: gửi ảnh chứng nhận qua API submitCertificate — server lưu
  /// ảnh lên Vercel Blob và đặt stores.certStatus = 'pending' chờ duyệt.
  static Future<void> submitCertificate(Uint8List bytes) async {
    await ApiService.post('/api/submitCertificate', {
      'imageBase64': base64Encode(bytes),
    });
  }
}

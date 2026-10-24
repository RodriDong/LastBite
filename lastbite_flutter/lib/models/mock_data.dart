import 'dart:math';
import 'package:flutter/material.dart';

class AppColors {
  // Bảng màu "Cuối ngày ấm áp" (bản Hoàn thiện 24/10/2026):
  // xanh rừng đậm + nền kem + cam hoàng hôn cho giảm giá/giờ vàng.
  static const bg = Color(0xFFF6F1E7);
  static const app = Color(0xFFFBF7EE);
  static const card = Colors.white;
  static const ink = Color(0xFF1E2A22);
  static const mute = Color(0xFF6E7A6E);
  static const line = Color(0xFFE7DDC9);
  static const green = Color(0xFF1E7A46);
  static const greenDark = Color(0xFF14532D);
  static const greenLight = Color(0xFFE3F2E7);
  static const lime = Color(0xFFB7E34F);
  static const price = Color(0xFFEA580C);
  static const priceBg = Color(0xFFFFEAD5);
  static const hot = Color(0xFFDC2626);
  static const hotBg = Color(0xFFFEE4E2);
}

/// Danh mục deal chốt cứng (Phase 9) — khớp DEAL_CATEGORIES phía
/// server (server/src/deals.ts): seller chọn trong form đăng deal,
/// buyer lọc theo danh sách này ở trang chủ. Mỗi mục: [emoji, tên].
class DealCategories {
  DealCategories._();

  static const List<List<String>> all = [
    ['🥐', 'Bánh ngọt'],
    ['🍚', 'Cơm'],
    ['🍜', 'Bún phở'],
    ['🧋', 'Đồ uống'],
    ['🍎', 'Hoa quả'],
    ['🥗', 'Rau củ'],
    ['🍕', 'Pizza'],
    ['🥬', 'Món chay'],
    ['📦', 'Khác'],
  ];

  static List<String> get names => all.map((e) => e[1]).toList();
}

class SurpriseBox {
  final String id;
  final String emoji;
  final String title;
  final String category;
  final String description;
  final String storeName;

  /// Phase 6: id cửa hàng trên Firestore (để đọc rating/đánh giá thật);
  /// rỗng với dữ liệu mock cũ.
  final String storeId;
  final String address;
  final String distanceKm;
  final double lat;
  final double lng;
  final int originalPrice;
  final int maxDiscountPercent;
  int remainingQty;
  final int totalQty;
  final String pickupWindow;
  /// Khung giờ nhận của deal (bản Hoàn thiện) — để checkout chọn thật.
  final List<String> pickupSlots;
  /// Suất tặng miễn phí (phi lợi nhuận, BMC) — giá 0đ.
  final bool isGift;
  final DateTime createdAt;
  final DateTime expiredAt;
  bool isActive;

  /// Phase 8: ảnh thật của deal (URL Vercel Blob); null → hiện emoji.
  final String? imageUrl;

  SurpriseBox({
    required this.id,
    required this.emoji,
    required this.title,
    required this.category,
    required this.description,
    required this.storeName,
    this.storeId = '',
    required this.address,
    required this.distanceKm,
    required this.lat,
    required this.lng,
    required this.originalPrice,
    this.maxDiscountPercent = 60,
    required this.remainingQty,
    required this.totalQty,
    this.pickupWindow = '20:00 – 21:30',
    this.pickupSlots = const [],
    this.isGift = false,
    required this.createdAt,
    required this.expiredAt,
    this.isActive = true,
    this.imageUrl,
  });

  int get remainingSeconds {
    final diff = expiredAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  bool get isUrgent => remainingSeconds < 7200; // Dưới 2 giờ hiển thị màu đỏ

  int get currentDiscountPercent {
    final rem = remainingSeconds;
    if (rem > 10800) return 20; // Trên 3 giờ: giảm 20%
    if (rem > 3600) return 40;  // 1 – 3 giờ: giảm 40%
    return maxDiscountPercent;  // Dưới 1 giờ: giảm 60% - 70%
  }

  int get currentDynamicPrice {
    final factor = (100 - currentDiscountPercent) / 100.0;
    return ((originalPrice * factor) / 1000).round() * 1000;
  }

  double get stockRatio => totalQty > 0 ? (remainingQty / totalQty).clamp(0.0, 1.0) : 0.0;
}

class OrderModel {
  final String id;
  final SurpriseBox box;
  final String buyerName;
  final int lockedPrice;
  final String pickupSlot;
  final String pickupCode;
  String status; // 'PENDING', 'COMPLETED', 'CANCELLED'
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.box,
    this.buyerName = 'Nguyễn Minh',
    required this.lockedPrice,
    required this.pickupSlot,
    required this.pickupCode,
    this.status = 'PENDING',
    required this.createdAt,
  });
}

class AppData {
  static String userName = 'Toàn';
  static int greenPoints = 1420;
  static int savedMoney = 186000;
  static int rescuedMeals = 14;

  static String formatVnd(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return '${buffer.toString()}đ';
  }

  static String formatCountdown(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00:00';
    final h = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static List<SurpriseBox> boxes = [
    SurpriseBox(
      id: 'BOX01',
      emoji: '🥐',
      title: 'Combo bánh ngọt cuối ngày',
      category: 'Bánh ngọt',
      description: 'Bánh còn mới, nướng trong ngày gồm Croissant bơ Pháp, su kem và bánh mì phô mai.',
      storeName: 'Tiệm Lúa Mì',
      address: '12 Xuân Thủy, Cầu Giấy, Hà Nội',
      distanceKm: '0,4 km',
      lat: 21.0368,
      lng: 105.7825,
      originalPrice: 80000,
      maxDiscountPercent: 60,
      remainingQty: 4,
      totalQty: 10,
      pickupWindow: '20:00 – 21:30',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      expiredAt: DateTime.now().add(const Duration(seconds: 1900)),
    ),
    SurpriseBox(
      id: 'BOX02',
      emoji: '🍜',
      title: 'Bún bò phần lớn',
      category: 'Bún phở',
      description: 'Phần bún bò Huế đầy đủ bắp bò, giò heo, chả cua nước dùng ninh xương đậm đà.',
      storeName: 'Bún bò Cô Ba',
      address: '45 Trần Thái Tông, Cầu Giấy, Hà Nội',
      distanceKm: '0,9 km',
      lat: 21.0325,
      lng: 105.7885,
      originalPrice: 55000,
      maxDiscountPercent: 60,
      remainingQty: 6,
      totalQty: 12,
      pickupWindow: '20:30 – 22:00',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      expiredAt: DateTime.now().add(const Duration(seconds: 9800)),
    ),
    SurpriseBox(
      id: 'BOX03',
      emoji: '🍱',
      title: 'Cơm tấm sườn bì chả',
      category: 'Cơm',
      description: 'Hộp cơm tấm sườn nướng mật ong kèm bì thính, chả trứng hấp và đồ chua.',
      storeName: 'Cơm tấm 24',
      address: '88 Cầu Giấy, Hà Nội',
      distanceKm: '1,2 km',
      lat: 21.0302,
      lng: 105.7990,
      originalPrice: 50000,
      maxDiscountPercent: 50,
      remainingQty: 3,
      totalQty: 8,
      pickupWindow: '20:00 – 21:00',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      expiredAt: DateTime.now().add(const Duration(seconds: 3010)),
    ),
    SurpriseBox(
      id: 'BOX04',
      emoji: '🥖',
      title: 'Bánh mì que pate (3 cái)',
      category: 'Bánh ngọt',
      description: 'Combo 3 chiếc bánh mì que Hải Phòng pate gan béo ngậy kèm tương ớt.',
      storeName: 'Bánh mì Hòa',
      address: '19 Chùa Hà, Cầu Giấy, Hà Nội',
      distanceKm: '0,6 km',
      lat: 21.0385,
      lng: 105.7932,
      originalPrice: 30000,
      maxDiscountPercent: 70,
      remainingQty: 12,
      totalQty: 20,
      pickupWindow: '19:30 – 21:00',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      expiredAt: DateTime.now().add(const Duration(seconds: 1520)),
    ),
    SurpriseBox(
      id: 'BOX05',
      emoji: '🥗',
      title: 'Salad rau củ hữu cơ',
      category: 'Rau củ',
      description: 'Rau xà lách thủy canh, cà chua bi, bắp ngọt, ức gà áp chảo kèm sốt mè rang.',
      storeName: 'Green Bowl',
      address: '102 Nguyễn Phong Sắc, Cầu Giấy, Hà Nội',
      distanceKm: '1,5 km',
      lat: 21.0412,
      lng: 105.7901,
      originalPrice: 45000,
      maxDiscountPercent: 55,
      remainingQty: 5,
      totalQty: 6,
      pickupWindow: '20:00 – 21:30',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      expiredAt: DateTime.now().add(const Duration(seconds: 12400)),
    ),
    SurpriseBox(
      id: 'BOX06',
      emoji: '🧋',
      title: 'Trà sữa size L (2 ly)',
      category: 'Đồ uống',
      description: 'Combo 2 ly trà sữa ô long nướng trân châu hoàng kim nguyên vị.',
      storeName: 'Chè Bông',
      address: '56 Tô Hiệu, Cầu Giấy, Hà Nội',
      distanceKm: '0,8 km',
      lat: 21.0435,
      lng: 105.7955,
      originalPrice: 70000,
      maxDiscountPercent: 57,
      remainingQty: 7,
      totalQty: 10,
      pickupWindow: '20:30 – 22:00',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      expiredAt: DateTime.now().add(const Duration(seconds: 6100)),
    ),
  ];

  static List<OrderModel> orders = [
    OrderModel(
      id: 'A2417',
      box: boxes[0],
      buyerName: 'Nguyễn Minh',
      lockedPrice: 32000,
      pickupSlot: '20:30 – 21:00',
      pickupCode: 'A2417',
      status: 'PENDING',
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    OrderModel(
      id: 'A2415',
      box: boxes[3],
      buyerName: 'Trần Lan',
      lockedPrice: 9000,
      pickupSlot: '20:00 – 20:30',
      pickupCode: 'A2415',
      status: 'COMPLETED',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  static String generateOrderCode() {
    return 'A${1000 + Random().nextInt(8999)}';
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/mock_data.dart';

class BoxDetailScreen extends StatefulWidget {
  final SurpriseBox box;
  const BoxDetailScreen({super.key, required this.box});

  @override
  State<BoxDetailScreen> createState() => _BoxDetailScreenState();
}

class _BoxDetailScreenState extends State<BoxDetailScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.box;
    final price = box.currentDynamicPrice;
    final discount = box.currentDiscountPercent;

    return Scaffold(
      backgroundColor: AppColors.app,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        title: const Text('Chi tiết deal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        children: [
          // Ảnh Hero
          Container(
            height: 180,
            color: AppColors.greenLight,
            alignment: Alignment.center,
            child: Text(box.emoji, style: const TextStyle(fontSize: 84)),
          ),
          // Thanh Flash Sale màu cam đỏ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.hot, Color(0xFFFF8A3C)]),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      AppData.formatVnd(price),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppData.formatVnd(box.originalPrice),
                      style: const TextStyle(color: Colors.white70, decoration: TextDecoration.lineThrough, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.priceBg, borderRadius: BorderRadius.circular(99)),
                      child: Text('-$discount%', style: const TextStyle(color: AppColors.price, fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Hết giá này sau', style: TextStyle(color: Colors.white, fontSize: 10)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        AppData.formatCountdown(box.remainingSeconds),
                        style: const TextStyle(color: AppColors.hot, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tên món & đánh giá
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(box.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 4),
                Text(
                  '★ 4,8 (126 đánh giá) · Còn ${box.remainingQty} phần',
                  style: const TextStyle(color: AppColors.mute, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(box.description, style: const TextStyle(fontSize: 13, color: AppColors.ink)),
              ],
            ),
          ),

          // Thông tin khung giờ nhận
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                _kvRow('Khung giờ nhận', box.pickupWindow),
                _kvRow('Hình thức', 'Nhận tại quán'),
                _kvRow('Hạn dùng', 'Trong ngày'),
              ],
            ),
          ),

          // Thông tin quán
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.greenLight, shape: BoxShape.circle),
                  child: const Text('🏪', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(box.storeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('${box.distanceKm} · ★ 4,9 · ${box.address}',
                          style: const TextStyle(color: AppColors.mute, fontSize: 11.5)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Xem quán', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
          ),

          // Đánh giá mẫu
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.all(14),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đánh giá', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text('“Đồ ăn còn mới, đóng gói sạch sẽ, giá rẻ bất ngờ.” – Minh',
                    style: TextStyle(color: AppColors.mute, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 54,
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 68,
              alignment: Alignment.center,
              decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.line))),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('💬', style: TextStyle(fontSize: 17)),
                  Text('Chat', style: TextStyle(fontSize: 10, color: AppColors.mute)),
                ],
              ),
            ),
            Container(
              width: 68,
              alignment: Alignment.center,
              decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.line))),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🤍', style: TextStyle(fontSize: 17)),
                  Text('Lưu', style: TextStyle(fontSize: 10, color: AppColors.mute)),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: box.remainingQty > 0
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CheckoutConfirmScreen(box: box)),
                        );
                      }
                    : null,
                child: Container(
                  color: box.remainingQty > 0 ? AppColors.green : AppColors.mute,
                  alignment: Alignment.center,
                  child: Text(
                    box.remainingQty > 0 ? 'Đặt giữ chỗ ngay' : 'Đã hết phần',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kvRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: AppColors.mute, fontSize: 13)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

// ==========================================
// MÀN HÌNH XÁC NHẬN ĐẶT CHỖ & THANH TOÁN VÍ
// ==========================================
class CheckoutConfirmScreen extends StatefulWidget {
  final SurpriseBox box;
  const CheckoutConfirmScreen({super.key, required this.box});

  @override
  State<CheckoutConfirmScreen> createState() => _CheckoutConfirmScreenState();
}

class _CheckoutConfirmScreenState extends State<CheckoutConfirmScreen> {
  String selectedSlot = '20:30 – 21:00';
  final slots = ['20:00 – 20:30', '20:30 – 21:00', '21:00 – 21:30'];

  void _confirmBooking() {
    final price = widget.box.currentDynamicPrice;
    if (AppData.walletBalance < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số dư Ví LastBite không đủ! Hãy vào mục Tôi để nạp thêm.')),
      );
      return;
    }

    final code = AppData.generateOrderCode();
    final newOrder = OrderModel(
      id: code,
      box: widget.box,
      lockedPrice: price,
      pickupSlot: selectedSlot,
      pickupCode: code,
      createdAt: DateTime.now(),
    );

    setState(() {
      widget.box.remainingQty -= 1;
      AppData.walletBalance -= price;
      AppData.savedMoney += (widget.box.originalPrice - price);
      AppData.orders.insert(0, newOrder);
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => QrSuccessScreen(order: newOrder)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.box;
    final price = box.currentDynamicPrice;

    return Scaffold(
      backgroundColor: AppColors.app,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        title: const Text('Xác nhận đặt chỗ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        children: [
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn khung giờ lấy hàng', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3.4,
                  children: [
                    ...slots.map((s) {
                      final active = selectedSlot == s;
                      return GestureDetector(
                        onTap: () => setState(() => selectedSlot = s),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: active ? AppColors.greenLight : AppColors.card,
                            border: Border.all(color: active ? AppColors.green : AppColors.line),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                              color: active ? AppColors.greenDark : AppColors.ink,
                            ),
                          ),
                        ),
                      );
                    }),
                    Opacity(
                      opacity: 0.4,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.line),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('19:30 – 20:00', style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
                  child: Text(box.emoji, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(box.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('${box.storeName} · × 1', style: const TextStyle(fontSize: 12, color: AppColors.mute)),
                      Text(AppData.formatVnd(price),
                          style: const TextStyle(color: AppColors.price, fontWeight: FontWeight.w800, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tạm tính', style: TextStyle(color: AppColors.mute)),
                    Text(AppData.formatVnd(price), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ví LastBite (số dư ${AppData.formatVnd(AppData.walletBalance)})',
                        style: const TextStyle(color: AppColors.mute)),
                    Text('-${AppData.formatVnd(price)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Thanh toán', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(
                      AppData.formatVnd(price),
                      style: const TextStyle(color: AppColors.price, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: GestureDetector(
          onTap: _confirmBooking,
          child: Container(
            height: 52,
            color: AppColors.green,
            alignment: Alignment.center,
            child: const Text(
              'Xác nhận đặt chỗ',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// MÀN HÌNH HIỂN THỊ MÃ QR NHẬN HÀNG TẠI QUẦY
// ==========================================
class QrSuccessScreen extends StatelessWidget {
  final OrderModel order;
  const QrSuccessScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        title: const Text('Mã nhận hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(99)),
                child: Text(
                  'Đặt thành công · #${order.pickupCode}',
                  style: const TextStyle(color: AppColors.greenDark, fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: QrImageView(data: order.pickupCode, size: 180),
              ),
              const SizedBox(height: 14),
              const Text('Đưa mã này cho quán', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              const SizedBox(height: 6),
              Text(
                '${order.box.storeName} · nhận ${order.pickupSlot}',
                style: const TextStyle(color: AppColors.mute, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.hot, Color(0xFFFF8A3C)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Mã: ${order.pickupCode} · Còn lại ${AppData.formatCountdown(order.box.remainingSeconds)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              const SizedBox(height: 28),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Quay lại trang chính'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
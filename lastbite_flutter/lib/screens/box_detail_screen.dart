import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/chat.dart';
import '../models/mock_data.dart';
import '../services/chat_service.dart';
import '../services/favorite_service.dart';
import '../services/directions.dart';
import '../services/order_service.dart';
import '../models/payment_method.dart';
import 'mock_payment_screen.dart';
import '../services/auth_service.dart';
import '../services/voucher_service.dart';
import '../services/api_service.dart';
import '../services/store_service.dart';
import '../services/review_service.dart';
import 'chat_screen.dart';

class BoxDetailScreen extends StatefulWidget {
  final SurpriseBox box;
  const BoxDetailScreen({super.key, required this.box});

  @override
  State<BoxDetailScreen> createState() => _BoxDetailScreenState();
}

class _BoxDetailScreenState extends State<BoxDetailScreen> {
  Timer? _timer;

  // Phase 6: rating + nhận xét THẬT của cửa hàng — đọc 1 lần khi mở màn
  // (không stream; màn hình có timer 1s nên giữ dữ liệu trong state).
  double _storeRating = 0;
  int _storeRatingCount = 0;
  List<StoreReview> _reviews = const [];
  // Phase 7: huy hiệu kiểm chứng ATTP (stores.certStatus == 'approved').
  bool _certApproved = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadStoreReviews();
  }

  Future<void> _loadStoreReviews() async {
    final storeId = widget.box.storeId;
    if (storeId.isEmpty) return;
    try {
      final store = await StoreService.getStore(storeId);
      if (!mounted) return;
      if (store != null) {
        setState(() {
          _storeRating = store.rating;
          _storeRatingCount = store.ratingCount;
          _certApproved = store.certStatus == 'approved';
        });
      }
      final reviews = await ReviewService.recentForStore(storeId);
      if (!mounted) return;
      setState(() => _reviews = reviews);
    } catch (_) {
      // Không đọc được đánh giá thì giữ hiển thị mặc định, không chặn xem deal.
    }
  }

  /// Phase 9: mở chat với quán của deal này (tạo thread nếu chưa có).
  Future<void> _openChatWithStore() async {
    final box = widget.box;
    if (box.storeId.isEmpty) return;
    try {
      final threadId = await ChatService.ensureThread(
        storeId: box.storeId,
        storeName: box.storeName,
      );
      if (!mounted) return;
      final uid = ChatService.myUid ?? '';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            thread: ChatThread(
              id: threadId,
              buyerUid: uid,
              buyerName: '',
              storeId: box.storeId,
              storeName: box.storeName,
              lastMessage: '',
              lastAt: null,
              buyerUnread: 0,
              sellerUnread: 0,
            ),
            asSeller: false,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được chat. Thử lại sau.')),
      );
    }
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
                      box.isGift ? 'Miễn phí 🎁' : AppData.formatVnd(price),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    if (!box.isGift) ...[
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
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(box.isBag ? 'Nhận trước' : 'Hết giá này sau', style: const TextStyle(color: Colors.white, fontSize: 10)),
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
                  _storeRatingCount > 0
                      ? '★ ${_storeRating.toStringAsFixed(1).replaceAll('.', ',')} ($_storeRatingCount đánh giá) · Còn ${box.remainingQty} ${box.isBag ? 'túi' : 'phần'}'
                      : 'Chưa có đánh giá · Còn ${box.remainingQty} ${box.isBag ? 'túi' : 'phần'}',
                  style: const TextStyle(color: AppColors.mute, fontSize: 12),
                ),
                // Gói Túi + Phí: túi hiện gợi ý trong túi + ghi chú dị ứng.
                if (box.isBag) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.greenLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.green),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🎒 Túi bất ngờ — quán đóng gì ngon thì bạn nhận nấy.',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.greenDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Có thể có: ${box.possibleCategories.join(', ')}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        if (box.allergyNote.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '⚠️ Dị ứng: ${box.allergyNote}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.hot),
                          ),
                        ],
                        const SizedBox(height: 4),
                        const Text(
                          'Giá túi cố định 50% giá trị thật, không đổi theo giờ.',
                          style: TextStyle(fontSize: 12, color: AppColors.mute),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_certApproved) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.verified,
                          size: 15, color: AppColors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Đã kiểm chứng an toàn thực phẩm',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
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
                _kvRow('Dùng ngon nhất', 'Trong ngày'),
              ],
            ),
          ),

          // Thông tin quán (Phase 9: rating thật + nút Chỉ đường / Chat)
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                Row(
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
                          Text(
                              _storeRatingCount > 0
                                  ? '${box.distanceKm} · ★ ${_storeRating.toStringAsFixed(1).replaceAll('.', ',')} · ${box.address}'
                                  : '${box.distanceKm} · Chưa có đánh giá · ${box.address}',
                              style: const TextStyle(color: AppColors.mute, fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Directions.open(box.lat, box.lng),
                        icon: const Text('🧭', style: TextStyle(fontSize: 13)),
                        label: const Text('Chỉ đường', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.greenDark,
                          side: const BorderSide(color: AppColors.line),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openChatWithStore,
                        icon: const Text('💬', style: TextStyle(fontSize: 13)),
                        label: const Text('Chat với quán', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.greenDark,
                          side: const BorderSide(color: AppColors.line),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FavoriteButton(
                      storeId: box.storeId,
                      storeName: box.storeName,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Đánh giá thật của khách (Phase 6)
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Đánh giá', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (_reviews.isEmpty)
                  const Text('Chưa có nhận xét nào cho quán này.',
                      style: TextStyle(color: AppColors.mute, fontSize: 12.5))
                else
                  ..._reviews.take(3).map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${'★' * r.rating} – ${r.buyerName.isEmpty ? 'Khách hàng' : r.buyerName}',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                              ),
                              if (r.comment.isNotEmpty)
                                Text('“${r.comment}”',
                                    style: const TextStyle(color: AppColors.mute, fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
      // Gói Túi + Phí: SafeArea để thanh điều hướng hệ thống của
      // Android không che mất nút đặt giữ chỗ.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
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
                    box.remainingQty > 0 ? 'Đặt giữ chỗ ngay' : (box.isBag ? 'Đã hết túi' : 'Đã hết phần'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
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
// MÀN HÌNH XÁC NHẬN ĐẶT CHỖ & THANH TOÁN KHI NHẬN
// ==========================================
class CheckoutConfirmScreen extends StatefulWidget {
  final SurpriseBox box;
  const CheckoutConfirmScreen({super.key, required this.box});

  @override
  State<CheckoutConfirmScreen> createState() => _CheckoutConfirmScreenState();
}

class _CheckoutConfirmScreenState extends State<CheckoutConfirmScreen> {
  String selectedSlot = ''; // Chưa chọn: mặc định slot đầu của deal.

  /// Các khung giờ nhận thật của deal (fallback: khung giờ chung).
  List<String> get _slots => widget.box.pickupSlots.isNotEmpty
      ? widget.box.pickupSlots
      : [widget.box.pickupWindow];

  String get _effectiveSlot =>
      selectedSlot.isEmpty ? _slots.first : selectedSlot;
  final slots = ['20:00 – 20:30', '20:30 – 21:00', '21:00 – 21:30'];
  bool _placing = false;

  /// Số lượng buyer chọn (Phase 6): server hỗ trợ 1..99 từ Phase 4,
  /// giới hạn trên theo tồn kho còn lại của deal.
  int qty = 1;

  /// Phương thức thanh toán giả lập (BMC) — mặc định VietQR.
  String _paymentMethod = 'vietqr';

  /// Ưu đãi (bản Hoàn thiện): voucher đổi điểm, chọn ở checkout.
  String? _voucherId;
  List<Voucher> _vouchers = [];
  StreamSubscription<List<Voucher>>? _vouchSub;

  List<Voucher> get _eligibleVouchers {
    final total = widget.box.currentDynamicPrice * qty;
    return _vouchers.where((v) => v.isUsable && total >= v.minOrder).toList();
  }

  int get _voucherDiscount {
    if (_voucherId == null) return 0;
    for (final v in _vouchers) {
      if (v.id == _voucherId) return v.amount;
    }
    return 0;
  }

  Widget _voucherChip(String? id, String label) {
    final selected = _voucherId == id;
    return GestureDetector(
      onTap: () => setState(() => _voucherId = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : AppColors.greenLight,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.greenDark)),
      ),
    );
  }

  Widget _payChip(String id, String label) {
    final selected = _paymentMethod == id;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : AppColors.greenLight,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.greenDark)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final uid = AuthService.currentUser?.uid;
    if (uid != null) {
      _vouchSub = VoucherService.myVouchers(uid).listen((list) {
        if (mounted) setState(() => _vouchers = list);
      });
    }
  }

  @override
  void dispose() {
    _vouchSub?.cancel();
    super.dispose();
  }

  int get _maxQty {
    final r = widget.box.remainingQty;
    if (r > 99) return 99;
    return r < 1 ? 1 : r;
  }

  Widget _qtyButton(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.greenLight : AppColors.card,
          border: Border.all(color: enabled ? AppColors.green : AppColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18, color: enabled ? AppColors.greenDark : AppColors.mute),
      ),
    );
  }

  /// Đặt chỗ qua API `createOrder`: server khóa giá theo giờ, trừ tồn
  /// kho, sinh mã nhận hàng. Thanh toán GIẢ LẬP qua cổng (BMC: MoMo /
  /// VNPay / ZaloPay / PayOS / VietQR) ở màn tiếp theo — không tiền thật.
  Future<void> _confirmBooking() async {
    if (_placing) return;
    setState(() => _placing = true);
    try {
      final res = await OrderService.createOrder(
        dealId: widget.box.id,
        quantity: qty,
        pickupSlot: _effectiveSlot,
        voucherId: _voucherId,
        paymentMethod: _paymentMethod,
      );
      final code = (res['pickupCode'] ?? '').toString();
      final locked = (res['unitLockedPrice'] as num?)?.round() ??
          widget.box.currentDynamicPrice;
      final order = OrderModel(
        id: (res['orderId'] ?? code).toString(),
        box: widget.box,
        lockedPrice: locked,
        pickupSlot: _effectiveSlot,
        pickupCode: code,
        createdAt: DateTime.now(),
      );
      if (!mounted) return;
      final amount = (res['amountPaid'] as num?)?.round() ??
          (res['totalLockedPrice'] as num?)?.round() ?? 0;
      if (amount == 0) {
        // Suất tặng: không có gì để trả, vào thẳng màn mã nhận hàng.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => QrSuccessScreen(order: order)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MockPaymentScreen(
              orderId: (res['orderId'] ?? code).toString(),
              amount: amount,
              method: PaymentMethod.byId(_paymentMethod),
              onPaid: (ctx) {
                Navigator.pushReplacement(
                  ctx,
                  MaterialPageRoute(builder: (_) => QrSuccessScreen(order: order)),
                );
              },
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đặt hàng thất bại: $e')),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
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
                      Text('${box.storeName} · × $qty', style: const TextStyle(fontSize: 12, color: AppColors.mute)),
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
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Số lượng', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Còn ${box.remainingQty} ${box.isBag ? 'túi' : 'phần'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.mute)),
                  ],
                ),
                Row(
                  children: [
                    _qtyButton(Icons.remove, qty > 1 ? () => setState(() => qty--) : null),
                    SizedBox(
                      width: 40,
                      child: Text('$qty',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    _qtyButton(Icons.add, qty < _maxQty ? () => setState(() => qty++) : null),
                  ],
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Khung giờ nhận',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _slots.map((slotOpt) {
                    final selected = _effectiveSlot == slotOpt;
                    return GestureDetector(
                      onTap: () => setState(() => selectedSlot = slotOpt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.green
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color: selected
                                  ? AppColors.green
                                  : AppColors.line),
                        ),
                        child: Text(
                          slotOpt,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : AppColors.ink,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          if (!widget.box.isGift)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thanh toán',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.greenDark)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PaymentMethod.all
                      .map((m) => _payChip(m.id, '${m.emoji} ${m.name}'))
                      .toList(),
                ),
              ],
            ),
          ),
          if (_eligibleVouchers.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ưu đãi',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.greenDark)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _voucherChip(null, 'Không dùng'),
                      ..._eligibleVouchers.map((v) =>
                          _voucherChip(v.id, 'Giảm ${AppData.formatVnd(v.amount)}')),
                    ],
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
                    Text(AppData.formatVnd(price * qty), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                if (_voucherDiscount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Ưu đãi', style: TextStyle(color: AppColors.mute)),
                        Text('-${AppData.formatVnd(_voucherDiscount)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.green)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Hình thức', style: TextStyle(color: AppColors.mute)),
                    Text(PaymentMethod.byId(_paymentMethod).name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Thanh toán', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(
                      AppData.formatVnd(price * qty - _voucherDiscount),
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
            child: Text(
              _placing ? 'Đang đặt…' : 'Xác nhận đặt chỗ',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
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
/// Nút tim yêu thích quán (tự theo dõi trạng thái qua favorites stream).
class _FavoriteButton extends StatefulWidget {
  final String storeId;
  final String storeName;
  const _FavoriteButton({required this.storeId, required this.storeName});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool _fav = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    try {
      _sub = FavoriteService.favoriteStoreIds().listen((ids) {
        if (mounted) setState(() => _fav = ids.contains(widget.storeId));
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.storeId.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: 44,
      child: OutlinedButton(
        onPressed: () async {
          try {
            await FavoriteService.toggle(
              storeId: widget.storeId,
              storeName: widget.storeName,
            );
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi: $e')),
              );
            }
          }
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.line),
          padding: EdgeInsets.zero,
        ),
        child: Text(_fav ? '❤️' : '🤍', style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/deal.dart';
import '../models/mock_data.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/deal_service.dart';
import '../services/order_service.dart';
import '../services/api_service.dart';
import '../services/stats_service.dart';
import '../services/store_service.dart';
import 'auth_screen.dart';
import 'buyer_home_screen.dart';
import 'chat_list_screen.dart';
import 'notifications_screen.dart';
import 'seller_deals_screen.dart';
import 'seller_reviews_screen.dart';
import 'week_chart_screen.dart';
import '../services/settlement_service.dart';
import 'promotion_screen.dart';
import 'complaints_screen.dart';
import 'support_screen.dart';

class SellerScreen extends StatefulWidget {
  const SellerScreen({super.key});

  @override
  State<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> {
  int currentTab = 0; // 0: Tổng quan, 1: Đăng deal, 2: Đơn hàng, 3: Doanh thu, 4: Cửa hàng
  int orderSubTab = 0; // 0: Cần xác nhận, 1: Đã giao
  int revenueRangeTab = 1; // 0: Hôm nay, 1: Tuần này, 2: Tháng
  Timer? _timer;

  // Controllers cho form Đăng deal mới
  final titleCtrl = TextEditingController(text: 'Combo bánh ngọt');
  final origPriceCtrl = TextEditingController(text: '80000');
  final qtyCtrl = TextEditingController(text: '10');
  final expTimeCtrl = TextEditingController(text: '21:30');
  String selectedEmoji = '🥐';
  // Phase 9: danh mục chốt cứng cho deal mới (DealCategories).
  String _dealCategory = 'Bánh ngọt';
  // Phase 8: ảnh deal tùy chọn (bytes đã nén, null = dùng emoji).
  Uint8List? _dealImageBytes;
  // Gói Túi + Phí: loại đăng (túi = sản phẩm chính) + nhóm món trong túi.
  bool _isBag = false;
  final Set<String> _bagCategories = {};
  final allergyCtrl = TextEditingController();

  // Phase 3: deal thật của cửa hàng từ Firestore.
  List<Deal> _deals = [];
  StreamSubscription<List<Deal>>? _dealSub;

  // Phase 4: số đơn PENDING thật của cửa hàng (cho tab Tổng quan).
  int _pendingOrders = 0;
  StreamSubscription<int>? _pendingSub;

  // Phase 5: doanh thu hôm nay thật từ dailyStats (cho tab Tổng quan).
  int _todayRevenue = 0;
  StreamSubscription<DailyStat>? _statsSub;

  // Phase 5: dữ liệu thật cho tab Đơn hàng + Doanh thu, nạp bằng listen()
  // ở initState giống _dealSub (ổn định từ Phase 3). Cố ý KHÔNG dùng
  // StreamBuilder cho các tab này: màn hình tự vẽ lại mỗi giây, cặp
  // StreamBuilder/stream đã gây nhấp nháy rồi kẹt tải ở các bản vá trước.
  List<FirestoreOrder> _pendingList = [];
  List<FirestoreOrder> _completedList = [];
  List<DailyStat> _stats = [];
  StreamSubscription<List<FirestoreOrder>>? _pendingOrdersSub;
  StreamSubscription<List<FirestoreOrder>>? _completedOrdersSub;
  StreamSubscription<List<DailyStat>>? _revenueSub;

  // Phase 6: hồ sơ cửa hàng thật (stores/{uid}) cho header + tab Cửa hàng.
  String _storeName = '';
  DateTime? _storeFeeExpiresAt;
  // Gói Túi + Phí: ngày tạo quán -> giai đoạn phí + % hoa hồng.
  DateTime? _storeCreatedAt;
  int _ledgerRecorded = 0;
  int _ledgerPaid = 0;
  bool _isGift = false;
  String _storeAddress = '';
  String? _storePhone;
  String? _storeOpenHours;
  double _storeRating = 0;
  int _storeRatingCount = 0;
  // Phase 7: trạng thái giấy chứng nhận ATTP (stores.certStatus).
  String _certStatus = 'none';
  String? _certUrl;
  String? _certReviewNote;
  StreamSubscription<StoreProfile?>? _storeSub;

  @override
  void initState() {
    super.initState();
    // Nếu Firebase chưa được cấu hình (chế độ mock), bỏ qua stream.
    try {
      final storeId = DealService.myStoreId;
      if (storeId != null) {
        _dealSub = DealService.storeDeals(storeId).listen((deals) {
          if (!mounted) return;
          setState(() => _deals = deals);
        });
        _pendingSub = OrderService.storePendingCount(storeId).listen((n) {
          if (!mounted) return;
          setState(() => _pendingOrders = n);
        });
        _statsSub = StatsService.todayStats(storeId).listen((stat) {
          if (!mounted) return;
          setState(() => _todayRevenue = stat.revenue);
        });
        _pendingOrdersSub =
            OrderService.storeOrders(storeId, 'PENDING').listen((list) {
          if (!mounted) return;
          setState(() => _pendingList = list);
        });
        _completedOrdersSub =
            OrderService.storeOrders(storeId, 'COMPLETED').listen((list) {
          if (!mounted) return;
          setState(() => _completedList = list);
        });
        _revenueSub =
            StatsService.recentStats(storeId, days: 30).listen((list) {
          if (!mounted) return;
          setState(() => _stats = list);
        });
        _storeSub = StoreService.myStore().listen((p) {
          if (!mounted || p == null) return;
          setState(() {
            _storeName = p.name;
            _storeAddress = p.address;
            _storePhone = p.phone;
            _storeOpenHours = p.openHours;
            _storeRating = p.rating;
            _storeRatingCount = p.ratingCount;
            _certStatus = p.certStatus;
            _certUrl = p.certUrl;
            _certReviewNote = p.certReviewNote;
            _storeFeeExpiresAt = p.feeExpiresAt;
            _storeCreatedAt = p.createdAt;
          });
        });
      }
    } catch (_) {
      // giữ _deals rỗng
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadLedger();
  }

  @override
  void dispose() {
    _dealSub?.cancel();
    _pendingSub?.cancel();
    _statsSub?.cancel();
    _pendingOrdersSub?.cancel();
    _completedOrdersSub?.cancel();
    _revenueSub?.cancel();
    _storeSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.app,
      body: IndexedStack(
        index: currentTab,
        children: [
          _buildOverviewTab(),
          _buildCreateAndManageDealTab(),
          _buildSellerOrdersTab(),
          _buildRevenueTab(),
          _buildStoreProfileTab(),
        ],
      ),
      // Gói Túi + Phí: bọc SafeArea để thanh điều hướng hệ thống của
      // Android (đặc biệt Android 15 edge-to-edge) không che mất tab.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.card,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
        child: BottomNavigationBar(
          currentIndex: currentTab,
          onTap: (i) => setState(() => currentTab = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.card,
          selectedItemColor: AppColors.green,
          unselectedItemColor: AppColors.mute,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Text('🏠', style: TextStyle(fontSize: 18)), label: 'Tổng quan'),
            BottomNavigationBarItem(icon: Text('➕', style: TextStyle(fontSize: 18)), label: 'Đăng deal'),
            BottomNavigationBarItem(icon: Text('🧾', style: TextStyle(fontSize: 18)), label: 'Đơn hàng'),
            BottomNavigationBarItem(icon: Text('💰', style: TextStyle(fontSize: 18)), label: 'Doanh thu'),
            BottomNavigationBarItem(icon: Text('🏪', style: TextStyle(fontSize: 18)), label: 'Cửa hàng'),
          ],
        ),
        ),
      ),
    );
  }

  /// 412000 -> '412k', 48000 -> '48k', 0 -> '0' (kiểu hiển thị ô Hôm nay).
  String _compactVnd(int v) => v >= 1000 ? '${(v / 1000).round()}k' : '$v';

  /// Nhãn thứ cho biểu đồ doanh thu: T2..T7, CN.
  String _weekdayLabel(DateTime d) =>
      d.weekday == 7 ? 'CN' : 'T${d.weekday + 1}';

  Widget _sellerHeader(String title, {Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.green, AppColors.greenDark]),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            trailing ??
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BuyerHomeScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)),
                    child: const Text('🛒 Sang Người mua', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 0: TỔNG QUAN SELLER
  // ==========================================
  Widget _buildOverviewTab() {
    final myDeals = _deals.where((d) => d.isActive).toList();
    final activeDealsCount = myDeals.length;
    final pendingOrdersCount = _pendingOrders;

    return Column(
      children: [
        _sellerHeader(_storeName.isEmpty ? 'Cửa hàng của tôi' : _storeName),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  _statBox('$activeDealsCount', 'Deal đang chạy'),
                  const SizedBox(width: 8),
                  _statBox('$pendingOrdersCount', 'Đơn chờ'),
                  const SizedBox(width: 8),
                  _statBox(_compactVnd(_todayRevenue), 'Hôm nay'),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => currentTab = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.price,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '+ Đăng deal mới',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Cần xử lý', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.greenDark)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
                      child: const Text('🧾', style: TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$pendingOrdersCount đơn đang chờ khách đến lấy',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          const Text('Nhấn “Xem” để quét mã khi khách đến lấy', style: TextStyle(fontSize: 11.5, color: AppColors.mute)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => currentTab = 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(8)),
                        child: const Text('Xem', style: TextStyle(color: AppColors.greenDark, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Deal đang chạy tại quán',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.greenDark)),
              const SizedBox(height: 8),
              ...myDeals.map((d) {
                final b = d.toSurpriseBox();
                return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
                          child: Text(b.emoji, style: const TextStyle(fontSize: 26)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              Row(
                                children: [
                                  Text(AppData.formatVnd(b.currentDynamicPrice),
                                      style: const TextStyle(color: AppColors.price, fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 6),
                                  Text(AppData.formatVnd(b.originalPrice),
                                      style: const TextStyle(
                                          color: AppColors.mute, fontSize: 11, decoration: TextDecoration.lineThrough)),
                                ],
                              ),
                              Text(
                                'Còn ${b.remainingQty}/${b.totalQty} · giờ vàng còn ${AppData.formatCountdown(b.remainingSeconds)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.mute),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _toggleDeal(d.id, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.hotBg, borderRadius: BorderRadius.circular(8)),
                            child: const Text('Tắt deal', style: TextStyle(color: AppColors.hot, fontWeight: FontWeight.w700, fontSize: 11.5)),
                          ),
                        ),
                      ],
                    ),
                  );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statBox(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.mute)),
          ],
        ),
      ),
    );
  }

  String _friendlyError(Object e) {
    if (e is ApiException) return e.message;
    return e.toString();
  }

  /// Tắt / mở lại deal qua Cloud Function `pauseDeal`.
  Future<void> _toggleDeal(String dealId, bool paused) async {
    try {
      await DealService.pauseDeal(dealId: dealId, paused: paused);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(paused ? '⏸️ Đã tắt deal.' : '▶️ Đã mở lại deal.'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${_friendlyError(e)}')),
      );
    }
  }

  /// Đăng deal mới qua API `createDeal`.
  /// Ô "Kết thúc bán lúc" nhập dạng HH:mm (giờ hôm nay theo giờ máy;
  /// nếu đã qua thì hiểu là ngày mai).
  /// Gói Túi + Phí: túi có giá cố định 50% giá trị thật, chọn nhiều
  /// nhóm món có thể có; lẻ giữ nguyên thang giảm theo giờ.
  Future<void> _submitDeal() async {
    final messenger = ScaffoldMessenger.of(context);
    var title = titleCtrl.text.trim();
    if (title.isEmpty) {
      if (_isBag) {
        title = 'Túi bất ngờ';
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên món.')));
        return;
      }
    }
    final orig = _isGift ? 0 : (int.tryParse(origPriceCtrl.text) ?? 0);
    final qty = int.tryParse(qtyCtrl.text) ?? 0;
    if (_isBag && _bagCategories.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Chọn ít nhất 1 nhóm món có thể có trong túi.')));
      return;
    }
    final bagCats = _bagCategories.toList();

    DateTime end;
    try {
      final parts = expTimeCtrl.text.split(':');
      if (parts.length != 2) throw const FormatException('bad time');
      final now = DateTime.now();
      end = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0].trim()),
        int.parse(parts[1].trim()),
      );
      if (!end.isAfter(now)) end = end.add(const Duration(days: 1));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Giờ kết thúc bán phải dạng HH:mm, ví dụ 21:30.')),
      );
      return;
    }

    try {
      final minPrice = _isGift
          ? 0
          : _isBag
              ? ((orig * 0.5) / 1000).round() * 1000
              : ((orig * 0.3) / 1000).round() * 1000;
      await DealService.createDeal(
        title: title,
        description: _isBag
            ? 'Túi bất ngờ cuối ngày — quán đóng gì ngon thì bạn nhận nấy.'
            : 'Phần ăn giải cứu cuối ngày, chất lượng đảm bảo.',
        icon: selectedEmoji,
        category: _isBag ? bagCats.first : _dealCategory,
        originalPrice: orig,
        minPrice: minPrice,
        maxDiscountPercent: _isBag ? 50 : 60,
        totalQty: qty,
        saleEndAt: end,
        pickupWindow: '20:00 – ${expTimeCtrl.text}',
        imageBytes: _dealImageBytes,
        isGift: _isGift,
        dealType: _isBag ? 'bag' : 'retail',
        originalValue: _isBag ? orig : null,
        possibleCategories: bagCats,
        allergyNote: _isBag ? allergyCtrl.text.trim() : '',
      );
      if (!mounted) return;
      setState(() {
        currentTab = 0;
        _dealImageBytes = null;
      });
      messenger.showSnackBar(
        const SnackBar(
            content: Text('✅ Đã đăng deal mới lên sàn!'),
            backgroundColor: AppColors.green),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Lỗi: ${_friendlyError(e)}')));
    }
  }

  // ==========================================
  // TAB 1: ĐĂNG DEAL MỚI + XEM TRƯỚC GIÁ THEO GIỜ
  // ==========================================
  Widget _buildCreateAndManageDealTab() {
    final orig = int.tryParse(origPriceCtrl.text) ?? 80000;
    // Giá sàn mặc định = 30% giá gốc (làm tròn nghìn). Server luôn kiểm tra
    // giá sàn ≤ giá gốc và giá bán không thấp hơn giá sàn.
    final minPrice = ((orig * 0.3) / 1000).round() * 1000;
    int floorPrice(int p) => p < minPrice ? minPrice : p;
    final p20 = floorPrice(((orig * 0.8) / 1000).round() * 1000);
    final p40 = floorPrice(((orig * 0.6) / 1000).round() * 1000);
    final p60 = floorPrice(((orig * 0.4) / 1000).round() * 1000);
    // Gói Túi + Phí: giá túi cố định 50% giá trị thật (tặng = 0đ).
    final bagPreview = _isGift ? 0 : ((orig * 0.5) / 1000).round() * 1000;

    return Column(
      children: [
        _sellerHeader('Đăng deal mới'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Chọn biểu tượng món ăn
              GestureDetector(
                onTap: () {
                  final list = ['🥐', '🍜', '🍱', '🥖', '🥗', '🧋', '🍕'];
                  setState(() {
                    selectedEmoji = list[(list.indexOf(selectedEmoji) + 1) % list.length];
                  });
                },
                child: Container(
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.green, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$selectedEmoji  📷 Chụp / đổi biểu tượng món',
                    style: const TextStyle(color: AppColors.greenDark, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Gói Túi + Phí: chọn loại đăng — túi là sản phẩm chính.
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _isBag = true;
                        if (titleCtrl.text == 'Combo bánh ngọt') {
                          titleCtrl.text = 'Túi bất ngờ';
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isBag ? AppColors.green : AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isBag ? AppColors.green : AppColors.line),
                        ),
                        alignment: Alignment.center,
                        child: Text('🎒 Túi bất ngờ',
                            style: TextStyle(
                                color: _isBag ? Colors.white : AppColors.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _isBag = false;
                        if (titleCtrl.text == 'Túi bất ngờ') {
                          titleCtrl.text = 'Combo bánh ngọt';
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isBag ? AppColors.green : AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: !_isBag ? AppColors.green : AppColors.line),
                        ),
                        alignment: Alignment.center,
                        child: Text('🍱 Bán lẻ từng món',
                            style: TextStyle(
                                color: !_isBag ? Colors.white : AppColors.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Phase 9: chọn danh mục (danh sách chốt cứng, khớp bộ lọc
              // phía buyer + validator phía server).
              if (!_isBag)
                DropdownButtonFormField<String>(
                  value: _dealCategory,
                decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: DealCategories.names
                    .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                    .toList(),
                onChanged: (v) => setState(() => _dealCategory = v ?? 'Khác'),
              ),
              const SizedBox(height: 12),
              // Gói Túi + Phí: túi chọn nhiều nhóm món có thể có.
              if (_isBag) ...[
                const Text(
                  'Nhóm món có thể có trong túi (chọn ít nhất 1)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DealCategories.names.map((n) {
                    final selected = _bagCategories.contains(n);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (selected) {
                          _bagCategories.remove(n);
                        } else {
                          _bagCategories.add(n);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.green : AppColors.card,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: selected ? AppColors.green : AppColors.line),
                        ),
                        child: Text(n,
                            style: TextStyle(
                                color: selected ? Colors.white : AppColors.ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              // Phase 8: ảnh món tùy chọn (không chọn thì app hiện emoji).
              GestureDetector(
                onTap: () async {
                  try {
                    final bytes = await DealService.pickDealImage();
                    if (bytes != null && mounted) {
                      setState(() => _dealImageBytes = bytes);
                    }
                  } on ApiException catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(e.message)));
                  }
                },
                child: Container(
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line, width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: _dealImageBytes == null
                      ? const Text('🖼️ Thêm ảnh món (tùy chọn)',
                          style: TextStyle(
                              color: AppColors.mute,
                              fontWeight: FontWeight.w600,
                              fontSize: 14))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(_dealImageBytes!,
                                  width: 56, height: 56, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 10),
                            const Text('Đã chọn ảnh món ✓ (bấm để đổi)',
                                style: TextStyle(
                                    color: AppColors.greenDark,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              _formFieldRow(
                  _isBag ? 'Tên túi (để trống = Túi bất ngờ)' : 'Tên món',
                  titleCtrl,
                  isNumber: false),
              _formFieldRow(
                  _isBag ? 'Giá trị thật của túi (VNĐ)' : 'Giá gốc (VNĐ)',
                  origPriceCtrl,
                  isNumber: true),
              GestureDetector(
                onTap: () => setState(() => _isGift = !_isGift),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.card,
                    border: Border(bottom: BorderSide(color: AppColors.line)),
                  ),
                  child: Row(
                    children: [
                      Text(_isGift ? '☑️' : '⬜',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '🎁 Tặng miễn phí suất này (giá 0đ, cho tổ chức phi lợi nhuận)',
                          style: TextStyle(fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isBag)
                _formFieldRow('Ghi chú dị ứng (tùy chọn)', allergyCtrl,
                    isNumber: false),
              _formFieldRow(
                  _isBag ? 'Số lượng túi' : 'Số lượng phần',
                  qtyCtrl,
                  isNumber: true),
              _formFieldRow('Kết thúc bán lúc', expTimeCtrl, isNumber: false),
              const SizedBox(height: 14),
              if (_isBag)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.green),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Giá túi cố định (50% giá trị thật)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      Text(
                        _isGift ? 'Miễn phí 🎁' : AppData.formatVnd(bagPreview),
                        style: const TextStyle(
                            color: AppColors.price,
                            fontWeight: FontWeight.w800,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),
              if (!_isBag) ...[
                const Text(
                  'Khách sẽ thấy giá giảm tự động như sau',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.greenDark),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.line),
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1.2),
                    2: FlexColumnWidth(1.5),
                  },
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
                      children: [
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Còn lại', style: TextStyle(color: AppColors.mute))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Giảm', style: TextStyle(color: AppColors.mute))),
                        Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text('Giá bán', textAlign: TextAlign.right, style: TextStyle(color: AppColors.mute))),
                      ],
                    ),
                    _previewRow('Trên 3 giờ', '20%', AppData.formatVnd(p20), false),
                    _previewRow('1 – 3 giờ', '40%', AppData.formatVnd(p40), false),
                    _previewRow('Dưới 1 giờ', '60%', AppData.formatVnd(p60), true),
                  ],
                ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _submitDeal(),
                  child: const Text('Đăng deal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formFieldRow(String label, TextEditingController ctrl, {required bool isNumber}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.mute, fontSize: 14))),
          SizedBox(
            width: 170,
            child: TextField(
              controller: ctrl,
              keyboardType: isNumber ? TextInputType.number : TextInputType.text,
              textAlign: TextAlign.right,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _previewRow(String time, String disc, String price, bool highlight) {
    return TableRow(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(time)),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(disc)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            price,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: highlight ? AppColors.price : AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: ĐƠN HÀNG & QUÉT QR NHẬN HÀNG
  // ==========================================
  Widget _buildSellerOrdersTab() {
    final pendingList = _pendingList;
    final completedList = _completedList;
    final displayList = orderSubTab == 0 ? pendingList : completedList;

    return Column(
              children: [
                _sellerHeader('Đơn hàng'),
                GestureDetector(
                  onTap: _showScanQrModal,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '📷 Quét QR nhận hàng',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 19),
                    ),
                  ),
                ),
                Container(
                  color: AppColors.card,
                  child: Row(
                    children: [
                      _sellerOrderSubTab(0, 'Cần xác nhận (${pendingList.length})'),
                      _sellerOrderSubTab(1, 'Đã giao (${completedList.length})'),
                    ],
                  ),
                ),
                Expanded(
                  child: displayList.isEmpty
                      ? const Center(
                          child: Text('Không có đơn hàng nào.',
                              style: TextStyle(color: AppColors.mute)))
                      : ListView.builder(
                              padding: const EdgeInsets.only(top: 6),
                              itemCount: displayList.length,
                              itemBuilder: (context, index) {
                                final ord = displayList[index];
                                final isPending = ord.isPending;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(12),
                                  color: AppColors.card,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                '#${ord.pickupCode} · ${ord.buyerName}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14)),
                                            const SizedBox(height: 2),
                                            Text(
                                                '${ord.dealTitle} × ${ord.quantity} · nhận ${ord.pickupSlot}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.mute)),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isPending
                                                    ? AppColors.priceBg
                                                    : AppColors.greenLight,
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              ),
                                              child: Text(
                                                isPending
                                                    ? 'Chờ nhận'
                                                    : 'Đã giao thành công',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isPending
                                                      ? AppColors.price
                                                      : AppColors.greenDark,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isPending)
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.greenLight,
                                            foregroundColor:
                                                AppColors.greenDark,
                                            elevation: 0,
                                          ),
                                          onPressed: () => _confirmOrder(ord),
                                          child: const Text('Xác nhận',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            );
  }

  Widget _sellerOrderSubTab(int idx, String title) {
    final active = orderSubTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => orderSubTab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: active ? AppColors.green : AppColors.line, width: active ? 2.5 : 1),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.normal,
              color: active ? AppColors.green : AppColors.mute,
            ),
          ),
        ),
      ),
    );
  }

  /// Xác nhận giao hàng qua Cloud Function `confirmPickup` (Phase 4):
  /// server chốt COMPLETED + thanh toán khi nhận + hoa hồng 10%.
  Future<void> _confirmOrder(FirestoreOrder ord) async {
    try {
      await OrderService.confirmPickup(ord.pickupCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã xác nhận giao đơn #${ord.pickupCode}! Khách được +25 điểm xanh.'),
          backgroundColor: AppColors.green,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  void _showScanQrModal() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('📷 Quét / Nhập mã nhận hàng'),
        content: TextField(
          controller: codeCtrl,
          decoration: const InputDecoration(
            labelText: 'Mã đơn (VD: A2417)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Đóng')),
          FilledButton(
            onPressed: () async {
              final input = codeCtrl.text;
              Navigator.pop(dialogContext);
              try {
                await OrderService.confirmPickup(input);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Đã xác nhận giao đơn #${input.trim().toUpperCase().replaceAll('#', '')}! Khách được +25 điểm xanh.'),
                    backgroundColor: AppColors.green,
                  ),
                );
              } on ApiException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ ${e.message}'),
                    backgroundColor: AppColors.hot,
                  ),
                );
              }
            },
            child: const Text('Xác nhận giao'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: DOANH THU 7 NGÀY
  // ==========================================
  Widget _buildRevenueTab() {
    // Dữ liệu từ _stats (nạp bằng listen() ở initState — xem ghi chú ở
    // khai báo field). Không còn StreamBuilder nên không kẹt tải/nhấp nháy.
    final stats = _stats;
    final byDay = {for (final st in stats) st.dayKey: st};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Biểu đồ: 7 ngày gần nhất (cũ -> mới), kể cả ngày chưa có đơn.
    final weekDays =
        List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final weekRevenue = weekDays
        .map((d) => byDay[StatsService.dayKeyOf(d)]?.revenue ?? 0)
        .toList();
    final maxRev = weekRevenue.fold<int>(0, (a, b) => b > a ? b : a);

    // Tổng theo khoảng đang chọn: Hôm nay / 7 ngày / 30 ngày.
    final rangeDays = revenueRangeTab == 0 ? 1 : revenueRangeTab == 1 ? 7 : 30;
    final fromKey =
        StatsService.dayKeyOf(today.subtract(Duration(days: rangeDays - 1)));
    var totalRevenue = 0;
    var totalCommission = 0;
    for (final st in stats) {
      if (st.dayKey.compareTo(fromKey) >= 0) {
        totalRevenue += st.revenue;
        totalCommission += st.commission;
      }
    }
    final net = totalRevenue - totalCommission;

    return Column(
      children: [
        _sellerHeader('Doanh thu'),
        Container(
          color: AppColors.card,
          child: Row(
            children: [
              _revSubTab(0, 'Hôm nay'),
              _revSubTab(1, 'Tuần này'),
              _revSubTab(2, 'Tháng'),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                height: 150,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (i) {
                    final rev = weekRevenue[i];
                    final ratio = maxRev == 0 ? 0.0 : rev / maxRev;
                    final isPeak = maxRev > 0 && rev == maxRev;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 28,
                          height: 3 + 92 * ratio,
                          decoration: BoxDecoration(
                            color: isPeak ? AppColors.price : AppColors.green,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(_weekdayLabel(weekDays[i]),
                            style: const TextStyle(
                                fontSize: 10.5, color: AppColors.mute)),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tổng thu',
                            style: TextStyle(color: AppColors.mute)),
                        Text(AppData.formatVnd(totalRevenue),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            'Hoa hồng sàn (${FeeStage.commissionPercentForStage(FeeStage.stageOf(_storeCreatedAt, DateTime.now()))}%)',
                            style: const TextStyle(color: AppColors.mute)),
                        Text('-${AppData.formatVnd(totalCommission)}',
                            style: const TextStyle(
                                color: AppColors.hot,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Thực nhận',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(AppData.formatVnd(net),
                            style: const TextStyle(
                                color: AppColors.price,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hoa hồng còn nợ',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Đã ghi nhận',
                            style: TextStyle(color: AppColors.mute)),
                        Text(AppData.formatVnd(_ledgerRecorded),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Đã thanh toán',
                            style: TextStyle(color: AppColors.mute)),
                        Text(AppData.formatVnd(_ledgerPaid),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Còn nợ',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          AppData.formatVnd(_ledgerRecorded - _ledgerPaid),
                          style: const TextStyle(
                              color: AppColors.hot,
                              fontWeight: FontWeight.w800,
                              fontSize: 16),
                        ),
                      ],
                    ),
                    if (_ledgerRecorded - _ledgerPaid > 0) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _reportSettlement,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Báo đã chuyển khoản (giả lập)',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      'Tiền thật chuyển khoản ngoài app, admin duyệt là trừ nợ.',
                      style: TextStyle(color: AppColors.mute, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (totalRevenue == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text(
                      'Chưa có doanh thu trong khoảng này. Số liệu cập nhật khi có đơn hoàn thành.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.mute, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _revSubTab(int idx, String label) {
    final active = revenueRangeTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => revenueRangeTab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: active ? AppColors.green : AppColors.line, width: active ? 2.5 : 1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.normal,
              color: active ? AppColors.green : AppColors.mute,
            ),
          ),
        ),
      ),
    );
  }

  String get _feeLabel {
    final exp = _storeFeeExpiresAt;
    if (exp == null) return 'chưa có hạn';
    return 'đến ${exp.day}/${exp.month}';
  }

  Future<void> _loadLedger() async {
    final storeId = AuthService.currentUser?.uid;
    if (storeId == null) return;
    try {
      final ledger = await SettlementService.loadLedger(storeId);
      if (!mounted) return;
      setState(() {
        _ledgerRecorded = ledger.recorded;
        _ledgerPaid = ledger.paid;
      });
    } catch (_) {}
  }

  Future<void> _reportSettlement() async {
    final owed = _ledgerRecorded - _ledgerPaid;
    if (owed <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Báo đã chuyển khoản'),
        content: Text(
          'Bạn báo đã chuyển khoản ${AppData.formatVnd(owed)} tiền hoa hồng. '
          'Tiền thật chuyển ngoài app, admin duyệt là trừ nợ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tôi đã chuyển'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SettlementService.reportSettlement(owed);
      await _loadLedger();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã gửi yêu cầu đối soát, chờ admin duyệt.'),
            backgroundColor: AppColors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _showFeeRenewDialog() async {
    final exp = _storeFeeExpiresAt;
    final expText = exp == null
        ? 'chưa có hạn'
        : '${exp.day}/${exp.month}/${exp.year}';
    // Gói Túi + Phí: dialog theo giai đoạn + công khai toàn bộ biểu phí
    // để quán biết trước lộ trình, không bị tăng giá bất ngờ.
    final stage = FeeStage.stageOf(_storeCreatedAt, DateTime.now());
    final commission = FeeStage.commissionPercentForStage(stage);
    final isFree = stage == 1;
    final amount = FeeStage.amountForStage(stage);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Gia hạn gian hàng'),
        content: Text(
          isFree
              ? 'Bạn đang ở Giai đoạn 1 — Miễn phí đến $expText, hoa hồng hiện tại: 5%. Chưa cần gia hạn.\n\n${FeeStage.scheduleText}'
              : 'Hạn duy trì hiện tại: $expText\n'
                  'Bạn đang ở Giai đoạn $stage — gia hạn 1 tháng: ${AppData.formatVnd(amount)} (giả lập, không cần admin duyệt). Hoa hồng hiện tại: $commission%. Hết hạn thì không đăng được suất mới.\n\n${FeeStage.scheduleText}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isFree ? 'Đóng' : 'Để sau'),
          ),
          if (!isFree)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tôi đã thanh toán'),
            ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await SettlementService.renewShopFee();
      if (!mounted) return;
      final paid = (res['amount'] as num?)?.round() ?? amount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Đã gia hạn gian hàng 1 tháng (${AppData.formatVnd(paid)})!'),
            backgroundColor: AppColors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  String _fmtRating(double r) => r.toStringAsFixed(1).replaceAll('.', ',');

  /// Phase 6: sửa hồ sơ cửa hàng -> lưu qua API updateStoreProfile.
  /// Giao diện tự cập nhật nhờ stream _storeSub, không cần nạp tay.
  Future<void> _showStoreEditDialog() async {
    final nameCtrl = TextEditingController(text: _storeName);
    final addressCtrl = TextEditingController(text: _storeAddress);
    final phoneCtrl = TextEditingController(text: _storePhone ?? '');
    final hoursCtrl = TextEditingController(text: _storeOpenHours ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thông tin cửa hàng'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tên cửa hàng'),
              ),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
              ),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
              ),
              TextField(
                controller: hoursCtrl,
                decoration: const InputDecoration(
                    labelText: 'Giờ mở cửa', hintText: 'VD: 07:00 – 22:00'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await StoreService.updateProfile(
        name: nameCtrl.text.trim(),
        address: addressCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        openHours: hoursCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thông tin cửa hàng.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  /// Phase 7: nhãn trạng thái chứng nhận ATTP cho mục menu.
  String get _certStatusLabel {
    switch (_certStatus) {
      case 'pending':
        return 'đang chờ duyệt';
      case 'approved':
        return 'đã duyệt ✓';
      case 'rejected':
        return 'bị từ chối — nộp lại';
      default:
        return 'chưa nộp';
    }
  }

  /// Phase 7: hộp thoại giấy chứng nhận ATTP — xem trạng thái + ảnh
  /// đã nộp, và nộp (lại) ảnh. Trạng thái tự cập nhật nhờ _storeSub
  /// sau khi server ghi Firestore / admin duyệt trong Console.
  Future<void> _showCertDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Giấy chứng nhận ATTP'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trạng thái: $_certStatusLabel'),
              if (_certStatus == 'rejected' &&
                  _certReviewNote != null &&
                  _certReviewNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Lý do từ chối: $_certReviewNote'),
              ],
              if (_certUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _certUrl!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Text('(Không tải được ảnh đã nộp)'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Nộp ảnh giấy chứng nhận cơ sở đủ điều kiện an toàn thực '
                'phẩm. Sau khi được duyệt, khách hàng sẽ thấy huy hiệu '
                '"Đã kiểm chứng an toàn thực phẩm" ở trang chi tiết món '
                'của quán.',
                style: TextStyle(fontSize: 12.5, color: AppColors.mute),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _submitCertificateFlow();
            },
            child:
                Text(_certStatus == 'none' ? 'Chọn ảnh & nộp' : 'Nộp lại ảnh'),
          ),
        ],
      ),
    );
  }

  /// Phase 7: chọn ảnh -> tải lên -> báo kết quả bằng SnackBar.
  Future<void> _submitCertificateFlow() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await StoreService.pickCertificateImage();
      if (bytes == null || !mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Đang tải ảnh chứng nhận lên...')),
      );
      await StoreService.submitCertificate(bytes);
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã nộp chứng nhận. Đang chờ kiểm duyệt.')),
      );
    } on ApiException catch (e) {
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Không nộp được chứng nhận. Thử lại sau.')),
      );
    }
  }

  // ==========================================
  // TAB 4: HỒ SƠ CỬA HÀNG CỦA TÔI
  // ==========================================
  Widget _buildStoreProfileTab() {
    final items = [
      'Thông tin cửa hàng',
      (_storeOpenHours != null && _storeOpenHours!.isNotEmpty)
          ? 'Giờ mở cửa ($_storeOpenHours)'
          : 'Giờ mở cửa (chưa đặt)',
      'Địa chỉ & vị trí bản đồ',
      'Deal của tôi',
      _storeRatingCount > 0
          ? 'Đánh giá của khách (★ ${_fmtRating(_storeRating)} · $_storeRatingCount)'
          : 'Đánh giá của khách (chưa có)',
      'Giấy chứng nhận ATTP ($_certStatusLabel)',
      'Biểu đồ 7 ngày',
      'Quảng bá suất',
      'Gia hạn gian hàng ($_feeLabel)',
      'Khiếu nại',
      'Hỗ trợ',
      'Tin nhắn với khách',
      'Thông báo',
      'Chuyển sang giao diện Người mua',
      'Đăng xuất',
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.green, AppColors.greenDark]),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cửa hàng của tôi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(12)),
                      child: const Text('🥐', style: TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _storeName.isEmpty ? 'Cửa hàng của tôi' : _storeName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text(
                          _storeRatingCount > 0
                              ? '★ ${_fmtRating(_storeRating)} (${_storeRatingCount} đánh giá) · Đã duyệt ✓'
                              : 'Chưa có đánh giá · Đã duyệt ✓',
                          style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
            itemBuilder: (context, index) {
              return ListTile(
                tileColor: AppColors.card,
                title: Text(items[index], style: const TextStyle(fontSize: 14)),
                trailing: const Text('›', style: TextStyle(color: AppColors.mute, fontSize: 18)),
                onTap: () async {
                  final title = items[index];
                  if (title == 'Thông tin cửa hàng' ||
                      title.startsWith('Giờ mở cửa') ||
                      title == 'Địa chỉ & vị trí bản đồ') {
                    _showStoreEditDialog();
                  } else if (title == 'Deal của tôi') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SellerDealsScreen()),
                    );
                  } else if (title.startsWith('Đánh giá của khách')) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SellerReviewsScreen()),
                    );
                  } else if (title.startsWith('Giấy chứng nhận ATTP')) {
                    _showCertDialog();
                  } else if (title == 'Biểu đồ 7 ngày') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WeekChartScreen()),
                    );
                  } else if (title == 'Quảng bá suất') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PromotionScreen()),
                    );
                  } else if (title.startsWith('Gia hạn gian hàng')) {
                    _showFeeRenewDialog();
                  } else if (title == 'Khiếu nại') {
                    final sid = AuthService.currentUser?.uid;
                    if (sid != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ComplaintsScreen(storeId: sid)),
                      );
                    }
                  } else if (title == 'Hỗ trợ') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SupportScreen()),
                    );
                  } else if (title == 'Tin nhắn với khách') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const ChatListScreen(asSeller: true)),
                    );
                  } else if (title == 'Thông báo') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    );
                  } else if (title == 'Chuyển sang giao diện Người mua') {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BuyerHomeScreen()));
                  } else if (title == 'Đăng xuất') {
                    await AuthService.signOut();
                    if (!context.mounted) return;
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
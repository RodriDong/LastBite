import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/mock_data.dart';
import '../models/deal.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/deal_service.dart';
import '../services/directions.dart';
import '../services/order_service.dart';
import '../services/api_service.dart';
import '../services/review_service.dart';
import '../services/user_service.dart';
import 'auth_screen.dart';
import 'box_detail_screen.dart';
import 'chat_list_screen.dart';
import 'seller_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/favorite_service.dart';
import '../services/notification_service.dart';
import '../services/voucher_service.dart';
import '../services/promotion_service.dart';
import 'admin_promotion_screen.dart';
import 'admin_settlement_screen.dart';
import 'admin_support_screen.dart';
import 'support_screen.dart';
import '../theme/app_theme.dart';
import 'admin_cert_screen.dart';
import 'favorites_screen.dart';
import 'notifications_screen.dart';
import 'order_detail_screen.dart';

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  int currentTab = 0;
  int orderFilterTab = 0; // 0: Đang chờ lấy, 1: Đã hoàn thành, 2: Đã hủy

  // Đơn thật của buyer theo 3 trạng thái, nạp bằng listen() ở initState
  // (giống _dealSub — ổn định từ Phase 3). Không dùng StreamBuilder cho
  // tab này: cặp StreamBuilder/stream từng gây nhấp nháy và kẹt tải.
  List<FirestoreOrder> _myPending = [];
  List<FirestoreOrder> _myCompleted = [];
  List<FirestoreOrder> _myCancelled = [];
  StreamSubscription<List<FirestoreOrder>>? _orderSub1;
  StreamSubscription<List<FirestoreOrder>>? _orderSub2;
  StreamSubscription<List<FirestoreOrder>>? _orderSub3;
  UserProfile _profile = const UserProfile();
  StreamSubscription<UserProfile>? _profileSub;
  int mapFilterChip = -1; // -1: tất cả; 0: <1km, 1: giảm sâu, 2: sắp hết giờ
  SurpriseBox? selectedMapBox;
  // Phase 9: vị trí thật của buyer (null = điểm tham chiếu Cầu Giấy)
  // + bộ điều khiển bản đồ tab Khám phá.
  LatLng? _myLatLng;
  List<Deal> _lastDeals = [];
  final MapController _mapController = MapController();
  String searchQuery = '';
  String selectedCategory = 'Tất cả';
  // Bản Hoàn thiện: sắp xếp + yêu thích + badge thông báo + cờ admin.
  String _sortMode = 'soon'; // soon | discount | near
  Set<String> _favIds = {};
  StreamSubscription? _favSub;
  int _unreadCount = 0;
  StreamSubscription? _notifSub;
  StreamSubscription<List<Voucher>>? _vouchSub;
  List<Voucher> _vouchers = [];
  StreamSubscription<Set<String>>? _promoSub;
  Set<String> _promotedIds = {};
  bool _isAdmin = false;
  Timer? _timer;
  // Phase 3: deal thật từ Firestore (thay cho AppData.boxes mock).
  List<SurpriseBox> _boxes = [];
  StreamSubscription<List<Deal>>? _dealSub;

  @override
  void initState() {
    super.initState();
    // Phase 3: nghe deal thật từ Firestore thay cho mock.
    // Nếu Firebase chưa được cấu hình (chế độ mock), giữ dữ liệu mẫu cũ.
    try {
      _dealSub = DealService.activeDeals().listen((deals) {
        if (!mounted) return;
        _lastDeals = deals;
        setState(() {
          _boxes = deals.map((d) => d.toSurpriseBox(from: _myLatLng)).toList();
          if (_boxes.isEmpty) {
            selectedMapBox = null;
          } else if (selectedMapBox == null ||
              !_boxes.any((b) => b.id == selectedMapBox!.id)) {
            selectedMapBox = _boxes.first;
          }
        });
      });
      _orderSub1 = OrderService.myOrders('PENDING').listen((list) {
        if (!mounted) return;
        setState(() => _myPending = list);
      });
      _orderSub2 = OrderService.myOrders('COMPLETED').listen((list) {
        if (!mounted) return;
        setState(() => _myCompleted = list);
      });
      _orderSub3 = OrderService.myOrders('CANCELLED').listen((list) {
        if (!mounted) return;
        setState(() => _myCancelled = list);
      });
      _profileSub = UserService.myProfile().listen((p) {
        if (!mounted) return;
        setState(() => _profile = p);
      });
      _favSub = FavoriteService.favoriteStoreIds().listen((ids) {
        if (mounted) setState(() => _favIds = ids);
      });
      _notifSub = NotificationService.unreadCount().listen((n) {
        if (mounted) setState(() => _unreadCount = n);
      });
      final myUid = AuthService.currentUser?.uid;
      if (myUid != null) {
        _vouchSub = VoucherService.myVouchers(myUid).listen((list) {
          if (mounted) setState(() => _vouchers = list);
        });
      }
      _promoSub = PromotionService.activeDealIds().listen((ids) {
        if (mounted) setState(() => _promotedIds = ids);
      });
      _loadAdminFlag();
    } catch (_) {
      _boxes = AppData.boxes;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _initMyLocation();
  }

  Future<void> _loadAdminFlag() async {
    try {
      final v = await AuthService.isAdmin();
      if (mounted) setState(() => _isAdmin = v);
    } catch (_) {}
  }

  /// Phase 9: xin quyền + lấy vị trí thật của buyer để tính khoảng
  /// cách đúng và hiện chấm vị trí trên bản đồ. Bị từ chối/lỗi thì
  /// giữ điểm tham chiếu Cầu Giấy — app vẫn chạy bình thường.
  Future<void> _initMyLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _myLatLng = LatLng(pos.latitude, pos.longitude);
        _boxes =
            _lastDeals.map((d) => d.toSurpriseBox(from: _myLatLng)).toList();
      });
    } catch (_) {
      // Không có GPS/quyền — bỏ qua, dùng điểm tham chiếu.
    }
  }

  @override
  void dispose() {
    _dealSub?.cancel();
    _orderSub1?.cancel();
    _orderSub2?.cancel();
    _orderSub3?.cancel();
    _profileSub?.cancel();
    _favSub?.cancel();
    _notifSub?.cancel();
    _vouchSub?.cancel();
    _promoSub?.cancel();
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
          _buildHomeTab(),
          _buildExploreMapTab(),
          _buildOrdersTab(),
          _buildRewardsTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
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
            BottomNavigationBarItem(icon: Text('🏠', style: TextStyle(fontSize: 18)), label: 'Trang chủ'),
            BottomNavigationBarItem(icon: Text('📍', style: TextStyle(fontSize: 18)), label: 'Khám phá'),
            BottomNavigationBarItem(icon: Text('🧾', style: TextStyle(fontSize: 18)), label: 'Đơn hàng'),
            BottomNavigationBarItem(icon: Text('🎁', style: TextStyle(fontSize: 18)), label: 'Ưu đãi'),
            BottomNavigationBarItem(icon: Text('👤', style: TextStyle(fontSize: 18)), label: 'Tôi'),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 0: TRANG CHỦ
  // ==========================================
  Widget _buildHomeTab() {
    final activeBoxes = _boxes.where((b) {
      if (!b.isActive) return false;
      if (b.remainingSeconds <= 0) return false; // hết giờ: chờ server flip status
      if (selectedCategory != 'Tất cả' && b.category != selectedCategory) return false;
      if (searchQuery.isNotEmpty &&
          !b.title.toLowerCase().contains(searchQuery.toLowerCase()) &&
          !b.storeName.toLowerCase().contains(searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    // Bản Hoàn thiện: sắp xếp theo lựa chọn của người dùng.
    if (_sortMode == 'discount') {
      activeBoxes.sort((a, b) =>
          b.currentDiscountPercent.compareTo(a.currentDiscountPercent));
    } else if (_sortMode == 'near') {
      final origin = _myLatLng ?? const LatLng(21.0368, 105.7900);
      final distCalc = Distance();
      double dist(SurpriseBox b) =>
          distCalc.as(LengthUnit.Meter, origin, LatLng(b.lat, b.lng));
      activeBoxes.sort((a, b) => dist(a).compareTo(dist(b)));
    }

    final featuredBoxes =
        activeBoxes.where((b) => _promotedIds.contains(b.id)).toList();

    final flashBoxes = [..._boxes.where((b) => b.isActive && b.remainingSeconds > 0)]
      ..sort((a, b) => a.remainingSeconds.compareTo(b.remainingSeconds));

    // Phase 9: danh mục dùng chung DealCategories (khớp form đăng
    // deal của seller + validator server) + mục Tất cả ở cuối.
    final categories = [
      ...DealCategories.all,
      ['➕', 'Tất cả'],
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.green, AppColors.greenDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          onChanged: (v) => setState(() => searchQuery = v),
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: '🔍 Tìm món, quán gần bạn…',
                            hintStyle: TextStyle(color: AppColors.mute, fontSize: 12.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen()),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Text('🔔', style: TextStyle(fontSize: 20)),
                          if (_unreadCount > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: const BoxDecoration(
                                  color: AppColors.hot,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  _unreadCount > 9 ? '9+' : '$_unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => setState(() => currentTab = 2),
                      child: const Text('🛒', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SellerScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)),
                        child: const Text('🏪 Quán', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '📍 Giao nhận quanh Cầu Giấy, Hà Nội',
                  style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Banner
              Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.lime, AppColors.green]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cứu bữa ngon\ngiảm đến 70%',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0E3B20),
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Giá giảm dần mỗi giờ',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF0E3B20)),
                        ),
                      ],
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/icon/icon.png',
                        width: 56,
                        height: 56,
                        errorBuilder: (_, __, ___) =>
                            const Text('🌿', style: TextStyle(fontSize: 48)),
                      ),
                    ),
                  ],
                ),
              ),

              // Lưới 8 danh mục
              Container(
                color: AppColors.card,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1.1,
                  ),
                  itemBuilder: (context, idx) {
                    final cat = categories[idx];
                    final isSelected = selectedCategory == cat[1];
                    return GestureDetector(
                      onTap: () => setState(() => selectedCategory = cat[1]),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.lime : AppColors.greenLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(cat[0], style: const TextStyle(fontSize: 22)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat[1],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Dải Flash Sale: SẮP HẾT GIỜ
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                color: AppColors.card,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text(
                          '⚡ GIỜ VÀNG',
                          style: TextStyle(color: AppColors.hot, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(5)),
                          child: Text(
                            AppData.formatCountdown(flashBoxes.isNotEmpty ? flashBoxes.first.remainingSeconds : 1520),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Spacer(),
                        const Text('Xem tất cả ›', style: TextStyle(color: AppColors.mute, fontSize: 11.5)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 178,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: flashBoxes.take(4).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return SizedBox(
                            width: 130,
                            child: _buildDealCard(flashBoxes[index], isMini: true),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gợi ý gần bạn',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.greenDark),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _sortChip('soon', 'Sắp kết thúc'),
                        const SizedBox(width: 8),
                        _sortChip('discount', 'Giảm nhiều nhất'),
                        const SizedBox(width: 8),
                        _sortChip('near', 'Gần nhất'),
                      ],
                    ),
                  ],
                ),
              ),

              if (featuredBoxes.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: Text(
                    '⭐ Nổi bật trên trang chủ',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.greenDark),
                  ),
                ),
                SizedBox(
                  height: 196,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemCount: featuredBoxes.length,
                    itemBuilder: (_, i) => _featuredCard(featuredBoxes[i]),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (activeBoxes.isEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Column(
                    children: [
                      Text('🍽️', style: TextStyle(fontSize: 40)),
                      SizedBox(height: 8),
                      Text(
                        'Chưa có deal nào đang bán',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Quán đăng deal mới sẽ hiện ở đây ngay.',
                        style: TextStyle(color: AppColors.mute, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeBoxes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) {
                    return _buildDealCard(activeBoxes[index], isMini: false);
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _featuredCard(SurpriseBox box) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => BoxDetailScreen(box: box)));
        setState(() {});
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 88,
              width: double.infinity,
              child: box.imageUrl != null
                  ? Image.network(
                      box.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.greenLight,
                        alignment: Alignment.center,
                        child: Text(box.emoji,
                            style: const TextStyle(fontSize: 36)),
                      ),
                    )
                  : Container(
                      color: AppColors.greenLight,
                      alignment: Alignment.center,
                      child: Text(box.emoji,
                          style: const TextStyle(fontSize: 36)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    box.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, height: 1.25),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    box.isGift
                        ? 'Miễn phí 🎁'
                        : AppData.formatVnd(box.currentDynamicPrice),
                    style: const TextStyle(
                        color: AppColors.price,
                        fontWeight: FontWeight.w800,
                        fontSize: 14),
                  ),
                  Text(
                    box.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.mute, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealCard(SurpriseBox box, {required bool isMini}) {
    final price = box.currentDynamicPrice;
    final discount = box.currentDiscountPercent;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => BoxDetailScreen(box: box)));
        setState(() {});
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
          boxShadow: LTheme.softShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: isMini ? 82 : 94,
                  width: double.infinity,
                  child: box.imageUrl != null
                      ? Image.network(
                          box.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.greenLight,
                            alignment: Alignment.center,
                            child: Text(box.emoji,
                                style: const TextStyle(fontSize: 42)),
                          ),
                        )
                      : Container(
                          color: AppColors.greenLight,
                          alignment: Alignment.center,
                          child: Text(box.emoji,
                              style: const TextStyle(fontSize: 42)),
                        ),
                ),
                if (box.storeId.isNotEmpty)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: GestureDetector(
                      onTap: () async {
                        try {
                          await FavoriteService.toggle(
                            storeId: box.storeId,
                            storeName: box.storeName,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Lỗi: $e')),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _favIds.contains(box.storeId) ? '❤️' : '🤍',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.priceBg,
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
                    ),
                    child: Text(
                      '-$discount%',
                      style: const TextStyle(color: AppColors.price, fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: box.isUrgent ? AppColors.hot : const Color(0xD123302A),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '⏱ ${AppData.formatCountdown(box.remainingSeconds)}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (_promotedIds.contains(box.id) || box.isGift)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Row(
                      children: [
                        if (_promotedIds.contains(box.id))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.price,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text('⭐ Nổi bật',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        if (box.isGift) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text('🎁 Tặng',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 32,
                    child: Text(
                      box.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.25),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        box.isGift ? 'Miễn phí 🎁' : AppData.formatVnd(price),
                        style: const TextStyle(color: AppColors.price, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      if (!isMini && !box.isGift) ...[
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            AppData.formatVnd(box.originalPrice),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.mute,
                              fontSize: 10.5,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Stack(
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.hotBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: box.stockRatio,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF9A3C), AppColors.hot]),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Center(
                          child: Text(
                            'Còn ${box.remainingQty}/${box.totalQty}',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isMini) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${box.storeName} · ${box.distanceKm}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.mute),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortChip(String mode, String label) {
    final selected = _sortMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _sortMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : AppColors.card,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: selected ? AppColors.green : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: KHÁM PHÁ (BẢN ĐỒ)
  // ==========================================
  Widget _buildExploreMapTab() {
    final activeBoxes =
        _boxes.where((b) => b.isActive && b.remainingSeconds > 0).toList();
    if (activeBoxes.isEmpty) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.green, AppColors.greenDark]),
            ),
            child: const SafeArea(
              bottom: false,
              child: Text(
                '📍 Khám phá',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Chưa có deal nào trên bản đồ.\nQuán đăng deal mới sẽ hiện ở đây ngay.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mute, fontSize: 13),
              ),
            ),
          ),
        ],
      );
    }
    // Phase 9: chip lọc bản đồ giờ LỌC THẬT (trước đây chỉ đổi màu).
    // Khoảng cách tính từ vị trí thật của buyer (hoặc điểm tham chiếu).
    final origin = _myLatLng ?? const LatLng(21.0368, 105.7900);
    final distCalc = Distance();
    final mapBoxes = activeBoxes.where((b) {
      if (mapFilterChip == 0) {
        return distCalc(origin, LatLng(b.lat, b.lng)) <= 1000;
      }
      if (mapFilterChip == 1) return b.currentDiscountPercent >= 40;
      if (mapFilterChip == 2) return b.remainingSeconds <= 3600;
      return true;
    }).toList();
    final SurpriseBox? currentBox = mapBoxes.isEmpty
        ? null
        : (selectedMapBox != null &&
                mapBoxes.any((b) => b.id == selectedMapBox!.id)
            ? mapBoxes.firstWhere((b) => b.id == selectedMapBox!.id)
            : mapBoxes.first);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.green, AppColors.greenDark]),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: const Text('🔍 Tìm trên bản đồ', style: TextStyle(color: AppColors.mute, fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('☰', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
          ),
        ),
        Container(
          color: AppColors.app,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _mapChip(0, 'Dưới 1 km'),
              const SizedBox(width: 8),
              _mapChip(1, 'Giảm sâu'),
              const SizedBox(width: 8),
              _mapChip(2, 'Giờ vàng'),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _myLatLng ?? const LatLng(21.0368, 105.7900),
                  initialZoom: 14.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.lastbite.app',
                  ),
                  MarkerLayer(
                    markers: mapBoxes.map((box) {
                      final isHot = box.currentDiscountPercent >= 60;
                      return Marker(
                        point: LatLng(box.lat, box.lng),
                        width: 54,
                        height: 34,
                        child: GestureDetector(
                          onTap: () => setState(() => selectedMapBox = box),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isHot ? AppColors.hot : const Color(0xFFF5A524),
                              borderRadius: BorderRadius.circular(99),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: Text(
                              '${box.currentDiscountPercent}%',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // Phase 9: chấm vị trí của tôi trên bản đồ.
                  if (_myLatLng != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _myLatLng!,
                          width: 22,
                          height: 22,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4)
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (currentBox != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => BoxDetailScreen(box: currentBox)));
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
                          child: Text(currentBox.emoji, style: const TextStyle(fontSize: 32)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(currentBox.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              const SizedBox(height: 2),
                              Text('${currentBox.storeName} · ${currentBox.distanceKm}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.mute)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    AppData.formatVnd(currentBox.currentDynamicPrice),
                                    style: const TextStyle(color: AppColors.price, fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppData.formatVnd(currentBox.originalPrice),
                                    style: const TextStyle(
                                      color: AppColors.mute,
                                      fontSize: 11,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    AppData.formatCountdown(currentBox.remainingSeconds),
                                    style: const TextStyle(color: AppColors.hot, fontWeight: FontWeight.w700, fontSize: 11.5),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: () => Directions.open(
                                      currentBox.lat, currentBox.lng),
                                  icon: const Text('🧭',
                                      style: TextStyle(fontSize: 13)),
                                  label: const Text('Chỉ đường tới quán',
                                      style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.greenDark,
                                    side:
                                        const BorderSide(color: AppColors.line),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Phase 9: nút về vị trí của tôi.
              Positioned(
                right: 12,
                top: 12,
                child: GestureDetector(
                  onTap: () {
                    if (_myLatLng != null) {
                      _mapController.move(_myLatLng!, 15);
                    } else {
                      _initMyLocation();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Đang lấy vị trí của bạn...')),
                      );
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 6)
                      ],
                    ),
                    child: const Text('🎯', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
              if (mapBoxes.isEmpty)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8)
                      ],
                    ),
                    child: const Text(
                      'Không có deal nào khớp bộ lọc này. Bấm lại chip để bỏ lọc.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.mute, fontSize: 12.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mapChip(int idx, String label) {
    final active = mapFilterChip == idx;
    return GestureDetector(
      onTap: () => setState(() => mapFilterChip = active ? -1 : idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.greenLight : AppColors.card,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: active ? AppColors.green : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? AppColors.greenDark : AppColors.ink,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: ĐƠN HÀNG CỦA TÔI & HIỂN THỊ MÃ QR
  // ==========================================
  Widget _buildOrdersTab() {
    final filtered = orderFilterTab == 0
        ? _myPending
        : orderFilterTab == 1
            ? _myCompleted
            : _myCancelled;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.green, AppColors.greenDark]),
          ),
          child: const SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Đơn hàng của tôi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                Text('💬', style: TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ),
        Container(
          color: AppColors.card,
          child: Row(
            children: [
              _orderSubTab(0, 'Đang chờ lấy'),
              _orderSubTab(1, 'Đã hoàn thành'),
              _orderSubTab(2, 'Đã hủy'),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('Chưa có đơn hàng nào ở mục này.',
                      style: TextStyle(color: AppColors.mute)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final ord = filtered[index];
                    final isPending = ord.isPending;
                    final statusLabel = ord.isPending
                        ? 'Chờ lấy'
                        : ord.isCompleted
                            ? 'Đã hoàn thành'
                            : 'Đã hủy';
                    final badgeColor = ord.isPending
                        ? AppColors.priceBg
                        : ord.isCompleted
                            ? AppColors.greenLight
                            : AppColors.hotBg;
                    final badgeTextColor = ord.isPending
                        ? AppColors.price
                        : ord.isCompleted
                            ? AppColors.greenDark
                            : AppColors.hot;
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailScreen(order: ord),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        color: AppColors.card,
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: AppColors.greenLight,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(ord.dealIcon,
                                  style: const TextStyle(fontSize: 28)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ord.dealTitle,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${ord.storeName} · ×${ord.quantity} · ${AppData.formatVnd(ord.totalLockedPrice)}',
                                    style: const TextStyle(
                                        fontSize: 11.5, color: AppColors.mute),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: badgeColor,
                                          borderRadius:
                                              BorderRadius.circular(99),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: badgeTextColor,
                                          ),
                                        ),
                                      ),
                                      if (isPending) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          'Còn ${AppData.formatCountdown(ord.remainingSeconds)}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.hot,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.qr_code_2,
                                color: AppColors.greenDark, size: 28),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _orderSubTab(int idx, String label) {
    final active = orderFilterTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => orderFilterTab = idx),
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

  void _showOrderQrSheet(FirestoreOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(99)),
              child: Text(
                'Đặt thành công · #${order.pickupCode}',
                style: const TextStyle(color: AppColors.greenDark, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: QrImageView(data: order.pickupCode, size: 170),
            ),
            const SizedBox(height: 12),
            const Text('Đưa mã này cho quán', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
            const SizedBox(height: 4),
            Text(
              '${order.storeName} · nhận ${order.pickupSlot}',
              style: const TextStyle(color: AppColors.mute, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.hot, Color(0xFFFF8A3C)]),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                'Mã xác nhận: ${order.pickupCode}  |  Còn lại ${AppData.formatCountdown(order.remainingSeconds)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            if (order.isPending) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _cancelOrder(order, sheetContext),
                child: const Text('Hủy đơn hàng',
                    style: TextStyle(color: AppColors.hot, fontWeight: FontWeight.w700)),
              ),
            ],
            if (order.isCompleted) ...[
              const SizedBox(height: 8),
              if (order.reviewed)
                Text(
                  'Bạn đã đánh giá ★${order.reviewRating} cho đơn này',
                  style: const TextStyle(
                      color: AppColors.greenDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                )
              else
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _showReviewDialog(order);
                  },
                  child: const Text('Đánh giá đơn này'),
                ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Đánh giá đơn COMPLETED (Phase 6): chọn sao + nhận xét -> API
  /// submitReview (server cập nhật luôn điểm trung bình của quán).
  Future<void> _showReviewDialog(FirestoreOrder order) async {
    var stars = 5;
    final commentCtrl = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Đánh giá đơn hàng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.dealTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setDialogState(() => stars = i),
                      icon: Icon(
                        i <= stars ? Icons.star : Icons.star_border,
                        color: const Color(0xFFFFA000),
                        size: 30,
                      ),
                    ),
                ],
              ),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Nhận xét (không bắt buộc)',
                  hintText: 'Đồ ăn thế nào, đóng gói ra sao...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Gửi đánh giá'),
            ),
          ],
        ),
      ),
    );
    if (sent != true) return;
    try {
      await ReviewService.submit(
        orderId: order.id,
        rating: stars,
        comment: commentCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cảm ơn bạn đã đánh giá!')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  /// Hủy đơn PENDING qua Cloud Function `cancelOrder` (server hoàn kho).
  Future<void> _cancelOrder(FirestoreOrder order, BuildContext sheetContext) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hủy đơn hàng?'),
        content: Text('Đơn #${order.pickupCode} sẽ bị hủy và phần ăn được mở bán lại.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await OrderService.cancelOrder(order.id);
      if (!mounted) return;
      Navigator.pop(sheetContext);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã hủy đơn hàng.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  // ==========================================
  // TAB 3: ƯU ĐÃI / ĐIỂM THƯỞNG
  // ==========================================
  Widget _buildRewardsTab() {
    final profile = _profile;
    final points = profile.greenPoints;
    final remaining = 2000 - points > 0 ? 2000 - points : 0;
    final progress = (points / 2000).clamp(0.0, 1.0);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.green, AppColors.greenDark]),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Điểm xanh của bạn', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                '$points điểm',
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
              ),
              Text(
                'Còn $remaining điểm để lên huy hiệu "Chiến binh xanh"',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.white30,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.lime),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppData.formatVnd(profile.savedMoney),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.greenDark),
                      ),
                      const Text('Đã tiết kiệm', style: TextStyle(fontSize: 11, color: AppColors.mute)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${profile.rescuedMeals}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.greenDark),
                      ),
                      const Text('Bữa ăn đã cứu', style: TextStyle(fontSize: 11, color: AppColors.mute)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text('Huy hiệu', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.greenDark)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              _badgeItem('🌱', 'Mầm xanh', true),
              const SizedBox(width: 8),
              _badgeItem('🥬', 'Người giữ bếp', points >= 500),
              const SizedBox(width: 8),
              _badgeItem('🛡️', 'Chiến binh', points >= 2000),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Text('Đổi điểm lấy ưu đãi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.greenDark)),
        ),
        _exchangeRow('Giảm 10.000đ', 'Đơn từ 30.000đ · 100 điểm xanh', 'V10K'),
        _exchangeRow('Giảm 20.000đ', 'Đơn từ 50.000đ · 200 điểm xanh', 'V20K'),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Text('Ưu đãi của tôi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.greenDark)),
        ),
        if (_vouchers.isEmpty)
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.all(14),
            child: const Text(
              'Bạn chưa có ưu đãi nào. Đổi điểm xanh ở trên để nhận mã giảm giá dùng khi đặt đơn.',
              style: TextStyle(fontSize: 12.5, color: AppColors.mute),
            ),
          )
        else
          ..._vouchers.map((v) {
            final expired =
                v.expiresAt != null && v.expiresAt!.isBefore(DateTime.now());
            final used = v.status != 'unused';
            return Container(
              color: AppColors.card,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
                    child: const Text('🎟️', style: TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Giảm ${AppData.formatVnd(v.amount)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        Text(
                          used
                              ? 'Đã dùng'
                              : expired
                                  ? 'Đã hết hiệu lực'
                                  : 'Đơn từ ${AppData.formatVnd(v.minOrder)} · Dùng đến ${v.expiresAt!.day}/${v.expiresAt!.month}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.mute),
                        ),
                      ],
                    ),
                  ),
                  if (!used && !expired)
                    GestureDetector(
                      onTap: () => setState(() => currentTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(8)),
                        child: const Text('Đi chợ',
                            style: TextStyle(color: AppColors.greenDark, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _exchangeRow(String title, String subtitle, String tier) {
    final cost = tier == 'V10K' ? 100 : 200;
    final enough = _profile.greenPoints >= cost;
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
            child: const Text('🎟️', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.mute)),
              ],
            ),
          ),
          GestureDetector(
            onTap: enough ? () => _exchangeVoucher(tier) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: enough ? AppColors.green : AppColors.line,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Đổi',
                  style: TextStyle(
                      color: enough ? Colors.white : AppColors.mute,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exchangeVoucher(String tier) async {
    try {
      await VoucherService.exchange(tier);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã đổi ưu đãi thành công! Dùng khi đặt đơn nhé.'),
            backgroundColor: AppColors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  Widget _badgeItem(String emoji, String title, bool unlocked) {
    return Expanded(
      child: Opacity(
        opacity: unlocked ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  /// Chuyển sang giao diện Người bán: nếu tài khoản chưa có quyền
  /// (đăng ký seller lần trước bị lỗi) thì thử cấp quyền lại ngay tại
  /// đây thay vì bắt đăng ký tài khoản mới.
  Future<void> _switchToSeller() async {
    try {
      if (await AuthService.isSeller()) {
        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const SellerScreen()));
        return;
      }
      final name = AuthService.currentUser?.displayName;
      await AuthService.becomeSeller(
          storeName: (name != null && name.isNotEmpty)
              ? name
              : 'Cửa hàng của tôi');
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const SellerScreen()));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chưa cấp được quyền bán hàng: ${e.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Chưa cấp được quyền bán hàng. Thử lại sau.')),
      );
    }
  }

  /// Hồ sơ của tôi: đổi tên hiển thị + đổi mật khẩu (cần nhập mật khẩu
  /// hiện tại để xác thực lại — yêu cầu bảo mật của Firebase Auth).
  Future<void> _showProfileDialog() async {
    final nameCtrl = TextEditingController(
        text: AuthService.currentUser?.displayName ?? '');
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hồ sơ của tôi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên hiển thị',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Đổi mật khẩu (không bắt buộc)',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu mới (tối thiểu 6 ký tự)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final name = nameCtrl.text.trim();
      if (name.isNotEmpty &&
          name != (AuthService.currentUser?.displayName ?? '')) {
        await AuthService.updateDisplayName(name);
      }
      if (newCtrl.text.isNotEmpty) {
        final user = AuthService.currentUser;
        final email = user?.email ?? '';
        if (user == null || email.isEmpty) {
          throw Exception('Không xác định được tài khoản.');
        }
        if (newCtrl.text.length < 6) {
          throw Exception('Mật khẩu mới tối thiểu 6 ký tự.');
        }
        final cred = EmailAuthProvider.credential(
            email: email, password: currentCtrl.text);
        await user.reauthenticateWithCredential(cred);
        await user.updatePassword(newCtrl.text);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đã lưu hồ sơ.'),
          backgroundColor: AppColors.green,
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  // ==========================================
  // TAB 4: TÀI KHOẢN ("TÔI")
  // ==========================================
  Widget _buildProfileTab() {
    final menuItems = [
      'Tin nhắn với cửa hàng',
      'Quán yêu thích',
      'Thông báo',
      'Hồ sơ của tôi',
      'Hỗ trợ',
      if (_isAdmin) 'Duyệt chứng nhận',
      if (_isAdmin) 'Duyệt quảng bá',
      if (_isAdmin) 'Duyệt đối soát',
      if (_isAdmin) 'Hỗ trợ khách hàng',
      'Chuyển sang giao diện Người bán',
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
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tôi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('⚙️', style: TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
                      child: const Text('🙂', style: TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AuthService.currentUser?.displayName ?? AppData.userName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text('🌱 ${_profile.greenPoints} điểm xanh', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppData.formatVnd(_profile.savedMoney),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.greenDark),
                      ),
                      const Text('Đã tiết kiệm', style: TextStyle(fontSize: 11, color: AppColors.mute)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_profile.rescuedMeals}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
                      const Text('Suất đã cứu', style: TextStyle(fontSize: 11, color: AppColors.mute)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: menuItems.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
            itemBuilder: (context, index) {
              final title = menuItems[index];
              return ListTile(
                tileColor: AppColors.card,
                title: Text(title, style: const TextStyle(fontSize: 14)),
                trailing: const Text('›', style: TextStyle(color: AppColors.mute, fontSize: 18)),
                onTap: () async {
                  if (title == 'Tin nhắn với cửa hàng') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const ChatListScreen(asSeller: false)),
                    );
                  } else if (title == 'Quán yêu thích') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FavoritesScreen()),
                    );
                  } else if (title == 'Thông báo') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    );
                  } else if (title == 'Hồ sơ của tôi') {
                    _showProfileDialog();
                  } else if (title == 'Duyệt chứng nhận') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminCertScreen()),
                    );
                  } else if (title == 'Hỗ trợ') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SupportScreen()),
                    );
                  } else if (title == 'Duyệt quảng bá') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminPromotionScreen()),
                    );
                  } else if (title == 'Duyệt đối soát') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminSettlementScreen()),
                    );
                  } else if (title == 'Hỗ trợ khách hàng') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminSupportScreen()),
                    );
                  } else if (title == 'Chuyển sang giao diện Người bán') {
                    _switchToSeller();
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
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/mock_data.dart';
import 'auth_screen.dart';
import 'box_detail_screen.dart';
import 'seller_screen.dart';

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  int currentTab = 0;
  int orderFilterTab = 0; // 0: Đang chờ lấy, 1: Đã hoàn thành, 2: Đã hủy
  int mapFilterChip = 0;
  SurpriseBox? selectedMapBox;
  String searchQuery = '';
  String selectedCategory = 'Tất cả';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    selectedMapBox = AppData.boxes.first;
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
    final activeBoxes = AppData.boxes.where((b) {
      if (!b.isActive) return false;
      if (selectedCategory != 'Tất cả' && b.category != selectedCategory) return false;
      if (searchQuery.isNotEmpty &&
          !b.title.toLowerCase().contains(searchQuery.toLowerCase()) &&
          !b.storeName.toLowerCase().contains(searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    final flashBoxes = [...AppData.boxes.where((b) => b.isActive)]
      ..sort((a, b) => a.remainingSeconds.compareTo(b.remainingSeconds));

    final categories = [
      ['🥐', 'Bánh ngọt'],
      ['🍚', 'Cơm'],
      ['🍜', 'Bún phở'],
      ['🧋', 'Đồ uống'],
      ['🥗', 'Rau củ'],
      ['🍕', 'Pizza'],
      ['🥬', 'Món chay'],
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
                child: const Row(
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
                    Text('🌿', style: TextStyle(fontSize: 48)),
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
                          '⚡ SẮP HẾT GIỜ',
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

              const Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Text(
                  'Gợi ý gần bạn',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.greenDark),
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
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: isMini ? 82 : 94,
                  width: double.infinity,
                  color: AppColors.greenLight,
                  alignment: Alignment.center,
                  child: Text(box.emoji, style: const TextStyle(fontSize: 42)),
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
                        AppData.formatVnd(price),
                        style: const TextStyle(color: AppColors.price, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      if (!isMini) ...[
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

  // ==========================================
  // TAB 1: KHÁM PHÁ (BẢN ĐỒ)
  // ==========================================
  Widget _buildExploreMapTab() {
    final activeBoxes = AppData.boxes.where((b) => b.isActive).toList();
    final currentBox = selectedMapBox ?? activeBoxes.first;

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
              _mapChip(2, 'Sắp hết giờ'),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(21.0368, 105.7900),
                  initialZoom: 14.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.lastbite.app',
                  ),
                  MarkerLayer(
                    markers: activeBoxes.map((box) {
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
                ],
              ),
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
                            ],
                          ),
                        ),
                      ],
                    ),
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
      onTap: () => setState(() => mapFilterChip = idx),
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
    final statusFilter = orderFilterTab == 0
        ? 'PENDING'
        : orderFilterTab == 1
            ? 'COMPLETED'
            : 'CANCELLED';
    final filtered = AppData.orders.where((o) => o.status == statusFilter).toList();

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
              ? const Center(child: Text('Chưa có đơn hàng nào ở mục này.', style: TextStyle(color: AppColors.mute)))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final ord = filtered[index];
                    final isPending = ord.status == 'PENDING';
                    return GestureDetector(
                      onTap: () => _showQrReceiptDialog(ord),
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
                              decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
                              child: Text(ord.box.emoji, style: const TextStyle(fontSize: 28)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ord.box.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${ord.box.storeName} · ${AppData.formatVnd(ord.lockedPrice)}',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.mute),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isPending ? AppColors.priceBg : AppColors.greenLight,
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                        child: Text(
                                          isPending ? 'Chờ lấy' : 'Đã hoàn thành',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: isPending ? AppColors.price : AppColors.greenDark,
                                          ),
                                        ),
                                      ),
                                      if (isPending) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          'Còn ${AppData.formatCountdown(ord.box.remainingSeconds)}',
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
                            const Icon(Icons.qr_code_2, color: AppColors.greenDark, size: 28),
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

  void _showQrReceiptDialog(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
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
              '${order.box.storeName} · nhận ${order.pickupSlot}',
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
                'Mã xác nhận: ${order.pickupCode}  |  Còn lại ${AppData.formatCountdown(order.box.remainingSeconds)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: ƯU ĐÃI / ĐIỂM THƯỞNG
  // ==========================================
  Widget _buildRewardsTab() {
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
                '${AppData.greenPoints} điểm',
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const Text(
                'Còn 580 điểm để lên huy hiệu "Chiến binh xanh"',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: const LinearProgressIndicator(
                  value: 0.71,
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
                        AppData.formatVnd(AppData.savedMoney),
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
                        '${AppData.rescuedMeals}',
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
              _badgeItem('🥬', 'Người giữ bếp', true),
              const SizedBox(width: 8),
              _badgeItem('🛡️', 'Chiến binh', false),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Text('Ưu đãi của tôi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.greenDark)),
        ),
        Container(
          color: AppColors.card,
          padding: const EdgeInsets.all(12),
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Giảm 10.000đ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    Text('Đơn từ 30.000đ · HSD 31/10', style: TextStyle(fontSize: 11.5, color: AppColors.mute)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(8)),
                child: const Text('Dùng', style: TextStyle(color: AppColors.greenDark, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
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

  // ==========================================
  // TAB 4: TÀI KHOẢN ("TÔI")
  // ==========================================
  Widget _buildProfileTab() {
    final menuItems = [
      'Địa chỉ của tôi',
      'Quán yêu thích',
      'Nạp tiền vào ví (+100.000đ)',
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
                        Text(AppData.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        const Text('Hạng Mầm xanh', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
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
                        AppData.formatVnd(AppData.walletBalance),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.greenDark),
                      ),
                      const Text('Ví LastBite', style: TextStyle(fontSize: 11, color: AppColors.mute)),
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
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('3', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
                      Text('Voucher', style: TextStyle(fontSize: 11, color: AppColors.mute)),
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
                onTap: () {
                  if (index == 2) {
                    setState(() => AppData.walletBalance += 100000);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã nạp +100.000đ vào Ví LastBite!')));
                  } else if (index == 3) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SellerScreen()));
                  } else if (index == 4) {
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
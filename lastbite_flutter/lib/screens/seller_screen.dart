import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import 'auth_screen.dart';
import 'buyer_home_screen.dart';

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
            BottomNavigationBarItem(icon: Text('🏠', style: TextStyle(fontSize: 18)), label: 'Tổng quan'),
            BottomNavigationBarItem(icon: Text('➕', style: TextStyle(fontSize: 18)), label: 'Đăng deal'),
            BottomNavigationBarItem(icon: Text('🧾', style: TextStyle(fontSize: 18)), label: 'Đơn hàng'),
            BottomNavigationBarItem(icon: Text('💰', style: TextStyle(fontSize: 18)), label: 'Doanh thu'),
            BottomNavigationBarItem(icon: Text('🏪', style: TextStyle(fontSize: 18)), label: 'Cửa hàng'),
          ],
        ),
      ),
    );
  }

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
    final activeDealsCount = AppData.boxes.where((b) => b.isActive).length;
    final pendingOrdersCount = AppData.orders.where((o) => o.status == 'PENDING').length;

    return Column(
      children: [
        _sellerHeader('Tiệm Lúa Mì'),
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
                  _statBox('412k', 'Hôm nay'),
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
                          const Text('Sớm nhất: 20:30', style: TextStyle(fontSize: 11.5, color: AppColors.mute)),
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
              ...AppData.boxes.where((b) => b.isActive).map((b) => Container(
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
                                'Còn ${b.remainingQty}/${b.totalQty} · hết giờ sau ${AppData.formatCountdown(b.remainingSeconds)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.mute),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => b.isActive = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.hotBg, borderRadius: BorderRadius.circular(8)),
                            child: const Text('Tắt deal', style: TextStyle(color: AppColors.hot, fontWeight: FontWeight.w700, fontSize: 11.5)),
                          ),
                        ),
                      ],
                    ),
                  )),
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

  // ==========================================
  // TAB 1: ĐĂNG DEAL MỚI + XEM TRƯỚC GIÁ THEO GIỜ
  // ==========================================
  Widget _buildCreateAndManageDealTab() {
    final orig = int.tryParse(origPriceCtrl.text) ?? 80000;
    final p20 = ((orig * 0.8) / 1000).round() * 1000;
    final p40 = ((orig * 0.6) / 1000).round() * 1000;
    final p60 = ((orig * 0.4) / 1000).round() * 1000;

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
              _formFieldRow('Tên món', titleCtrl, isNumber: false),
              _formFieldRow('Giá gốc (VNĐ)', origPriceCtrl, isNumber: true),
              _formFieldRow('Số lượng phần', qtyCtrl, isNumber: true),
              _formFieldRow('Hết hạn lúc', expTimeCtrl, isNumber: false),
              const SizedBox(height: 14),
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
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final qty = int.tryParse(qtyCtrl.text) ?? 10;
                    setState(() {
                      AppData.boxes.insert(
                        0,
                        SurpriseBox(
                          id: 'BOX0${AppData.boxes.length + 1}',
                          emoji: selectedEmoji,
                          title: titleCtrl.text.trim(),
                          category: 'Bánh ngọt',
                          description: 'Phần ăn giải cứu cuối ngày chất lượng đảm bảo tại Tiệm Lúa Mì.',
                          storeName: 'Tiệm Lúa Mì',
                          address: '12 Xuân Thủy, Cầu Giấy, Hà Nội',
                          distanceKm: '0,4 km',
                          lat: 21.0368,
                          lng: 105.7825,
                          originalPrice: orig,
                          remainingQty: qty,
                          totalQty: qty,
                          pickupWindow: '20:00 – ${expTimeCtrl.text}',
                          createdAt: DateTime.now(),
                          expiredAt: DateTime.now().add(const Duration(minutes: 45)),
                        ),
                      );
                      currentTab = 0;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Đã đăng deal mới lên sàn!'), backgroundColor: AppColors.green),
                    );
                  },
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
    final pendingList = AppData.orders.where((o) => o.status == 'PENDING').toList();
    final completedList = AppData.orders.where((o) => o.status == 'COMPLETED').toList();
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
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19),
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
              ? const Center(child: Text('Không có đơn hàng nào.', style: TextStyle(color: AppColors.mute)))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 6),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final ord = displayList[index];
                    final isPending = ord.status == 'PENDING';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      color: AppColors.card,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('#${ord.pickupCode} · ${ord.buyerName}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text('${ord.box.title} × 1 · nhận ${ord.pickupSlot}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.mute)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isPending ? AppColors.priceBg : AppColors.greenLight,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    isPending ? 'Chờ nhận' : 'Đã giao thành công',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: isPending ? AppColors.price : AppColors.greenDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isPending)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.greenLight,
                                foregroundColor: AppColors.greenDark,
                                elevation: 0,
                              ),
                              onPressed: () => _completeOrder(ord),
                              child: const Text('Xác nhận', style: TextStyle(fontWeight: FontWeight.w700)),
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

  void _completeOrder(OrderModel ord) {
    setState(() {
      ord.status = 'COMPLETED';
      AppData.greenPoints += 25;
      AppData.rescuedMeals += 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Đã xác nhận giao đơn #${ord.pickupCode}! Khách được +25 điểm xanh.'),
        backgroundColor: AppColors.green,
      ),
    );
  }

  void _showScanQrModal() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('📷 Quét / Nhập mã nhận hàng'),
        content: TextField(
          controller: codeCtrl,
          decoration: const InputDecoration(
            labelText: 'Mã đơn (VD: A2417)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          FilledButton(
            onPressed: () {
              final input = codeCtrl.text.trim().toUpperCase().replaceAll('#', '');
              final idx = AppData.orders.indexWhere((o) => o.pickupCode.toUpperCase() == input && o.status == 'PENDING');
              Navigator.pop(context);
              if (idx == -1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❌ Không tìm thấy mã đơn chờ nhận!'), backgroundColor: AppColors.hot),
                );
              } else {
                _completeOrder(AppData.orders[idx]);
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
    final bars = [0.42, 0.58, 0.50, 0.74, 0.85, 1.0, 0.64];
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
                  children: List.generate(bars.length, (i) {
                    final isPeak = i == 5;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 28,
                          height: 95 * bars[i],
                          decoration: BoxDecoration(
                            color: isPeak ? AppColors.price : AppColors.green,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('T${i + 2}', style: const TextStyle(fontSize: 10.5, color: AppColors.mute)),
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
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tổng thu', style: TextStyle(color: AppColors.mute)),
                        Text('2.480.000đ', style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Hoa hồng sàn (10%)', style: TextStyle(color: AppColors.mute)),
                        Text('-248.000đ', style: TextStyle(color: AppColors.hot, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Thực nhận', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        Text('2.232.000đ', style: TextStyle(color: AppColors.price, fontSize: 17, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
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

  // ==========================================
  // TAB 4: HỒ SƠ CỬA HÀNG CỦA TÔI
  // ==========================================
  Widget _buildStoreProfileTab() {
    final items = [
      'Thông tin cửa hàng',
      'Giờ mở cửa (07:00 – 22:00)',
      'Địa chỉ & vị trí bản đồ',
      'Tài khoản nhận tiền',
      'Đánh giá của khách (★ 4,9)',
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
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tiệm Lúa Mì', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        Text('★ 4,9 · Đã duyệt ✓', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
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
                onTap: () {
                  if (index == 5) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BuyerHomeScreen()));
                  } else if (index == 6) {
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
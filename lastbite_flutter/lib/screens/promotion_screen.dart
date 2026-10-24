import 'dart:async';
import 'package:flutter/material.dart';
import '../models/deal.dart';
import '../models/mock_data.dart';
import '../services/auth_service.dart';
import '../services/deal_service.dart';
import '../services/promotion_service.dart';

/// Quảng bá suất (seller, BMC "phí ưu tiên hiển thị"): chọn suất đang bán
/// + gói ngày, gửi yêu cầu chờ admin duyệt. Phí 20.000đ/ngày (giả lập).
class PromotionScreen extends StatefulWidget {
  const PromotionScreen({super.key});

  @override
  State<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends State<PromotionScreen> {
  List<Deal> _deals = [];
  List<Promotion> _promos = [];
  StreamSubscription? _dealSub;
  StreamSubscription? _promoSub;
  String? _selectedDealId;
  int _days = 3;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    _dealSub = DealService.storeDeals(uid).listen((list) {
      if (mounted) setState(() => _deals = list);
    });
    _promoSub = PromotionService.myPromotions(uid).listen((list) {
      if (mounted) setState(() => _promos = list);
    });
  }

  @override
  void dispose() {
    _dealSub?.cancel();
    _promoSub?.cancel();
    super.dispose();
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Chờ duyệt';
      case 'active':
        return 'Đang chạy';
      case 'rejected':
        return 'Bị từ chối';
      default:
        return s;
    }
  }

  Future<void> _submit() async {
    if (_selectedDealId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy chọn một suất đang bán.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await PromotionService.requestPromotion(_selectedDealId!, _days);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã gửi yêu cầu quảng bá, chờ admin duyệt.'),
            backgroundColor: AppColors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeDeals = _deals.where((d) => d.status == 'active').toList();
    return Scaffold(
      backgroundColor: AppColors.app,
      appBar: AppBar(
        title: const Text('Quảng bá suất'),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Chọn suất đang bán',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          if (activeDeals.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: const Text(
                'Quán chưa có suất nào đang bán. Đăng deal trước rồi quay lại đây.',
                style: TextStyle(color: AppColors.mute, fontSize: 12.5),
              ),
            )
          else
            ...activeDeals.map((d) {
              final selected = _selectedDealId == d.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedDealId = d.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.greenLight : AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: selected ? AppColors.green : AppColors.line),
                  ),
                  child: Row(
                    children: [
                      Text(d.icon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(
                              'Còn ${d.remainingQty} suất · ${AppData.formatVnd(d.currentDynamicPrice)}',
                              style: const TextStyle(
                                  color: AppColors.mute, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        const Text('✓',
                            style: TextStyle(
                                color: AppColors.green,
                                fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          const Text('Gói quảng bá (20.000đ/ngày, giả lập)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [1, 3, 7].map((d) {
              final selected = _days == d;
              return GestureDetector(
                onTap: () => setState(() => _days = d),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.green : AppColors.greenLight,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('$d ngày · ${AppData.formatVnd(d * 20000)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: selected
                              ? Colors.white
                              : AppColors.greenDark)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _sending ? null : _submit,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _sending ? 'Đang gửi…' : 'Gửi yêu cầu quảng bá',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Yêu cầu của tôi',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          if (_promos.isEmpty)
            const Text('Chưa có yêu cầu nào.',
                style: TextStyle(color: AppColors.mute, fontSize: 12.5))
          else
            ..._promos.map((p) {
              final deal = _deals.where((d) => d.id == p.dealId).firstOrNull;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deal?.title ?? 'Suất ${p.dealId}',
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${p.days} ngày · ${AppData.formatVnd(p.fee)} · ${_statusLabel(p.status)}',
                      style: const TextStyle(
                          color: AppColors.mute, fontSize: 12),
                    ),
                    if (p.status == 'rejected' &&
                        (p.reviewNote ?? '').isNotEmpty)
                      Text('Lý do: ${p.reviewNote}',
                          style: const TextStyle(
                              color: AppColors.hot, fontSize: 12)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

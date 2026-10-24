import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import '../services/promotion_service.dart';

/// Duyệt quảng bá (admin): duyệt -> suất lên trang chủ N ngày.
class AdminPromotionScreen extends StatefulWidget {
  const AdminPromotionScreen({super.key});

  @override
  State<AdminPromotionScreen> createState() => _AdminPromotionScreenState();
}

class _AdminPromotionScreenState extends State<AdminPromotionScreen> {
  List<Promotion> _promos = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = PromotionService.pendingPromotions().listen((list) {
      if (mounted) setState(() => _promos = list);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _review(Promotion p, bool approve) async {
    var note = '';
    if (!approve) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Từ chối quảng bá'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Lý do từ chối',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Từ chối'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      note = ctrl.text.trim();
    }
    try {
      await PromotionService.reviewPromotion(p.id, approve, note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                approve ? 'Đã duyệt quảng bá.' : 'Đã từ chối quảng bá.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.app,
      appBar: AppBar(
        title: const Text('Duyệt quảng bá'),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: _promos.isEmpty
          ? const Center(
              child: Text('Không có yêu cầu nào đang chờ.',
                  style: TextStyle(color: AppColors.mute)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _promos.length,
              itemBuilder: (_, i) {
                final p = _promos[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Suất: ${p.dealId}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('Quán: ${p.storeId}',
                          style: const TextStyle(
                              color: AppColors.mute, fontSize: 12)),
                      Text(
                        '${p.days} ngày · Phí ${AppData.formatVnd(p.fee)} (giả lập)',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _review(p, true),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.green,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('Duyệt',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _review(p, false),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.hotBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('Từ chối',
                                    style: TextStyle(
                                        color: AppColors.hot,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

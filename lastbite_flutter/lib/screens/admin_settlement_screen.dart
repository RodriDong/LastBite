import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import '../services/settlement_service.dart';

/// Duyệt đối soát hoa hồng (admin): duyệt -> trừ công nợ của quán.
class AdminSettlementScreen extends StatefulWidget {
  const AdminSettlementScreen({super.key});

  @override
  State<AdminSettlementScreen> createState() => _AdminSettlementScreenState();
}

class _AdminSettlementScreenState extends State<AdminSettlementScreen> {
  List<Settlement> _items = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = SettlementService.pendingSettlements().listen((list) {
      if (mounted) setState(() => _items = list);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _review(Settlement st, bool approve) async {
    var note = '';
    if (!approve) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Từ chối đối soát'),
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
      await SettlementService.confirmSettlement(
          st.storeId, st.id, approve, note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(approve ? 'Đã duyệt đối soát.' : 'Đã từ chối đối soát.')),
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
        title: const Text('Duyệt đối soát'),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: _items.isEmpty
          ? const Center(
              child: Text('Không có yêu cầu nào đang chờ.',
                  style: TextStyle(color: AppColors.mute)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final st = _items[i];
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
                      Text(AppData.formatVnd(st.amount),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('Quán: ${st.storeId}',
                          style: const TextStyle(
                              color: AppColors.mute, fontSize: 12)),
                      const Text('Chuyển khoản ngoài app (giả lập)',
                          style: TextStyle(fontSize: 12.5)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _review(st, true),
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
                              onTap: () => _review(st, false),
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

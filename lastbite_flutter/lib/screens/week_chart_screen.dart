import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import '../services/deal_service.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';

/// Biểu đồ 7 ngày gần nhất (bản Hoàn thiện): cột doanh thu theo ngày,
/// vẽ bằng Container thuần (không thêm package biểu đồ).
class WeekChartScreen extends StatefulWidget {
  const WeekChartScreen({super.key});

  @override
  State<WeekChartScreen> createState() => _WeekChartScreenState();
}

class _WeekChartScreenState extends State<WeekChartScreen> {
  List<DailyStat> _stats = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    try {
      final storeId = DealService.myStoreId;
      if (storeId != null) {
        _sub = StatsService.recentStats(storeId, days: 7).listen((list) {
          if (!mounted) return;
          // recentStats trả về mới nhất trước → đảo lại để vẽ từ trái sang phải.
          setState(() => _stats = list.reversed.toList());
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _label(String dayKey) {
    if (dayKey.length != 8) return dayKey;
    return '${dayKey.substring(6, 8)}/${dayKey.substring(4, 6)}';
  }

  @override
  Widget build(BuildContext context) {
    final maxRevenue =
        _stats.fold<int>(0, (m, s) => s.revenue > m ? s.revenue : m);
    final total = _stats.fold<int>(0, (s, d) => s + d.revenue);
    final totalOrders = _stats.fold<int>(0, (s, d) => s + d.orders);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biểu đồ 7 ngày'),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: _stats.isEmpty
          ? LTheme.emptyState(
              emoji: '📊',
              title: 'Chưa có số liệu 7 ngày qua',
              subtitle:
                  'Khi có đơn hoàn thành, doanh thu từng ngày sẽ hiện ở đây dưới dạng biểu đồ cột.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: LTheme.cardDecoration,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _totalCell('Doanh thu', AppData.formatVnd(total)),
                          _totalCell('Đơn hoàn thành', '$totalOrders'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 180,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: _stats.map((s) {
                            final h = maxRevenue > 0
                                ? (s.revenue / maxRevenue) * 140
                                : 0.0;
                            return Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (s.revenue > 0)
                                    Text(
                                      AppData.formatVnd(s.revenue),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.greenDark,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: h < 4 && s.revenue > 0 ? 4 : h,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.green,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _label(s.dayKey),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.mute,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ..._stats.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ngày ${_label(s.dayKey)}',
                            style: const TextStyle(fontSize: 13.5),
                          ),
                          Text(
                            '${s.orders} đơn · ${AppData.formatVnd(s.revenue)}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
    );
  }

  Widget _totalCell(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.greenDark,
          ),
        ),
        Text(label,
            style: const TextStyle(fontSize: 11.5, color: AppColors.mute)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import '../services/deal_service.dart';
import '../services/review_service.dart';
import '../theme/app_theme.dart';

/// Toàn bộ đánh giá của quán (bản Hoàn thiện) — trước đây mục này trong
/// menu Cửa hàng bấm vào không làm gì.
class SellerReviewsScreen extends StatefulWidget {
  const SellerReviewsScreen({super.key});

  @override
  State<SellerReviewsScreen> createState() => _SellerReviewsScreenState();
}

class _SellerReviewsScreenState extends State<SellerReviewsScreen> {
  List<StoreReview> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final storeId = DealService.myStoreId ?? '';
      final list =
          await ReviewService.recentForStore(storeId, limit: 50);
      if (mounted) setState(() => _reviews = list);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đánh giá của khách'),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
              ? LTheme.emptyState(
                  emoji: '⭐',
                  title: 'Chưa có đánh giá nào',
                  subtitle:
                      'Khi khách nhận hàng và gửi đánh giá, tất cả sẽ hiện ở đây để quán theo dõi và cải thiện.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _reviews.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = _reviews[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: LTheme.cardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '★' * r.rating + '☆' * (5 - r.rating),
                                style: const TextStyle(
                                  color: AppColors.price,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r.buyerName.isEmpty
                                      ? 'Khách hàng'
                                      : r.buyerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              if (r.createdAt != null)
                                Text(
                                  '${r.createdAt!.day}/${r.createdAt!.month}/${r.createdAt!.year}',
                                  style: const TextStyle(
                                    color: AppColors.mute,
                                    fontSize: 11.5,
                                  ),
                                ),
                            ],
                          ),
                          if (r.comment.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              r.comment,
                              style: const TextStyle(fontSize: 13.5, height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import '../services/deal_service.dart';
import '../services/favorite_service.dart';
import '../theme/app_theme.dart';
import 'box_detail_screen.dart';

/// Quán yêu thích (bản Hoàn thiện): danh sách quán đã tim, kèm các suất
/// đang bán của từng quán. Bấm vào suất để xem chi tiết như ở trang chủ.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FavoriteStore> _favs = [];
  List<SurpriseBox> _boxes = [];
  StreamSubscription? _favSub;
  StreamSubscription? _dealSub;

  @override
  void initState() {
    super.initState();
    try {
      _favSub = FavoriteService.favorites().listen((list) {
        if (mounted) setState(() => _favs = list);
      });
      _dealSub = DealService.activeDeals().listen((deals) {
        if (!mounted) return;
        setState(() {
          _boxes = deals.map((d) => d.toSurpriseBox()).toList();
        });
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _favSub?.cancel();
    _dealSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quán yêu thích'),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: _favs.isEmpty
          ? LTheme.emptyState(
              emoji: '❤️',
              title: 'Chưa có quán yêu thích',
              subtitle:
                  'Bấm vào trái tim trên thẻ deal để lưu quán lại, lần sau mở app là thấy ngay.',
              actionLabel: 'Khám phá ngay',
              onAction: () => Navigator.pop(context),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: _favs.map((fav) {
                final deals = _boxes
                    .where((b) => b.storeId == fav.storeId)
                    .toList();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: LTheme.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                        child: Row(
                          children: [
                            const Text('🏪',
                                style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                fav.storeName.isEmpty
                                    ? 'Quán yêu thích'
                                    : fav.storeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                await FavoriteService.toggle(
                                  storeId: fav.storeId,
                                  storeName: fav.storeName,
                                );
                              },
                              child: const Text('❤️',
                                  style: TextStyle(fontSize: 18)),
                            ),
                          ],
                        ),
                      ),
                      if (deals.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(14, 4, 14, 14),
                          child: Text(
                            'Quán chưa có suất nào đang bán lúc này.',
                            style: TextStyle(
                                color: AppColors.mute, fontSize: 12.5),
                          ),
                        )
                      else
                        ...deals.map((box) => ListTile(
                              leading: box.imageUrl != null
                                  ? ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      child: Image.network(
                                        box.imageUrl!,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Text(box.emoji,
                                                style: const TextStyle(
                                                    fontSize: 24)),
                                      ),
                                    )
                                  : Text(box.emoji,
                                      style:
                                          const TextStyle(fontSize: 24)),
                              title: Text(box.title,
                                  style: const TextStyle(fontSize: 13.5)),
                              subtitle: Text(
                                'Còn ${box.remainingQty} suất · ⏱ ${AppData.formatCountdown(box.remainingSeconds)}',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              trailing: Text(
                                AppData.formatVnd(box.currentDynamicPrice),
                                style: const TextStyle(
                                  color: AppColors.price,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BoxDetailScreen(box: box),
                                ),
                              ),
                            )),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

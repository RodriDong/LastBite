import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/deal.dart';
import '../models/mock_data.dart';
import '../services/deal_service.dart';
import '../theme/app_theme.dart';
/// Deal của tôi (bản Hoàn thiện): danh sách deal của quán kèm nút
/// Tắt/Mở và Sửa (tên, mô tả, danh mục, ảnh). Giá/số lượng/giờ bán
/// không sửa được vì đã khóa theo đơn đang chờ.
class SellerDealsScreen extends StatefulWidget {
  const SellerDealsScreen({super.key});

  @override
  State<SellerDealsScreen> createState() => _SellerDealsScreenState();
}

class _SellerDealsScreenState extends State<SellerDealsScreen> {
  List<Deal> _deals = [];

  @override
  void initState() {
    super.initState();
    try {
      final storeId = DealService.myStoreId;
      if (storeId != null) {
        DealService.storeDeals(storeId).listen((list) {
          if (mounted) setState(() => _deals = list);
        });
      }
    } catch (_) {}
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'active':
        return 'Đang bán';
      case 'paused':
        return 'Tạm dừng';
      case 'soldout':
        return 'Hết suất';
      case 'expired':
        return 'Đã kết thúc';
      default:
        return s;
    }
  }

  Future<void> _toggle(Deal d) async {
    try {
      await DealService.pauseDeal(
        dealId: d.id,
        paused: d.status == 'active',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(d.status == 'active'
              ? '⏸️ Đã tạm dừng deal.'
              : '▶️ Đã mở lại deal.'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  Future<void> _edit(Deal d) async {
    final titleCtrl = TextEditingController(text: d.title);
    final descCtrl = TextEditingController(text: d.description);
    String category = DealCategories.all.map((c) => c[1]).contains(d.category)
        ? d.category
        : 'Khác';
    Uint8List? imageBytes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Sửa deal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên món',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Danh mục',
                    border: OutlineInputBorder(),
                  ),
                  items: DealCategories.all
                      .map((c) => DropdownMenuItem(
                            value: c[1],
                            child: Text('${c[0]} ${c[1]}'),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => category = v ?? 'Khác'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      final bytes = await DealService.pickDealImage();
                      if (bytes != null) {
                        setDialogState(() => imageBytes = bytes);
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Lỗi: $e')),
                        );
                      }
                    }
                  },
                  child: Text(imageBytes != null
                      ? 'Đã chọn ảnh mới ✓ (bấm để đổi)'
                      : 'Đổi ảnh món (không bắt buộc)'),
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
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await DealService.updateDeal(
        dealId: d.id,
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        category: category,
        imageBytes: imageBytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đã lưu thay đổi.'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deal của tôi'),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: _deals.isEmpty
          ? LTheme.emptyState(
              emoji: '🍱',
              title: 'Chưa có deal nào',
              subtitle:
                  'Đăng deal đầu tiên ở tab “Đăng deal” — quán sẽ thấy nó ở đây để tắt/mở và sửa bất cứ lúc nào.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _deals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final d = _deals[i];
                final editable =
                    d.status == 'active' || d.status == 'paused';
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: LTheme.cardDecoration,
                  child: Row(
                    children: [
                      d.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                d.imageUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Text(
                                  d.icon,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            )
                          : Text(d.icon,
                              style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${_statusLabel(d.status)} · Còn ${d.remainingQty}/${d.totalQty} suất · ${d.category}',
                              style: const TextStyle(
                                color: AppColors.mute,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (editable) ...[
                        TextButton(
                          onPressed: () => _edit(d),
                          child: const Text('Sửa'),
                        ),
                        TextButton(
                          onPressed: () => _toggle(d),
                          child: Text(d.status == 'active'
                              ? 'Tạm dừng'
                              : 'Mở lại'),
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

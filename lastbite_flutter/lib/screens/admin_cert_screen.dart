import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Duyệt chứng nhận ATTP trong app (bản Hoàn thiện) — chỉ tài khoản có
/// claim admin mới thấy mục này. Trước đây phải sửa tay trong Console.
class AdminCertScreen extends StatefulWidget {
  const AdminCertScreen({super.key});

  @override
  State<AdminCertScreen> createState() => _AdminCertScreenState();
}

class _AdminCertScreenState extends State<AdminCertScreen> {
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .where('certStatus', isEqualTo: 'pending')
          .get();
      if (mounted) {
        setState(() => _pending = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _review(Map<String, dynamic> store, bool approved) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(approved ? 'Duyệt chứng nhận?' : 'Từ chối chứng nhận?'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: approved
                ? 'Ghi chú cho quán (không bắt buộc)'
                : 'Lý do từ chối (quán sẽ đọc được)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approved ? 'Duyệt' : 'Từ chối'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiService.post('/api/reviewCertificate', {
        'storeId': store['id'],
        'approved': approved,
        'note': noteCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved
              ? '✅ Đã duyệt chứng nhận.'
              : 'Đã từ chối chứng nhận.'),
          backgroundColor: AppColors.green,
        ),
      );
      _load();
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
        title: const Text('Duyệt chứng nhận'),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pending.isEmpty
              ? LTheme.emptyState(
                  emoji: '🛡️',
                  title: 'Không còn chứng nhận chờ duyệt',
                  subtitle:
                      'Khi quán gửi chứng nhận mới, nó sẽ hiện ở đây kèm ảnh để bạn kiểm tra và duyệt.',
                  actionLabel: 'Tải lại',
                  onAction: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _pending.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final s = _pending[i];
                      final certUrl = (s['certUrl'] ?? '').toString();
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: LTheme.cardDecoration,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (s['name'] ?? 'Quán chưa đặt tên').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            if ((s['address'] ?? '').toString().isNotEmpty)
                              Text(
                                (s['address'] as String),
                                style: const TextStyle(
                                  color: AppColors.mute,
                                  fontSize: 12.5,
                                ),
                              ),
                            const SizedBox(height: 10),
                            if (certUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  certUrl,
                                  width: double.infinity,
                                  height: 180,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Text(
                                          'Không tải được ảnh chứng nhận.'),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _review(s, false),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.hot,
                                      side: const BorderSide(
                                          color: AppColors.hot),
                                    ),
                                    child: const Text('Từ chối'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _review(s, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Duyệt'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

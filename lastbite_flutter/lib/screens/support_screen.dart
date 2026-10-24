import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/support_service.dart';
import '../models/mock_data.dart';

/// Hỗ trợ (CSKH, BMC): người dùng gửi yêu cầu, xem trả lời của admin.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  List<SupportTicket> _tickets = [];
  StreamSubscription? _sub;
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    _sub = SupportService.myTickets(uid).listen((list) {
      if (mounted) setState(() => _tickets = list);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final msg = _msgCtrl.text.trim();
    if (title.isEmpty || msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tiêu đề và nội dung.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await SupportService.createTicket(title, msg);
      _titleCtrl.clear();
      _msgCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã gửi yêu cầu hỗ trợ.'),
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
    return Scaffold(
      backgroundColor: AppColors.app,
      appBar: AppBar(
        title: const Text('Hỗ trợ'),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gửi yêu cầu mới',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _msgCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _sending ? 'Đang gửi…' : 'Gửi',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Yêu cầu của tôi',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          if (_tickets.isEmpty)
            const Text('Chưa có yêu cầu nào.',
                style: TextStyle(color: AppColors.mute, fontSize: 12.5))
          else
            ..._tickets.map((t) {
              final open = t.status == 'open';
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
                    Text(t.title,
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                    Text(t.message,
                        style: const TextStyle(fontSize: 12.5)),
                    Text(
                      open ? 'Đang mở' : 'Đã đóng',
                      style: TextStyle(
                          fontSize: 12,
                          color: open ? AppColors.hot : AppColors.green),
                    ),
                    if ((t.adminReply ?? '').isNotEmpty)
                      Text('Trả lời: ${t.adminReply}',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.greenDark)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

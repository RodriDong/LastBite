import 'dart:async';
import 'package:flutter/material.dart';
import '../services/support_service.dart';
import '../models/mock_data.dart';

/// Hỗ trợ khách hàng (admin): trả lời + đóng các yêu cầu đang mở.
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  List<SupportTicket> _tickets = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = SupportService.openTickets().listen((list) {
      if (mounted) setState(() => _tickets = list);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _reply(SupportTicket t) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Trả lời hỗ trợ'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Nội dung trả lời',
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
            child: const Text('Gửi + đóng'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupportService.replyTicket(t.id, ctrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã trả lời và đóng yêu cầu.')),
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
        title: const Text('Hỗ trợ khách hàng'),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: _tickets.isEmpty
          ? const Center(
              child: Text('Không có yêu cầu nào đang mở.',
                  style: TextStyle(color: AppColors.mute)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _tickets.length,
              itemBuilder: (_, i) {
                final t = _tickets[i];
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
                      Text(t.title,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(t.message,
                          style: const TextStyle(fontSize: 12.5)),
                      Text('Người gửi: ${t.userId}',
                          style: const TextStyle(
                              color: AppColors.mute, fontSize: 12)),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => _reply(t),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Trả lời',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

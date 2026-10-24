import 'dart:async';
import 'package:flutter/material.dart';
import '../services/complaint_service.dart';
import '../models/mock_data.dart';

/// Khiếu nại (BMC "đổi trả, xử lý khiếu nại"): quán xem khiếu nại của
/// mình, admin xem tất cả; xử lý bằng cách ghi cách giải quyết.
class ComplaintsScreen extends StatefulWidget {
  /// null = admin xem tất cả; khác null = quán xem của mình.
  final String? storeId;
  const ComplaintsScreen({super.key, this.storeId});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  List<Complaint> _items = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    final stream = widget.storeId == null
        ? ComplaintService.allComplaints()
        : ComplaintService.storeComplaints(widget.storeId!);
    _sub = stream.listen((list) {
      if (mounted) setState(() => _items = list);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _resolve(Complaint c) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xử lý khiếu nại'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Cách xử lý (gửi cho khách)',
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
            child: const Text('Xong'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ComplaintService.resolveComplaint(c.id, ctrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xử lý khiếu nại.')),
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
        title: const Text('Khiếu nại'),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: _items.isEmpty
          ? const Center(
              child: Text('Chưa có khiếu nại nào.',
                  style: TextStyle(color: AppColors.mute)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final c = _items[i];
                final open = c.status == 'open';
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
                      Text(c.dealTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('Lý do: ${c.reason}',
                          style: const TextStyle(fontSize: 12.5)),
                      if (c.note.isNotEmpty)
                        Text('Chi tiết: ${c.note}',
                            style: const TextStyle(
                                color: AppColors.mute, fontSize: 12.5)),
                      Text(
                        open ? 'Đang mở' : 'Đã xử lý: ${c.resolution ?? ''}',
                        style: TextStyle(
                            fontSize: 12,
                            color: open ? AppColors.hot : AppColors.green),
                      ),
                      if (open) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => _resolve(c),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Xử lý',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800)),
                          ),
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

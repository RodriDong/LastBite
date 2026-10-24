import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/mock_data.dart';
import '../services/chat_service.dart';

/// Màn hình trò chuyện 1-1 trong 1 thread (Phase 9). Tin nhắn nạp
/// bằng listen() một lần ở initState (mẫu ổn định của dự án, tránh
/// StreamBuilder trong các màn hình có timer).
class ChatScreen extends StatefulWidget {
  final ChatThread thread;
  final bool asSeller;

  const ChatScreen({super.key, required this.thread, required this.asSeller});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatMessage> _messages = [];
  StreamSubscription<List<ChatMessage>>? _sub;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String get _myUid => ChatService.myUid ?? '';

  @override
  void initState() {
    super.initState();
    _sub = ChatService.messages(widget.thread.id).listen((list) {
      if (!mounted) return;
      setState(() => _messages = list);
      // Đang ở trong màn chat = đã đọc phía mình.
      ChatService.markRead(widget.thread.id, asSeller: widget.asSeller)
          .catchError((_) {});
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    try {
      await ChatService.sendMessage(
        threadId: widget.thread.id,
        text: text,
        asSeller: widget.asSeller,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không gửi được tin nhắn. Thử lại.')),
      );
    }
  }

  String _fmtTime(DateTime? t) {
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.thread;
    final title = widget.asSeller
        ? (t.buyerName.isEmpty ? 'Khách hàng' : t.buyerName)
        : (t.storeName.isEmpty ? 'Cửa hàng' : t.storeName);
    return Scaffold(
      backgroundColor: AppColors.app,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      widget.asSeller
                          ? 'Chưa có tin nhắn trong hội thoại này.'
                          : 'Hãy gửi lời chào tới quán để bắt đầu!',
                      style:
                          const TextStyle(color: AppColors.mute, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final mine = m.senderUid == _myUid;
                      return Align(
                        alignment:
                            mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.72,
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: mine ? AppColors.green : AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: mine
                                ? null
                                : Border.all(color: AppColors.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                m.text,
                                style: TextStyle(
                                  color: mine ? Colors.white : AppColors.ink,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _fmtTime(m.createdAt),
                                style: TextStyle(
                                  color: mine ? Colors.white70 : AppColors.mute,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send, color: AppColors.green),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

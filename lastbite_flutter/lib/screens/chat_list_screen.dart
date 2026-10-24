import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/mock_data.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

/// Danh sách hội thoại chat (Phase 9) — dùng cho cả buyer
/// (asSeller=false: các quán đã nhắn) và seller (asSeller=true:
/// các khách đã nhắn tới quán mình).
class ChatListScreen extends StatefulWidget {
  final bool asSeller;

  const ChatListScreen({super.key, required this.asSeller});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatThread> _threads = [];
  StreamSubscription<List<ChatThread>>? _sub;

  @override
  void initState() {
    super.initState();
    final uid = ChatService.myUid;
    if (uid == null) return;
    _sub = (widget.asSeller
            ? ChatService.threadsForStore(uid)
            : ChatService.threadsForBuyer(uid))
        .listen((list) {
      if (!mounted) return;
      setState(() => _threads = list);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _fmtTime(DateTime? t) {
    if (t == null) return '';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return '$hh:$mm';
    }
    return '${t.day}/${t.month} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.app,
      appBar: AppBar(
        title: const Text('Tin nhắn'),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: _threads.isEmpty
          ? Center(
              child: Text(
                widget.asSeller
                    ? 'Chưa có khách nào nhắn tin tới quán.'
                    : 'Chưa có cuộc trò chuyện nào.\nMở 1 món và bấm "Chat với quán" để bắt đầu.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mute, fontSize: 13),
              ),
            )
          : ListView.separated(
              itemCount: _threads.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.line),
              itemBuilder: (context, i) {
                final t = _threads[i];
                final unread = widget.asSeller ? t.sellerUnread : t.buyerUnread;
                return ListTile(
                  tileColor: AppColors.card,
                  leading: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.greenLight,
                      shape: BoxShape.circle,
                    ),
                    child: Text(widget.asSeller ? '🙂' : '🏪',
                        style: const TextStyle(fontSize: 20)),
                  ),
                  title: Text(
                    widget.asSeller
                        ? (t.buyerName.isEmpty ? 'Khách hàng' : t.buyerName)
                        : (t.storeName.isEmpty ? 'Cửa hàng' : t.storeName),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    t.lastMessage.isEmpty ? 'Bắt đầu trò chuyện' : t.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_fmtTime(t.lastAt),
                          style: const TextStyle(
                              color: AppColors.mute, fontSize: 11)),
                      if (unread > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.hot,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatScreen(thread: t, asSeller: widget.asSeller),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

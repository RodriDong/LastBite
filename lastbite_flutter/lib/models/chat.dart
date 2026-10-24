import 'package:cloud_firestore/cloud_firestore.dart';

/// Hội thoại buyer <-> 1 cửa hàng (collection `chats`) — Phase 9.
///
/// Một cặp (buyer, quán) có đúng 1 thread, id = "{buyerUid}__{storeId}"
/// (storeId = uid của seller theo thiết kế 1 seller = 1 quán). Tin nhắn
/// nằm ở subcollection `chats/{id}/messages`. Khác với nghiệp vụ lõi,
/// chat ghi THẲNG từ client (cần thời gian thực) và được bảo vệ bằng
/// rules riêng: chỉ 2 bên tham gia mới đọc/ghi được thread của mình.
class ChatThread {
  final String id;
  final String buyerUid;
  final String buyerName;
  final String storeId;
  final String storeName;
  final String lastMessage;
  final DateTime? lastAt;
  final int buyerUnread;
  final int sellerUnread;

  const ChatThread({
    required this.id,
    required this.buyerUid,
    required this.buyerName,
    required this.storeId,
    required this.storeName,
    required this.lastMessage,
    required this.lastAt,
    required this.buyerUnread,
    required this.sellerUnread,
  });

  static ChatThread fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? <String, dynamic>{};
    return ChatThread(
      id: doc.id,
      buyerUid: (d['buyerUid'] ?? '').toString(),
      buyerName: (d['buyerName'] ?? '').toString(),
      storeId: (d['storeId'] ?? '').toString(),
      storeName: (d['storeName'] ?? '').toString(),
      lastMessage: (d['lastMessage'] ?? '').toString(),
      lastAt:
          d['lastAt'] is Timestamp ? (d['lastAt'] as Timestamp).toDate() : null,
      buyerUnread: (d['buyerUnread'] as num?)?.round() ?? 0,
      sellerUnread: (d['sellerUnread'] as num?)?.round() ?? 0,
    );
  }
}

class ChatMessage {
  final String id;
  final String senderUid;

  /// 'buyer' | 'seller'
  final String senderRole;
  final String text;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  static ChatMessage fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      senderUid: (d['senderUid'] ?? '').toString(),
      senderRole: (d['senderRole'] ?? '').toString(),
      text: (d['text'] ?? '').toString(),
      createdAt: d['createdAt'] is Timestamp
          ? (d['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}

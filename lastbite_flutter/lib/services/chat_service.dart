import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat.dart';

/// Chat buyer <-> seller (Phase 9) — đọc/ghi thẳng Firestore theo
/// rules `chats` (chỉ 2 bên tham gia). Xem models/chat.dart.
class ChatService {
  ChatService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get myUid => FirebaseAuth.instance.currentUser?.uid;

  static String threadIdFor(String buyerUid, String storeId) =>
      '${buyerUid}__$storeId';

  static CollectionReference<Map<String, dynamic>> get _threads =>
      _db.collection('chats');

  /// Danh sách hội thoại của buyer hiện tại, mới nhất trước (sắp xếp
  /// phía client để khỏi cần composite index).
  static Stream<List<ChatThread>> threadsForBuyer(String uid) {
    return _threads
        .where('buyerUid', isEqualTo: uid)
        .snapshots()
        .map((s) => _sorted(s.docs.map(ChatThread.fromFirestore).toList()));
  }

  /// Danh sách hội thoại tới cửa hàng của seller hiện tại (storeId=uid).
  static Stream<List<ChatThread>> threadsForStore(String storeId) {
    return _threads
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map((s) => _sorted(s.docs.map(ChatThread.fromFirestore).toList()));
  }

  static List<ChatThread> _sorted(List<ChatThread> list) {
    list.sort((a, b) => (b.lastAt ?? DateTime(0)).compareTo(a.lastAt ?? DateTime(0)));
    return list;
  }

  /// Tin nhắn trong 1 thread, cũ -> mới.
  static Stream<List<ChatMessage>> messages(String threadId) {
    return _threads
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map(ChatMessage.fromFirestore).toList());
  }

  /// Lấy thread giữa buyer hiện tại và 1 quán; chưa có thì tạo.
  /// Trả về threadId.
  static Future<String> ensureThread({
    required String storeId,
    required String storeName,
  }) async {
    final uid = myUid;
    if (uid == null) throw StateError('Chưa đăng nhập.');
    final id = threadIdFor(uid, storeId);
    final ref = _threads.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      final user = FirebaseAuth.instance.currentUser;
      await ref.set({
        'buyerUid': uid,
        'buyerName': user?.displayName ?? user?.email ?? 'Khách hàng',
        'storeId': storeId,
        'storeName': storeName,
        'lastMessage': '',
        'lastAt': FieldValue.serverTimestamp(),
        'buyerUnread': 0,
        'sellerUnread': 0,
      });
    }
    return id;
  }

  /// Gửi 1 tin nhắn: thêm message + cập nhật lastMessage/số chưa đọc
  /// của phía đối tác trong cùng 1 batch.
  static Future<void> sendMessage({
    required String threadId,
    required String text,
    required bool asSeller,
  }) async {
    final uid = myUid;
    if (uid == null) throw StateError('Chưa đăng nhập.');
    final t = text.trim();
    if (t.isEmpty) return;
    final threadRef = _threads.doc(threadId);
    final msgRef = threadRef.collection('messages').doc();
    final batch = _db.batch();
    batch.set(msgRef, {
      'senderUid': uid,
      'senderRole': asSeller ? 'seller' : 'buyer',
      'text': t,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(threadRef, {
      'lastMessage': t,
      'lastAt': FieldValue.serverTimestamp(),
      if (asSeller)
        'buyerUnread': FieldValue.increment(1)
      else
        'sellerUnread': FieldValue.increment(1),
    });
    await batch.commit();
  }

  /// Đánh dấu đã đọc phía của mình (đưa counter về 0).
  static Future<void> markRead(String threadId, {required bool asSeller}) {
    return _threads.doc(threadId).update({
      if (asSeller) 'sellerUnread': 0 else 'buyerUnread': 0,
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';

/// Quán yêu thích (bản Hoàn thiện): toggle qua server, đọc từ subcollection
/// `users/{uid}/favorites` (rules chỉ cho chủ tài khoản đọc).
class FavoriteStore {
  final String storeId;
  final String storeName;

  const FavoriteStore({required this.storeId, required this.storeName});
}

class FavoriteService {
  FavoriteService._();

  static final _db = FirebaseFirestore.instance;

  static Future<bool> toggle({
    required String storeId,
    required String storeName,
  }) async {
    final res = await ApiService.post('/api/toggleFavorite', {
      'storeId': storeId,
      'storeName': storeName,
    });
    return res['favorited'] == true;
  }

  /// Stream id các quán đã yêu thích (cho trạng thái tim trên thẻ deal).
  static Stream<Set<String>> favoriteStoreIds() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const <String>{});
    return _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toSet());
  }

  /// Stream danh sách quán yêu thích (mới nhất trước).
  static Stream<List<FavoriteStore>> favorites() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => FavoriteStore(
                  storeId: (d.data()['storeId'] ?? d.id).toString(),
                  storeName: (d.data()['storeName'] ?? '').toString(),
                ))
            .toList());
  }
}

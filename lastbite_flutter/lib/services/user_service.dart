import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Hồ sơ người dùng trong Firestore (`users/{uid}`) — điểm xanh, số bữa
/// đã cứu, tiền đã tiết kiệm. Tạo bởi function `onUserCreate`, cập nhật
/// bởi `createOrder` / `confirmPickup`.
class UserProfile {
  final String displayName;
  final String email;
  final int greenPoints;
  final int rescuedMeals;
  final int savedMoney;

  const UserProfile({
    this.displayName = '',
    this.email = '',
    this.greenPoints = 0,
    this.rescuedMeals = 0,
    this.savedMoney = 0,
  });

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return 0;
  }

  factory UserProfile.fromMap(Map<String, dynamic> d) {
    return UserProfile(
      displayName: (d['displayName'] ?? '').toString(),
      email: (d['email'] ?? '').toString(),
      greenPoints: _asInt(d['greenPoints']),
      rescuedMeals: _asInt(d['rescuedMeals']),
      savedMoney: _asInt(d['savedMoney']),
    );
  }
}

/// Đọc hồ sơ của user đang đăng nhập.
class UserService {
  UserService._();

  static Stream<UserProfile> myProfile() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const UserProfile());
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) =>
            s.data() == null ? const UserProfile() : UserProfile.fromMap(s.data()!));
  }
}

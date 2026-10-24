import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';

/// Wrapper Firebase Authentication cho LastBite.
///
/// - Đăng ký / đăng nhập bằng email + password.
/// - Quyền seller đọc từ custom claim `seller` trên ID token. Từ
///   Phase 10, user TỰ đăng ký làm seller trong app qua API
///   `becomeSeller` (server cấp claim cho chính uid trong token +
///   tạo stores/{uid}); đường admin `grantSellerRole` vẫn giữ cho
///   quản trị viên cấp hộ.
/// - Hồ sơ users/{uid} do API `bootstrap` của server tạo (thay cho Auth
///   trigger onUserCreate trước đây) — gọi qua [ensureProfile].
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() => _auth.signOut();

  /// Gửi email đặt lại mật khẩu (Firebase Auth lo phần gửi + trang đặt lại).
  /// Trên cloud: email thật tới hộp thư của user. Trên Emulator: lấy link
  /// đặt lại trong Emulator UI (Authentication).
  static Future<void> resetPassword(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Đảm bảo hồ sơ users/{uid} đã tồn tại trên Firestore bằng cách gọi
  /// POST /api/bootstrap (idempotent — có rồi thì server bỏ qua).
  /// Lỗi được nuốt lặng: đăng nhập/đăng ký không được phép hỏng vì bước
  /// này; lần gọi sau sẽ tự bù.
  static Future<void> ensureProfile({String? displayName}) async {
    try {
      await ApiService.post('/api/bootstrap', {
        if (displayName != null && displayName.isNotEmpty)
          'displayName': displayName,
      });
    } catch (_) {
      // Bỏ qua — xem chú thích ở trên.
    }
  }

  /// true nếu tài khoản hiện tại có custom claim `seller`.
  /// [refresh]=true để lấy claim mới nhất (dùng sau khi admin vừa cấp quyền).
  static Future<bool> isSeller({bool refresh = true}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final token = await user.getIdTokenResult(refresh);
    return token.claims?['seller'] == true;
  }

  /// true nếu tài khoản hiện tại có custom claim `admin` (chủ dự án) —
  /// dùng để hiện mục "Duyệt chứng nhận" trong app.
  static Future<bool> isAdmin({bool refresh = true}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final token = await user.getIdTokenResult(refresh);
    return token.claims?['admin'] == true;
  }

  /// Đổi tên hiển thị: cập nhật Auth + đồng bộ users doc qua server.
  static Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Chưa đăng nhập.');
    await user.updateDisplayName(name);
    await ApiService.post('/api/updateBuyerProfile', {'displayName': name});
  }

  /// Tự đăng ký làm seller (Phase 10): gọi POST /api/becomeSeller —
  /// server cấp claim `seller` cho chính tài khoản này và tạo
  /// stores/{uid} nếu chưa có. Sau khi gọi, [isSeller] (refresh=true
  /// là mặc định) sẽ thấy claim mới ngay. Ném ApiException khi lỗi.
  static Future<void> becomeSeller({required String storeName}) async {
    await ApiService.post('/api/becomeSeller', {'storeName': storeName});
  }
}

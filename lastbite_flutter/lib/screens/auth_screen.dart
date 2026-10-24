import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'buyer_home_screen.dart';
import 'seller_screen.dart';

/// Màn hình đăng nhập / đăng ký bằng Firebase Authentication (email + password).
/// Thiết kế giữ nguyên; chỉ thay logic `_handleAuth` từ mock sang Auth thật.
///
/// - Chọn "Người bán" khi đăng ký: app gọi API `becomeSeller` ngay sau
///   khi tạo tài khoản — server tự cấp claim `seller` + tạo cửa hàng,
///   vào thẳng giao diện seller (Phase 10, thay cơ chế duyệt tay cũ).
///   Đăng nhập mà chọn vai trò "Người bán" cũng tự nâng quyền tương tự
///   (cho tài khoản tạo từ trước). Tên cửa hàng lấy từ ô tên; đổi lại
///   sau trong tab Cửa hàng.
/// - Sau đăng nhập, route màn hình theo custom claim `seller`.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool _loading = false;
  String selectedRole = 'buyer'; // Chỉ có 'buyer' hoặc 'seller'
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Đã đăng nhập từ phiên trước → vào thẳng theo quyền, khỏi nhập lại.
    if (AuthService.currentUser != null) {
      _routeByRole();
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  String _lastSellerError = '';

  Future<void> _routeByRole() async {
    final seller = await AuthService.isSeller();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => seller ? const SellerScreen() : const BuyerHomeScreen(),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoặc mật khẩu chưa đúng.';
      case 'email-already-in-use':
        return 'Email này đã được đăng ký. Hãy đăng nhập.';
      case 'weak-password':
        return 'Mật khẩu quá yếu (tối thiểu 6 ký tự).';
      case 'invalid-email':
        return 'Email chưa đúng định dạng.';
      case 'too-many-requests':
        return 'Thử quá nhiều lần. Vui lòng đợi một lát rồi thử lại.';
      case 'network-request-failed':
        return 'Lỗi mạng. Kiểm tra kết nối và thử lại.';
      default:
        return 'Có lỗi xảy ra: ${e.message ?? e.code}';
    }
  }

  Future<void> _handleAuth() async {
    final email = emailCtrl.text.trim();
    final password = passCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _snack('Vui lòng nhập email và mật khẩu.');
      return;
    }
    setState(() => _loading = true);
    try {
      if (isLogin) {
        await AuthService.signIn(email: email, password: password);
        await AuthService.ensureProfile();
        // Phase 10: đăng nhập với vai trò Người bán mà chưa có quyền
        // -> tự nâng quyền luôn (tài khoản tạo từ các bản trước).
        if (selectedRole == 'seller') {
          await _ensureSellerRoleWithDialog('Cửa hàng của tôi');
        }
        await _routeByRole();
      } else {
        final cred = await AuthService.signUp(email: email, password: password);
        final name = nameCtrl.text.trim();
        if (name.isNotEmpty) {
          await cred.user?.updateDisplayName(name);
        }
        await AuthService.ensureProfile(displayName: name);
        if (!mounted) return;
        if (selectedRole == 'seller') {
          // Ô tên ở chế độ Người bán chính là "Tên cửa hàng".
          final ok = await _ensureSellerRoleWithDialog(
              name.isNotEmpty ? name : 'Cửa hàng của tôi');
          if (!mounted) return;
          if (ok) {
            _snack('Đã tạo tài khoản chủ quán. Chào mừng bạn mở quán!');
          }
        }
        await _routeByRole();
      }
    } on FirebaseAuthException catch (e) {
      _snack(_authErrorMessage(e));
    } catch (e) {
      _snack('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Phase 10: đảm bảo tài khoản hiện tại có quyền seller (tự đăng ký
  /// qua API becomeSeller). Đã là seller thì bỏ qua. Trả về true khi đã
  /// có quyền; false khi lỗi (lý do giữ trong _lastSellerError để hộp
  /// thoại bên dưới hiển thị — trước đây lỗi chỉ hiện snackbar vài giây
  /// nên người dùng dễ bỏ sót rồi tưởng mình vẫn là người mua).
  Future<bool> _ensureSellerRole(String storeName) async {
    try {
      if (await AuthService.isSeller()) return true;
      await AuthService.becomeSeller(storeName: storeName);
      return true;
    } on ApiException catch (e) {
      _lastSellerError = e.message;
      return false;
    } catch (_) {
      _lastSellerError = 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.';
      return false;
    }
  }

  /// Cấp quyền seller kèm hộp thoại khi lỗi: cho thử lại ngay tại chỗ,
  /// hoặc vào mua trước rồi thử lại sau từ mục "Chuyển sang giao diện
  /// Người bán" trong tab Tôi.
  Future<bool> _ensureSellerRoleWithDialog(String storeName) async {
    if (await _ensureSellerRole(storeName)) return true;
    if (!mounted) return false;
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Chưa cấp được quyền bán hàng'),
        content: Text(
          '$_lastSellerError\n\nBạn có thể thử lại ngay, hoặc vào giao diện mua trước rồi thử lại sau từ mục "Chuyển sang giao diện Người bán" trong tab Tôi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vào mua trước'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
    if (retry == true) {
      return _ensureSellerRole(storeName);
    }
    return false;
  }

  /// Quên mật khẩu (Phase 6): nhập email -> Firebase Auth gửi email
  /// chứa liên kết đặt lại mật khẩu.
  Future<void> _showForgotPasswordDialog() async {
    final ctrl = TextEditingController(text: emailCtrl.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đặt lại mật khẩu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nhập email của tài khoản. Bạn sẽ nhận được một email chứa liên kết đặt lại mật khẩu.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text('Gửi email'),
          ),
        ],
      ),
    );
    if (email == null) return;
    if (email.isEmpty) {
      _snack('Vui lòng nhập email.');
      return;
    }
    try {
      await AuthService.resetPassword(email);
      _snack('Đã gửi email đặt lại mật khẩu tới $email. Kiểm tra hộp thư (cả mục Spam).');
    } on FirebaseAuthException catch (e) {
      _snack(_authErrorMessage(e));
    } catch (e) {
      _snack('Có lỗi xảy ra: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.line),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo thật của LastBite (biểu tượng đồng hồ + thìa + nĩa)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/icon/icon.png',
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'LASTBITE',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.greenDark, letterSpacing: 1),
                  ),
                  const Text(
                    'Cứu bữa ngon cuối ngày, giá tốt dần theo giờ',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mute, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  // 2 Nút chọn vai trò: Người mua / Người bán
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _roleButton('buyer', '🛒 Người mua'),
                      const SizedBox(width: 10),
                      _roleButton('seller', '🏪 Người bán'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!isLogin) ...[
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: selectedRole == 'buyer' ? 'Họ và tên' : 'Tên cửa hàng',
                        filled: true,
                        fillColor: AppColors.app,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      filled: true,
                      fillColor: AppColors.app,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      filled: true,
                      fillColor: AppColors.app,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  if (isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _showForgotPasswordDialog,
                        child: const Text(
                          'Quên mật khẩu?',
                          style: TextStyle(color: AppColors.greenDark, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _loading ? null : _handleAuth,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isLogin
                                  ? (selectedRole == 'buyer' ? 'ĐĂNG NHẬP NGƯỜI MUA' : 'ĐĂNG NHẬP CHỦ QUÁN')
                                  : 'ĐĂNG KÝ TÀI KHOẢN',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading ? null : () => setState(() => isLogin = !isLogin),
                    child: Text(
                      isLogin ? 'Chưa có tài khoản? Đăng ký mới' : 'Đã có tài khoản? Đăng nhập',
                      style: const TextStyle(color: AppColors.greenDark, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleButton(String role, String label) {
    final active = selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.green : AppColors.card,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: active ? AppColors.green : AppColors.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import 'buyer_home_screen.dart';
import 'seller_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  String selectedRole = 'buyer'; // Chỉ có 'buyer' hoặc 'seller'
  final phoneCtrl = TextEditingController(text: '0987654321');
  final passCtrl = TextEditingController(text: '123456');
  final nameCtrl = TextEditingController(text: 'Toàn');

  void _handleAuth() {
    if (selectedRole == 'buyer') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BuyerHomeScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SellerScreen()));
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
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.lime, AppColors.green]),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🌿', style: TextStyle(fontSize: 34)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'LASTBITE',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.greenDark, letterSpacing: 1),
                  ),
                  const Text(
                    'Cứu đồ ăn sắp hết hạn, giá giảm dần theo giờ',
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
                    controller: phoneCtrl,
                    decoration: InputDecoration(
                      labelText: 'Số điện thoại / Email',
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _handleAuth,
                      child: Text(
                        isLogin
                            ? (selectedRole == 'buyer' ? 'ĐĂNG NHẬP NGƯỜI MUA' : 'ĐĂNG NHẬP CHỦ QUÁN')
                            : 'ĐĂNG KÝ TÀI KHOẢN',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
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
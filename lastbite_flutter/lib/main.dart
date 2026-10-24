import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/firebase_setup.dart';
import 'models/mock_data.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Khởi tạo Firebase (kết nối Emulator khi debug). Nếu chưa có config,
  // app vẫn chạy ở chế độ mock hiện tại — xem lib/config/firebase_setup.dart.
  await FirebaseSetup.initialize();
  // Đăng ký nhận push (Android; web bỏ qua — xem push_service.dart).
  await PushService.init();
  runApp(const LastBiteApp());
}

class LastBiteApp extends StatelessWidget {
  const LastBiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LastBite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.green),
        scaffoldBackgroundColor: AppColors.app,
        useMaterial3: true,
      ),
      home: const _StartGate(),
    );
  }
}

/// Cổng vào: lần đầu mở app thì hiện màn chào, sau đó vào AuthScreen.
class _StartGate extends StatefulWidget {
  const _StartGate();

  @override
  State<_StartGate> createState() => _StartGateState();
}

class _StartGateState extends State<_StartGate> {
  bool? _seen;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _seen = p.getBool('onboarding_done') ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_seen == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_seen!) {
      return OnboardingScreen(
        onDone: () async {
          final p = await SharedPreferences.getInstance();
          await p.setBool('onboarding_done', true);
          if (mounted) setState(() => _seen = true);
        },
      );
    }
    return const AuthScreen();
  }
}

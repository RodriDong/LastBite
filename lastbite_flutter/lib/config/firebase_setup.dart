import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Điểm khởi tạo Firebase duy nhất của app.
///
/// Cách dùng trong `main()`:
/// ```dart
/// WidgetsFlutterBinding.ensureInitialized();
/// await FirebaseSetup.initialize();
/// runApp(const LastBiteApp());
/// ```
///
/// - Config lấy từ `lib/firebase_options.dart` (sinh bằng `flutterfire configure`,
///   xem docs/backend-workflow.md §7). Trên Android cũng có thể dùng
///   `google-services.json`; trên Web bắt buộc có firebase_options.
/// - Nếu chưa có config (lỗi `Firebase.initializeApp`), hàm trả về `false` và app
///   tiếp tục chạy ở chế độ mock hiện tại — không crash, không đổi UI.
/// - Ở chế độ debug, tự động trỏ Auth/Firestore/Functions tới Emulator Suite
///   trên máy dev (xem `firebase.json` ở repo root).
class FirebaseSetup {
  FirebaseSetup._();

  /// Trả về true khi Firebase sẵn sàng.
  static Future<bool> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('[FirebaseSetup] Chưa có cấu hình Firebase — chạy chế độ mock: $e');
      return false;
    }

    if (kDebugMode) {
      _connectEmulators();
    }
    debugPrint('[FirebaseSetup] Firebase đã sẵn sàng.');
    return true;
  }

  static void _connectEmulators() {
    // Android emulator nhìn "localhost" của máy dev qua 10.0.2.2;
    // Web/desktop dùng localhost.
    final host =
        defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
    try {
      FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      // API nghiệp vụ không còn là Cloud Functions — app gọi API server
      // riêng (ApiService) nên không cần trỏ Functions emulator ở đây.
      debugPrint('[FirebaseSetup] Đã trỏ tới Emulator Suite tại $host.');
    } catch (e) {
      debugPrint('[FirebaseSetup] Không kết nối được Emulator: $e');
    }
  }
}

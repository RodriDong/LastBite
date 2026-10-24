import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Handler chạy nền bắt buộc của FCM (Android). Chỉ đăng ký, không xử lý
/// nặng: thông báo hiển thị do hệ thống lo, chi tiết đơn nằm ở trung tâm
/// thông báo trong app.
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {}

/// Push notification (Android). Web bỏ qua: FCM web cần thêm VAPID key +
/// service worker, ngoài phạm vi bản này — web vẫn nhận thông báo trong
/// app qua trung tâm thông báo (xem notification_service.dart).
class PushService {
  PushService._();

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      final token = await fm.getToken();
      if (token != null) {
        await ApiService.post('/api/saveFcmToken', {
          'token': token,
          'platform': 'android',
        });
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
        try {
          await ApiService.post('/api/saveFcmToken', {
            'token': t,
            'platform': 'android',
          });
        } catch (_) {}
      });
    } catch (_) {
      // Chưa có quyền/không có mạng: push tắt lặng, app vẫn chạy.
    }
  }
}

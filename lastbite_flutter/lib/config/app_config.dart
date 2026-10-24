import 'package:flutter/foundation.dart';

/// Cấu hình địa chỉ backend API của LastBite (API server riêng trên
/// Vercel — xem thư mục `server/` và HUONG_DAN_TACH_BACKEND.md).
///
/// Cách xác định, theo thứ tự:
/// 1. Biến `--dart-define=API_BASE_URL=...` khi build (nếu có).
/// 2. Bản debug (flutter run): máy chủ local ở cổng 3000
///    (web: localhost; Android emulator: 10.0.2.2).
/// 3. Bản release: dùng [productionApiBaseUrl] — ĐIỀN URL Vercel thật
///    vào đó sau khi deploy (chỉ sửa 1 dòng này).
class AppConfig {
  AppConfig._();

  /// URL API trên Vercel sau khi deploy, VD: https://lastbite-api.vercel.app
  /// Để trống = bản release chưa cấu hình (ApiService sẽ báo lỗi rõ ràng).
  static const String productionApiBaseUrl = 'https://server-indol-psi-83.vercel.app';

  static const String _fromEnv = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    if (kDebugMode) {
      return kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000';
    }
    return productionApiBaseUrl;
  }
}

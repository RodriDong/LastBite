import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Lỗi do API server trả về — thay vai trò của FirebaseFunctionsException
/// trước đây: có [code] (mã lỗi nghiệp vụ) và [message] tiếng Việt.
class ApiException implements Exception {
  final String code;
  final String message;

  const ApiException(this.code, this.message);

  @override
  String toString() => message;
}

/// Client gọi API server riêng của LastBite (thư mục `server/`, chạy trên
/// Vercel hoặc local cổng 3000 khi dev).
///
/// Mọi request đều đính kèm Firebase ID token của user đang đăng nhập
/// trong header Authorization — server xác thực token rồi mới chạy
/// nghiệp vụ (đặt hàng, đăng deal, xác nhận...). Việc ĐỌC dữ liệu
/// (deals/orders/stats) vẫn đi thẳng Firestore như trước.
class ApiService {
  ApiService._();

  /// POST JSON tới [path] (VD '/api/createOrder'), trả về map kết quả.
  /// Ném [ApiException] khi server báo lỗi hoặc không kết nối được.
  static Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic> body = const {},
  ]) async {
    final base = AppConfig.apiBaseUrl;
    if (base.isEmpty) {
      throw const ApiException(
        'unavailable',
        'Chưa cấu hình địa chỉ máy chủ API (AppConfig.productionApiBaseUrl).',
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    final token = user == null ? null : await user.getIdToken();

    http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse('$base$path'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      throw const ApiException(
        'unavailable',
        'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.',
      );
    }

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(resp.body);
      data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      data = <String, dynamic>{};
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return data;
    }
    throw ApiException(
      (data['code'] ?? 'internal').toString(),
      (data['error'] ?? 'Có lỗi xảy ra (${resp.statusCode}).').toString(),
    );
  }
}

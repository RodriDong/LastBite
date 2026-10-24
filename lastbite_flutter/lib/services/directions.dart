import 'package:url_launcher/url_launcher.dart';

/// Mở Google Maps chỉ đường tới 1 tọa độ (Phase 9). Dùng chung cho
/// trang chi tiết deal và thẻ deal trên bản đồ Khám phá.
class Directions {
  Directions._();

  static Future<void> open(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

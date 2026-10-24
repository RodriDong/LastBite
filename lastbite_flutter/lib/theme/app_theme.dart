import 'package:flutter/material.dart';
import '../models/mock_data.dart';

/// Thành phần giao diện dùng chung của bản Hoàn thiện:
/// badge giảm giá, chip đếm ngược giờ vàng, tiêu đề mục, trạng thái trống.
/// Mọi màn hình dùng chung để app nhìn nhất quán.
class LTheme {
  LTheme._();

  static const cardRadius = 20.0;
  static const chipRadius = 99.0;

  static List<BoxShadow> get softShadow => [
        const BoxShadow(
          color: Color(0x14000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: AppColors.line),
        boxShadow: softShadow,
      );

  /// Badge giảm giá phủ lên ảnh deal (cam hoàng hôn).
  static Widget discountBadge(int discount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: const BoxDecoration(
        color: AppColors.price,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Text(
        '-$discount%',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  /// Chip đếm ngược: dưới 1 giờ thì đỏ (giờ vàng), còn lại nền tối.
  static Widget countdownChip(int remainingSeconds) {
    final urgent = remainingSeconds < 3600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: urgent ? AppColors.hot : const Color(0xD11E2A22),
        borderRadius: BorderRadius.circular(chipRadius),
      ),
      child: Text(
        '⏱ ${AppData.formatCountdown(remainingSeconds)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Tiêu đề mục + hành động phụ (vd "Xem tất cả").
  static Widget sectionTitle(String title,
      {String? actionLabel, VoidCallback? onAction}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.greenDark,
          ),
        ),
        const Spacer(),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(color: AppColors.mute, fontSize: 12),
            ),
          ),
      ],
    );
  }

  /// Trạng thái trống: không bao giờ để màn hình trắng trơn.
  static Widget emptyState({
    required String emoji,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: cardDecoration,
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mute, fontSize: 13, height: 1.4),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}

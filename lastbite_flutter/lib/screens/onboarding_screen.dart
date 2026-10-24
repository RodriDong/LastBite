import 'package:flutter/material.dart';

/// Màn chào lần đầu (hiện 1 lần duy nhất, lưu bằng SharedPreferences).
/// Văn phong tích cực: "cứu bữa ngon", "giờ vàng", "giá tốt" —
/// không nhắc tới đồ ăn quá hạn hay bỏ đi.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _idx = 0;

  static const _pages = [
    (
      emoji: '🌿',
      title: 'Cứu bữa ngon cuối ngày',
      body:
          'Mỗi tối, các quán còn những suất ngon chưa có chủ. LastBite giúp bạn rước chúng về với giá thật tốt — ngon cho bạn, nhẹ cho hành tinh.',
    ),
    (
      emoji: '⏱️',
      title: 'Càng gần giờ vàng, giá càng tốt',
      body:
          'Giá giảm dần theo từng khung giờ: 20%, rồi 40%, tới 60% vào giờ vàng. Canh đúng lúc là có bữa ngon với giá đẹp nhất.',
    ),
    (
      emoji: '🏪',
      title: 'Đến quán nhận, trả tiền tại chỗ',
      body:
          'Đặt chỗ trong vài chạm, nhận mã QR, ghé quán đúng khung giờ là xong. Không cần thanh toán trước, không phí giao hàng.',
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF7EE),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/icon/icon.png',
                width: 88,
                height: 88,
                errorBuilder: (_, __, ___) =>
                    const Text('🌿', style: TextStyle(fontSize: 64)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'LastBite',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF14532D),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _idx = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p.emoji, style: const TextStyle(fontSize: 64)),
                        const SizedBox(height: 20),
                        Text(
                          p.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF14532D),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          p.body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.5,
                            color: Color(0xFF6E7A6E),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _idx == i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _idx == i
                        ? const Color(0xFF1E7A46)
                        : const Color(0xFFE7DDC9),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (_idx < _pages.length - 1) {
                      _page.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    } else {
                      widget.onDone();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E7A46),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  child: Text(
                    _idx < _pages.length - 1 ? 'Tiếp theo' : 'Bắt đầu khám phá',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_idx < _pages.length - 1)
              TextButton(
                onPressed: widget.onDone,
                child: const Text(
                  'Bỏ qua',
                  style: TextStyle(color: Color(0xFF6E7A6E)),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

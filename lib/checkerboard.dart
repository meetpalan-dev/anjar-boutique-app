import 'package:flutter/material.dart';

/// Draws a standard transparency checkerboard behind [child]. Purely a
/// visual aid — never part of any exported image.
class Checkerboard extends StatelessWidget {
  final Widget child;
  const Checkerboard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _CheckerPainter()),
        child,
      ],
    );
  }
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();
  static const double tile = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0xFFEDEDED);
    final dark = Paint()..color = const Color(0xFFD3D3D3);
    canvas.drawRect(Offset.zero & size, light);
    for (double y = 0; y < size.height; y += tile) {
      for (double x = 0; x < size.width; x += tile) {
        final isDark = ((x / tile).floor() + (y / tile).floor()) % 2 == 0;
        if (isDark) {
          canvas.drawRect(Rect.fromLTWH(x, y, tile, tile), dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 渐变电量环,带发光效果与平滑动画。
class BatteryRing extends StatelessWidget {
  final int level;
  final bool charging;
  final String caption;

  const BatteryRing({
    super.key,
    required this.level,
    required this.charging,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forLevel(level, charging: charging);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: level / 100),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: 250,
          height: 250,
          child: CustomPaint(
            painter: _RingPainter(progress: value, color: color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (charging)
                    Icon(Icons.bolt_rounded, color: color, size: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${(value * 100).round()}',
                        style: const TextStyle(
                          fontSize: 76,
                          fontWeight: FontWeight.w200,
                          height: 1.0,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('%',
                            style: TextStyle(
                                fontSize: 22, color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(caption,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.cardBorder;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final sweep = 2 * math.pi * progress;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 10
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, glow);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        transform: const GradientRotation(-math.pi / 2),
        colors: [color.withOpacity(0.55), color],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

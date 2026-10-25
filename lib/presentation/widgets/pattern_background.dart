import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/customization_models.dart';
import '../providers/customization_provider.dart';

class PatternBackground extends ConsumerWidget {
  final Widget child;
  final BackgroundPatternType? patternOverride;

  const PatternBackground({
    super.key,
    required this.child,
    this.patternOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BackgroundPatternType pattern =
        patternOverride ?? ref.watch(backgroundPatternProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    if (pattern == BackgroundPatternType.none) {
      return Container(
        color: theme.scaffoldBackgroundColor,
        child: child,
      );
    }

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: CustomPaint(
        painter: _PatternPainter(
          pattern: pattern,
          isDark: isDark,
          accentColor: accent,
          borderColor: theme.colorScheme.outline,
        ),
        child: child,
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final BackgroundPatternType pattern;
  final bool isDark;
  final Color accentColor;
  final Color borderColor;

  _PatternPainter({
    required this.pattern,
    required this.isDark,
    required this.accentColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (pattern) {
      case BackgroundPatternType.none:
        break;

      case BackgroundPatternType.grid:
        final paint = Paint()
          ..color = isDark
              ? Colors.white.withValues(alpha: 0.045)
              : accentColor.withValues(alpha: 0.065)
          ..strokeWidth = 1.0;

        const double step = 28.0;
        for (double x = 0; x <= size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = 0; y <= size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        break;

      case BackgroundPatternType.dots:
        final paint = Paint()
          ..color = isDark
              ? accentColor.withValues(alpha: 0.16)
              : accentColor.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill;

        const double step = 24.0;
        const double radius = 1.5;
        for (double x = step / 2; x < size.width; x += step) {
          for (double y = step / 2; y < size.height; y += step) {
            canvas.drawCircle(Offset(x, y), radius, paint);
          }
        }
        break;

      case BackgroundPatternType.mesh:
        final paint = Paint()
          ..color = isDark
              ? Colors.white.withValues(alpha: 0.035)
              : accentColor.withValues(alpha: 0.055)
          ..strokeWidth = 1.0;

        const double step = 32.0;
        for (double x = -size.height; x < size.width + size.height; x += step) {
          canvas.drawLine(
            Offset(x, 0),
            Offset(x + size.height, size.height),
            paint,
          );
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.pattern != pattern ||
        oldDelegate.isDark != isDark ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.borderColor != borderColor;
  }
}

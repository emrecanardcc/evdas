import 'package:flutter/material.dart';
import '../../core/utils/currency_formatter.dart';

class AnimatedRollingNumber extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final bool isMasked;
  final String prefix;
  final String suffix;
  final bool cleanFormatting;

  const AnimatedRollingNumber({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOutCubic,
    this.isMasked = false,
    this.prefix = '',
    this.suffix = '',
    this.cleanFormatting = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isMasked) {
      final masked = CurrencyFormatter.formatMasked();
      return Text(
        '$prefix$masked$suffix',
        style: style,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value),
      duration: duration,
      curve: curve,
      builder: (context, animatedVal, child) {
        final formatted = cleanFormatting
            ? CurrencyFormatter.formatClean(animatedVal)
            : CurrencyFormatter.format(animatedVal);

        return Text(
          '$prefix$formatted$suffix',
          style: style,
        );
      },
    );
  }
}

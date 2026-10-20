import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomNumpad extends StatelessWidget {
  final Function(String) onDigitPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback? onClearPressed;

  const CustomNumpad({
    super.key,
    required this.onDigitPressed,
    required this.onDeletePressed,
    this.onClearPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(['1', '2', '3'], buttonBg, textColor),
        const SizedBox(height: 10),
        _buildRow(['4', '5', '6'], buttonBg, textColor),
        const SizedBox(height: 10),
        _buildRow(['7', '8', '9'], buttonBg, textColor),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildButton('.', buttonBg, textColor, () => onDigitPressed('.')),
            const SizedBox(width: 10),
            _buildButton('0', buttonBg, textColor, () => onDigitPressed('0')),
            const SizedBox(width: 10),
            _buildIconButton(
              Icons.backspace_outlined,
              buttonBg,
              textColor,
              onDeletePressed,
              onLongPress: onClearPressed,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> values, Color bg, Color textColor) {
    return Row(
      children: [
        for (int i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          _buildButton(values[i], bg, textColor, () => onDigitPressed(values[i])),
        ],
      ],
    );
  }

  Widget _buildButton(
    String label,
    Color bg,
    Color textColor,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            height: 60,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(
    IconData icon,
    Color bg,
    Color textColor,
    VoidCallback onTap, {
    VoidCallback? onLongPress,
  }) {
    return Expanded(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          onLongPress: onLongPress != null
              ? () {
                  HapticFeedback.mediumImpact();
                  onLongPress();
                }
              : null,
          child: Container(
            height: 60,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 24,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

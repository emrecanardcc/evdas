import 'package:flutter/material.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/customization_models.dart';

class CustomNumpad extends StatelessWidget {
  final Function(String) onDigitPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback? onClearPressed;
  final Function(String)? onOperatorPressed;
  final VoidCallback? onEqualsPressed;
  final NumpadLayoutType layout;
  final bool showCalculator;

  const CustomNumpad({
    super.key,
    required this.onDigitPressed,
    required this.onDeletePressed,
    this.onClearPressed,
    this.onOperatorPressed,
    this.onEqualsPressed,
    this.layout = NumpadLayoutType.phone,
    this.showCalculator = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final operatorBg = isDark
        ? Theme.of(context).primaryColor.withValues(alpha: 0.18)
        : Theme.of(context).primaryColor.withValues(alpha: 0.12);
    final operatorColor = Theme.of(context).primaryColor;

    final row1 = layout == NumpadLayoutType.atm
        ? ['7', '8', '9']
        : ['1', '2', '3'];
    final row2 = ['4', '5', '6'];
    final row3 = layout == NumpadLayoutType.atm
        ? ['1', '2', '3']
        : ['7', '8', '9'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // DAHİLİ HESAP MAKİNESİ İŞLEÇ ŞERİDİ (+, -, ×, ÷, %, =)
        if (showCalculator) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D31) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                _buildOperatorButton('+', operatorBg, operatorColor, () => _handleOperator('+')),
                const SizedBox(width: 6),
                _buildOperatorButton('-', operatorBg, operatorColor, () => _handleOperator('-')),
                const SizedBox(width: 6),
                _buildOperatorButton('×', operatorBg, operatorColor, () => _handleOperator('×')),
                const SizedBox(width: 6),
                _buildOperatorButton('÷', operatorBg, operatorColor, () => _handleOperator('÷')),
                const SizedBox(width: 6),
                _buildOperatorButton('%', operatorBg, operatorColor, () => _handleOperator('%')),
                const SizedBox(width: 6),
                _buildOperatorButton('=', operatorColor, Colors.white, _handleEquals, isPrimary: true),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // 1-2-3 / 7-8-9 SATIRLARI
        _buildRow(row1, buttonBg, textColor),
        const SizedBox(height: 8),
        _buildRow(row2, buttonBg, textColor),
        const SizedBox(height: 8),
        _buildRow(row3, buttonBg, textColor),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildButton('.', buttonBg, textColor, () => _handleDigit('.')),
            const SizedBox(width: 8),
            _buildButton('0', buttonBg, textColor, () => _handleDigit('0')),
            const SizedBox(width: 8),
            _buildIconButton(
              Icons.backspace_outlined,
              buttonBg,
              textColor,
              _handleDelete,
              onLongPress: _handleClear,
            ),
          ],
        ),
      ],
    );
  }

  void _handleDigit(String digit) {
    HapticService.light();
    SoundService.playNumpadTick();
    onDigitPressed(digit);
  }

  void _handleOperator(String op) {
    HapticService.light();
    SoundService.playNumpadTick();
    if (onOperatorPressed != null) {
      onOperatorPressed!(op);
    } else {
      onDigitPressed(' $op ');
    }
  }

  void _handleEquals() {
    HapticService.medium();
    SoundService.playNumpadTick();
    if (onEqualsPressed != null) {
      onEqualsPressed!();
    }
  }

  void _handleDelete() {
    HapticService.light();
    SoundService.playNumpadTick();
    onDeletePressed();
  }

  void _handleClear() {
    HapticService.heavy();
    SoundService.playNumpadTick();
    if (onClearPressed != null) {
      onClearPressed!();
    }
  }

  Widget _buildOperatorButton(
    String label,
    Color bg,
    Color textColor,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    return Expanded(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: isPrimary ? FontWeight.w900 : FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<String> values, Color bg, Color textColor) {
    return Row(
      children: [
        for (int i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _buildButton(values[i], bg, textColor, () => _handleDigit(values[i])),
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
          onTap: onTap,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 24,
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
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 22,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

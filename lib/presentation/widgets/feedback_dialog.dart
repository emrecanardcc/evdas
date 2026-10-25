import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/feedback_service.dart';

class FeedbackDialog extends StatefulWidget {
  final String? activePartnershipName;

  const FeedbackDialog({
    super.key,
    this.activePartnershipName,
  });

  static Future<void> show(BuildContext context, {String? activePartnershipName}) {
    return showDialog(
      context: context,
      builder: (ctx) => FeedbackDialog(
        activePartnershipName: activePartnershipName,
      ),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  FeedbackType _selectedType = FeedbackType.suggestion;
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen iletmek istediğiniz mesajınızı yazın.'),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    final launched = await FeedbackService.sendFeedback(
      type: _selectedType,
      userMessage: text,
      activePartnershipName: widget.activePartnershipName,
    );

    if (!mounted) return;
    setState(() => _isSending = false);
    Navigator.pop(context);

    if (launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('E-posta uygulamanız açıldı. Gönder butonuna basınız.'),
          backgroundColor: AppColors.positive,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'E-posta uygulaması bulunamadı. Mesaj ve ${FeedbackService.supportEmail} panoya kopyalandı.',
          ),
          backgroundColor: AppColors.neutral,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.feedback_rounded, color: AppColors.primary, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Geri Bildirim & Destek',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bildirim Türü:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: FeedbackType.values.map((type) {
                final isSelected = type == _selectedType;
                return ChoiceChip(
                  label: Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withValues(alpha: 0.18),
                  onSelected: (val) {
                    if (val) setState(() => _selectedType = type);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              maxLines: 4,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Fikriniz, karşılaştığınız hata veya şikayetinizi detaylıca açıklayınız...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Geri bildiriminiz doğrudan geliştiriciye iletilecektir:\nemrecanardc.dev@gmail.com',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          child: const Text('İptal'),
        ),
        ElevatedButton.icon(
          onPressed: _isSending ? null : _handleSend,
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: _isSending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded, size: 16),
          label: const Text('Gönder'),
        ),
      ],
    );
  }
}

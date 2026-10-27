import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/sound_service.dart';
import '../../data/models/household_member.dart';
import '../providers/app_providers.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/pattern_background.dart';

class DecisionWheelScreen extends ConsumerStatefulWidget {
  const DecisionWheelScreen({super.key});

  @override
  ConsumerState<DecisionWheelScreen> createState() =>
      _DecisionWheelScreenState();
}

class _DecisionWheelScreenState extends ConsumerState<DecisionWheelScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  final List<String> _taskPresets = [
    'Çöpü Dök',
    'Bulaşıkları Yıka',
    'Sabah Ekmeği Al',
    'Evi Süpür',
    'Kahve Yap',
    'Markete Git',
    'Yemeği Söyle',
    'Özel Görev',
  ];

  late String _selectedTask;
  final TextEditingController _customTaskController = TextEditingController();

  final Set<String> _selectedMemberIds = {};
  double _currentAngle = 0.0;
  double _previousAngle = 0.0;
  bool _isSpinning = false;
  int _lastTickSlice = -1;
  double _spinningSliceAngle = 0.0;

  final List<Color> _wheelColors = const [
    Color(0xFFF97316), // Coral
    Color(0xFF0284C7), // Sky Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
  ];

  @override
  void initState() {
    super.initState();
    _selectedTask = _taskPresets.first;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    _controller.addListener(() {
      setState(() {
        _currentAngle = _animation.value;
      });

      // Dilim geçişlerinde haptic tick sesi/titreşimi (O(1) hesaplama, sıfır Riverpod/Liste tahsisi)
      if (_spinningSliceAngle > 0) {
        const double twoPi = 2 * math.pi;
        final normalizedAngle = (_currentAngle % twoPi + twoPi) % twoPi;
        final currentSlice = (normalizedAngle / _spinningSliceAngle).floor();
        if (currentSlice != _lastTickSlice) {
          _lastTickSlice = currentSlice;
          HapticService.selection();
          SoundService.playWheelTick();
        }
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _isSpinning = false;
        HapticService.heavy();
        SoundService.playSettlementChime();
        if (mounted) {
          ConfettiOverlay.show(context);
        }
        _showWinnerDialog();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _customTaskController.dispose();
    super.dispose();
  }

  List<HouseholdMember> _getParticipatingMembers() {
    final house = ref.read(householdProvider);
    if (house == null) return [];
    if (_selectedMemberIds.isEmpty) {
      return house.members;
    }
    return house.members
        .where((m) => _selectedMemberIds.contains(m.id))
        .toList();
  }

  void _spinWheel() {
    final members = _getParticipatingMembers();
    if (members.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Çarkı çevirmek için en az 2 kişi seçilmelidir.'),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }

    if (_isSpinning) return;
    _isSpinning = true;

    final random = math.Random();
    const double twoPi = 2 * math.pi;
    final winnerIndex = random.nextInt(members.length);
    final sliceAngle = twoPi / members.length;
    _spinningSliceAngle = sliceAngle;

    // İşaretçi saat 12 yönünde (üstte) durduğu için:
    // Üstteki açı 3 * pi / 2 (270 derece)
    // Slicelar 0 açısından başlar.
    // Kapalı Modüler Formül: O(1) sıfır while döngüsü
    final targetSliceCenter = (winnerIndex * sliceAngle) + (sliceAngle / 2);
    const double pointerAngle = 3 * math.pi / 2;
    final stopAngle = ((pointerAngle - targetSliceCenter) % twoPi + twoPi) % twoPi;

    // 5 ile 8 tam tur ekle (hızlı ve heyecanlı dönüş)
    final fullRotations = (5 + random.nextInt(4)) * twoPi;
    final startAngle = (_currentAngle % twoPi + twoPi) % twoPi;
    final totalTarget = _currentAngle + (fullRotations + stopAngle - startAngle);

    _previousAngle = _currentAngle;
    _animation = Tween<double>(begin: _previousAngle, end: totalTarget).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward(from: 0.0);
  }

  HouseholdMember _calculateWinner() {
    const double twoPi = 2 * math.pi;
    final members = _getParticipatingMembers();
    final sliceAngle = twoPi / members.length;
    const double pointerAngle = 3 * math.pi / 2;

    // Kapalı modüler aritmetik: O(1) sıfır while döngüsü
    final normalized = ((pointerAngle - _currentAngle) % twoPi + twoPi) % twoPi;
    final index = (normalized / sliceAngle).floor() % members.length;
    return members[index];
  }

  void _showWinnerDialog() {
    final winner = _calculateWinner();
    final taskName = _selectedTask == 'Özel Görev' &&
            _customTaskController.text.trim().isNotEmpty
        ? _customTaskController.text.trim()
        : _selectedTask;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Çark Kararını Verdi!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      winner.displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sıra sende, görevin:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      taskName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Evdaş Karar Çarkı sonucu belirlendi, iyi şanslar!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton.icon(
            onPressed: () {
              final shareText =
                  '*Evdaş Karar Çarkı Sonucu*\n'
                  'Görev: $taskName\n'
                  'Seçilen Kişi: *${winner.displayName}*\n\n'
                  'Çark sonucu belirlendi, görevi yapma sırası sende!';
              SharePlus.instance.share(
                ShareParams(
                  text: shareText,
                  subject: 'Ev Karar Çarkı Sonucu',
                ),
              );
            },
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Ortaklarla Paylaş'),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Tamamdır!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final house = ref.watch(householdProvider);
    final members = house?.members ?? [];

    if (_selectedMemberIds.isEmpty && members.isNotEmpty) {
      _selectedMemberIds.addAll(members.map((m) => m.id));
    }

    final participating = _getParticipatingMembers();

    return PatternBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Ev Karar Çarkı',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // 1. GÖREV SEÇİM ALANI
            _buildTaskSelector(),

            const SizedBox(height: 16),

            // 2. ÇARK ALANI VE İBRE
            LayoutBuilder(
              builder: (context, constraints) {
                final wheelSize = math.min(270.0, constraints.maxWidth - 20.0);
                return SizedBox(
                  height: wheelSize + 20,
                  width: wheelSize + 20,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Dönen Çark
                      Transform.rotate(
                        angle: _currentAngle,
                        child: CustomPaint(
                          size: Size(wheelSize, wheelSize),
                          painter: _WheelPainter(
                            members: participating,
                            colors: _wheelColors,
                          ),
                        ),
                      ),

                      // Merkez Göbek
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.casino_rounded,
                            color: house?.displayColor ?? AppColors.primary,
                            size: 26,
                          ),
                        ),
                      ),

                      // Üstteki İşaretçi / İbre (Pointer)
                      Positioned(
                        top: 0,
                        child: Container(
                          width: 24,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // 3. ÇEVİR BUTONU
            ElevatedButton(
              onPressed: _isSpinning || participating.length < 2
                  ? null
                  : _spinWheel,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sync_rounded, size: 24),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _isSpinning
                          ? 'Çark Dönüyor...'
                          : 'Çarkı Çevir! (${participating.length} Kişi)',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 4. KATILAN ORTAKLAR SEÇİCİ
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Çarka Katılan Ortaklar',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${participating.length}/${members.length} seçildi',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: members.map((m) {
                        final isSelected = _selectedMemberIds.contains(m.id);
                        return FilterChip(
                          selected: isSelected,
                          avatar: CircleAvatar(
                            radius: 12,
                            backgroundColor: isSelected
                                ? Colors.white
                                : AppColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              m.displayName.isNotEmpty
                                  ? m.displayName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                          label: Text(m.displayName),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected ? Colors.white : null,
                          ),
                          onSelected: (val) {
                            if (_isSpinning) return;
                            setState(() {
                              if (val) {
                                _selectedMemberIds.add(m.id);
                              } else {
                                if (_selectedMemberIds.length > 2) {
                                  _selectedMemberIds.remove(m.id);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Çark için en az 2 kişi seçili kalmalıdır.'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildTaskSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_rounded,
                    size: 18, color: AppColors.primary),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Kura Konusu / Görev',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _taskPresets.map((task) {
                  final isSelected = _selectedTask == task;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text(task),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : null,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedTask = task);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            if (_selectedTask == 'Özel Görev') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customTaskController,
                decoration: InputDecoration(
                  hintText: 'Özel görev yazın (örn: Fırını temizle)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<HouseholdMember> members;
  final List<Color> colors;

  _WheelPainter({required this.members, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (members.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = (2 * math.pi) / members.length;
    final wheelRect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < members.length; i++) {
      paint.color = colors[i % colors.length];
      final startAngle = i * sweepAngle;

      canvas.drawArc(
        wheelRect,
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      canvas.drawArc(
        wheelRect,
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      // Üye İsmini Çiz
      canvas.save();
      final textAngle = startAngle + sweepAngle / 2;
      canvas.translate(center.dx, center.dy);
      canvas.rotate(textAngle);

      final textSpan = TextSpan(
        text: members[i].displayName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(
              color: Colors.black45,
              blurRadius: 3,
              offset: Offset(1, 1),
            ),
          ],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: radius * 0.65);

      textPainter.paint(
        canvas,
        Offset(radius * 0.30, -textPainter.height / 2),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.members != members;
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';

class ConfettiOverlay {
  static void show(BuildContext context, {Duration duration = const Duration(milliseconds: 2500)}) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ConfettiParticleWidget(
        duration: duration,
        onComplete: () {
          if (entry.mounted) {
            entry.remove();
          }
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _ConfettiParticleWidget extends StatefulWidget {
  final Duration duration;
  final VoidCallback onComplete;

  const _ConfettiParticleWidget({
    required this.duration,
    required this.onComplete,
  });

  @override
  State<_ConfettiParticleWidget> createState() => _ConfettiParticleWidgetState();
}

class _ConfettiParticleWidgetState extends State<_ConfettiParticleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  final List<Color> _colors = const [
    Color(0xFFF97316), // Coral
    Color(0xFF10B981), // Emerald
    Color(0xFF0284C7), // Blue
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFFE11D48), // Red
    Color(0xFFFACC15), // Gold
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _controller.addListener(() {
      setState(() {
        for (final p in _particles) {
          p.update();
        }
      });
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      for (int i = 0; i < 90; i++) {
        _particles.add(
          _ConfettiParticle(
            x: size.width * 0.5 + (_random.nextDouble() * 120 - 60),
            y: size.height * 0.35 + (_random.nextDouble() * 60 - 30),
            color: _colors[_random.nextInt(_colors.length)],
            vx: (_random.nextDouble() * 16 - 8),
            vy: -(_random.nextDouble() * 15 + 8),
            size: _random.nextDouble() * 8 + 6,
            shape: _random.nextInt(3),
            rotation: _random.nextDouble() * 2 * math.pi,
            rotationSpeed: (_random.nextDouble() * 0.3 - 0.15),
          ),
        );
      }
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _ConfettiPainter(particles: _particles, opacity: 1.0 - _controller.value * 0.3),
      ),
    );
  }
}

class _ConfettiParticle {
  double x;
  double y;
  final Color color;
  double vx;
  double vy;
  final double size;
  final int shape; // 0: rect, 1: circle, 2: strip
  double rotation;
  final double rotationSpeed;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.vx,
    required this.vy,
    required this.size,
    required this.shape,
    required this.rotation,
    required this.rotationSpeed,
  });

  void update() {
    x += vx;
    y += vy;
    vy += 0.45; // gravity
    vx *= 0.985; // friction
    rotation += rotationSpeed;
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double opacity;

  _ConfettiPainter({required this.particles, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      if (p.shape == 0) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.7),
          paint,
        );
      } else if (p.shape == 1) {
        canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size * 1.5, height: p.size * 0.4),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

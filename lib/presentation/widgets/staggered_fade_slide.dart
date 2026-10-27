import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Herhangi bir liste veya kart öğesini zarif bir yukarı kayma (slide-up) ve
/// solma (fade-in) mikro-animasyonuyla ekrana getiren, harici bağımlılık gerektirmeyen
/// (zero bloatware) donanım hızlandırmalı widget.
class StaggeredFadeSlide extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration duration;
  final Duration? delay;
  final Offset offset;
  final Curve curve;

  const StaggeredFadeSlide({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 320),
    this.delay,
    this.offset = const Offset(0.0, 0.08),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    // Stagger gecikmesi indeks başına 35ms (Aşırı uzun bekleme olmaması için maks 350ms)
    final delayMs = widget.delay?.inMilliseconds ??
        math.min(widget.index * 35, 350);

    if (delayMs <= 0) {
      _controller.forward();
    } else {
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // OS düzeyinde animasyonlar kapatılmışsa (Reduced Motion) direkt render et
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

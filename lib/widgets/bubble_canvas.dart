import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bubble.dart';
import '../providers/bubble_provider.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';

class BubbleCanvas extends StatefulWidget {
  final Function(Bubble) onBubbleTap;

  const BubbleCanvas({super.key, required this.onBubbleTap});

  @override
  State<BubbleCanvas> createState() => _BubbleCanvasState();
}

class _BubbleCanvasState extends State<BubbleCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Duration _lastElapsed = Duration.zero;
  final AudioService _audio = AudioService();
  String? _draggedBubbleId;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(_updatePhysics);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updatePhysics() {
    final elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;

    if (delta > Duration.zero) {
      context.read<BubbleProvider>().updatePhysics(delta);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<BubbleProvider>().setScreenSize(
            constraints.maxWidth,
            constraints.maxHeight,
          );
        });

        return Consumer<BubbleProvider>(
          builder: (context, provider, child) {
            return GestureDetector(
              onTapUp: (details) => _handleTap(details, provider),
              onPanStart: (details) => _handlePanStart(details, provider),
              onPanUpdate: (details) => _handlePanUpdate(details, provider),
              onPanEnd: (details) => _handlePanEnd(details, provider),
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: BubblePainter(
                  bubbles: provider.bubbles,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleTap(TapUpDetails details, BubbleProvider provider) {
    if (_draggedBubbleId != null) return;

    final tapPos = details.localPosition;
    for (final bubble in provider.bubbles) {
      final dx = tapPos.dx - bubble.x;
      final dy = tapPos.dy - bubble.y;
      final distance = math.sqrt(dx * dx + dy * dy);

      if (distance <= bubble.radius) {
        _audio.triggerHapticMedium();
        _audio.playTap();
        widget.onBubbleTap(bubble);
        break;
      }
    }
  }

  void _handlePanStart(DragStartDetails details, BubbleProvider provider) {
    final pos = details.localPosition;
    for (final bubble in provider.bubbles) {
      final dx = pos.dx - bubble.x;
      final dy = pos.dy - bubble.y;
      final distance = math.sqrt(dx * dx + dy * dy);

      if (distance <= bubble.radius) {
        _draggedBubbleId = bubble.id;
        provider.onBubbleDragStart(bubble.id);
        _audio.triggerHapticLight();
        break;
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, BubbleProvider provider) {
    if (_draggedBubbleId != null) {
      provider.onBubbleDragUpdate(
        _draggedBubbleId!,
        math.Point(details.localPosition.dx, details.localPosition.dy),
      );
    }
  }

  void _handlePanEnd(DragEndDetails details, BubbleProvider provider) {
    if (_draggedBubbleId != null) {
      final velocity = details.velocity.pixelsPerSecond;
      provider.onBubbleDragEnd(
        _draggedBubbleId!,
        math.Point(velocity.dx, velocity.dy),
      );
      _draggedBubbleId = null;
    }
  }
}

class BubblePainter extends CustomPainter {
  final List<Bubble> bubbles;
  final bool isDark;

  BubblePainter({required this.bubbles, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Sort so dragged bubbles are on top
    final sortedBubbles = List<Bubble>.from(bubbles)
      ..sort((a, b) => (a.isDragged ? 1 : 0).compareTo(b.isDragged ? 1 : 0));

    for (final bubble in sortedBubbles) {
      _drawBubble(canvas, bubble, size);
    }
  }

  void _drawBubble(Canvas canvas, Bubble bubble, Size size) {
    final center = Offset(bubble.x, bubble.y);
    final ratio = bubble.spendRatio;
    final baseColor = _parseHexColor(bubble.colorHex);
    final currentRadius = bubble.isDragged
        ? bubble.radius * 1.08
        : bubble.radius;

    // Pass 1: Elevation Shadow (Light mode = soft black shadow, Dark mode = subtle neon ambient colored back-glow to pop against black background!)
    final shadowOffset = Offset(0.0, currentRadius * 0.10);
    final shadowColor = isDark
        ? baseColor.withOpacity(0.28) // Dynamic, gorgeous back-glow of the category's own color!
        : Colors.black.withOpacity(0.14); // Standard soft drop shadow
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDark ? currentRadius * 0.22 : currentRadius * 0.18);
    canvas.drawCircle(center + shadowOffset, currentRadius, shadowPaint);

    // 1. Draw elegant outer status rings if needed
    if (ratio > 1.0) {
      final ringPaint = Paint()
        ..color = const Color(0xFFFF5A5F).withAlpha(200)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6;
      canvas.drawCircle(center, currentRadius + 5, ringPaint);

      final glowPaint = Paint()
        ..color = const Color(0xFFFF5A5F).withAlpha(62)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8.0);
      canvas.drawCircle(center, currentRadius + 6, glowPaint);
    } else if (ratio > 0.8) {
      final ringPaint = Paint()
        ..color = const Color(0xFFFBBF24).withAlpha(165)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, currentRadius + 4, ringPaint);

      final glowPaint = Paint()
        ..color = const Color(0xFFFBBF24).withAlpha(46)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5.0);
      canvas.drawCircle(center, currentRadius + 4, glowPaint);
    }

    // Pass 2: Radial Body (Centered at top-left specular glint Alignment(-0.35, -0.35))
    // In Dark Mode, we increase the specular glint factor to 0.62 and bottom-right shadow factor to 0.55 to maximize volumetric depth!
    final glintFactor = isDark ? 0.62 : 0.50;
    final shadowFactor = isDark ? 0.55 : 0.42;

    // Four stops rather than three: the bright core is held a little longer and
    // then rolls into the body faster, which is the falloff a curved surface
    // actually has. Dark-mode endpoint colours are deliberately unchanged.
    final bodyGradient = RadialGradient(
      center: const Alignment(-0.32, -0.38),
      radius: 0.95,
      colors: [
        Color.lerp(baseColor, Colors.white, glintFactor)!, // Specular top-left glint
        Color.lerp(baseColor, Colors.white, glintFactor * 0.45)!, // Highlight falloff
        baseColor, // Main sphere body
        Color.lerp(baseColor, Colors.black, shadowFactor)!, // Deep bottom-right shadow
      ],
      stops: const [0.0, 0.28, 0.66, 1.0],
    );

    final bodyPaint = Paint()
      ..shader = bodyGradient.createShader(
        Rect.fromCircle(center: center, radius: currentRadius),
      );
    canvas.drawCircle(center, currentRadius, bodyPaint);

    // Pass 2b: Specular catch-light. One soft ellipse in the upper-left is the
    // single strongest cue that a shaded circle is a glass sphere.
    final catchRect = Rect.fromCenter(
      center: center + Offset(-currentRadius * 0.40, -currentRadius * 0.44),
      width: currentRadius * 0.60,
      height: currentRadius * 0.40,
    );
    final catchPaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, currentRadius * 0.06);
    canvas.drawOval(catchRect, catchPaint);

    // Pass 3: Ambient Rim (Draw a 1.2px stroke around perimeter to prevent color bleed and add crispness)
    final rimColor = isDark
        ? Colors.white.withOpacity(0.18) // Doubled opacity for high contrast glass edge in Dark Mode!
        : Colors.black.withOpacity(0.06);
    final rimPaint = Paint()
      ..color = rimColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, currentRadius, rimPaint);

    // Pass 3b: on real glass the rim is bright where it faces the light and
    // nearly gone on the shaded side. Keep the uniform rim as the base, then
    // lay a brighter arc over its upper-left quadrant (195 deg -> 300 deg).
    final rimArcPaint = Paint()
      ..color = Colors.white.withOpacity(isDark ? 0.30 : 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: currentRadius),
      math.pi * 195 / 180,
      math.pi * 105 / 180,
      false,
      rimArcPaint,
    );

    // 3. Category Text
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '...',
    );

    const shadow = Shadow(
      blurRadius: 6.0,
      color: Colors.black45,
      offset: Offset(0, 1.5),
    );

    final labelFontSize = (currentRadius * 0.22).clamp(12.0, 22.0);

    textPainter.text = TextSpan(
      text: bubble.categoryName,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: labelFontSize,
        shadows: const [shadow],
      ),
    );
    textPainter.layout(maxWidth: currentRadius * 1.8);
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height),
    );

    final settings = SettingsService();
    textPainter.text = TextSpan(
      text: bubble.isBudgeted
          ? '${settings.currencySymbol}${bubble.monthlySpend.toStringAsFixed(2)} / ${settings.currencySymbol}${bubble.budgetLimit.toStringAsFixed(2)}'
          : '${settings.currencySymbol}${bubble.monthlySpend.toStringAsFixed(2)}',
      style: TextStyle(
        color: Colors.white.withAlpha(235),
        fontSize: (currentRadius * 0.17).clamp(9.0, 15.0),
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        // Locks digit width so the amount stops shifting sideways as it repaints.
        fontFeatures: const [FontFeature.tabularFigures()],
        shadows: const [shadow],
      ),
    );
    textPainter.layout(maxWidth: currentRadius * 1.8);
    textPainter.paint(canvas, center + Offset(-textPainter.width / 2, 4));
  }

  Color _parseHexColor(String hex) {
    try {
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return Colors.blueAccent;
    }
  }

  @override
  bool shouldRepaint(covariant BubblePainter oldDelegate) => true;
}

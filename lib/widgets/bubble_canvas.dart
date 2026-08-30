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
                painter: BubblePainter(bubbles: provider.bubbles),
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

  BubblePainter({required this.bubbles});

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

    // 0. Shadow lift if dragged
    if (bubble.isDragged) {
      final shadowPaint = Paint()
        ..color = Colors.black.withAlpha(80)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
      canvas.drawCircle(
        center + const Offset(0, 8),
        currentRadius,
        shadowPaint,
      );
    }

    // 1. Draw elegant outer status rings if needed
    if (ratio > 1.0) {
      final ringPaint = Paint()
        ..color = Colors.redAccent.withAlpha(180)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawCircle(center, currentRadius + 5, ringPaint);

      final glowPaint = Paint()
        ..color = Colors.redAccent.withAlpha(60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8.0);
      canvas.drawCircle(center, currentRadius + 6, glowPaint);
    } else if (ratio > 0.8) {
      final ringPaint = Paint()
        ..color = Colors.orangeAccent.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, currentRadius + 4, ringPaint);

      final glowPaint = Paint()
        ..color = Colors.orangeAccent.withAlpha(40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5.0);
      canvas.drawCircle(center, currentRadius + 4, glowPaint);
    }

    // Dynamic Point-Light Source (Torch at Top-Left)
    final lightSource = Offset(size.width * 0.12, size.height * 0.04);
    final toLight = lightSource - center;
    final distanceToLight = toLight.distance;
    final dir = distanceToLight > 0.001 ? toLight / distanceToLight : const Offset(0, -1);

    final lightAlignX = (dir.dx * 0.45).clamp(-0.5, 0.5);
    final lightAlignY = (dir.dy * 0.45).clamp(-0.5, 0.5);

    final maxDistance = size.longestSide > 0 ? size.longestSide : 800.0;
    final proximityFactor = (1.0 - (distanceToLight / maxDistance).clamp(0.0, 1.0));
    final sheenStrength = 0.20 + (proximityFactor * 0.15);

    // 2a. Seamless Volumetric Gradient (No hard circles or disc artifacts)
    final bodyGradient = RadialGradient(
      center: Alignment(lightAlignX, lightAlignY),
      radius:
          1.15, // Smoothly spans past the edge for a feathered organic falloff
      colors: [
        Color.lerp(
          baseColor,
          Colors.white,
          sheenStrength,
        )!, // Soft subtle sheen facing the torch
        baseColor.withAlpha(235), // Base sphere body
        Color.lerp(
          baseColor,
          Colors.black,
          0.25,
        )!, // Deep shadow on opposite side
      ],
      stops: const [0.0, 0.55, 1.0],
    );

    final paint = Paint()
      ..shader = bodyGradient.createShader(
        Rect.fromCircle(center: center, radius: currentRadius),
      );
    canvas.drawCircle(center, currentRadius, paint);

    // 2b. Dynamic Glass Rim Highlight (Brighter edge facing the torch)
    final rimPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(dir.dx, dir.dy),
        end: Alignment(-dir.dx, -dir.dy),
        colors: [
          Colors.white.withAlpha(
            (40 + proximityFactor * 40).toInt(),
          ), // Catch light facing torch
          Colors.white.withAlpha(10), // Faint ambient edge on shadow side
        ],
      ).createShader(Rect.fromCircle(center: center, radius: currentRadius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, currentRadius - 0.5, rimPaint);
    // 3. Category Text
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    const shadow = Shadow(
      blurRadius: 4.0,
      color: Colors.black54,
      offset: Offset(1, 1),
    );

    textPainter.text = TextSpan(
      text: bubble.categoryName,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: (currentRadius / 4.2).clamp(11, 16),
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
        color: Colors.white.withAlpha(230),
        fontSize: (currentRadius / 5.5).clamp(9, 13),
        fontWeight: FontWeight.w500,
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

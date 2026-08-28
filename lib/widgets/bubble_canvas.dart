import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bubble.dart';
import '../providers/bubble_provider.dart';
import '../services/audio_service.dart';

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
      _drawBubble(canvas, bubble);
    }
  }

  void _drawBubble(Canvas canvas, Bubble bubble) {
    final center = Offset(bubble.x, bubble.y);
    final ratio = bubble.spendRatio;
    final baseColor = _parseHexColor(bubble.colorHex);
    final currentRadius = bubble.isDragged ? bubble.radius * 1.08 : bubble.radius;

    // 0. Shadow lift if dragged
    if (bubble.isDragged) {
      final shadowPaint = Paint()
        ..color = Colors.black.withAlpha(80)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
      canvas.drawCircle(center + const Offset(0, 8), currentRadius, shadowPaint);
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

    // 2. Main Bubble Body with Gradient
    final gradient = RadialGradient(
      colors: [
        baseColor.withAlpha(200),
        baseColor,
      ],
      stops: const [0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: currentRadius),
      );

    canvas.drawCircle(center, currentRadius, paint);
    
    final rimPaint = Paint()
      ..color = Colors.white.withAlpha(30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, currentRadius - 1, rimPaint);

    // 3. Category Text
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    const shadow = Shadow(blurRadius: 4.0, color: Colors.black54, offset: Offset(1, 1));

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

    textPainter.text = TextSpan(
      text: '${bubble.monthlySpend.toStringAsFixed(0)} / ${bubble.budgetLimit.toStringAsFixed(0)}',
      style: TextStyle(
        color: Colors.white.withAlpha(230),
        fontSize: (currentRadius / 5.5).clamp(9, 13),
        fontWeight: FontWeight.w500,
        shadows: const [shadow],
      ),
    );
    textPainter.layout(maxWidth: currentRadius * 1.8);
    textPainter.paint(
      canvas,
      center + Offset(-textPainter.width / 2, 4),
    );
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

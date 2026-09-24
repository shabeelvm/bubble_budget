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
    with TickerProviderStateMixin {
  late AnimationController _controller;
  Duration _lastElapsed = Duration.zero;
  final AudioService _audio = AudioService();
  String? _draggedBubbleId;

  /// Which bubble was poked, where it was poked, and how far through the
  /// wobble we are. Deliberately widget state, not model state: presentation
  /// only, never reaches the provider or the database.
  String? _pressedBubbleId;
  double _pokeAngle = 0.0;
  late AnimationController _pokeCtl;

  /// One-shot: the whole arc plays from tap-down regardless of when the finger
  /// lifts. Tying it to press/release was the bug - a real tap is often
  /// shorter than the press-in, so the squash never completed and all you saw
  /// was the tail of the rebound.
  static const Duration _pokeDuration = Duration(milliseconds: 820);

  /// How long the sheet waits before covering the canvas. Long enough to see
  /// the dent and the first rebound, short enough not to be friction.
  static const Duration _pressRevealDelay = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(_updatePhysics);
    _controller.repeat();

    // Drives 0 -> 1 once per poke. The painter reads this raw and shapes it
    // into two decaying harmonics; no Curve is involved, because the motion we
    // want is a damped oscillation rather than an eased interpolation.
    _pokeCtl = AnimationController(vsync: this, duration: _pokeDuration);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pokeCtl.dispose();
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
              onTapDown: (details) => _handleTapDown(details, provider),
              onTapCancel: _handleTapCancel,
              onTapUp: (details) => _handleTap(details, provider),
              onPanStart: (details) => _handlePanStart(details, provider),
              onPanUpdate: (details) => _handlePanUpdate(details, provider),
              onPanEnd: (details) => _handlePanEnd(details, provider),
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: BubblePainter(
                  bubbles: provider.bubbles,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                  pressedBubbleId: _pressedBubbleId,
                  pokeT: _pokeCtl.value,
                  pokeAngle: _pokeAngle,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Bubble? _bubbleAt(Offset pos, BubbleProvider provider) {
    for (final bubble in provider.bubbles) {
      final dx = pos.dx - bubble.x;
      final dy = pos.dy - bubble.y;
      if (math.sqrt(dx * dx + dy * dy) <= bubble.radius) return bubble;
    }
    return null;
  }

  void _handleTapDown(TapDownDetails details, BubbleProvider provider) {
    if (_draggedBubbleId != null) return;

    final pos = details.localPosition;
    final bubble = _bubbleAt(pos, provider);
    if (bubble == null) return;

    // The dent goes where the finger landed, not always downward.
    _pokeAngle = math.atan2(pos.dy - bubble.y, pos.dx - bubble.x);
    _pressedBubbleId = bubble.id;

    _audio.triggerHapticLight();
    _pokeCtl.forward(from: 0.0).whenComplete(() {
      if (mounted) _pressedBubbleId = null;
    });
  }

  void _handleTapCancel() {
    // The wobble is one-shot and already running; let it finish on its own.
  }

  void _handleTap(TapUpDetails details, BubbleProvider provider) {
    if (_draggedBubbleId != null) return;

    final bubble = _bubbleAt(details.localPosition, provider);
    if (bubble == null) return;

    _audio.triggerHapticMedium();
    _audio.playTap();

    // Let the dent and first rebound be seen before the sheet covers it.
    Future.delayed(_pressRevealDelay, () {
      if (mounted) widget.onBubbleTap(bubble);
    });
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

  /// The poked bubble, how far through the wobble it is (0 -> 1), and the
  /// angle from its centre to the point the finger landed.
  final String? pressedBubbleId;
  final double pokeT;
  final double pokeAngle;

  BubblePainter({
    required this.bubbles,
    required this.isDark,
    this.pressedBubbleId,
    this.pokeT = 0.0,
    this.pokeAngle = 0.0,
  });

  // ---------------------------------------------------------------------
  // Surface wobble
  //
  // The outline is a sum of two angular harmonics rather than an ellipse.
  // An ellipse is a single mode and always reads as "squeezed between two
  // plates"; real liquid deforms locally where it is touched and the wave
  // travels round the surface. Two modes with different decay rates give
  // that, because higher modes die faster in any real fluid - which is what
  // stops the shape from merely scaling.
  //
  // Both are cosines of (theta - pokeAngle), so the dent lands under the
  // finger. Their mean over a full turn is zero, so the enclosed area stays
  // roughly constant and the bubble does not appear to shrink.
  // ---------------------------------------------------------------------

  /// Depth of the initial dent, as a fraction of the radius.
  static const double _wobbleAmplitude = 0.135;

  /// Mode 2 is the broad squash; mode 3 is the asymmetry that keeps it from
  /// looking like a rotating ellipse.
  ///
  /// Mode 3 is driven by SIN, not cos, so it starts at zero and peaks while
  /// mode 2 is crossing through zero. That phase offset is what makes it
  /// visible at all: with both on cos and mode 3 decaying fast, mode 3 lived
  /// for about three frames and was swamped by the much deeper mode-2 dent -
  /// physically correct, perceptually invisible.
  ///
  /// It is also the truer shape. A poke starts as a clean indentation and the
  /// surface breaks into higher modes as it rebounds, which is what a real
  /// droplet does.
  static const double _mode3Ratio = 0.0;
  static const double _mode2Decay = 4.2;
  static const double _mode3Decay = 3.0;
  static const double _mode2Cycles = 1.45;
  static const double _mode3Cycles = 1.00;

  /// Points around the outline. 72 is smooth at every size the app uses.
  static const int _wobbleSteps = 72;

  /// The bright rim arc spans this slice of the outline (upper left).
  static const double _rimArcStartDeg = 195.0;
  static const double _rimArcSweepDeg = 105.0;

  /// The same wobble outline, but only the rim-arc slice of it. Without this
  /// the bright arc kept being stroked on a perfect circle while the body
  /// deformed, leaving a white crescent floating outside the dented bubble -
  /// obvious against the dark canvas, nearly invisible on the light one.
  Path _wobbleArcPath(Offset centre, double radius, double t) {
    final double a2 = _mode2At(t);
    final double a3 = _mode3At(t);

    final double start = _rimArcStartDeg * math.pi / 180.0;
    final double sweep = _rimArcSweepDeg * math.pi / 180.0;
    const int steps = 24;

    final Path path = Path();
    for (int i = 0; i <= steps; i++) {
      final double th = start + sweep * i / steps;
      final double d = th - pokeAngle;
      final double r =
          radius * (1.0 - a2 * math.cos(2 * d) - a3 * math.cos(3 * d));
      final double x = centre.dx + r * math.cos(th);
      final double y = centre.dy + r * math.sin(th);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  double _mode2At(double t) =>
      _wobbleAmplitude *
      math.exp(-_mode2Decay * t) *
      math.cos(2 * math.pi * _mode2Cycles * t);

  double _mode3At(double t) =>
      _wobbleAmplitude *
      _mode3Ratio *
      math.exp(-_mode3Decay * t) *
      math.sin(2 * math.pi * _mode3Cycles * t);

  /// Only ever one bubble is poked at a time, so this runs once per frame
  /// rather than once per bubble.
  ///
  /// [outset] pushes the outline out by a fixed number of pixels, used by the
  /// budget status rings. It is added AFTER the harmonics rather than folded
  /// into the radius, so the ring keeps a constant gap from the surface
  /// instead of the gap breathing as the bubble deforms.
  Path _wobblePath(Offset centre, double radius, double t,
      {double outset = 0.0}) {
    final double a2 = _mode2At(t);
    final double a3 = _mode3At(t);

    final Path path = Path();
    for (int i = 0; i <= _wobbleSteps; i++) {
      final double th = 2 * math.pi * i / _wobbleSteps;
      final double d = th - pokeAngle;
      final double r =
          radius * (1.0 - a2 * math.cos(2 * d) - a3 * math.cos(3 * d)) +
              outset;
      final double x = centre.dx + r * math.cos(th);
      final double y = centre.dy + r * math.sin(th);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Sort so dragged and pressed bubbles are on top - a squash hidden under
    // a neighbour is no confirmation at all.
    int lift(Bubble b) =>
        (b.isDragged || b.id == pressedBubbleId) ? 1 : 0;
    final sortedBubbles = List<Bubble>.from(bubbles)
      ..sort((a, b) => lift(a).compareTo(lift(b)));

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

    // Non-null only while this bubble is mid-wobble. Shadow, body and rim all
    // follow it so the deformation is of the whole object, not a decal on it.
    final Path? wobble = (bubble.id == pressedBubbleId && pokeT > 0.0 && pokeT < 1.0)
        ? _wobblePath(center, currentRadius, pokeT)
        : null;

    // Pass 1: Elevation Shadow (Light mode = soft black shadow, Dark mode = subtle neon ambient colored back-glow to pop against black background!)
    final shadowOffset = Offset(0.0, currentRadius * 0.10);
    final shadowColor = isDark
        ? baseColor.withOpacity(0.28) // Dynamic, gorgeous back-glow of the category's own color!
        : Colors.black.withOpacity(0.14); // Standard soft drop shadow
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDark ? currentRadius * 0.22 : currentRadius * 0.18);
    if (wobble != null) {
      canvas.drawPath(wobble.shift(shadowOffset), shadowPaint);
    } else {
      canvas.drawCircle(center + shadowOffset, currentRadius, shadowPaint);
    }

    // 1. Draw elegant outer status rings if needed
    if (ratio > 1.0) {
      final ringPaint = Paint()
        ..color = const Color(0xFFFF5A5F).withAlpha(200)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6;
      final glowPaint = Paint()
        ..color = const Color(0xFFFF5A5F).withAlpha(62)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8.0);

      if (wobble != null) {
        canvas.drawPath(
            _wobblePath(center, currentRadius, pokeT, outset: 5.0), ringPaint);
        canvas.drawPath(
            _wobblePath(center, currentRadius, pokeT, outset: 6.0), glowPaint);
      } else {
        canvas.drawCircle(center, currentRadius + 5, ringPaint);
        canvas.drawCircle(center, currentRadius + 6, glowPaint);
      }
    } else if (ratio > 0.8) {
      final ringPaint = Paint()
        ..color = const Color(0xFFFBBF24).withAlpha(165)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final glowPaint = Paint()
        ..color = const Color(0xFFFBBF24).withAlpha(46)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5.0);

      if (wobble != null) {
        canvas.drawPath(
            _wobblePath(center, currentRadius, pokeT, outset: 4.0), ringPaint);
        canvas.drawPath(
            _wobblePath(center, currentRadius, pokeT, outset: 4.0), glowPaint);
      } else {
        canvas.drawCircle(center, currentRadius + 4, ringPaint);
        canvas.drawCircle(center, currentRadius + 4, glowPaint);
      }
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
    if (wobble != null) {
      canvas.drawPath(wobble, bodyPaint);
    } else {
      canvas.drawCircle(center, currentRadius, bodyPaint);
    }

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

    if (wobble != null) {
      canvas.drawPath(wobble, rimPaint);
    } else {
      canvas.drawCircle(center, currentRadius, rimPaint);
    }

    // Pass 3b: on real glass the rim is bright where it faces the light and
    // nearly gone on the shaded side. Keep the uniform rim as the base, then
    // lay a brighter arc over its upper-left quadrant (195 deg -> 300 deg).
    final rimArcPaint = Paint()
      ..color = Colors.white.withOpacity(isDark ? 0.30 : 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    if (wobble != null) {
      canvas.drawPath(_wobbleArcPath(center, currentRadius, pokeT), rimArcPaint);
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: currentRadius),
        _rimArcStartDeg * math.pi / 180.0,
        _rimArcSweepDeg * math.pi / 180.0,
        false,
        rimArcPaint,
      );
    }

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
          ? '${settings.currencySymbol}${bubble.monthlySpend.toStringAsFixed(settings.currencyDecimals)} / ${settings.currencySymbol}${bubble.budgetLimit.toStringAsFixed(settings.currencyDecimals)}'
          : '${settings.currencySymbol}${bubble.monthlySpend.toStringAsFixed(settings.currencyDecimals)}',
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

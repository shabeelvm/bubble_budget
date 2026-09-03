// DEV-ONLY mock of the proposed canvas redo. Nothing in the app imports it.
//
// What this proposes, after review:
//   * size always means money (currently it means ratio for budgeted bubbles
//     and money for unbudgeted ones, on the same screen)
//   * a header that always shows the month's total spend
//   * a dock where all four destinations are labelled and equal
//
// What it deliberately does NOT propose:
//   * no liquid fill level (dropped on review)
//   * no change to budget behaviour - budgets stay opt-in and default to 0,
//     exactly as they do today
//   * no "$x over" text; the red ring already says it

import 'dart:math' as math;

import 'package:flutter/material.dart';
// Scoped to DateFormat on purpose: intl also exports a TextDirection class,
// which would shadow the dart:ui one that TextPainter needs.
import 'package:intl/intl.dart' show DateFormat;

import '../services/settings_service.dart';

class ProposedBubble {
  final String name;
  final double spend;

  /// The limit this category would have IF the user set one. Applied only when
  /// [budgetedByDefault] is true, or when the "all budgeted" switch is on.
  final double limit;
  final bool budgetedByDefault;
  final String colorHex;

  const ProposedBubble(
    this.name,
    this.spend,
    this.limit,
    this.budgetedByDefault,
    this.colorHex,
  );
}

// A realistic mix: budgets are opt-in, so most categories have none. Two are
// budgeted, four are not - which is exactly the case the header has to get
// right.
const List<ProposedBubble> kProposedBubbles = <ProposedBubble>[
  ProposedBubble('Groceries', 512.0, 600.0, true, 'FF4CAF50'),
  ProposedBubble('Dining Out', 240.0, 300.0, false, 'FFFF5722'),
  ProposedBubble('Transport', 176.0, 150.0, true, 'FF2196F3'),
  ProposedBubble('Coffee', 21.0, 80.0, false, 'FF795548'),
  ProposedBubble('Utilities', 88.0, 120.0, false, 'FFF59E0B'),
  ProposedBubble('Fun', 118.0, 200.0, false, 'FFEC4899'),
];

double _baseRadius(double w, double h) {
  final double area = w * h;
  return area > 0 ? (math.sqrt(area) * 0.125).clamp(70.0, 130.0) : 80.0;
}

/// Verbatim copy of BubbleProvider.calculateRadius, for comparison.
double currentRadiusOf(double spend, double limit, double w, double h) {
  final double base = _baseRadius(w, h);
  if (limit <= 0) {
    final double r = base + math.sqrt(spend) * 2.5;
    return r.clamp(base, base * 1.6);
  }
  final double ratio = spend / limit;
  final double r = base + (ratio * (base * 0.6));
  return r.clamp(base * 0.7, base * 1.6);
}

/// Proposed: size is always money, budgeted or not, so every bubble on screen
/// is measured on the same scale. Radius tracks sqrt(spend) because area is
/// what the eye reads as quantity.
double proposedRadiusOf(double spend, double limit, double w, double h) {
  final double base = _baseRadius(w, h);
  final double r = base * 0.62 + math.sqrt(spend) * (base * 0.044);
  return r.clamp(base * 0.62, base * 1.75);
}

class _MockBubble {
  final ProposedBubble data;
  double spend;
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  bool isDragged;

  _MockBubble(this.data)
      : spend = data.spend,
        x = 0,
        y = 0,
        vx = 0,
        vy = 0,
        radius = 60,
        isDragged = false;

  double limitFor(bool allBudgeted) =>
      (allBudgeted || data.budgetedByDefault) ? data.limit : 0.0;
}

class _ProposedCanvasPainter extends CustomPainter {
  final List<_MockBubble> bubbles;
  final bool isDark;
  final bool allBudgeted;
  final String currency;
  final Listenable repaint;

  _ProposedCanvasPainter({
    required this.bubbles,
    required this.isDark,
    required this.allBudgeted,
    required this.currency,
    required this.repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final List<_MockBubble> ordered = List<_MockBubble>.from(bubbles)
      ..sort((_MockBubble a, _MockBubble b) =>
          (a.isDragged ? 1 : 0).compareTo(b.isDragged ? 1 : 0));
    for (final _MockBubble b in ordered) {
      _drawBubble(canvas, b);
    }
  }

  void _drawBubble(Canvas canvas, _MockBubble b) {
    final Color base = _parseHex(b.data.colorHex);
    final Offset centre = Offset(b.x, b.y);
    final double r = b.isDragged ? b.radius * 1.08 : b.radius;
    final double limit = b.limitFor(allBudgeted);
    final double ratio = limit > 0 ? b.spend / limit : 0.0;

    canvas.drawCircle(
      centre + Offset(0.0, r * 0.10),
      r,
      Paint()
        ..color = isDark ? base.withAlpha(71) : Colors.black.withAlpha(36)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, isDark ? r * 0.22 : r * 0.18),
    );

    if (ratio > 1.0) {
      canvas.drawCircle(
        centre,
        r + 5,
        Paint()
          ..color = const Color(0xFFFF5A5F).withAlpha(200)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
    } else if (ratio > 0.8) {
      canvas.drawCircle(
        centre,
        r + 4,
        Paint()
          ..color = const Color(0xFFFBBF24).withAlpha(165)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    final double glint = isDark ? 0.62 : 0.50;
    final double shade = isDark ? 0.55 : 0.42;
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.32, -0.38),
          radius: 0.95,
          colors: <Color>[
            Color.lerp(base, Colors.white, glint)!,
            Color.lerp(base, Colors.white, glint * 0.45)!,
            base,
            Color.lerp(base, Colors.black, shade)!,
          ],
          stops: const <double>[0.0, 0.28, 0.66, 1.0],
        ).createShader(Rect.fromCircle(center: centre, radius: r)),
    );

    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..color =
            isDark ? Colors.white.withAlpha(46) : Colors.black.withAlpha(15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: r),
      math.pi * 195 / 180,
      math.pi * 105 / 180,
      false,
      Paint()
        ..color = Colors.white.withAlpha(isDark ? 77 : 61)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: centre + Offset(-r * 0.40, -r * 0.44),
        width: r * 0.60,
        height: r * 0.40,
      ),
      Paint()
        ..color = Colors.white.withAlpha(56)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06),
    );

    // Labels: exactly today's rule - spend alone, or spend against the limit
    // once the user has set one in Manage Bubbles.
    const Shadow sh =
        Shadow(blurRadius: 6.0, color: Colors.black45, offset: Offset(0, 1.5));
    final TextPainter tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '...',
    );

    tp.text = TextSpan(
      text: b.data.name,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: (r * 0.22).clamp(12.0, 22.0),
        shadows: const <Shadow>[sh],
      ),
    );
    tp.layout(maxWidth: r * 1.8);
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height));

    tp.text = TextSpan(
      text: limit > 0
          ? '$currency${b.spend.toStringAsFixed(2)} / $currency${limit.toStringAsFixed(2)}'
          : '$currency${b.spend.toStringAsFixed(2)}',
      style: TextStyle(
        color: Colors.white.withAlpha(235),
        fontSize: (r * (limit > 0 ? 0.17 : 0.19)).clamp(9.0, 16.0),
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        shadows: const <Shadow>[sh],
      ),
    );
    tp.layout(maxWidth: r * 1.8);
    tp.paint(canvas, centre + Offset(-tp.width / 2, 4));
  }

  Color _parseHex(String hex) {
    try {
      return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
    } catch (_) {
      return Colors.blueAccent;
    }
  }

  @override
  bool shouldRepaint(covariant _ProposedCanvasPainter old) => true;
}

class ProposedCanvasScreen extends StatefulWidget {
  final bool proposedSizing;
  final bool allBudgeted;
  final bool proposedChrome;

  const ProposedCanvasScreen({
    super.key,
    required this.proposedSizing,
    required this.allBudgeted,
    required this.proposedChrome,
  });

  @override
  State<ProposedCanvasScreen> createState() => _ProposedCanvasScreenState();
}

class _ProposedCanvasScreenState extends State<ProposedCanvasScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_MockBubble> _bubbles = <_MockBubble>[];
  final math.Random _rand = math.Random(11);
  Size _canvas = Size.zero;
  Duration _lastElapsed = Duration.zero;
  int? _dragIndex;

  @override
  void initState() {
    super.initState();
    for (final ProposedBubble b in kProposedBubbles) {
      _bubbles.add(_MockBubble(b));
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(_tick);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProposedCanvasScreen old) {
    super.didUpdateWidget(old);
    if (old.proposedSizing != widget.proposedSizing ||
        old.allBudgeted != widget.allBudgeted) {
      _applyRadii();
    }
  }

  double _radiusFor(_MockBubble b) {
    final double limit = b.limitFor(widget.allBudgeted);
    return widget.proposedSizing
        ? proposedRadiusOf(b.spend, limit, _canvas.width, _canvas.height)
        : currentRadiusOf(b.spend, limit, _canvas.width, _canvas.height);
  }

  void _applyRadii() {
    if (_canvas.width <= 0) return;
    for (final _MockBubble b in _bubbles) {
      b.radius = _radiusFor(b);
      b.x = b.x.clamp(b.radius, math.max(b.radius, _canvas.width - b.radius));
      b.y = b.y.clamp(b.radius, math.max(b.radius, _canvas.height - b.radius));
    }
  }

  void _setCanvas(Size size) {
    if (size == _canvas || size.width <= 0) return;
    final bool first = _canvas == Size.zero;
    _canvas = size;
    _applyRadii();
    if (first) {
      for (final _MockBubble b in _bubbles) {
        b.x = b.radius +
            _rand.nextDouble() * math.max(1, size.width - b.radius * 2);
        b.y = b.radius +
            _rand.nextDouble() * math.max(1, size.height - b.radius * 2);
        b.vx = _rand.nextDouble() * 800.0 - 400.0;
        b.vy = _rand.nextDouble() * 800.0 - 400.0;
      }
    }
  }

  void _tick() {
    final Duration elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    final Duration delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    if (delta <= Duration.zero || _canvas.width <= 0) return;
    _step(delta);
    setState(() {});
  }

  // Faithful port of BubbleProvider.updatePhysics, minus the audio hooks.
  // NOTE: the `impulse * nx` on b2's vy is reproduced from the original on
  // purpose - it is a bug in the shipped code, but copying it keeps this mock
  // feeling like the real app rather than a corrected version of it.
  void _step(Duration delta) {
    final double dt = delta.inMicroseconds / 1000000.0;
    if (dt <= 0 || dt > 0.1) return;
    const double bounceFactor = -0.7;

    for (final _MockBubble b in _bubbles) {
      if (b.isDragged) continue;
      b.x += b.vx * dt;
      b.y += b.vy * dt;

      if (b.x - b.radius < 0) {
        b.x = b.radius;
        b.vx *= bounceFactor;
      } else if (b.x + b.radius > _canvas.width) {
        b.x = _canvas.width - b.radius;
        b.vx *= bounceFactor;
      }
      if (b.y - b.radius < 0) {
        b.y = b.radius;
        b.vy *= bounceFactor;
      } else if (b.y + b.radius > _canvas.height) {
        b.y = _canvas.height - b.radius;
        b.vy *= bounceFactor;
      }

      b.vx *= math.pow(0.93, dt * 60.0);
      b.vy *= math.pow(0.93, dt * 60.0);

      if (b.vx.abs() > 3.0 || b.vy.abs() > 3.0) {
        b.vx += (_rand.nextDouble() - 0.5) * 6.0 * dt;
        b.vy += (_rand.nextDouble() - 0.5) * 6.0 * dt;
      } else {
        b.vx = 0.0;
        b.vy = 0.0;
      }
    }

    for (int pass = 0; pass < 2; pass++) {
      for (int i = 0; i < _bubbles.length; i++) {
        for (int j = i + 1; j < _bubbles.length; j++) {
          final _MockBubble b1 = _bubbles[i];
          final _MockBubble b2 = _bubbles[j];
          double dx = b2.x - b1.x;
          double dy = b2.y - b1.y;
          double distance = math.sqrt(dx * dx + dy * dy);
          final double minDistance = b1.radius + b2.radius + 2.0;
          if (distance >= minDistance) continue;

          if (distance == 0.0) {
            dx = (_rand.nextDouble() - 0.5) * 2.0;
            dy = (_rand.nextDouble() - 0.5) * 2.0;
            distance = math.sqrt(dx * dx + dy * dy);
          }

          final double overlap = minDistance - distance;
          final double nx = dx / distance;
          final double ny = dy / distance;
          final double pushX = nx * overlap * 0.5;
          final double pushY = ny * overlap * 0.5;

          b1.x = (b1.x - pushX)
              .clamp(b1.radius, math.max(b1.radius, _canvas.width - b1.radius));
          b1.y = (b1.y - pushY).clamp(
              b1.radius, math.max(b1.radius, _canvas.height - b1.radius));
          b2.x = (b2.x + pushX)
              .clamp(b2.radius, math.max(b2.radius, _canvas.width - b2.radius));
          b2.y = (b2.y + pushY).clamp(
              b2.radius, math.max(b2.radius, _canvas.height - b2.radius));

          const double elasticity = 0.4;
          final double rvn = (b1.vx - b2.vx) * nx + (b1.vy - b2.vy) * ny;
          if (rvn > 0 && !b1.isDragged && !b2.isDragged) {
            final double impulse = (1.0 + elasticity) * rvn / 2.0;
            b1.vx -= impulse * nx;
            b1.vy -= impulse * ny;
            b2.vx += impulse * nx;
            b2.vy += impulse * nx; // reproduced bug, see note above
          }
        }
      }
    }
  }

  int? _hit(Offset p) {
    for (int i = _bubbles.length - 1; i >= 0; i--) {
      final _MockBubble b = _bubbles[i];
      if ((p - Offset(b.x, b.y)).distance <= b.radius) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (widget.proposedChrome)
              _ProposedHeader(
                isDark: isDark,
                bubbles: _bubbles,
                allBudgeted: widget.allBudgeted,
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _setCanvas(Size(c.maxWidth, c.maxHeight));
                  });
                  return GestureDetector(
                    onTapUp: (TapUpDetails d) {
                      final int? i = _hit(d.localPosition);
                      if (i == null) return;
                      // Logs a fiver, so sizing changes are visible. Hot
                      // restart (R) resets the amounts.
                      setState(() {
                        _bubbles[i].spend += 5.0;
                        _bubbles[i].radius = _radiusFor(_bubbles[i]);
                      });
                    },
                    onPanStart: (DragStartDetails d) {
                      _dragIndex = _hit(d.localPosition);
                      if (_dragIndex != null) {
                        _bubbles[_dragIndex!].isDragged = true;
                        _bubbles[_dragIndex!].vx = 0;
                        _bubbles[_dragIndex!].vy = 0;
                      }
                    },
                    onPanUpdate: (DragUpdateDetails d) {
                      final int? i = _dragIndex;
                      if (i == null) return;
                      final _MockBubble b = _bubbles[i];
                      b.x = d.localPosition.dx.clamp(b.radius,
                          math.max(b.radius, _canvas.width - b.radius));
                      b.y = d.localPosition.dy.clamp(b.radius,
                          math.max(b.radius, _canvas.height - b.radius));
                    },
                    onPanEnd: (DragEndDetails d) {
                      final int? i = _dragIndex;
                      if (i == null) return;
                      _bubbles[i].isDragged = false;
                      _bubbles[i].vx = d.velocity.pixelsPerSecond.dx;
                      _bubbles[i].vy = d.velocity.pixelsPerSecond.dy;
                      _dragIndex = null;
                    },
                    child: CustomPaint(
                      painter: _ProposedCanvasPainter(
                        bubbles: _bubbles,
                        isDark: isDark,
                        allBudgeted: widget.allBudgeted,
                        currency: SettingsService().currencySymbol,
                        repaint: _controller,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              ),
            ),
            if (widget.proposedChrome) _ProposedDock(isDark: isDark),
          ],
        ),
      ),
    );
  }
}

class _ProposedHeader extends StatelessWidget {
  final bool isDark;
  final List<_MockBubble> bubbles;
  final bool allBudgeted;

  const _ProposedHeader({
    required this.isDark,
    required this.bubbles,
    required this.allBudgeted,
  });

  @override
  Widget build(BuildContext context) {
    final String symbol = SettingsService().currencySymbol;

    double spent = 0;
    double budget = 0;
    int budgetedCount = 0;
    for (final _MockBubble b in bubbles) {
      spent += b.spend;
      final double limit = b.limitFor(allBudgeted);
      if (limit > 0) {
        budget += limit;
        budgetedCount++;
      }
    }

    // The total spend covers every category. A budget total only covers the
    // budgeted ones, so comparing them is apples to oranges unless every
    // category has a limit. Until then, show the spend alone.
    final bool everyCategoryBudgeted =
        bubbles.isNotEmpty && budgetedCount == bubbles.length;

    final double pct = everyCategoryBudgeted && budget > 0 ? spent / budget : 0.0;
    final Color bar = pct > 1.0
        ? const Color(0xFFFF5A5F)
        : (pct > 0.8 ? const Color(0xFFFBBF24) : Colors.blueAccent);
    final Color primary = isDark ? Colors.white : const Color(0xFF1F2937);
    final Color muted = isDark ? Colors.white60 : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      DateFormat('MMMM yyyy')
                          .format(DateTime.now())
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$symbol${spent.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.8,
                        color: primary,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (everyCategoryBudgeted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    'of $symbol${budget.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 14, color: muted),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'spent this month',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ),
            ],
          ),
          if (everyCategoryBudgeted) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(999)),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: isDark
                    ? Colors.white.withAlpha(20)
                    : Colors.black.withAlpha(18),
                valueColor: AlwaysStoppedAnimation<Color>(bar),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProposedDock extends StatelessWidget {
  final bool isDark;

  const _ProposedDock({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(8),
        border: Border(
          top: BorderSide(
            color:
                isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(15),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const <Widget>[
          _Dest(icon: Icons.bar_chart_rounded, label: 'Reports'),
          _Dest(icon: Icons.bubble_chart_rounded, label: 'Bubbles'),
          _Dest(icon: Icons.receipt_long_rounded, label: 'History'),
          _Dest(icon: Icons.settings_outlined, label: 'Settings'),
        ],
      ),
    );
  }
}

class _Dest extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Dest({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color tint = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: tint, size: 23),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

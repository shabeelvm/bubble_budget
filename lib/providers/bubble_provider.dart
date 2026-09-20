import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/bubble.dart';
import '../services/db_service.dart';
import '../services/sync_service.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';

class BubbleProvider with ChangeNotifier {
  List<Bubble> _bubbles = [];
  double _screenWidth = 375.0;
  double _screenHeight = 600.0;
  final DBService _dbService;
  int _expenseCount = 0;
  int _collisionSoundCount = 0;

  List<Bubble> get bubbles => _bubbles;
  double get screenWidth => _screenWidth;
  double get screenHeight => _screenHeight;
  int get expenseCount => _expenseCount;

  ThemeMode get themeMode {
    final str = SettingsService().themeModeStr;
    switch (str) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  void setThemeMode(ThemeMode mode) {
    String str;
    switch (mode) {
      case ThemeMode.light:
        str = 'light';
        break;
      case ThemeMode.dark:
      default:
        str = 'dark';
        break;
    }
    SettingsService().themeModeStr = str;
    notifyListeners();
  }

  double get totalSpend => _bubbles.fold(0, (sum, b) => sum + b.monthlySpend);
  double get totalBudget => _bubbles.where((b) => b.isBudgeted).fold(0, (sum, b) => sum + b.budgetLimit);

  BubbleProvider({DBService? dbService}) : _dbService = dbService ?? DBService() {
    loadFromDatabase();
  }

  Future<void> loadFromDatabase() async {
    final data = await _dbService.getCategoriesWithMonthlySpend(DateTime.now());
    _expenseCount = await _dbService.getExpenseCount();
    _collisionSoundCount = 0; // Reset collision sound counter on fresh load
    final random = math.Random();
    
    _bubbles = data.map((map) {
      final id = map['id'] as String;
      final name = map['name'] as String;
      final limit = map['budget_limit'] as double;
      final spend = (map['monthly_spend'] as num?)?.toDouble() ?? 0.0;
      final colorHex = map['color_hex'] as String? ?? 'FF448AFF';
      
      // Placeholder radius; _applyAreaBudget() sizes the whole set below,
      // once every bubble's spend is known.
      final radius = calculateRadius(spend, spend);
      final x = radius + random.nextDouble() * (_screenWidth - radius * 2);
      final y = radius + random.nextDouble() * (_screenHeight - radius * 2);

      return Bubble(
        id: id,
        categoryName: name,
        monthlySpend: spend,
        budgetLimit: limit,
        x: x,
        y: y,
        vx: (random.nextDouble() * 800.0) - 400.0,
        vy: (random.nextDouble() * 800.0) - 400.0,
        radius: radius,
        colorHex: colorHex,
      );
    }).toList();

    _applyAreaBudget();

    notifyListeners();
  }

  Future<bool> addCategory(String name, double limit, String colorHex) async {
    if (_bubbles.length >= 25) return false;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _dbService.insertCategory(id, name, limit, colorHex);
    await loadFromDatabase();
    return true;
  }

  Future<void> updateCategory(String id, {String? name, double? budgetLimit, String? colorHex}) async {
    await _dbService.updateCategory(id, name: name, budgetLimit: budgetLimit, colorHex: colorHex);
    await loadFromDatabase();
  }

  Future<void> deleteCategory(String id) async {
    await _dbService.deleteCategory(id);
    await loadFromDatabase();
  }

  void onBubbleDragStart(String id) {
    final index = _bubbles.indexWhere((b) => b.id == id);
    if (index == -1) return;
    _collisionSoundCount = 0; // Reset collision sound counter on user interaction
    _bubbles[index] = _bubbles[index].copyWith(isDragged: true, vx: 0, vy: 0);
    notifyListeners();
  }

  void onBubbleDragUpdate(String id, math.Point<double> position) {
    final index = _bubbles.indexWhere((b) => b.id == id);
    if (index == -1) return;
    
    _bubbles[index] = _bubbles[index].copyWith(
      x: position.x.clamp(_bubbles[index].radius, _screenWidth - _bubbles[index].radius),
      y: position.y.clamp(_bubbles[index].radius, _screenHeight - _bubbles[index].radius),
    );
  }

  void onBubbleDragEnd(String id, math.Point<double> flingVelocity) {
    final index = _bubbles.indexWhere((b) => b.id == id);
    if (index == -1) return;
    _collisionSoundCount = 0; // Reset collision sound counter on user interaction
    _bubbles[index] = _bubbles[index].copyWith(
      isDragged: false,
      vx: flingVelocity.x,
      vy: flingVelocity.y,
    );
    notifyListeners();
  }

  void shuffleBubbles() {
    final random = math.Random();
    _collisionSoundCount = 0; // Reset collision sound counter on user interaction
    for (int i = 0; i < _bubbles.length; i++) {
      final impulseVx = (random.nextDouble() * 1000.0) - 500.0;
      final impulseVy = (random.nextDouble() * 1000.0) - 500.0;
      _bubbles[i] = _bubbles[i].copyWith(
        vx: impulseVx,
        vy: impulseVy,
      );
    }
    notifyListeners();
  }

  void setScreenSize(double width, double height) {
    _screenWidth = width;
    _screenHeight = height;
    
    // Recalculate radii and clamp coordinates to the new viewport
    _applyAreaBudget();

    _clampBubblesToScreen();
    notifyListeners();
  }

  /// Largest:smallest radius ratio allowed on one canvas. Without a cap, a
  /// 500x spend spread would shrink the smallest bubble below a usable tap
  /// target. Higher = more dramatic size differences.
  static const double _maxRadiusRatio = 3.5;

  /// Hard ceiling on any single bubble, as a fraction of the canvas's shorter
  /// side. Stops a lone category from filling the screen.
  static const double _maxRadiusFraction = 0.42;

  /// Fraction of the canvas that ALL bubbles together are allowed to cover.
  ///
  /// Unequal-circle packing stops being solvable somewhere around 0.70, so
  /// above that the pairwise separation pass in updatePhysics can never
  /// converge and bubbles sit permanently intersecting. Lower = more room.
  /// This is the single knob to tune.
  static const double _targetPackingDensity = 0.60;

  /// Shrinks every bubble by one shared factor so the total bubble area never
  /// exceeds [_targetPackingDensity] of the canvas.
  ///
  /// [calculateRadius] returns relative weights, so this pass turns them into
  /// real radii: it scales the whole set by one shared factor until the total
  /// bubble area equals [_targetPackingDensity] of the canvas. Relative sizes
  /// are preserved exactly.
  ///
  /// Scales BOTH ways. Shrinking stops a crowded canvas from overflowing;
  /// growing stops a sparse one from looking empty. The only thing that
  /// overrides the target is [_maxRadiusFraction].
  void _applyAreaBudget() {
    if (_bubbles.isEmpty) return;

    final canvasArea = _screenWidth * _screenHeight;
    if (canvasArea <= 0) return;

    double maxSpend = 0.0;
    for (final b in _bubbles) {
      if (b.monthlySpend > maxSpend) maxSpend = b.monthlySpend;
    }

    final natural = List<double>.filled(_bubbles.length, 0.0);
    double naturalAreaSum = 0.0;
    double largest = 0.0;
    for (int i = 0; i < _bubbles.length; i++) {
      final r = calculateRadius(_bubbles[i].monthlySpend, maxSpend);
      natural[i] = r;
      naturalAreaSum += math.pi * r * r;
      if (r > largest) largest = r;
    }
    if (naturalAreaSum <= 0 || largest <= 0) return;

    double scale = math.sqrt((canvasArea * _targetPackingDensity) / naturalAreaSum);

    final maxAllowed =
        math.min(_screenWidth, _screenHeight) * _maxRadiusFraction;
    if (largest * scale > maxAllowed) scale = maxAllowed / largest;

    for (int i = 0; i < _bubbles.length; i++) {
      _bubbles[i] = _bubbles[i].copyWith(radius: natural[i] * scale);
    }
  }

  /// Nominal radius for [spend], measured against [maxSpend] - the largest
  /// spend currently on the canvas.
  ///
  /// AREA tracks spend (hence the sqrt), because the eye reads a circle by its
  /// area, not its radius. The result is floored at 1/[_maxRadiusRatio] of full
  /// size so a near-empty category stays big enough to tap.
  ///
  /// The budget limit deliberately plays no part. Size means "how much was
  /// spent"; budget status is carried by the ring colour. One visual property,
  /// one meaning - otherwise \$50 against a \$1000 limit and \$500 against a
  /// \$10000 limit render identically despite being 10x apart.
  ///
  /// This returns the size BEFORE [_applyAreaBudget] fits the set to the
  /// canvas, so treat it as a relative weight rather than a final radius.
  double calculateRadius(double spend, double maxSpend) {
    final viewportArea = _screenWidth * _screenHeight;
    final nominal = viewportArea > 0
        ? (math.sqrt(viewportArea) * 0.125).clamp(70.0, 130.0) * 1.6
        : 128.0;

    final floor = 1.0 / _maxRadiusRatio;
    if (maxSpend <= 0.0) return nominal * floor;

    final t = (spend / maxSpend).clamp(0.0, 1.0);
    final rel = floor + (1.0 - floor) * math.sqrt(t);
    return nominal * rel;
  }

  /// Logs an expense, persists it to DB, and updates local state.
  Future<void> logExpense(String categoryId, double amount) async {
    if (amount.abs() >= 10000000) {
      throw ArgumentError("Entry error: Amount must be less than 10,000,000");
    }

    final index = _bubbles.indexWhere((b) => b.id == categoryId);
    if (index == -1) return;

    final expenseId = await _dbService.insertExpense(categoryId, amount);
    _expenseCount = await _dbService.getExpenseCount();
    _collisionSoundCount = 0; // Reset collision sound counter on user interaction

    final bubble = _bubbles[index];
    final newSpend = bubble.monthlySpend + amount;

    final random = math.Random();
    final bumpVx = (random.nextDouble() * 120.0) - 60.0;
    final bumpVy = (random.nextDouble() * 120.0) - 60.0;

    _bubbles[index] = bubble.copyWith(
      monthlySpend: newSpend,
      vx: bubble.vx + bumpVx,
      vy: bubble.vy + bumpVy,
    );

    // Re-fit the whole set: this bubble grew, so everything may need to shrink.
    _applyAreaBudget();

    notifyListeners();

    // Fire background sync asynchronously
    SyncService().syncExpense({
      'id': expenseId,
      'category_name': bubble.categoryName,
      'amount': amount,
      'timestamp': DateTime.now().toIso8601String(),
      'note': '',
    });
  }

  /// Clamps all bubbles to make sure they are within current screen bounds.
  void _clampBubblesToScreen() {
    for (int i = 0; i < _bubbles.length; i++) {
      final b = _bubbles[i];
      double x = b.x;
      double y = b.y;

      if (x - b.radius < 0) x = b.radius;
      if (x + b.radius > _screenWidth) x = _screenWidth - b.radius;
      if (y - b.radius < 0) y = b.radius;
      if (y + b.radius > _screenHeight) y = _screenHeight - b.radius;

      if (x != b.x || y != b.y) {
        _bubbles[i] = b.copyWith(x: x, y: y);
      }
    }
  }

  /// Overlap smaller than this (in px) is treated as "touching, good enough".
  /// Correcting a sub-pixel overlap just re-creates it on the next frame.
  static const double _overlapSlop = 0.5;

  /// Below this speed (px/s) a bubble is considered at rest and is stopped dead.
  static const double _restSpeed = 3.0;

  /// Physics simulation step with Dynamic Elastic Repulsion and boundary damping.
  void updatePhysics(Duration delta) {
    final double dt = delta.inMicroseconds / 1000000.0;
    if (dt <= 0 || dt > 0.1) return;

    // 1. Move and check screen boundaries
    for (int i = 0; i < _bubbles.length; i++) {
      var b = _bubbles[i];
      if (b.isDragged) continue;

      double x = b.x + b.vx * dt;
      double y = b.y + b.vy * dt;
      double vx = b.vx;
      double vy = b.vy;

      const double bounceFactor = -0.7;

      if (x - b.radius < 0) {
        x = b.radius;
        vx = vx * bounceFactor;
      } else if (x + b.radius > _screenWidth) {
        x = _screenWidth - b.radius;
        vx = vx * bounceFactor;
      }

      if (y - b.radius < 0) {
        y = b.radius;
        vy = vy * bounceFactor;
      } else if (y + b.radius > _screenHeight) {
        y = _screenHeight - b.radius;
        vy = vy * bounceFactor;
      }

      vx *= math.pow(0.93, dt * 60.0);
      vy *= math.pow(0.93, dt * 60.0);

      // Only add Brownian drift if already moving, otherwise settle to a dead stop
      if (vx.abs() > 3.0 || vy.abs() > 3.0) {
        vx += (math.Random().nextDouble() - 0.5) * 6.0 * dt;
        vy += (math.Random().nextDouble() - 0.5) * 6.0 * dt;
      } else {
        vx = 0.0;
        vy = 0.0;
      }

      _bubbles[i] = b.copyWith(x: x, y: y, vx: vx, vy: vy);
    }

    // 2. Resolve pairwise overlaps (Dynamic Elastic Repulsion)
    for (int pass = 0; pass < 2; pass++) {
      for (int i = 0; i < _bubbles.length; i++) {
        for (int j = i + 1; j < _bubbles.length; j++) {
          final b1 = _bubbles[i];
          final b2 = _bubbles[j];

          double dx = b2.x - b1.x;
          double dy = b2.y - b1.y;
          double distance = math.sqrt(dx * dx + dy * dy);
          double minDistance = b1.radius + b2.radius + 2.0;

          // Sub-pixel overlaps are left alone: correcting them re-triggers the
          // same correction next frame and the pair shivers in place forever.
          if (distance < minDistance - _overlapSlop) {
            if (distance == 0.0) {
              dx = (math.Random().nextDouble() - 0.5) * 2.0;
              dy = (math.Random().nextDouble() - 0.5) * 2.0;
              distance = math.sqrt(dx * dx + dy * dy);
            }

            final overlap = minDistance - distance;
            final nx = dx / distance;
            final ny = dy / distance;

            final pushX = nx * overlap * 0.5;
            final pushY = ny * overlap * 0.5;

            var newB1X = (b1.x - pushX).clamp(b1.radius, _screenWidth - b1.radius);
            var newB1Y = (b1.y - pushY).clamp(b1.radius, _screenHeight - b1.radius);
            var newB2X = (b2.x + pushX).clamp(b2.radius, _screenWidth - b2.radius);
            var newB2Y = (b2.y + pushY).clamp(b2.radius, _screenHeight - b2.radius);

            const double elasticity = 0.4; 
            final double dvx = b1.vx - b2.vx;
            final double dvy = b1.vy - b2.vy;
            final double relativeVelocityNormal = dvx * nx + dvy * ny;

            if (relativeVelocityNormal > 120.0) {
              // Hard-cap collision sound to 10 plays per action
              if (_collisionSoundCount < 10) {
                _collisionSoundCount++;
                // Smooth linear mapping from speed [120, 600] to volume [0.10, 0.25]
                final double normalizedSpeed = (relativeVelocityNormal - 120.0) / 480.0;
                final double volume = (0.10 + normalizedSpeed * 0.15).clamp(0.10, 0.25);
                AudioService().playChime(volume: volume);
              }
            }

            if (relativeVelocityNormal > 0 && !b1.isDragged && !b2.isDragged) {
              final double impulse = (1.0 + elasticity) * relativeVelocityNormal / 2.0;
              
              _bubbles[i] = b1.copyWith(
                x: newB1X,
                y: newB1Y,
                vx: b1.vx - impulse * nx,
                vy: b1.vy - impulse * ny,
              );

              _bubbles[j] = b2.copyWith(
                x: newB2X,
                y: newB2Y,
                vx: b2.vx + impulse * nx,
                vy: b2.vy + impulse * ny,
              );
            } else {
              _bubbles[i] = b1.copyWith(x: newB1X, y: newB1Y);
              _bubbles[j] = b2.copyWith(x: newB2X, y: newB2Y);
            }
          }
        }
      }
    }

    // 3. Settle pass. The rest check in step 1 runs BEFORE collisions hand out
    //    fresh impulses, so without this a bubble topped up by a standing
    //    contact each frame never reaches a dead stop. The dampener gets the
    //    final say.
    for (int i = 0; i < _bubbles.length; i++) {
      final b = _bubbles[i];
      if (b.isDragged) continue;
      if (b.vx == 0.0 && b.vy == 0.0) continue;
      final speed = math.sqrt(b.vx * b.vx + b.vy * b.vy);
      if (speed < _restSpeed) {
        _bubbles[i] = b.copyWith(vx: 0.0, vy: 0.0);
      }
    }

    notifyListeners();
  }
}

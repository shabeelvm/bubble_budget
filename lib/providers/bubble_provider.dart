import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/bubble.dart';
import '../services/db_service.dart';
import '../services/sync_service.dart';

class BubbleProvider with ChangeNotifier {
  List<Bubble> _bubbles = [];
  double _screenWidth = 375.0;
  double _screenHeight = 600.0;
  final DBService _dbService;

  List<Bubble> get bubbles => _bubbles;
  double get screenWidth => _screenWidth;
  double get screenHeight => _screenHeight;

  double get totalSpend => _bubbles.fold(0, (sum, b) => sum + b.monthlySpend);
  double get totalBudget => _bubbles.where((b) => b.isBudgeted).fold(0, (sum, b) => sum + b.budgetLimit);

  BubbleProvider({DBService? dbService}) : _dbService = dbService ?? DBService() {
    loadFromDatabase();
  }

  Future<void> loadFromDatabase() async {
    final data = await _dbService.getCategoriesWithMonthlySpend(DateTime.now());
    final random = math.Random();
    
    _bubbles = data.map((map) {
      final id = map['id'] as String;
      final name = map['name'] as String;
      final limit = map['budget_limit'] as double;
      final spend = (map['monthly_spend'] as num?)?.toDouble() ?? 0.0;
      final colorHex = map['color_hex'] as String? ?? 'FF448AFF';
      
      final radius = calculateRadius(spend, limit);
      final x = radius + random.nextDouble() * (_screenWidth - radius * 2);
      final y = radius + random.nextDouble() * (_screenHeight - radius * 2);

      return Bubble(
        id: id,
        categoryName: name,
        monthlySpend: spend,
        budgetLimit: limit,
        x: x,
        y: y,
        vx: (random.nextDouble() * 40.0) - 20.0,
        vy: (random.nextDouble() * 40.0) - 20.0,
        radius: radius,
        colorHex: colorHex,
      );
    }).toList();
    
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
    _bubbles[index] = _bubbles[index].copyWith(
      isDragged: false,
      vx: flingVelocity.x,
      vy: flingVelocity.y,
    );
    notifyListeners();
  }

  void shuffleBubbles() {
    final random = math.Random();
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
    _clampBubblesToScreen();
    notifyListeners();
  }

  /// Calculates dynamic radius based on spend vs limit.
  /// Minimum radius is 40.0 (for tap accuracy), scaling up to a maximum cap of 85.0.
  /// If limit is 0 (unbudgeted), radius is scaled relative to the spending (base 45 + sqrt(spend) * 2).
  double calculateRadius(double spend, double limit) {
    if (limit <= 0) {
      // Unbudgeted/Flexible scaling logic:
      final radius = 45.0 + math.sqrt(spend) * 2.0; 
      return radius.clamp(45.0, 85.0);
    }
    
    final ratio = spend / limit;
    final radius = 40.0 + (ratio * 40.0);
    return radius.clamp(40.0, 85.0);
  }

  /// Logs an expense, persists it to DB, and updates local state.
  Future<void> logExpense(String categoryId, double amount) async {
    final index = _bubbles.indexWhere((b) => b.id == categoryId);
    if (index == -1) return;

    final expenseId = await _dbService.insertExpense(categoryId, amount);

    final bubble = _bubbles[index];
    final newSpend = bubble.monthlySpend + amount;
    final newRadius = calculateRadius(newSpend, bubble.budgetLimit);

    final random = math.Random();
    final bumpVx = (random.nextDouble() * 120.0) - 60.0;
    final bumpVy = (random.nextDouble() * 120.0) - 60.0;

    _bubbles[index] = bubble.copyWith(
      monthlySpend: newSpend,
      radius: newRadius,
      vx: bubble.vx + bumpVx,
      vy: bubble.vy + bumpVy,
    );

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

      vx *= math.pow(0.96, dt * 60.0);
      vy *= math.pow(0.96, dt * 60.0);

      vx += (math.Random().nextDouble() - 0.5) * 8.0 * dt;
      vy += (math.Random().nextDouble() - 0.5) * 8.0 * dt;

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

          if (distance < minDistance) {
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
                vy: b2.vy + impulse * nx,
              );
            } else {
              _bubbles[i] = b1.copyWith(x: newB1X, y: newB1Y);
              _bubbles[j] = b2.copyWith(x: newB2X, y: newB2Y);
            }
          }
        }
      }
    }

    notifyListeners();
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'dart:math' as math;
import 'package:bubble_budget/providers/bubble_provider.dart';
import 'package:bubble_budget/services/db_service.dart';

class MockDBService implements DBService {
  final List<Map<String, dynamic>> _categories = [
    {'id': 'dining', 'name': 'Dining Out', 'budget_limit': 200.0, 'monthly_spend': 40.0, 'color_hex': 'FFFF5722'},
    {'id': 'groceries', 'name': 'Groceries', 'budget_limit': 400.0, 'monthly_spend': 120.0, 'color_hex': 'FF4CAF50'},
  ];

  @override
  Future<List<Map<String, dynamic>>> getCategoriesWithMonthlySpend(DateTime month) async {
    return _categories;
  }

  @override
  Future<int> insertExpense(String categoryId, double amount, {String note = ''}) async => 1;

  @override
  Future<List<Map<String, dynamic>>> getExpenses() async => [];

  @override
  Future<List<Map<String, dynamic>>> getUnsyncedExpenses() async => [];

  @override
  Future<void> markExpenseAsSynced(int id) async {}
  
  @override
  Future<void> deleteExpense(int id) async {}

  @override
  Future<void> updateCategory(String id, {String? name, double? budgetLimit, String? colorHex}) async {}

  @override
  Future<void> deleteCategory(String id) async {}

  @override
  Future<void> insertCategory(String id, String name, double limit, String colorHex) async {
    _categories.add({
      'id': id,
      'name': name,
      'budget_limit': limit,
      'monthly_spend': 0.0,
      'color_hex': colorHex,
    });
  }

  @override
  Future<int> getCategoryCount() async => _categories.length;

  @override
  Future<int> getExpenseCount() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BubbleProvider Tests', () {
    late MockDBService mockDb;

    setUp(() {
      mockDb = MockDBService();
    });

    test('Initial initialization loads default bubbles from mock DB', () async {
      final provider = BubbleProvider(dbService: mockDb);
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(provider.bubbles.length, 2);
      expect(provider.bubbles[0].colorHex, 'FFFF5722');
    });

    test('addCategory enforces 25 limit', () async {
      final provider = BubbleProvider(dbService: mockDb);
      await Future.delayed(const Duration(milliseconds: 50));
      
      for (int i = 0; i < 23; i++) {
        await provider.addCategory('Test $i', 100, 'FF000000');
      }
      expect(provider.bubbles.length, 25);
      
      final result = await provider.addCategory('Over limit', 100, 'FF000000');
      expect(result, isFalse);
    });

    test('drag and fling updates state correctly', () async {
      final provider = BubbleProvider(dbService: mockDb);
      await Future.delayed(const Duration(milliseconds: 50));
      
      final bubbleId = provider.bubbles[0].id;
      
      provider.onBubbleDragStart(bubbleId);
      expect(provider.bubbles[0].isDragged, isTrue);
      expect(provider.bubbles[0].vx, 0);
      
      provider.onBubbleDragUpdate(bubbleId, const math.Point(100.0, 100.0));
      expect(provider.bubbles[0].x, 100.0);
      expect(provider.bubbles[0].y, 100.0);
      
      provider.onBubbleDragEnd(bubbleId, const math.Point(500.0, -500.0));
      expect(provider.bubbles[0].isDragged, isFalse);
      expect(provider.bubbles[0].vx, 500.0);
      expect(provider.bubbles[0].vy, -500.0);
    });

    test('shuffleBubbles applies impulses', () async {
      final provider = BubbleProvider(dbService: mockDb);
      await Future.delayed(const Duration(milliseconds: 50));
      
      final originalVelocities = provider.bubbles.map((b) => (b.vx, b.vy)).toList();
      
      provider.shuffleBubbles();
      
      final newVelocities = provider.bubbles.map((b) => (b.vx, b.vy)).toList();
      expect(newVelocities, isNot(equals(originalVelocities)));
    });

    test('calculateRadius sizes by spend relative to the largest spend', () {
      final provider = BubbleProvider(dbService: mockDb);

      // Default viewport 375x600 => nominal radius 112.0,
      // floor = 112 / _maxRadiusRatio(3.5) = 32.0.

      // The biggest spender gets the full nominal radius.
      expect(provider.calculateRadius(100.0, 100.0), closeTo(112.0, 0.01));

      // Area tracks spend, so radius tracks sqrt: half the spend of the
      // largest => floor + (112 - 32) * sqrt(0.5).
      expect(provider.calculateRadius(50.0, 100.0), closeTo(88.5685, 0.01));

      // A quarter of the largest spend => exactly half the variable range.
      expect(provider.calculateRadius(25.0, 100.0), closeTo(72.0, 0.01));

      // Zero spend floors rather than vanishing, so it stays tappable.
      expect(provider.calculateRadius(0.0, 100.0), closeTo(32.0, 0.01));

      // Refunds can push a category negative; it floors too, never inverts.
      expect(provider.calculateRadius(-5.0, 100.0), closeTo(32.0, 0.01));

      // An empty canvas (no spend anywhere) puts every bubble on the floor.
      expect(provider.calculateRadius(50.0, 0.0), closeTo(32.0, 0.01));

      // The ratio between biggest and smallest never exceeds _maxRadiusRatio.
      expect(
        provider.calculateRadius(100.0, 100.0) /
            provider.calculateRadius(0.0, 100.0),
        closeTo(3.5, 0.01),
      );
    });

    test('calculateRadius ignores the budget limit entirely', () {
      final provider = BubbleProvider(dbService: mockDb);

      // Size means spend. \$50 against a \$1000 limit must be SMALLER than
      // \$60 against a \$100 limit, even though it uses far less of its budget.
      final smallSpend = provider.calculateRadius(50.0, 60.0);
      final largeSpend = provider.calculateRadius(60.0, 60.0);
      expect(smallSpend, lessThan(largeSpend));
    });
  });
}

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
  });
}

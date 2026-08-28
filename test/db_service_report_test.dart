import 'package:flutter_test/flutter_test.dart';
import 'package:bubble_budget/services/db_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DBService Aggregate Tests', () {
    late DBService dbService;

    setUp(() async {
      dbService = DBService();
      final db = await dbService.database;
      await db.delete('expenses');
      await db.delete('categories');
      
      // Seed categories
      await dbService.insertCategory('cat1', 'Food', 100.0, 'FF0000FF');
      await dbService.insertCategory('cat2', 'Rent', 500.0, 'FF00FF00');
    });

    test('Monthly aggregation calculates correctly', () async {
      // Insert expenses for August 2026
      await dbService.insertExpense('cat1', 20.0, note: 'Lunch'); // 2026-08-xx
      await dbService.insertExpense('cat1', 30.0, note: 'Dinner');
      await dbService.insertExpense('cat2', 100.0, note: 'Part');

      final now = DateTime.now();
      final categorySpending = await dbService.getCategorySpendingForMonth(now.year, now.month);
      
      // We expect 2 categories since we added expenses for both
      expect(categorySpending.length, 2);
      
      // Check top category (Rent has 100, Food has 50)
      expect(categorySpending[0]['category_name'], 'Rent');
      expect(categorySpending[0]['total'], 100.0);
      expect(categorySpending[1]['category_name'], 'Food');
      expect(categorySpending[1]['total'], 50.0);
    });

    test('Daily aggregation groups correctly', () async {
      // Manual timestamp inserts to test daily grouping
      final db = await dbService.database;
      await db.insert('expenses', {
        'category_id': 'cat1',
        'amount': 10.0,
        'timestamp': '2026-08-01T10:00:00',
        'is_synced': 0
      });
      await db.insert('expenses', {
        'category_id': 'cat1',
        'amount': 15.0,
        'timestamp': '2026-08-01T15:00:00',
        'is_synced': 0
      });
      await db.insert('expenses', {
        'category_id': 'cat1',
        'amount': 50.0,
        'timestamp': '2026-08-05T10:00:00',
        'is_synced': 0
      });

      final dailySpending = await dbService.getDailySpendingForMonth(2026, 8);
      
      expect(dailySpending[1], 25.0);
      expect(dailySpending[5], 50.0);
      expect(dailySpending[2], isNull);
    });

    test('Yearly aggregation calculates correctly', () async {
      final db = await dbService.database;
      // Jan 2026
      await db.insert('expenses', {
        'category_id': 'cat1',
        'amount': 100.0,
        'timestamp': '2026-01-01T10:00:00',
        'is_synced': 0
      });
      // Feb 2026
      await db.insert('expenses', {
        'category_id': 'cat1',
        'amount': 200.0,
        'timestamp': '2026-02-01T10:00:00',
        'is_synced': 0
      });

      final monthlySpending = await dbService.getMonthlySpendingForYear(2026);
      
      expect(monthlySpending[1], 100.0);
      expect(monthlySpending[2], 200.0);
    });
  });
}

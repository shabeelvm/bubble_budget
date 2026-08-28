import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBService {
  static final DBService _instance = DBService._internal();
  static Database? _database;

  factory DBService() => _instance;

  DBService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'bubble_budget.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT,
        budget_limit REAL,
        color_hex TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id TEXT,
        amount REAL,
        timestamp TEXT,
        note TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // Seed 4 clean defaults with distinct colors
    await db.insert('categories', {'id': 'groceries', 'name': 'Groceries', 'budget_limit': 400.0, 'color_hex': 'FF4CAF50'}); 
    await db.insert('categories', {'id': 'dining', 'name': 'Dining Out', 'budget_limit': 200.0, 'color_hex': 'FFFF5722'});
    await db.insert('categories', {'id': 'transport', 'name': 'Transport', 'budget_limit': 120.0, 'color_hex': 'FF2196F3'});
    await db.insert('categories', {'id': 'subscriptions', 'name': 'Subscriptions', 'budget_limit': 50.0, 'color_hex': 'FF9C27B0'});
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add is_synced column to expenses table
      await db.execute('ALTER TABLE expenses ADD COLUMN is_synced INTEGER DEFAULT 0');
    }
  }

  Future<List<Map<String, dynamic>>> getCategoriesWithMonthlySpend(DateTime month) async {
    final db = await database;
    final startOfMonth = DateTime(month.year, month.month, 1).toIso8601String();
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59).toIso8601String();

    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT c.*, 
             (SELECT SUM(amount) FROM expenses e 
              WHERE e.category_id = c.id 
              AND e.timestamp BETWEEN ? AND ?) as monthly_spend
      FROM categories c
    ''', [startOfMonth, endOfMonth]);

    return results;
  }

  Future<int> insertExpense(String categoryId, double amount, {String note = ''}) async {
    final db = await database;
    return await db.insert('expenses', {
      'category_id': categoryId,
      'amount': amount,
      'timestamp': DateTime.now().toIso8601String(),
      'note': note,
      'is_synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT e.*, c.name as category_name
      FROM expenses e
      JOIN categories c ON e.category_id = c.id
      ORDER BY e.timestamp DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedExpenses() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT e.*, c.name as category_name
      FROM expenses e
      JOIN categories c ON e.category_id = c.id
      WHERE e.is_synced = 0
    ''');
  }

  Future<void> markExpenseAsSynced(int id) async {
    final db = await database;
    await db.update('expenses', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateCategory(String id, {String? name, double? budgetLimit, String? colorHex}) async {
    final db = await database;
    final Map<String, dynamic> values = {};
    if (name != null) values['name'] = name;
    if (budgetLimit != null) values['budget_limit'] = budgetLimit;
    if (colorHex != null) values['color_hex'] = colorHex;
    
    if (values.isNotEmpty) {
      await db.update('categories', values, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('expenses', where: 'category_id = ?', whereArgs: [id]);
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> insertCategory(String id, String name, double limit, String colorHex) async {
    final db = await database;
    await db.insert('categories', {
      'id': id,
      'name': name,
      'budget_limit': limit,
      'color_hex': colorHex,
    });
  }

  Future<int> getCategoryCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM categories'));
    return count ?? 0;
  }
}

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'db_service.dart';
import 'settings_service.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  final DBService _dbService = DBService();
  final SettingsService _settings = SettingsService();

  factory ExportService() => _instance;

  ExportService._internal();

  Future<void> exportToCsv() async {
    final expenses = await _dbService.getExpenses();
    
    List<List<dynamic>> rows = [];
    
    rows.add([
      'ID',
      'Timestamp',
      'Date',
      'Time',
      'Category',
      'Amount',
      'Currency',
      'Note'
    ]);

    for (var e in expenses) {
      final dt = DateTime.parse(e['timestamp']);
      rows.add([
        e['id'],
        e['timestamp'],
        DateFormat('yyyy-MM-dd').format(dt),
        DateFormat('HH:mm:ss').format(dt),
        e['category_name'],
        e['amount'],
        _settings.currencySymbol,
        e['note'] ?? ''
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/bubble_budget_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(path)], text: 'Bubble Budget Expense Export');
  }
}

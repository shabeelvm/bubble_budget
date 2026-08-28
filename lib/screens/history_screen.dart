import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/db_service.dart';
import '../providers/bubble_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DBService _dbService = DBService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Expense History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dbService.getExpenses(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final expenses = snapshot.data!;
          if (expenses.isEmpty) return const Center(child: Text('No expenses logged yet.'));

          return ListView.builder(
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              final date = DateTime.parse(expense['timestamp']);
              final formattedDate = DateFormat('MMM d, HH:mm').format(date);

              return Dismissible(
                key: Key(expense['id'].toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.redAccent,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) async {
                  final messenger = ScaffoldMessenger.of(context);
                  final provider = context.read<BubbleProvider>();
                  await _dbService.deleteExpense(expense['id']);
                  if (!mounted) return;
                  provider.loadFromDatabase();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Expense deleted')),
                  );
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withAlpha(50),
                    child: const Icon(Icons.shopping_bag_outlined, color: Colors.blueAccent),
                  ),
                  title: Text(expense['category_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(formattedDate),
                  trailing: Text(
                    '-\$${(expense['amount'] as double).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

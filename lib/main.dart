import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'providers/bubble_provider.dart';
import 'widgets/bubble_canvas.dart';
import 'widgets/quick_entry_modal.dart';
import 'screens/settings_screen.dart';
import 'screens/history_screen.dart';
import 'screens/category_screen.dart';
import 'screens/reports_screen.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().init();
  runApp(const BubbleBudgetApp());
}

class BubbleBudgetApp extends StatelessWidget {
  final BubbleProvider? provider;
  const BubbleBudgetApp({super.key, this.provider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => provider ?? BubbleProvider(),
      child: MaterialApp(
        title: 'Bubble Budget',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            if (settings.showTotalBudgetHeader) _buildTopBar(context),
            Expanded(
              child: BubbleCanvas(
                onBubbleTap: (bubble) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => QuickEntryModal(
                      bubble: bubble,
                      onDone: (amount) {
                        context.read<BubbleProvider>().logExpense(bubble.id, amount);
                      },
                    ),
                  );
                },
              ),
            ),
            _buildBottomDock(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final provider = context.watch<BubbleProvider>();
    final settings = SettingsService();
    final now = DateTime.now();
    final monthYear = DateFormat('MMMM yyyy').format(now);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            monthYear,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          if (provider.totalBudget > 0)
            Text(
              '${settings.currencySymbol}${provider.totalSpend.toStringAsFixed(0)} / ${provider.totalBudget.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            )
          else
            Text(
              '${settings.currencySymbol}${provider.totalSpend.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomDock(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          border: Border(top: BorderSide(color: Colors.white.withAlpha(15))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _DockItem(
              icon: Icons.bar_chart_rounded,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                );
                setState(() {});
              },
            ),
            _DockCapsule(
              icon: Icons.tune_rounded,
              label: 'Manage Bubbles',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
                );
                setState(() {});
              },
            ),
            _DockItem(
              icon: Icons.receipt_long_rounded,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
                setState(() {});
              },
            ),
            _DockItem(
              icon: Icons.settings_outlined,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _DockItem({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white70),
      onPressed: onTap,
    );
  }
}

class _DockCapsule extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DockCapsule({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

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
import 'screens/google_sheets_sync_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/privacy_onboarding_screen.dart';
import 'services/settings_service.dart';
import 'services/export_service.dart';
import 'services/analytics_service.dart';
import 'theme/app_theme.dart';

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
      child: Consumer<BubbleProvider>(
        builder: (context, bubbleProvider, _) {
          final settings = SettingsService();
          final bool hasAcceptedPrivacy = settings.hasAcceptedPrivacy;
          final bool hasSeenWelcome = settings.hasSeenWelcome;

          Widget homeWidget;
          if (!hasAcceptedPrivacy) {
            homeWidget = const PrivacyOnboardingScreen();
          } else if (!hasSeenWelcome) {
            homeWidget = const WelcomeScreen();
          } else {
            homeWidget = const HomeScreen();
          }

          return MaterialApp(
            title: 'Bubble Budget',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: bubbleProvider.themeMode,
            home: homeWidget,
          );
        },
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService().logEvent('app_opened');
    });
  }

  void _checkStorageLimit(BuildContext context) {
    final provider = context.read<BubbleProvider>();
    final count = provider.expenseCount;
    if (count >= 400 && count <= 500) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
              SizedBox(width: 8),
              Text("Storage Nearing Limit", style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            "You have logged $count transactions. Bubble Budget is nearing its 500-transaction local storage limit. Older transactions will be overwritten.",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Dismiss", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ExportService().exportToCsv();
              },
              child: const Text("Export CSV", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoogleSheetsSyncScreen()),
                );
              },
              child: const Text("Sync to Sheets", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      onDone: (amount) async {
                        final provider = context.read<BubbleProvider>();
                        await provider.logExpense(bubble.id, amount);
                        if (context.mounted) {
                          _checkStorageLimit(context);
                        }
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            monthYear,
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.w600, 
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
          border: Border(top: BorderSide(color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(15))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DockItem(
              icon: Icons.bar_chart_rounded,
              label: 'Reports',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                );
                setState(() {});
              },
            ),
            _DockItem(
              icon: Icons.bubble_chart_rounded,
              label: 'Bubbles',
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
              label: 'History',
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
              label: 'Settings',
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
  final String label;
  final VoidCallback onTap;

  const _DockItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// DEV-ONLY design harness for Bubble Budget.
//
// This file is a SEPARATE entry point. It is not imported by lib/main.dart,
// it is not referenced by any shipped widget, and it is tree-shaken out of
// every release build. It touches no routing, no state machine and no
// SharedPreferences behaviour: it only imports screens and renders them.
//
//   flutter run -d macos -t lib/dev/design_preview.dart
//
// Then edit any screen file and press "r" in that terminal (or just save,
// with hot-reload-on-save enabled in your IDE). Sub-second turnaround.
//
// Note: the Privacy screen's CTA still runs its real onPressed, so tapping it
// writes has_accepted_privacy in the *macOS* preferences store. That store is
// separate from your phone, and this harness renders every screen directly
// regardless of those flags, so it changes nothing you can see.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bubble.dart';
import '../providers/bubble_provider.dart';
import '../screens/category_screen.dart';
import '../screens/privacy_onboarding_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/welcome_screen.dart';
import '../services/db_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bubble_canvas.dart';
import '../widgets/quick_entry_modal.dart';
import 'proposed_canvas.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().init();
  await _seedPreviewData();
  runApp(const DesignPreviewApp());
}

// ReportsScreen constructs `DBService()` itself rather than taking one injected,
// so it cannot be given the fake below - it reads the real database. On macOS
// that is the desktop app's own sandbox, entirely separate from the database on
// your phone. This seeds it once, only when it is empty, so the charts have
// something to draw. It never touches a database that already has data.
Future<void> _seedPreviewData() async {
  try {
    final DBService service = DBService();
    if (await service.getExpenseCount() > 0) return;

    // Budgets, so the over-budget and warning ring states are reachable.
    await service.updateCategory('groceries', budgetLimit: 600.0);
    await service.updateCategory('dining', budgetLimit: 200.0);
    await service.updateCategory('transport', budgetLimit: 150.0);
    await service.updateCategory('subscriptions', budgetLimit: 60.0);
    await service.updateCategory('coffee', budgetLimit: 80.0);

    // insertExpense() always stamps DateTime.now(), which would pile every row
    // onto today and flatten the bar chart. The public `database` getter lets
    // the seed spread rows across three months so both charts have shape.
    final db = await service.database;
    final DateTime now = DateTime.now();
    final math.Random rand = math.Random(7); // fixed seed: same preview each run
    const List<String> ids = <String>[
      'groceries', 'dining', 'transport', 'subscriptions', 'coffee',
    ];

    for (int monthsBack = 0; monthsBack < 3; monthsBack++) {
      final DateTime month = DateTime(now.year, now.month - monthsBack);
      final int lastDay = monthsBack == 0
          ? now.day
          : DateTime(month.year, month.month + 1, 0).day;
      for (int i = 0; i < 26; i++) {
        await db.insert('expenses', {
          'category_id': ids[rand.nextInt(ids.length)],
          'amount': (rand.nextInt(4200) + 300) / 100.0,
          'timestamp': DateTime(
            month.year,
            month.month,
            1 + rand.nextInt(lastDay),
            9 + rand.nextInt(10),
          ).toIso8601String(),
          'note': '',
          'is_synced': 1,
        });
      }
    }
    debugPrint('[preview] seeded sample expenses for the Reports screen');
  } catch (e) {
    debugPrint('[preview] seed skipped: $e');
  }
}

// ---------------------------------------------------------------- presets

class DevicePreset {
  final String name;
  final double width;
  final double height;
  final double top;
  final double bottom;
  final double corner;

  const DevicePreset(
    this.name,
    this.width,
    this.height,
    this.top,
    this.bottom,
    this.corner,
  );
}

const List<DevicePreset> kDevices = <DevicePreset>[
  DevicePreset('iPhone SE (3rd gen)', 375, 667, 20, 0, 10),
  DevicePreset('iPhone XR / 11', 414, 896, 48, 34, 42),
  DevicePreset('iPhone 15 / 16', 393, 852, 59, 34, 46),
  DevicePreset('iPhone 15 Pro Max', 430, 932, 59, 34, 48),
  DevicePreset('Pixel 8', 412, 915, 24, 24, 28),
  DevicePreset('Small Android', 360, 740, 24, 24, 20),
];

enum PreviewScreen { privacy, welcome, canvas, settings, reports, manage, quickEntry, canvasRedo }

enum ThemeChoice { light, dark, both }

// ---------------------------------------------------------------- fake db

// Mirrors the pattern already used in test/widget_test.dart: implement the
// surface BubbleProvider actually calls and let noSuchMethod cover the rest,
// so the harness never opens sqflite.
class PreviewDb implements DBService {
  @override
  Future<List<Map<String, dynamic>>> getCategoriesWithMonthlySpend(
    DateTime month,
  ) async {
    return <Map<String, dynamic>>[
      {'id': 'dining', 'name': 'Dining Out', 'budget_limit': 200.0, 'monthly_spend': 40.0, 'color_hex': 'FFFF5722'},
      {'id': 'grocery', 'name': 'Groceries', 'budget_limit': 600.0, 'monthly_spend': 512.0, 'color_hex': 'FF0D9488'},
      {'id': 'transit', 'name': 'Transport', 'budget_limit': 150.0, 'monthly_spend': 176.0, 'color_hex': 'FF2563EB'},
      {'id': 'coffee', 'name': 'Coffee', 'budget_limit': 60.0, 'monthly_spend': 21.0, 'color_hex': 'FF7C3AED'},
      {'id': 'utils', 'name': 'Utilities', 'budget_limit': 0.0, 'monthly_spend': 88.0, 'color_hex': 'FFD97706'},
      {'id': 'fun', 'name': 'Fun', 'budget_limit': 120.0, 'monthly_spend': 118.0, 'color_hex': 'FFEC4899'},
    ];
  }

  @override
  Future<int> getExpenseCount() async => 24;

  @override
  Future<int> getCategoryCount() async => 6;

  @override
  Future<int> insertExpense(String categoryId, double amount, {String note = ''}) async => 1;

  @override
  Future<void> insertCategory(String id, String name, double limit, String colorHex) async {}

  @override
  Future<void> updateCategory(String id, {String? name, double? budgetLimit, String? colorHex}) async {}

  @override
  Future<void> deleteCategory(String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------- shell

class DesignPreviewApp extends StatelessWidget {
  const DesignPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bubble Budget - Design Preview',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF2563EB),
        scaffoldBackgroundColor: const Color(0xFFEDEDE9),
      ),
      home: const PreviewShell(),
    );
  }
}

class PreviewShell extends StatefulWidget {
  const PreviewShell({super.key});

  @override
  State<PreviewShell> createState() => _PreviewShellState();
}

class _PreviewShellState extends State<PreviewShell> {
  PreviewScreen _screen = PreviewScreen.privacy;
  ThemeChoice _theme = ThemeChoice.both;
  int _deviceIndex = 1;
  double _scale = 1.0;
  bool _grid = false;

  // Canvas v2 proposal switches.
  bool _proposedSizing = true;
  bool _allBudgeted = false;
  bool _proposedChrome = true;

  late final BubbleProvider _providerLight = BubbleProvider(dbService: PreviewDb());
  late final BubbleProvider _providerDark = BubbleProvider(dbService: PreviewDb());

  DevicePreset get _device => kDevices[_deviceIndex];

  // Only the two onboarding screens pin their own theme. Everything else is
  // reached from HomeScreen, after the theme toggle exists, so it has both.
  bool get _isPinnedDark =>
      _screen == PreviewScreen.privacy || _screen == PreviewScreen.welcome;

  String _screenName(PreviewScreen s) {
    switch (s) {
      case PreviewScreen.privacy:
        return 'Privacy';
      case PreviewScreen.welcome:
        return 'Welcome';
      case PreviewScreen.canvas:
        return 'Canvas';
      case PreviewScreen.settings:
        return 'Settings';
      case PreviewScreen.reports:
        return 'Reports';
      case PreviewScreen.manage:
        return 'Manage';
      case PreviewScreen.quickEntry:
        return 'Quick entry';
      case PreviewScreen.canvasRedo:
        return 'Canvas v2';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildRail(),
          Expanded(child: _buildStage()),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- rail

  Widget _buildRail() {
    // A Material, not a decorated Container: ListTile paints its background and
    // ink splashes onto the nearest Material ancestor, so a coloured
    // DecoratedBox in between would hide them. Putting the colour and the
    // divider on the Material itself removes the DecoratedBox entirely.
    return Material(
      color: const Color(0xFFF7F7F5),
      shape: const Border(right: BorderSide(color: Color(0xFFE2E2DD))),
      child: SizedBox(
        width: 284,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 28),
        children: [
          const Text(
            'Design Preview',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, letterSpacing: -0.3),
          ),
          const SizedBox(height: 4),
          const Text(
            'dev-only harness · press r to hot reload',
            style: TextStyle(fontSize: 12, color: Color(0xFF727A84)),
          ),

          _label('Screen'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final PreviewScreen s in PreviewScreen.values)
                ChoiceChip(
                  label: Text(_screenName(s)),
                  labelStyle: const TextStyle(fontSize: 12),
                  visualDensity: VisualDensity.compact,
                  selected: _screen == s,
                  onSelected: (bool _) => setState(() => _screen = s),
                ),
            ],
          ),

          _label('Theme'),
          if (_isPinnedDark)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFEFEFEB),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.dark_mode_outlined, size: 15, color: Color(0xFF727A84)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pinned dark. This screen is only ever seen on first run, '
                      'before Settings exists, so it has no light variant to preview.',
                      style: TextStyle(fontSize: 11.5, height: 1.35, color: Color(0xFF727A84)),
                    ),
                  ),
                ],
              ),
            )
          else
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SegmentedButton<ThemeChoice>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const <ButtonSegment<ThemeChoice>>[
                ButtonSegment<ThemeChoice>(value: ThemeChoice.light, label: Text('Light')),
                ButtonSegment<ThemeChoice>(value: ThemeChoice.dark, label: Text('Dark')),
                ButtonSegment<ThemeChoice>(value: ThemeChoice.both, label: Text('Both')),
              ],
              selected: <ThemeChoice>{_theme},
              onSelectionChanged: (Set<ThemeChoice> s) => setState(() => _theme = s.first),
            ),
          ),

          _label('Device'),
          DropdownButton<int>(
            isExpanded: true,
            value: _deviceIndex,
            underline: const SizedBox.shrink(),
            items: <DropdownMenuItem<int>>[
              for (int i = 0; i < kDevices.length; i++)
                DropdownMenuItem<int>(
                  value: i,
                  child: Text(
                    kDevices[i].name,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
            onChanged: (int? v) => setState(() => _deviceIndex = v ?? 0),
          ),
          Text(
            '${_device.width.toInt()} × ${_device.height.toInt()} pt · '
            'safe area ${_device.top.toInt()}/${_device.bottom.toInt()}',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF727A84)),
          ),

          _label('Dynamic Type'),
          Slider(
            value: _scale,
            min: 0.85,
            max: 2.0,
            divisions: 23,
            label: '${_scale.toStringAsFixed(2)}x',
            onChanged: (double v) => setState(() => _scale = v),
          ),
          Wrap(
            spacing: 6,
            children: <Widget>[
              for (final double s in const <double>[1.0, 1.3, 1.6, 2.0])
                ChoiceChip(
                  label: Text('${s.toStringAsFixed(1)}x'),
                  labelStyle: const TextStyle(fontSize: 12),
                  visualDensity: VisualDensity.compact,
                  selected: (_scale - s).abs() < 0.001,
                  onSelected: (bool _) => setState(() => _scale = s),
                ),
            ],
          ),

          if (_screen == PreviewScreen.canvasRedo) ...<Widget>[
            _label('Canvas v2 proposals'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _proposedSizing,
              title: const Text('Size = money', style: TextStyle(fontSize: 13)),
              subtitle: const Text(
                'Off shows the current sizing for comparison',
                style: TextStyle(fontSize: 11, color: Color(0xFF727A84)),
              ),
              onChanged: (bool v) => setState(() => _proposedSizing = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _allBudgeted,
              title: const Text('Budget set on every bubble', style: TextStyle(fontSize: 13)),
              subtitle: const Text(
                'Off: only 2 of 6 budgeted, as budgets are opt-in',
                style: TextStyle(fontSize: 11, color: Color(0xFF727A84)),
              ),
              onChanged: (bool v) => setState(() => _allBudgeted = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _proposedChrome,
              title: const Text('New header + dock', style: TextStyle(fontSize: 13)),
              onChanged: (bool v) => setState(() => _proposedChrome = v),
            ),
          ],

          _label('Overlay'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _grid,
            title: const Text('8 pt baseline grid', style: TextStyle(fontSize: 13)),
            onChanged: (bool v) => setState(() => _grid = v),
          ),

          const SizedBox(height: 26),
          const Divider(height: 1),
          const SizedBox(height: 14),
          const Text(
            'Resize the window to test short layouts. Frames auto-fit; the '
            'zoom percentage is shown under each one.',
            style: TextStyle(fontSize: 11.5, height: 1.45, color: Color(0xFF727A84)),
          ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
          color: Color(0xFF727A84),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- stage

  Widget _buildStage() {
    // The two onboarding screens pin AppTheme.darkTheme themselves, so a light
    // pane would render dark and quietly misrepresent what the toggle does.
    final List<bool> panes = _isPinnedDark
        ? const <bool>[true]
        : _theme == ThemeChoice.both
            ? const <bool>[false, true]
            : <bool>[_theme == ThemeChoice.dark];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        // Natural size of the row before any scaling: 6 px of bezel on each
        // side, a 12 px gap to the caption, and one ~18 px caption line.
        final double naturalW =
            panes.length * (_device.width + 12) + (panes.length - 1) * 30;
        final double naturalH = _device.height + 12 + 12 + 18;
        final double availW = math.max(1.0, c.maxWidth - 48);
        final double availH = math.max(1.0, c.maxHeight - 48);
        final double fit =
            math.min(1.0, math.min(availW / naturalW, availH / naturalH));

        // FittedBox rather than Transform.scale: Transform scales only at paint
        // time, so the row went on laying out at full size and overflowed any
        // window smaller than the frame.
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < panes.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 30),
                    _buildFrame(panes[i], fit),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrame(bool dark, double fit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1D21),
            borderRadius: BorderRadius.circular(_device.corner + 6),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 14)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_device.corner),
            child: SizedBox(
              width: _device.width,
              height: _device.height,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: _buildApp(dark)),
                  if (_grid)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: GridPainter()),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_isPinnedDark ? 'Dark · pinned' : (dark ? 'Dark' : 'Soft Light')}'
          '  ·  ${_scale.toStringAsFixed(2)}x text'
          '${fit < 0.999 ? '  ·  zoom ${(fit * 100).round()}%' : ''}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF5B6169)),
        ),
      ],
    );
  }

  Widget _buildApp(bool dark) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            size: Size(_device.width, _device.height),
            padding: EdgeInsets.only(top: _device.top, bottom: _device.bottom),
            viewPadding: EdgeInsets.only(top: _device.top, bottom: _device.bottom),
            viewInsets: EdgeInsets.zero,
            textScaler: TextScaler.linear(_scale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _buildScreen(dark),
    );
  }

  Widget _buildScreen(bool dark) {
    switch (_screen) {
      case PreviewScreen.privacy:
        return const PrivacyOnboardingScreen();
      case PreviewScreen.welcome:
        return const WelcomeScreen();
      case PreviewScreen.canvas:
        return ChangeNotifierProvider<BubbleProvider>.value(
          value: dark ? _providerDark : _providerLight,
          child: Builder(
            builder: (BuildContext ctx) => Scaffold(
              backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
              body: SafeArea(
                child: BubbleCanvas(onBubbleTap: (_) {}),
              ),
            ),
          ),
        );
      case PreviewScreen.settings:
        return ChangeNotifierProvider<BubbleProvider>.value(
          value: dark ? _providerDark : _providerLight,
          child: const SettingsScreen(),
        );
      case PreviewScreen.reports:
        // Reads the seeded macOS database directly; needs no provider.
        return const ReportsScreen();
      case PreviewScreen.manage:
        return ChangeNotifierProvider<BubbleProvider>.value(
          value: dark ? _providerDark : _providerLight,
          child: const CategoryManagementScreen(),
        );
      case PreviewScreen.quickEntry:
        return const _QuickEntryPreview();
      case PreviewScreen.canvasRedo:
        // Static mock from lib/dev/proposed_canvas.dart. Touches nothing real.
        return ProposedCanvasScreen(
          proposedSizing: _proposedSizing,
          allBudgeted: _allBudgeted,
          proposedChrome: _proposedChrome,
        );
    }
  }
}

// ---------------------------------------------------------------- grid

class GridPainter extends CustomPainter {
  const GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fine = Paint()
      ..color = const Color(0x142563EB)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), fine);
    }

    final Paint major = Paint()
      ..color = const Color(0x2E2563EB)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), major);
    }

    final Paint gutter = Paint()
      ..color = const Color(0x33EC4899)
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(24, 0), Offset(24, size.height), gutter);
    canvas.drawLine(Offset(size.width - 24, 0), Offset(size.width - 24, size.height), gutter);
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => false;
}


// Opens the real QuickEntryModal through showModalBottomSheet with exactly the
// arguments main.dart uses, so the Material ancestry and ambient theme the
// chips resolve against are the same as in the app.
class _QuickEntryPreview extends StatefulWidget {
  const _QuickEntryPreview();

  @override
  State<_QuickEntryPreview> createState() => _QuickEntryPreviewState();
}

class _QuickEntryPreviewState extends State<_QuickEntryPreview> {
  static const Bubble _sample = Bubble(
    id: 'dining',
    categoryName: 'Food & Dining',
    monthlySpend: 240.0,
    budgetLimit: 0.0,
    x: 0,
    y: 0,
    radius: 90,
    colorHex: 'FFFF5722',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  void _open() {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext _) => QuickEntryModal(
        bubble: _sample,
        onDone: (double _) {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Two renderings on purpose. The inline one always shows, so the colours
      // can be judged even if the sheet route misbehaves. The sheet is the
      // faithful one - it sits in the Navigator's Overlay, above the Scaffold's
      // Material, which is exactly where the app puts it and may well be what
      // decides how the chips resolve.
      body: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: TextButton(
                onPressed: _open,
                child: const Text('Open as real bottom sheet'),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'inline copy below',
              style: TextStyle(fontSize: 11, color: Color(0xFF8B939D)),
            ),
          ),
          QuickEntryModal(bubble: _sample, onDone: _noop),
        ],
      ),
    );
  }

  static void _noop(double _) {}
}

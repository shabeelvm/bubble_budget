import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bubble_budget/widgets/quick_entry_modal.dart';
import 'package:bubble_budget/models/bubble.dart';
import 'package:bubble_budget/services/settings_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().init();
  });

  final testBubble = Bubble(
    id: 'test',
    categoryName: 'Test Category',
    monthlySpend: 50.0,
    budgetLimit: 100.0,
    x: 0,
    y: 0,
    radius: 40.0,
    colorHex: 'FF448AFF',
  );

  testWidgets('QuickEntryModal keypad inputs correctly', (WidgetTester tester) async {
    // Set a taller surface to accommodate the numpad in tests
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    double? reportedAmount;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuickEntryModal(
          bubble: testBubble,
          onDone: (amount) => reportedAmount = amount,
        ),
      ),
    ));

    // Tap digits
    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('.'));
    await tester.tap(find.text('5'));
    await tester.pump();

    expect(find.text('\$12.5'), findsOneWidget);

    // Tap Done
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();

    expect(reportedAmount, 12.5);
  });

  testWidgets('QuickEntryModal backspace and long-press clear work', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuickEntryModal(
          bubble: testBubble,
          onDone: (_) {},
        ),
      ),
    ));

    // Enter 123
    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(find.text('\$123'), findsOneWidget);

    // Tap backspace
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(find.text('\$12'), findsOneWidget);

    // Long press backspace to clear
    await tester.longPress(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(find.text('\$0'), findsOneWidget);
  });

  testWidgets('QuickEntryModal refund toggle works', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    double? reportedAmount;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuickEntryModal(
          bubble: testBubble,
          onDone: (amount) => reportedAmount = amount,
        ),
      ),
    ));

    // Enter 10
    await tester.tap(find.text('1'));
    await tester.tap(find.text('0'));
    await tester.pump();
    expect(find.text('\$10'), findsOneWidget);

    // Toggle refund
    await tester.tap(find.text('± Refund'));
    await tester.pump();

    // Verify negative sign display
    expect(find.text('-'), findsOneWidget);
    
    // Tap Done
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();

    expect(reportedAmount, -10.0);
  });
}

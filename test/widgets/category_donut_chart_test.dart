import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bubble_budget/widgets/category_donut_chart.dart';
import 'package:bubble_budget/services/settings_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().init();
  });

  group('CategoryDonutChart Widget Tests', () {
    testWidgets('Empty State - shows 0 and No Spend', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryDonutChart(categoryData: []),
          ),
        ),
      );

      // Verify empty text displays
      expect(find.text('\$0'), findsOneWidget);
      expect(find.text('No Spend'), findsOneWidget);
    });

    testWidgets('Populated State - shows total spent readout', (WidgetTester tester) async {
      final data = [
        {'category_name': 'Dining Out', 'total': 100.0, 'color_hex': 'FFFF5722', 'count': 2},
        {'category_name': 'Groceries', 'total': 300.0, 'color_hex': 'FF4CAF50', 'count': 4},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryDonutChart(categoryData: data),
          ),
        ),
      );

      // Verify total spent displays ($400)
      expect(find.text('\$400'), findsOneWidget);
      expect(find.text('Total Spent'), findsOneWidget);
    });

    testWidgets('Tapping center deselects or does not crash', (WidgetTester tester) async {
      final data = [
        {'category_name': 'Dining Out', 'total': 100.0, 'color_hex': 'FFFF5722', 'count': 2},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryDonutChart(categoryData: data),
          ),
        ),
      );

      // Tap the center region to test deselect / standard behavior
      await tester.tap(find.byType(CategoryDonutChart));
      await tester.pumpAndSettle();

      expect(find.text('\$100'), findsOneWidget);
      expect(find.text('Total Spent'), findsOneWidget);
    });
  });
}

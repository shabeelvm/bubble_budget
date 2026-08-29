import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bubble_budget/widgets/sheet_setup_guide_dialog.dart';
import 'package:bubble_budget/services/settings_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().init();
  });

  group('SheetSetupGuideDialog Widget Tests', () {
    testWidgets('renders all steps and titles correctly in Dark Theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        Theme(
          data: ThemeData.dark(),
          child: const MaterialApp(
            home: Scaffold(
              body: SheetSetupGuideDialog(),
            ),
          ),
        ),
      );

      // Verify the walkthrough header is present
      expect(find.text('Sheets Setup Walkthrough'), findsOneWidget);

      // Verify the titles of all 4 steps are rendered correctly
      expect(find.text('Copy the Template'), findsOneWidget);
      expect(find.text('Open Apps Script'), findsOneWidget);
      expect(find.text('Deploy Web App'), findsOneWidget);
      expect(find.text('Connect & Verify'), findsOneWidget);

      // Verify the button elements are found
      expect(find.text('Copy Template Spreadsheet'), findsOneWidget);
      expect(find.text('Email Me Instructions'), findsOneWidget);
    });

    testWidgets('renders beautifully and adapts in Soft Light Theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        Theme(
          data: ThemeData.light(),
          child: const MaterialApp(
            home: Scaffold(
              body: SheetSetupGuideDialog(),
            ),
          ),
        ),
      );

      // Verify the walkthrough renders in Light/Soft mode correctly
      expect(find.text('Sheets Setup Walkthrough'), findsOneWidget);
      expect(find.text('Copy the Template'), findsOneWidget);
      expect(find.text('Email Me Instructions'), findsOneWidget);
    });
  });
}

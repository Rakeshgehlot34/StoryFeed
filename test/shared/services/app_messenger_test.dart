import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/core/validation/validation_issue.dart';
import 'package:shorts_splitter/shared/services/app_messenger.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      scaffoldMessengerKey: AppMessenger.scaffoldMessengerKey,
      home: Scaffold(body: child),
    );
  }

  group('AppMessenger Tests', () {
    testWidgets('Displays error message in floating SnackBar', (tester) async {
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  AppMessenger.showError(context, 'Failed to load video file'),
              child: const Text('Show Error'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Failed to load video file'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('Deduplicates rapid consecutive identical messages', (
      tester,
    ) async {
      int tapCount = 0;
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                tapCount++;
                AppMessenger.showInfo(context, 'Processing started...');
              },
              child: const Text('Rapid Tap'),
            ),
          ),
        ),
      );

      // Tap twice rapidly
      await tester.tap(find.text('Rapid Tap'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Rapid Tap'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tapCount, 2);
      // Only one SnackBar should exist
      expect(find.text('Processing started...'), findsOneWidget);
    });

    testWidgets('Displays action button and triggers callback on tap', (
      tester,
    ) async {
      bool actionTriggered = false;
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppMessenger.showWarning(
                context,
                'Storage space is low',
                actionLabel: 'Settings',
                onAction: () {
                  actionTriggered = true;
                },
              ),
              child: const Text('Show Warning'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Warning'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Storage space is low'), findsOneWidget);
      final actionBtn = find.text('Settings');
      expect(actionBtn, findsOneWidget);

      await tester.tap(actionBtn);
      await tester.pump();

      expect(actionTriggered, isTrue);
    });

    testWidgets('showIssue renders ValidationIssue correctly', (tester) async {
      const issue = ValidationIssue(
        code: 'TEST_ERR',
        fieldId: 'field_x',
        message: 'Invalid field input provided',
        severity: ValidationSeverity.error,
        actionLabel: 'Fix',
      );

      bool fixed = false;
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppMessenger.showIssue(
                context,
                issue,
                onAction: () => fixed = true,
              ),
              child: const Text('Show Issue'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Issue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Invalid field input provided'), findsOneWidget);
      expect(find.text('Fix'), findsOneWidget);

      await tester.tap(find.text('Fix'));
      await tester.pump();
      expect(fixed, isTrue);
    });

    testWidgets('clear removes active snackbar', (tester) async {
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () => AppMessenger.showSuccess(context, 'Saved!'),
                  child: const Text('Show Success'),
                ),
                ElevatedButton(
                  onPressed: () => AppMessenger.clear(context: context),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Success'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Saved!'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Saved!'), findsNothing);
    });
  });
}

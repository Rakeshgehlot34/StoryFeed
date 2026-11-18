---
name: flutter-screen-scaffold
description: Scaffolds a new production-ready Flutter screen complying with ShortsSplitter design tokens, 4-state async handling, Riverpod controller, and widget test stubs.
---

# Flutter Screen Scaffold Skill

## Trigger Conditions
Use this skill when:
- Creating a new page or view in `ShortsSplitter`.
- Refactoring an existing screen to conform to design tokens and the 14 shared widgets.
- Writing widget tests that verify loading, empty, error, and content states.

---

## Screen Architecture Template

Every screen must reside under `lib/features/<feature>/presentation/screens/<screen_name>_screen.dart` and follow this blueprint:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/constants/app_strings.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../controllers/<feature>_controller.dart';

/// Screen description and role.
class SampleScreen extends ConsumerWidget {
  const SampleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(sampleControllerProvider);
    final controller = ref.read(sampleControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Title'),
      ),
      body: SafeArea(
        child: stateAsync.when(
          loading: () => _buildLoading(),
          error: (err, _) => ErrorState(
            message: err.toString(),
            onRetry: () => controller.refresh(),
          ),
          data: (data) {
            if (data.isEmpty) {
              return EmptyState(
                icon: Icons.inbox_outlined,
                title: 'No Items Found',
                message: 'Items will appear here once added.',
                actionLabel: 'Add Item',
                onAction: () => controller.addItem(),
              );
            }
            return _buildContent(context, data);
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      children: [
        LoadingSkeleton.card(height: 120),
        const SizedBox(height: AppTokens.spaceMd),
        LoadingSkeleton.tile(),
        const SizedBox(height: AppTokens.spaceSm),
        LoadingSkeleton.tile(),
      ],
    );
  }

  Widget _buildContent(BuildContext context, List<SampleItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTokens.spaceSm),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          title: Text(item.title),
          subtitle: Text(item.subtitle),
        );
      },
    );
  }
}
```

---

## Accompanying Widget Test Template

Place widget tests under `test/features/<feature>/<screen_name>_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SampleScreen renders empty state when items list is empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SampleScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No Items Found'), findsOneWidget);
  });
}
```

---

## Quality Checklist Before Completion
- [ ] No hardcoded numbers: spacing, radius, elevations sourced from `AppTokens`.
- [ ] No hardcoded user strings: text sourced from `AppStrings`.
- [ ] Handles all four states: `loading`, `empty`, `error`, `content`.
- [ ] File is under 300 lines total.
- [ ] `build()` method is under 100 lines.
- [ ] Passes `flutter analyze` with 0 warnings.


---
name: flutter-feature-scaffold
description: Scaffolds a new feature directory with data, domain, and presentation layers, Riverpod provider, GoRouter route, and test stub matching ShortsSplitter conventions.
---

# Flutter Feature Scaffold Skill

## Trigger Conditions
Use this skill when:
- Creating a new user-facing capability or screen in `ShortsSplitter`.
- Adding an isolated subsystem (e.g. video filters, watermark, audio extraction).
- Refactoring an ad-hoc module into the feature-first architectural pattern.

---

## Step-by-Step Instructions

### Step 1: Establish Feature Directory Structure
Create the following directory layout under `lib/features/<feature_name>/`:
```
lib/features/<feature_name>/
├── data/
│   ├── <feature_name>_repository.dart
│   └── models/
├── domain/
│   ├── <feature_name>_entity.dart
│   └── <feature_name>_repository_interface.dart
└── presentation/
    ├── screens/
    │   └── <feature_name>_screen.dart
    ├── widgets/
    └── providers/
        └── <feature_name>_controller.dart
```

### Step 2: Define Domain Entity & Interface
Create pure Dart entities without UI dependencies:
```dart
// lib/features/<feature_name>/domain/<feature_name>_entity.dart
class FeatureItem {
  final String id;
  final String name;

  const FeatureItem({
    required this.id,
    required this.name,
  });
}
```

Define the repository interface:
```dart
// lib/features/<feature_name>/domain/<feature_name>_repository_interface.dart
import '../../../core/result.dart';
import '../../../core/errors/app_exception.dart';
import '<feature_name>_entity.dart';

abstract class IFeatureRepository {
  Future<Result<List<FeatureItem>, AppException>> fetchItems();
}
```

### Step 3: Implement Data Repository
```dart
// lib/features/<feature_name>/data/<feature_name>_repository.dart
import '../../../core/result.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/<feature_name>_entity.dart';
import '../domain/<feature_name>_repository_interface.dart';

class FeatureRepository implements IFeatureRepository {
  @override
  Future<Result<List<FeatureItem>, AppException>> fetchItems() async {
    try {
      // Data implementation here
      return Result.success(const []);
    } catch (e, st) {
      return Result.failure(AppException.unknown(e.toString(), cause: e, stackTrace: st));
    }
  }
}
```

### Step 4: Create Riverpod State & Controller
```dart
// lib/features/<feature_name>/presentation/providers/<feature_name>_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/<feature_name>_entity.dart';

class FeatureState {
  final bool isLoading;
  final List<FeatureItem> items;
  final String? errorMessage;

  const FeatureState({
    this.isLoading = false,
    this.items = const [],
    this.errorMessage,
  });

  FeatureState copyWith({
    bool? isLoading,
    List<FeatureItem>? items,
    String? errorMessage,
  }) {
    return FeatureState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      errorMessage: errorMessage,
    );
  }
}

class FeatureController extends StateNotifier<FeatureState> {
  FeatureController() : super(const FeatureState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    // perform operation
    state = state.copyWith(isLoading: false);
  }
}

final featureControllerProvider =
    StateNotifierProvider<FeatureController, FeatureState>((ref) {
  return FeatureController();
});
```

### Step 5: Implement Presentation Screen
```dart
// lib/features/<feature_name>/presentation/screens/<feature_name>_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/<feature_name>_controller.dart';

class FeatureScreen extends ConsumerWidget {
  const FeatureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(featureControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Title'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(state.items[index].name),
                );
              },
            ),
    );
  }
}
```

### Step 6: Register Route in `lib/app/`
1. Add constant to `lib/app/constants.dart`:
   ```dart
   static const String featureRoute = '/feature';
   ```
2. Add GoRoute in `lib/app/router.dart`:
   ```dart
   GoRoute(
     path: AppRoutes.featureRoute,
     builder: (context, state) => const FeatureScreen(),
   ),
   ```

### Step 7: Create Corresponding Test File
Create `test/features/<feature_name>/<feature_name>_test.dart` and run:
```bash
./scripts/verify.sh
```


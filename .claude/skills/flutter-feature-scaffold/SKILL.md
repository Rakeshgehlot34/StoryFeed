---
name: flutter-feature-scaffold
description: Scaffolds a new feature folder structure following ShortsSplitter conventions with data, domain, presentation layers, Riverpod controller, GoRouter route, and test stub.
---

# Feature Scaffolding Skill for ShortsSplitter

## Trigger Conditions
Use this skill when adding a new business capability or feature module to `lib/features/<feature_name>`.

## Directory Structure to Scaffold
```
lib/features/<feature_name>/
├── data/
│   └── <feature_name>_repository.dart
├── domain/
│   └── models/
│       └── <feature_name>_model.dart
└── presentation/
    ├── controllers/
    │   └── <feature_name>_controller.dart
    ├── screens/
    │   └── <feature_name>_screen.dart
    └── widgets/
        └── <feature_name>_tile.dart
test/features/<feature_name>/
└── <feature_name>_test.dart
```

## Step-by-Step Implementation

### Step 1: Create Domain Entity
Create `lib/features/<feature_name>/domain/models/<feature_name>_model.dart`.
Ensure it is a pure Dart model with immutable fields, `copyWith`, and zero Flutter or external library dependencies.

```dart
class SampleFeatureModel {
  final String id;
  final String title;
  final DateTime createdAt;

  const SampleFeatureModel({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  SampleFeatureModel copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
  }) {
    return SampleFeatureModel(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
```

### Step 2: Create Data Repository
Create `lib/features/<feature_name>/data/<feature_name>_repository.dart`.

```dart
import '../../../../core/logger/app_logger.dart';
import '../../../../core/result/result.dart';
import '../domain/models/<feature_name>_model.dart';

class SampleFeatureRepository {
  Future<Result<List<SampleFeatureModel>, Exception>> fetchData() async {
    try {
      AppLogger.info('Fetching sample feature data...');
      return Success([
        SampleFeatureModel(id: '1', title: 'Default', createdAt: DateTime.now()),
      ]);
    } catch (e, st) {
      AppLogger.error('Failed to fetch data', error: e, stackTrace: st);
      return Failure(Exception(e.toString()), st);
    }
  }
}
```

### Step 3: Create Riverpod Controller
Create `lib/features/<feature_name>/presentation/controllers/<feature_name>_controller.dart`.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/<feature_name>_repository.dart';
import '../../domain/models/<feature_name>_model.dart';

final sampleFeatureRepositoryProvider = Provider<SampleFeatureRepository>((ref) {
  return SampleFeatureRepository();
});

final sampleFeatureControllerProvider =
    AsyncNotifierProvider<SampleFeatureController, List<SampleFeatureModel>>(
  SampleFeatureController.new,
);

class SampleFeatureController extends AsyncNotifier<List<SampleFeatureModel>> {
  @override
  Future<List<SampleFeatureModel>> build() async {
    final repo = ref.read(sampleFeatureRepositoryProvider);
    final result = await repo.fetchData();
    return result.when(
      success: (data) => data,
      failure: (error, _) => throw error,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
```

### Step 4: Register Route in AppConstants & AppRouter
Add route constants to `lib/app/constants.dart`:
```dart
static const String sampleFeature = '/sample-feature';
static const String sampleFeatureName = 'sample-feature';
```
Add route to `lib/app/router.dart`:
```dart
GoRoute(
  path: AppRoutes.sampleFeature,
  name: AppRoutes.sampleFeatureName,
  builder: (context, state) => const SampleFeatureScreen(),
),
```

### Step 5: Create Unit Test Stub
Create `test/features/<feature_name>/<feature_name>_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SampleFeature Tests', () {
    test('initializes correctly', () {
      expect(true, isTrue);
    });
  });
}
```
Run `flutter analyze && flutter test` to verify integration.


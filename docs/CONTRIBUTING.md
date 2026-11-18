# ShortsSplitter Contributing Guide

Guidelines, coding standards, branch conventions, and quality gates for contributing to ShortsSplitter.

---

## Table of Contents
1. [Code of Conduct & Principles](#1-code-of-conduct--principles)
2. [Branch Naming Conventions](#2-branch-naming-conventions)
3. [Conventional Commit Messages](#3-conventional-commit-messages)
4. [Strict Coding & Architectural Standards](#4-strict-coding--architectural-standards)
5. [Adding a Feature (Step-by-Step)](#5-adding-a-feature-step-by-step)
6. [Definition of Done (DoD) & PR Checklist](#6-definition-of-done-dod--pr-checklist)

---

## 1. Code of Conduct & Principles

- **Zero Breaking Invariants:** Never compromise core domain invariants (the 180s cap, contiguous slice boundaries, memory safety, and 4-tier storage compliance).
- **Hermetic Testing:** Every non-trivial modification to business logic, mathematics, or data translation must be accompanied by unit or widget tests.
- **Documentation First:** Any change to features, routes, permissions, or scripts must update matching documentation in `/docs` within the same pull request.

---

## 2. Branch Naming Conventions

Create topic branches originating from `main`:

```
<type>/<short-descriptive-kebab-case-name>
```

### Approved Prefixes
- `feat/`: New feature or user capability (e.g. `feat/audio-volume-boost`).
- `fix/`: Bug fix or defect resolution (e.g. `fix/saf-permission-recheck`).
- `perf/`: Performance or memory optimization (e.g. `perf/stream-chunk-size`).
- `refactor/`: Code reorganization without behavioral change (e.g. `refactor/extract-clip-card`).
- `test/`: Adding or updating tests (e.g. `test/plan-review-widget-tests`).
- `docs/`: Documentation additions or synchronization (e.g. `docs/update-commands-ref`).

---

## 3. Conventional Commit Messages

ShortsSplitter follows the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <short imperative description>
```

### Examples
- `feat(trimmer): add quick trim chip for 3-minute max range`
- `fix(storage): handle null DocumentFile on deleted external folder`
- `perf(ffmpeg): stream temp pipe via 64KB chunks to conserve heap`
- `test(plan): verify trailing remainder merge threshold under 3 seconds`
- `docs(setup): document OpenJDK 17 installation for Linux and macOS`

---

## 4. Strict Coding & Architectural Standards

### Sound Null-Safety & Type Rules
- **No `dynamic`:** Never use `dynamic`. Use strong static typing or generics (`<T>`).
- **No Unjustified Bang Operator (`!`):** Never use `!` unless accompanied by a clarifying inline comment justifying why the expression is guaranteed to be non-null.
- **Error Handling:** Operations that can fail must return `Result<T, AppException>` or throw typed `AppException`. Never swallow exceptions silently in empty catch blocks.

### State Management & Navigation
- **Riverpod Only:** Use Riverpod (`Notifier` / `AsyncNotifier`) for all shared or cross-widget state. Providers live exclusively in `lib/features/<feature>/presentation/controllers/`.
- **GoRouter Declarative Routes:** Navigate exclusively via `AppRoutes` constants (`lib/app/constants.dart`). Imperative `Navigator.push` is forbidden.

### File Hygiene & Modularity
- **File Length:** Maximum 300 lines of code per file.
- **Build Method:** Maximum 100 lines per `build()` method. Extract sub-sections into private helper methods or dedicated widgets.
- **Design Tokens:** Always use `AppTokens` for spacing, radii, elevations, and durations. Zero magic numbers.

---

## 5. Adding a Feature (Step-by-Step)

Follow this 5-stage procedure when creating a new feature module:

### Stage 1: Scaffold Feature Layout
Use the `flutter-feature-scaffold` skill to establish directories under `lib/features/<feature_name>/`:
```
lib/features/<feature_name>/
├── data/
│   └── <feature_name>_repository.dart
├── domain/
│   ├── models/
│   └── <feature_name>_repository_interface.dart
└── presentation/
    ├── controllers/
    │   └── <feature_name>_controller.dart
    ├── screens/
    │   └── <feature_name>_screen.dart
    └── widgets/
```

### Stage 2: Define Domain Entities & Contracts
Define pure Dart entities without UI or external framework dependencies.

### Stage 3: Implement Data Layer
Implement repositories or native platform channel bridges implementing the domain contract.

### Stage 4: Build Presentation UI with 4 States
Implement the screen handling all 4 states (`loading`, `empty`, `error`, `content`) using `shared/widgets/`.

### Stage 5: Register Route & Write Tests
Add route constant to `AppRoutes` (`lib/app/constants.dart`), register route in `lib/app/router.dart`, and add unit/widget tests in `test/features/<feature_name>/`.

---

## 6. Definition of Done (DoD) & PR Checklist

Every pull request must satisfy all items before merging:

- [ ] Code formatted with `dart format .`
- [ ] Static analysis passes with zero warnings: `flutter analyze`
- [ ] Automated tests pass: `flutter test`
- [ ] Documentation integrity verified: `./scripts/docs_check.sh`
- [ ] Complete verification suite passes: `./scripts/verify.sh`
- [ ] 14 shared widgets and `AppTokens` design tokens utilized across screens
- [ ] Domain invariants preserved (180s max, contiguity, zero-padded names)
- [ ] Zero FFmpeg imports outside `lib/features/processing/data/`
- [ ] Android version guards verified for API 28 through API 35+
- [ ] `CHANGELOG.md` updated with changes under `[Unreleased]`


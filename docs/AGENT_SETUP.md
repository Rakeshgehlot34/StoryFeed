# Antigravity Agent Configuration & DX Reference

Technical guide to how ShortsSplitter is configured for autonomous engineering with Google Antigravity: rules, skills, workflows, and governance policies.

---

## Table of Contents
1. [Configuration Hierarchy & Loading Order](#1-configuration-hierarchy--loading-order)
2. [AGENTS.md Engineering Guide](#2-agentsmd-engineering-guide)
3. [Agent Rules Catalog (.agents/rules/)](#3-agent-rules-catalog-agentsrules)
4. [Agent Skills Catalog (.agents/skills/)](#4-agent-skills-catalog-agentsskills)
5. [Slash Workflows Catalog (.agents/workflows/)](#5-slash-workflows-catalog-agentsworkflows)
6. [How to Author a New Skill or Workflow](#6-how-to-author-a-new-skill-or-workflow)
7. [Security Boundaries & Manual Governance Policies](#7-security-boundaries--manual-governance-policies)

---

## 1. Configuration Hierarchy & Loading Order

Antigravity parses project configuration in strict hierarchical precedence:

```
[System & User Prompts]
          │
          ▼
[Project Root: AGENTS.md] (Hard domain invariants, tech stack, DoD, under 200 lines)
          │
          ▼
[.agents/rules/] (Focused operational rules: storage, testing, architecture, ui)
          │
          ▼
[.agents/skills/] (Specialized instructions loaded on demand via SKILL.md)
          │
          ▼
[.agents/workflows/] (Executable multi-step slash command workflows)
```

### AGENTS.md vs Legacy Configurations
- **`AGENTS.md`:** The authoritative engineering guide for Antigravity agents. Must remain concise (under 200 lines) and contains non-negotiable architectural laws and commands.
- **`.agents/` Directory:** Contains deep modular instructions (rules, skills, workflows). If migrating from legacy agents, `.claude/` or `GEMINI.md` are archived or aligned with `.agents/`.

---

## 2. AGENTS.md Engineering Guide

Located at repository root `AGENTS.md`. Key sections:
- **Pinned Tech Stack:** Flutter `3.47.5`, Dart `3.13.4`, Riverpod `^2.6.1`, GoRouter `^14.8.1`, FFmpeg Kit `^4.6.8`.
- **Domain Invariants:** 180s hard cap, boundary contiguity, zero-padded sequence names, memory streaming.
- **Definition of Done (DoD):** Format clean, zero static analyzer issues, tests pass, documentation synchronized.
- **Mandatory "Ask Before" Gates:** Dependency changes, SDK version modifications, and release signing edits.

---

## 3. Agent Rules Catalog (.agents/rules/)

Modular operational rules loaded automatically by the agent:

| Rule File | Scope & Mandatory Requirements |
| :--- | :--- |
| `android-storage.md` | Enforces 4-tier storage strategy, SAF persistable URI checks, and version guards for API 28–35+. |
| `architecture.md` | Inward dependency rule (Presentation -> Domain <- Data), FFmpeg isolation, and Riverpod conventions. |
| `dart-style.md` | Sound null-safety, zero `dynamic`, no bang operator `!` without inline justification, line lengths. |
| `domain-invariants.md` | Non-negotiable domain rules: 180s max clip, boundary contiguity, naming pattern, and 3s remainder merge. |
| `security.md` | Prohibits committing keys/passwords, enforces safe Android IPC, and validates file boundaries. |
| `testing.md` | Mandates accompanying tests for domain logic changes, `FakeVideoProcessor` usage, and verify script execution. |
| `ui-guidelines.md` | Mandates `AppTokens` design tokens, 14 reusable widgets, 4 screen states, and accessibility standards. |

---

## 4. Agent Skills Catalog (.agents/skills/)

Specialized skill folders containing `SKILL.md` instructions loaded when relevant:

| Skill Name | Directory | Capabilities & Use Cases |
| :--- | :--- | :--- |
| `android-scoped-storage` | `.agents/skills/android-scoped-storage/` | Resolves SAF tree URI issues, runtime permissions, and MediaStore fallbacks across API 28–35+. |
| `debug-playbook` | `.agents/skills/debug-playbook/` | Diagnostic procedures for FFmpeg transcode failures, native memory leaks, and Android JNI errors. |
| `ffmpeg-split-recipes` | `.agents/skills/ffmpeg-split-recipes/` | Tested FFmpeg command syntax for stream copy, precise cut, blur background, and PNG overlays. |
| `flutter-feature-scaffold`| `.agents/skills/flutter-feature-scaffold/` | Scaffolds new feature modules with data, domain, and presentation layers matching project conventions. |
| `flutter-screen-scaffold` | `.agents/skills/flutter-screen-scaffold/` | Scaffolds production-ready screens with design tokens, 14 shared widgets, 4 states, and test stubs. |
| `flutter-testing` | `.agents/skills/flutter-testing/` | Authoring unit and widget tests using `FakeVideoProcessor`, `FakeClipWriter`, and mock preferences. |
| `release-checklist` | `.agents/skills/release-checklist/` | Production release verification: signing, R8/ProGuard checks, split APKs, and Play Store bundle. |
| `split-planner-logic` | `.agents/skills/split-planner-logic/` | Pure mathematical algorithms for contiguous clip slicing, boundary math, and remainder merges. |

---

## 5. Slash Workflows Catalog (.agents/workflows/)

Interactive slash commands executable during development:

| Workflow Command | File Path | Operational Purpose |
| :--- | :--- | :--- |
| `/verify` | `.agents/workflows/verify.md` | Run pre-commit quality gate (format check, static analysis, unit/widget tests, docs check). |
| `/sanity` | `.agents/workflows/sanity.md` | End-to-end repository health gate (env, analysis, tests, fixtures, docs). |
| `/ui-check` | `.agents/workflows/ui-check.md` | Audit UI code for token compliance, shared widgets, and accessibility standards. |
| `/compat-check` | `.agents/workflows/compat-check.md` | Verify Android API 28 through API 35+ compatibility and storage strategy selection. |
| `/plan-check` | `.agents/workflows/plan-check.md` | Verify contiguous slice calculation, remainder merge threshold, and 180s hard cap. |
| `/docs-sync` | `.agents/workflows/docs-sync.md` | Audit code vs `/docs`, synchronize drifted documentation, and run `docs_check.sh`. |
| `/new-feature` | `.agents/workflows/new-feature.md` | Guide creation of a new vertical feature slice from domain contract to presentation UI. |
| `/write-tests` | `.agents/workflows/write-tests.md` | Generate unit, widget, and provider test suites for newly introduced or modified modules. |
| `/fix-build` | `.agents/workflows/fix-build.md` | Diagnose and resolve compiler errors, Gradle/JDK version conflicts, or missing SDKs. |
| `/release-check` | `.agents/workflows/release-check.md` | Execute pre-release verification: keystore checks, ProGuard rules, and split APK generation. |
| `/build-apk` | `.agents/workflows/build-apk.md` | Interactive workflow for compiling production, debug, or profile APKs. |
| `/lifecycle-check` | `.agents/workflows/lifecycle-check.md` | Audit single-player invariants, audio leakage prevention, and export job decoupling. |
| `/review` | `.agents/workflows/review.md` | Perform comprehensive code review against AGENTS.md rules before merging PRs. |

---

## 6. How to Author a New Skill or Workflow

### Adding a Skill
1. Create directory: `.agents/skills/<skill-name>/`.
2. Create `.agents/skills/<skill-name>/SKILL.md` with YAML frontmatter:
   ```markdown
   ---
   name: <skill-name>
   description: One-sentence description of what this skill does and when to invoke it.
   ---
   # Skill Title
   ## Trigger Conditions
   ## Step-by-Step Instructions
   ```

### Adding a Workflow
1. Create markdown file: `.agents/workflows/<workflow-name>.md`.
2. Format with numbered execution steps and bash commands:
   ```markdown
   # /<workflow-name> Workflow
   Description of goal.
   ## Execution Steps
   1. Step description...
   ```
3. Index the new workflow in `docs/COMMANDS.md` and `docs/AGENT_SETUP.md`.

---

## 7. Security Boundaries & Manual Governance Policies

To ensure safe autonomous development, the following governance rules are enforced:

1. **Terminal Allow/Deny List:**
   - **Allowed Commands:** `flutter *`, `dart *`, `git status/diff/log/branch/checkout`, `./scripts/*`, `adb devices/install/logcat`.
   - **Deny / Require Human Confirmation:** `rm -rf`, `git push --force`, `git reset --hard`, modifying `android/key.properties`, modifying signing keys.
2. **Never Touch Secrets:** Agents must never read, output, or modify private cryptographic keystore files (`*.jks`, `*.keystore`) or real credentials in `key.properties`.
3. **Never Edit Generated Files Directly:** Never manually edit `*.g.dart` files. Always modify the source model or provider and run `dart run build_runner build`.
4. **Mandatory Human Confirmation:** The agent must request human approval before:
   - Adding, updating, or removing dependencies in `pubspec.yaml`.
   - Altering architecture boundaries or cross-feature imports.
   - Modifying Android `minSdk`, `targetSdk`, or Gradle build configurations.
   - Creating or modifying release signing configurations or ProGuard rules.

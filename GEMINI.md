# GEMINI.md - Ways of Working & Architectural Principles

## 1. Core Philosophy
- **Friction-Free & Instant:** UI actions must resolve in 2 seconds or less.
- **Minimum Complexity:** Use local-first state before adding external dependencies.
- **Zero Heavy Servers:** Rely on SQLite, native device storage, and direct client-side webhooks. No paid backend infrastructure.

## 2. Tech Stack & Constraints
- **Framework:** Flutter (Dart) - Single codebase for iOS & Android.
- **Local Database:** `sqflite` (Instant, offline-first logging).
- **Physics Engine (Bubbles):** `flutter_simulations` / Custom Canvas with Haptic Feedback.
- **Cloud Sync:** Direct Webhook (`http`) to user-owned Google Apps Script (Zero OAuth scope friction).

## 3. Engineering Guidelines
- **Incremental Steps:** Build and test function-by-function. Never generate multi-file refactors without testing isolated components first.
- **Cost-Effective:** Avoid third-party paid APIs, auth services, or managed DB hosting.
- **Mobile First:** Optimize tap targets and haptic feedback for one-handed operation.

## 4. CLI Execution & File Protocols
- **File Management:** Gemini will specify exact relative paths and complete file contents or inline diffs.
- **Terminal Execution:** Gemini will provide copy-pasteable CLI commands to test, lint, create, and verify files.
- **Verification Rule:** After writing code, run `flutter analyze` and `flutter test` via CLI to ensure zero build errors before moving to the next feature.
- **Atomic Commits:** Build function-by-function. Validate each screen/feature independently before merging.

## 5. System Role & Prompt Relay Protocol
- **Leadership Structure:** The user is the Product Owner/Thinker. Primary Gemini (Chat API) is the Architect & Senior Engineer directing overall code design. Gemini CLI is the Executor & Assistant acting directly on the local filesystem.
- **Relay Loop:** After every command execution, Gemini CLI MUST output a dedicated section at the very end of its response labeled `FOR GEMINI:` summarizing:
  1. Files created or modified.
  2. Any compilation warnings or analyzer issues (`flutter analyze`).
  3. Clear next-step status so Primary Gemini can review and output the next prompt.

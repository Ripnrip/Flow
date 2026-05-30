# Swift Dev Skill Audit — Flow

**Date:** 2026-05-30
**Scope:** `Flow/` Xcode project (app + `Widgets` extension + tests), audited against the
`swift-dev` skill (`SKILL.md`, `swift_guidelines.md`, `hig_accessibility.md`,
`testing_automation.md`).

## Verdict

**Partially up to par — strong architecture, three blocking gaps.**

Flow already reflects the *architectural* spirit of the skill well: `@Observable`
view-model services, `actor`-isolated concurrency, a rich `enum`-driven domain
(`TaskStyle`, `FlowRoute`), typed deep-link routing, a centralized `OSLog`
`FlowLogger`, and a thoughtfully animated Live Activity. Where it falls short is in
three areas the skill treats as non-negotiable: **strict concurrency is not actually
enabled**, **accessibility is effectively absent**, and **there is no real test
coverage**. There is also a **committed API secret** that should be treated as urgent.

## Scorecard

| Area | Status | Notes |
| --- | --- | --- |
| Architecture (Observable / actors / DI) | ✅ Good | `@Observable` services, actors, initializer injection of `ModelContext`. TCA not needed at this size. |
| Rich enums / domain modeling | ✅ Good | `TaskStyle`, `FlowRoute` (typed, `Sendable`), `ActiveTaskSnapshot`. |
| Concurrency *model* | ✅ Good | `@MainActor` services, `SharedTaskStore`/`TaskLingeringActor`/`TaskStyleSuggester` actors, `Sendable` value types. |
| **Swift 6.2 strict concurrency *enabled*** | ❌ Gap | `SWIFT_VERSION = 5.0`, no `SWIFT_STRICT_CONCURRENCY`. Skill requires *complete* checking. |
| Logging | ⚠️ Mixed | `FlowLogger` exists and is excellent, but **26 `print()` calls** remain in `Item`, `TaskLingeringActor`, `ExternalIntegrationService`, `TodoistService`. |
| **Accessibility** | ❌ Gap | **0** `accessibilityLabel/Value/Hint` and **0** `accessibilityReduceMotion` usages in app/widget code. Particle systems + custom motion have no reduce-motion fallback. |
| **Testing** | ❌ Gap | `FlowTests` is an empty stub; only an XCText snapshot generator exists. No tests for `FlowRoute` parsing, the heuristic suggester, or reconcile logic — all highly testable. |
| Secrets / security | 🔴 Urgent | Live Todoist token hardcoded in `TodoistService.swift` and committed to git. |
| Error modeling | ⚠️ Mixed | Errors are mostly logged-and-swallowed; no typed domain errors or rich `LoadState` for UI. |
| Force unwraps | ⚠️ Minor | A handful (`URL(string:)!`, `…first!`, `Calendar.current.date(…)!`) outside tests. |
| Docs accuracy | ⚠️ Minor | `README` badges say Swift 5.9 / MVVM+Combine / iOS 17; reality is Swift 5-mode / `@Observable`+SwiftData / iOS 26, no Combine. |
| Dead code | ⚠️ Minor | `MainNavigationFlow.swift` is an intentional empty placeholder. |

## Blocking gaps (do these to be "up to par")

### 1. Enable Swift 6 strict concurrency
The build sets `SWIFT_APPROACHABLE_CONCURRENCY = YES` and
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (good Swift 6.2 features), but
`SWIFT_VERSION = 5.0` with no `SWIFT_STRICT_CONCURRENCY`, so the compiler runs in
*minimal* checking. The skill's first checklist item is "compiles with zero warnings
under Swift 6.2+ complete strict concurrency." Move to `SWIFT_VERSION = 6.0` (or set
`SWIFT_STRICT_CONCURRENCY = complete`) and resolve resulting diagnostics. The code is
already largely shaped for this, so the lift should be moderate.

### 2. Accessibility pass
No screen currently declares VoiceOver labels, and nothing honors
`@Environment(\.accessibilityReduceMotion)`. Minimum work:
- Label/trait the inbox rows, sync/add toolbar buttons, and the emoji "souls" in
  `TaskRow` (emoji-as-content reads poorly under VoiceOver).
- Gate the `CosmicParticleSystem` / `ForestParticleSystem` / wave animations and SF
  Symbol effects behind `reduceMotion` with a static fallback.
- Verify Dynamic Type and dark mode on the `Form` and gallery.

### 3. Real tests with Swift Testing
Add a `@Suite` covering pure, deterministic logic that exists today:
- `FlowRoute(url:)` parsing for custom-scheme, Universal Link, and malformed inputs.
- `TaskStyleSuggester.suggestWithHeuristic` keyword mapping.
- `Item` lingering-time / `growthLevel` thresholds.
- `SharedTaskStore` pending-flag reconciliation (inject a non-shared instance).
Keep the existing XCTest snapshot generator, but fix its hardcoded
`/Users/admin/...` path to use the `SNAPSHOT_PATH` env var unconditionally.

## Urgent (security)

`Flow/Flow/TodoistService.swift` hardcodes `apiKey = "9fe3…be7"`. Rotate/revoke that
token now, move it to Keychain or a build-time config, and scrub it from history. A
committed bearer token is a leaked credential regardless of repo visibility.

## Recommended (non-blocking)

- Replace the remaining `print()` calls with the matching `FlowLogger` channel
  (`.task`, `.local`, `.ai`) so all diagnostics are structured and privacy-aware.
- Introduce typed domain errors and a `LoadState` enum for service results instead of
  log-and-return, matching the skill's templates.
- Remove force unwraps in non-test code (guard/`??` the `URL` and date constructions).
- Update `README` badges/architecture section to match reality (Swift 6 target,
  `@Observable` + SwiftData, iOS 26, no Combine), or note Combine as aspirational.
- Delete the empty `MainNavigationFlow.swift` once a pbxproj edit is acceptable.

## What's already exemplary

- `FlowLogger`: clean, per-subsystem `OSLog` channels — exactly the skill's logging guidance.
- `FlowRoute`: typed, `Sendable`, bidirectional URL parsing/generation with fallbacks.
- `SharedTaskStore` / `TaskLingeringActor`: correct `actor` isolation for cross-process
  and timing state.
- `TaskStyleSuggester`: gated `FoundationModels` with a graceful heuristic fallback.
- `WidgetsLiveActivity`: deliberate, state-driven SF Symbol motion that matches the
  HIG "polished restraint" principle.

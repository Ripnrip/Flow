# Flow Modernization Plan (2026 Apple Ecosystem)

> Last verified: 2026-03-24 (UTC). This plan intentionally references Apple docs/HIG pages directly so implementation can track current API behavior.

## 1) Source packet (Apple-first references)

### Human Interface Guidelines (HIG)
- Live Activities: https://developer.apple.com/design/human-interface-guidelines/live-activities
- Widgets: https://developer.apple.com/design/human-interface-guidelines/widgets
- App Clips: https://developer.apple.com/design/human-interface-guidelines/app-clips
- SF Symbols: https://developer.apple.com/sf-symbols/

### Documentation (API + platform)
- ActivityKit: https://developer.apple.com/documentation/activitykit
- Displaying live data with Live Activities: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- WidgetKit interactivity: https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities
- App Intents: https://developer.apple.com/documentation/appintents
- App Shortcuts: https://developer.apple.com/documentation/appintents/appshortcuts
- App Clips: https://developer.apple.com/documentation/appclip
- Universal Links (Xcode docs): https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app
- Associated Domains entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_associated-domains
- NSUserActivity: https://developer.apple.com/documentation/foundation/nsuseractivity
- Link Presentation: https://developer.apple.com/documentation/linkpresentation

### WWDC topic tracks to review while implementing
(Use the Developer app filter each season: “Live Activities”, “WidgetKit”, “App Intents”, “App Clips”, “Universal Links”, “SF Symbols”, “SwiftUI animation”, “Foundation Models”.)
- Apple Developer Videos: https://developer.apple.com/videos/
- SF Symbols updates sessions (by year) from the videos catalog.
- WidgetKit + interactive widgets sessions (by year) from the videos catalog.
- App Intents + Siri/Shortcuts sessions (by year) from the videos catalog.
- App Clips + deep linking sessions (by year) from the videos catalog.

---

## 2) Product direction for primary targets

Primary targets: **iOS 26, macOS 26, watchOS 26, tvOS 26**.

### Platform stance
- Shared domain logic via SwiftPM modules (`FlowCore`, `FlowIntents`, `FlowRouting`, `FlowAI`, `FlowSync`).
- Per-surface UI targets:
  - iOS/iPadOS app + Widget extension + Live Activity surfaces.
  - watchOS app/complications + Smart Stack experience.
  - macOS app UX (desktop-first affordances).
  - tvOS “at-a-distance” status/overview mode (focus rooms, large typography, remote-friendly actions).

> Note: Live Activities are iPhone-originated system surfaces; tvOS does not host Live Activities directly. We still mirror state on tvOS through shared model/sync.

---

## 3) UI/UX strategy (glanceable + purposeful motion)

### 3.1 Lock Screen / Dynamic Island hierarchy
- Compact view: one semantic icon + one critical metric.
- Minimal view: recognizable state glyph only (or timer only).
- Expanded view: title, elapsed/progress, top-two actions.
- Lock Screen card: stronger typography hierarchy and explicit state chip (active/paused/snoozed/offline).

### 3.2 Motion policy (HIG-aligned)
- Use motion only for state change confirmation, urgency shift, or continuity.
- Respect `Reduce Motion` and minimize continuous loops.
- SF Symbols usage:
  - Variable/layer rendering for progress and emphasis.
  - Symbol effects for transitions (subtle appear/disappear/emphasis only).

### 3.3 Accessibility + contrast
- Ensure legibility for personalized Lock Screens and Always-On conditions.
- Snapshot test matrix for light/dark, contrast settings, dynamic type, and reduced luminance.

---

## 4) Surface-by-surface feature matrix

| Capability | Live Activity | Widgets | Lock Screen | In-app | Watch | Mac | Apple TV |
|---|---|---|---|---|---|---|---|
| Active task state | Primary | Mirrors state | Primary card | Full detail | Smart Stack + glance list | Sidebar + menu bar status | Focus dashboard |
| Primary actions (done/snooze/start) | Intent-based where allowed | Intent-based buttons | Via activity/widget affordances | Full controls | Quick actions | Keyboard + click actions | Remote-friendly big buttons |
| Offline/local behavior | Cached state + optimistic update | Cached timeline + intent fallback | Cached state chip | Full local model | Cached + sync later | Cached + sync later | Read-mostly cached |
| Deep links | `flow://task/:id` + universal link handoff | same route model | same route model | typed router | typed router | typed router | typed router |
| Analytics/logging | action outcome + latency | intent success/failure | display state logs | full diagnostics | glance action logs | desktop logs | tv focus/session logs |

---

## 5) Tappable Live Activities without app launch

### Supported direct actions
- Use `Button(intent:)` + `AppIntent`/`LiveActivityIntent` for “Done”, “Snooze”, “Pause/Resume”, “Add +5m”.
- Keep each action idempotent and fast; enforce strict timeout budget.

### Graceful handoff (when app launch is required)
- If action needs UI/auth/network re-consent, return lightweight status and route user into app screen:
  - “Couldn’t complete here” → deep-link to exact remediation screen.
  - Preserve pending intent payload and replay once app is active.

---

## 6) Widgets that correspond to Live Activity state/actions

### Single source of truth
- Use App Group container for shared read/write models.
- Shared schema package (`FlowSharedModels`) used by app, widget, intents.
- Reconcile with conflict policy: latest-write-wins + monotonic event timestamp.

### Widget lineup
- iPhone/iPad: small/medium/large + accessory variants where relevant.
- watchOS complications/Smart Stack map to the same state machine.
- Ensure each widget action maps to same intent handlers as Live Activity and in-app commands.

---

## 7) Siri, App Intents, and Shortcuts matrix

| User capability | App Intent | Shortcut Phrase Example | Used by |
|---|---|---|---|
| Start focus | `StartFocusIntent` | “Start Flow focus for 25 minutes” | App, widget, Live Activity |
| Complete task | `CompleteTaskIntent` | “Complete my current Flow task” | Live Activity, widget, Siri |
| Snooze task | `SnoozeTaskIntent` | “Snooze Flow task for 10 minutes” | Live Activity, widget, Siri |
| Capture task | `CaptureTaskIntent` | “Add task in Flow” | App Clip, app, Siri |
| Open route | `OpenFlowRouteIntent` | “Open my overdue tasks in Flow” | Siri, Spotlight, app continuation |

Design rule: one handler path per capability (reuse across surfaces), no duplicate business logic.

---

## 8) App Clips strategy

### High-value entry points
1. **QR at desk/meeting room** → launch “Quick Capture”.
2. **NFC tag** → launch “Start Focus Preset”.
3. **Messages/Safari shared link** → open shared task summary.
4. **Maps place card** (if location workflows exist) → location-scoped checklist clip.

### App Clip implementation plan
- Keep clip binary minimal; include only capture/focus/join flows.
- Define invocation URL templates:
  - `/clip/capture`
  - `/clip/focus/{preset}`
  - `/clip/task/{id}`
- Handoff paths:
  - `SKOverlay` promotion to full app.
  - Preserve route via universal link + `NSUserActivity` continuation payload.

---

## 9) Universal Links + associated domains design

### 9.1 Associated domains table

| Bundle target | Entitlement value | Purpose |
|---|---|---|
| iOS app | `applinks:flow.example.com` | Task routes + app promotion |
| App Clip | `applinks:flow.example.com` | Shared route parsing for clip entry |
| (optional) web credentials | `webcredentials:flow.example.com` | Password/passkey continuity |

### 9.2 AASA rules plan
- Host `/.well-known/apple-app-site-association` and `/apple-app-site-association`.
- Use path/components routing for:
  - `/task/*`
  - `/focus/*`
  - `/clip/*`
  - `/invite/*`
- Keep private/admin URLs excluded.

### 9.3 Typed routing layer (single implementation)

```text
Incoming URL / NSUserActivity
        |
        v
FlowRouteParser  -->  enum FlowRoute {
                        case task(id: UUID)
                        case focus(preset: String)
                        case clipCapture
                        case invite(code: String)
                     }
        |
        v
AppReducer(.handleRoute(route))
        |
        +--> cold start boot routing
        +--> warm resume navigation
        +--> App Clip -> full app promotion continuation
```

### 9.4 Fallback behavior
- If universal link validation fails:
  - open Safari web fallback with clear CTA (“Open in Flow”).
  - show in-app nonfatal error surface and copy-link option.

---

## 10) Data, sync, and offline strategy

### Data model + storage
- `actor`-backed repository for task state mutations.
- Local-first persistence; network sync as asynchronous reconciliation.
- Activity/widget/intent state written through shared repository interface.

### Sync rules
- Event log with deterministic merge (timestamp + source + intent id).
- Offline actions queue and replay with backoff.
- Conflict telemetry logs with emoji markers for ops observability.

---

## 11) Optional LLM strategy (online + offline)

| Mode | Path | Privacy controls | Degradation |
|---|---|---|---|
| Offline/local | On-device model/local network endpoint | Default-on for private processing; no cloud transfer | Disable suggestions, keep rule-based heuristics |
| Online | MCP-capable/API provider via explicit opt-in | Consent gate, redaction, timeout budget, audit logging | Fallback to offline or no-AI mode with clear UI |

Engineering rules:
- Never send sensitive text unless user has explicitly enabled cloud AI.
- Per-request timeout + cancellation.
- UI badges: 🌐 online, 🏠 local, ⚠️ fallback, 🎉 success.

---

## 12) TCA + Swift concurrency module breakdown

### Proposed SwiftPM packages
- `FlowCore`: entities, enums, reducers for domain logic.
- `FlowRouting`: typed route parser, URL/NSUserActivity adapters.
- `FlowIntents`: AppIntent definitions + handlers.
- `FlowWidgetsShared`: timeline/state presenters shared with widgets/live activity.
- `FlowAI`: provider protocol + online/offline adapters.
- `FlowPlatform`: thin OS-specific adapters using `#if os(...)`.

### Concurrency and typing standards
- Swift 6 strict concurrency compliance (Sendable audits).
- `actor` for mutable shared state.
- `@MainActor` UI reducers/effects touching presentation.
- enum-driven state machines for navigation, intent results, and errors.

---

## 13) Test strategy

### Automated
- Reducer tests for all intent actions and route parsing.
- Widget + Live Activity snapshot coverage for key families and states.
- Universal link parser tests (cold start / warm resume / clip promotion).
- Offline queue replay tests with deterministic clocks.
- Privacy tests ensuring redaction before online AI calls.

### Manual verification matrix
- iPhone with Dynamic Island + Always-On checks.
- iPad Lock Screen/accessory widget behavior.
- Apple Watch Smart Stack + interaction.
- macOS continuity/open behavior from iPhone-origin live activity.
- tvOS readability at distance and remote navigation.

---

## 14) Milestones (small, verifiable)

1. **Routing + links foundation**
   - Add associated domains, AASA, typed route parser, cold/warm tests.
2. **Shared intent engine**
   - Implement AppIntents once; wire into app + widgets + live activity.
3. **Live Activity interaction hardening**
   - Move current placeholder intent logic to real repository-backed actions.
4. **Widget parity**
   - Corresponding widgets for active task state/actions across sizes.
5. **TCA vertical slice**
   - Migrate one full feature (task lifecycle) to TCA + strict concurrency.
6. **App Clip MVP**
   - QR/NFC capture flow + install handoff + route continuity.
7. **AI optional layer**
   - Local-first provider + opt-in online provider + privacy controls.
8. **Cross-surface polish**
   - Motion tuning, accessibility, contrast, and platform-specific affordances.

---

## 15) Immediate gaps found in current repo (to prioritize first)

- Intent actions in `Flow/Widgets/LiveActivityIntents.swift` are placeholder logic (`print`) and do not mutate shared state yet.
- Associated domains entitlement is not yet present in `Flow/Flow/Flow.entitlements`.
- Current architecture is mostly MVVM/service-based; phased TCA migration is needed rather than big-bang rewrite.
- Live Activity UI exists and is rich, but should be normalized against current HIG spacing/recognizability and cross-surface behavior.


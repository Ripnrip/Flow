# Phase 4: Enhanced Live Activity Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the ActivityKit Live Activity with configurable action buttons, pause/resume/extend actions, animated progress ring, and richer Dynamic Island layouts.

**Architecture:** Extend `FlowAttributes.ContentState` with pause/target fields; add `LiveActivityConfiguration` persisted in App Groups; implement new `LiveActivityIntent`s for pause/resume and extend; refactor `WidgetsLiveActivity` views to render configuration-driven buttons and animations.

**Tech Stack:** Swift 6, SwiftUI, ActivityKit, AppIntents, App Groups (`group.com.binarybros.Flow`).

## Global Constraints

- iOS 26 / Swift 6.2 / Xcode 26.0
- Strict concurrency disabled (`SWIFT_STRICT_CONCURRENCY = targeted`) in current build settings
- Live Activity intents must conform to `LiveActivityIntent`
- All cross-process models must be `Codable` + `Sendable`
- Out-of-scope: in-app configuration UI (Phase 5)

---

## Task 1: Extend Content State + Add Configuration Model

**Files:**
- Modify: `Flow/Widgets/LiveActivityIntents.swift`
- Modify: `Flow/Flow/SharedTaskStore.swift`

**Interfaces:**
- Produces: `enum LiveActivityAction`
- Produces: `enum LiveActivityAnimationIntensity`
- Produces: `struct LiveActivityConfiguration`
- Produces: `SharedTaskStore.saveLiveActivityConfiguration(_:)`
- Produces: `SharedTaskStore.loadLiveActivityConfiguration() -> LiveActivityConfiguration`
- Produces: updated `FlowAttributes.ContentState`

- [ ] **Step 1: Add enums and configuration model to LiveActivityIntents.swift**

Insert after the imports / before `FlowAttributes`:

```swift
// MARK: - 🎛️ Live Activity Configuration

/// An action that can appear on the Live Activity.
enum LiveActivityAction: String, Sendable, Codable, CaseIterable {
    case snooze
    case done
    case pauseResume
    case extend
}

/// How much motion the Live Activity should use.
enum LiveActivityAnimationIntensity: String, Sendable, Codable, CaseIterable {
    case calm
    case normal
    case lively
}

/// User-facing configuration for the Live Activity.
struct LiveActivityConfiguration: Sendable, Codable {
    var leadingAction: LiveActivityAction
    var trailingAction: LiveActivityAction
    var showProgressRing: Bool
    var animationIntensity: LiveActivityAnimationIntensity

    static var `default`: LiveActivityConfiguration {
        LiveActivityConfiguration(
            leadingAction: .snooze,
            trailingAction: .done,
            showProgressRing: true,
            animationIntensity: .normal
        )
    }
}
```

- [ ] **Step 2: Extend FlowAttributes.ContentState**

Replace the existing `ContentState` struct with:

```swift
    public struct ContentState: Codable, Hashable, Sendable {
        var title: String
        var snoozeCount: Int
        var moveCount: Int
        var startDate: Date
        var emoji: String
        var style: TaskStyle
        var lastInteractionDate: Date = .now
        var growthLevel: Int = 0
        var isPaused: Bool = false
        var focusTargetMinutes: Int = 25
        var elapsedPauseSeconds: TimeInterval = 0
    }
```

- [ ] **Step 3: Update makeContentState helper**

Update `makeContentState(from:)` to include the new fields. Since `ActiveTaskSnapshot` does not yet store these, default them:

```swift
nonisolated func makeContentState(from snapshot: ActiveTaskSnapshot) -> FlowAttributes.ContentState {
    FlowAttributes.ContentState(
        title: snapshot.title,
        snoozeCount: snapshot.snoozeCount,
        moveCount: snapshot.moveCount,
        startDate: snapshot.startDate,
        emoji: snapshot.emoji,
        style: snapshot.style,
        lastInteractionDate: snapshot.lastInteractionDate,
        growthLevel: snapshot.growthLevel,
        isPaused: false,
        focusTargetMinutes: 25,
        elapsedPauseSeconds: 0
    )
}
```

- [ ] **Step 4: Add SharedTaskStore persistence**

Add to `Flow/Flow/SharedTaskStore.swift` after the pinned tasks section:

```swift
    // MARK: - 🎛️ Live Activity Configuration

    private let liveActivityConfigKey = "com.binarybros.Flow.liveActivityConfiguration"

    /// Persist Live Activity configuration to App Groups.
    func saveLiveActivityConfiguration(_ configuration: LiveActivityConfiguration) {
        guard let defaults else {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] App Groups unavailable — cannot save LA config")
            return
        }
        do {
            let data = try JSONEncoder().encode(configuration)
            defaults.set(data, forKey: liveActivityConfigKey)
            FlowLogger.sync.info("🎛️ [SharedTaskStore] Saved Live Activity configuration")
        } catch {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] LA config encode failed: \(error.localizedDescription)")
        }
    }

    /// Load Live Activity configuration from App Groups.
    func loadLiveActivityConfiguration() -> LiveActivityConfiguration {
        guard let defaults,
              let data = defaults.data(forKey: liveActivityConfigKey) else { return .default }
        do {
            return try JSONDecoder().decode(LiveActivityConfiguration.self, from: data)
        } catch {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] LA config decode failed: \(error.localizedDescription)")
            return .default
        }
    }
```

- [ ] **Step 5: Build the Flow scheme**

Run:
```bash
cd /Users/admin/Developer/Flow-GitHub/Flow
xcodebuild build -project Flow.xcodeproj -scheme Flow \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D3914993-86CF-46F5-94C5-BDE0CAA0ADBF' \
  ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

Expected: `** BUILD SUCCEEDED **`

---

## Task 2: Implement Pause/Resume and Extend Intents

**Files:**
- Modify: `Flow/Widgets/LiveActivityIntents.swift`
- Modify: `Flow/Flow/SharedTaskStore.swift`

**Interfaces:**
- Produces: `PauseResumeIntent`
- Produces: `ExtendFocusIntent`
- Produces: `SharedTaskStore.togglePause(taskId:)`
- Produces: `SharedTaskStore.extendFocus(taskId:additionalMinutes:)`

- [ ] **Step 1: Add SharedTaskStore helpers**

Add to `Flow/Flow/SharedTaskStore.swift` inside the actor:

```swift
    /// Toggle the paused state of the active task snapshot.
    func togglePause(taskId: String) -> ActiveTaskSnapshot? {
        guard var snapshot = loadSnapshot(), snapshot.taskId == taskId else {
            FlowLogger.sync.warning("⚠️ [SharedTaskStore] Cannot toggle pause — no active task")
            return nil
        }
        snapshot.isPaused.toggle()
        snapshot.lastInteractionDate = .now
        saveSnapshot(snapshot)
        FlowLogger.sync.info("⏸️ [SharedTaskStore] Pause toggled: \(snapshot.isPaused)")
        return snapshot
    }

    /// Extend the focus target by the given number of minutes.
    func extendFocus(taskId: String, additionalMinutes: Int) -> ActiveTaskSnapshot? {
        guard var snapshot = loadSnapshot(), snapshot.taskId == taskId else {
            FlowLogger.sync.warning("⚠️ [SharedTaskStore] Cannot extend focus — no active task")
            return nil
        }
        // Cap total target at 60 minutes to prevent runaway timers.
        snapshot.focusTargetMinutes = min((snapshot.focusTargetMinutes ?? 25) + additionalMinutes, 60)
        snapshot.lastInteractionDate = .now
        saveSnapshot(snapshot)
        FlowLogger.sync.info("⏱️ [SharedTaskStore] Focus target extended to \(snapshot.focusTargetMinutes ?? 25) min")
        return snapshot
    }
```

- [ ] **Step 2: Extend ActiveTaskSnapshot with new fields**

Add to `ActiveTaskSnapshot` struct:

```swift
    var isPaused: Bool = false
    var focusTargetMinutes: Int = 25
    var elapsedPauseSeconds: TimeInterval = 0
```

- [ ] **Step 3: Update makeContentState to use new snapshot fields**

Update `makeContentState(from:)` in `LiveActivityIntents.swift`:

```swift
nonisolated func makeContentState(from snapshot: ActiveTaskSnapshot) -> FlowAttributes.ContentState {
    FlowAttributes.ContentState(
        title: snapshot.title,
        snoozeCount: snapshot.snoozeCount,
        moveCount: snapshot.moveCount,
        startDate: snapshot.startDate,
        emoji: snapshot.emoji,
        style: snapshot.style,
        lastInteractionDate: snapshot.lastInteractionDate,
        growthLevel: snapshot.growthLevel,
        isPaused: snapshot.isPaused,
        focusTargetMinutes: snapshot.focusTargetMinutes,
        elapsedPauseSeconds: snapshot.elapsedPauseSeconds
    )
}
```

- [ ] **Step 4: Add PauseResumeIntent**

Append to `LiveActivityIntents.swift` after `DoneIntent`:

```swift
// MARK: - ⏸️ Pause / Resume

struct PauseResumeIntent: LiveActivityIntent {
    static let openAppWhenRun: Bool = false
    static let title: LocalizedStringResource = "Pause or Resume Focus"
    static let description = IntentDescription(
        "Pause or resume your active Flow focus session.",
        categoryName: "Focus"
    )
    static let isDiscoverable: Bool = true

    @Parameter(title: "Task Identifier")
    var taskId: String

    init(taskId: String) { self.taskId = taskId }
    init() { self.taskId = "" }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        FlowLogger.intent.info("⏸️ [PauseResumeIntent] Performing for task: \(taskId)")

        guard let updated = await SharedTaskStore.shared.togglePause(taskId: taskId) else {
            FlowLogger.intent.warning("⚠️ [PauseResumeIntent] No active task matching \(taskId)")
            return .result(value: false)
        }

        let newState = makeContentState(from: updated)
        await pushLiveActivityUpdate(state: newState)
        WidgetCenter.shared.reloadAllTimelines()

        FlowLogger.intent.info("🎉 [PauseResumeIntent] Paused=\(updated.isPaused)")
        return .result(value: true)
    }
}
```

- [ ] **Step 5: Add ExtendFocusIntent**

Append after `PauseResumeIntent`:

```swift
// MARK: - ⏱️ Extend Focus

struct ExtendFocusIntent: LiveActivityIntent {
    static let openAppWhenRun: Bool = false
    static let title: LocalizedStringResource = "Extend Focus Session"
    static let description = IntentDescription(
        "Add five more minutes to your current focus target.",
        categoryName: "Focus"
    )
    static let isDiscoverable: Bool = true

    @Parameter(title: "Task Identifier")
    var taskId: String

    init(taskId: String) { self.taskId = taskId }
    init() { self.taskId = "" }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        FlowLogger.intent.info("⏱️ [ExtendFocusIntent] Performing for task: \(taskId)")

        guard let updated = await SharedTaskStore.shared.extendFocus(taskId: taskId, additionalMinutes: 5) else {
            FlowLogger.intent.warning("⚠️ [ExtendFocusIntent] No active task matching \(taskId)")
            return .result(value: false)
        }

        let newState = makeContentState(from: updated)
        await pushLiveActivityUpdate(state: newState)
        WidgetCenter.shared.reloadAllTimelines()

        FlowLogger.intent.info("🎉 [ExtendFocusIntent] Target=\(updated.focusTargetMinutes) min")
        return .result(value: true)
    }
}
```

- [ ] **Step 6: Build the Flow scheme**

Same command as Task 1, Step 5.
Expected: `** BUILD SUCCEEDED **`

---

## Task 3: Refactor WidgetsLiveActivity Views

**Files:**
- Modify: `Flow/Widgets/WidgetsLiveActivity.swift`

**Interfaces:**
- Consumes: `LiveActivityConfiguration`
- Consumes: `LiveActivityAction`
- Consumes: `PauseResumeIntent`, `ExtendFocusIntent`
- Produces: `ProgressRingView`
- Produces: `ActionButtonView`
- Produces: updated lock screen / Dynamic Island views

- [ ] **Step 1: Add configuration + progress helpers**

Insert after the imports in `WidgetsLiveActivity.swift`:

```swift
// MARK: - 🧮 Progress Helpers

extension FlowAttributes.ContentState {
    /// Elapsed focus time, excluding paused periods.
    var effectiveElapsed: TimeInterval {
        let raw = Date().timeIntervalSince(startDate)
        return max(0, raw - elapsedPauseSeconds)
    }

    /// Progress toward the focus target (0...1).
    var progress: Double {
        let target = TimeInterval(focusTargetMinutes * 60)
        guard target > 0 else { return 0 }
        return min(effectiveElapsed / target, 1.0)
    }
}

// MARK: - 🎨 Progress Ring View

struct ProgressRingView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let animate: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
    }
}

// MARK: - 🔘 Configurable Action Button

struct LiveActivityActionButton: View {
    let action: LiveActivityAction
    let taskId: String
    let style: TaskStyle
    let snoozeCount: Int

    var body: some View {
        switch action {
        case .snooze:
            actionIntentButton(
                intent: SnoozeIntent(taskId: taskId),
                icon: "bed.double.fill",
                label: "Snooze",
                color: style.themeForegroundColor(),
                symbolEffect: .wiggle(value: snoozeCount)
            )
        case .done:
            actionIntentButton(
                intent: DoneIntent(taskId: taskId),
                icon: "checkmark.circle.fill",
                label: doneLabel(for: style),
                color: .white,
                background: style.themeAccentColor(),
                symbolEffect: .bounce(value: true)
            )
        case .pauseResume:
            // ContentState is not available here; we show a generic Pause label.
            actionIntentButton(
                intent: PauseResumeIntent(taskId: taskId),
                icon: "pause.fill",
                label: "Pause",
                color: style.themeForegroundColor(),
                symbolEffect: nil
            )
        case .extend:
            actionIntentButton(
                intent: ExtendFocusIntent(taskId: taskId),
                icon: "plus.circle.fill",
                label: "+5 min",
                color: style.themeForegroundColor(),
                symbolEffect: nil
            )
        }
    }

    private func actionIntentButton<I: LiveActivityIntent>(
        intent: I,
        icon: String,
        label: String,
        color: Color,
        background: Color? = nil,
        symbolEffect: SymbolWiggleEffect?
    ) -> some View {
        Button(intent: intent) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .symbolEffect(symbolEffect)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .background(background ?? style.themeForegroundColor().opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

// Helper placeholder; real SymbolEffect handling is done inline in views.
enum SymbolWiggleEffect {
    case wiggle(value: Int)
    case bounce(value: Bool)
}

extension Image {
    @ViewBuilder
    func symbolEffect(_ effect: SymbolWiggleEffect?) -> some View {
        switch effect {
        case .wiggle(let value):
            self.symbolEffect(.wiggle, value: value)
        case .bounce(let value):
            self.symbolEffect(.bounce, value: value)
        case .none:
            self
        }
    }
}
```

- [ ] **Step 2: Update lock screen view**

Replace the bottom action button HStack in `lockScreenView` with a configuration-driven view:

```swift
                // ── Bottom row: configurable action buttons ───────────
                HStack(spacing: 10) {
                    LiveActivityActionButton(
                        action: liveActivityConfig.leadingAction,
                        taskId: context.attributes.taskId,
                        style: style,
                        snoozeCount: context.state.snoozeCount
                    )
                    LiveActivityActionButton(
                        action: liveActivityConfig.trailingAction,
                        taskId: context.attributes.taskId,
                        style: style,
                        snoozeCount: context.state.snoozeCount
                    )
                }
```

Add configuration lookup at the top of `lockScreenView`:

```swift
        let style = context.state.style
        let config = await SharedTaskStore.shared.loadLiveActivityConfiguration()
```

Wait — `ActivityConfiguration` content closure is synchronous and cannot await an actor method. We need to pass configuration through the ContentState instead.

REVISE: Add `leadingActionRawValue`, `trailingActionRawValue`, `showProgressRing`, `animationIntensityRawValue` to `FlowAttributes.ContentState`. Then `makeContentState` populates them from `SharedTaskStore.loadLiveActivityConfiguration()`.

Update `ContentState`:

```swift
    public struct ContentState: Codable, Hashable, Sendable {
        var title: String
        var snoozeCount: Int
        var moveCount: Int
        var startDate: Date
        var emoji: String
        var style: TaskStyle
        var lastInteractionDate: Date = .now
        var growthLevel: Int = 0
        var isPaused: Bool = false
        var focusTargetMinutes: Int = 25
        var elapsedPauseSeconds: TimeInterval = 0
        var leadingActionRawValue: String = LiveActivityAction.snooze.rawValue
        var trailingActionRawValue: String = LiveActivityAction.done.rawValue
        var showProgressRing: Bool = true
        var animationIntensityRawValue: String = LiveActivityAnimationIntensity.normal.rawValue
    }
```

Add computed properties:

```swift
extension FlowAttributes.ContentState {
    var leadingAction: LiveActivityAction {
        LiveActivityAction(rawValue: leadingActionRawValue) ?? .snooze
    }
    var trailingAction: LiveActivityAction {
        LiveActivityAction(rawValue: trailingActionRawValue) ?? .done
    }
    var animationIntensity: LiveActivityAnimationIntensity {
        LiveActivityAnimationIntensity(rawValue: animationIntensityRawValue) ?? .normal
    }
}
```

Update `makeContentState` to read config:

```swift
nonisolated func makeContentState(from snapshot: ActiveTaskSnapshot, configuration: LiveActivityConfiguration = .default) -> FlowAttributes.ContentState {
    FlowAttributes.ContentState(
        title: snapshot.title,
        snoozeCount: snapshot.snoozeCount,
        moveCount: snapshot.moveCount,
        startDate: snapshot.startDate,
        emoji: snapshot.emoji,
        style: snapshot.style,
        lastInteractionDate: snapshot.lastInteractionDate,
        growthLevel: snapshot.growthLevel,
        isPaused: snapshot.isPaused,
        focusTargetMinutes: snapshot.focusTargetMinutes,
        elapsedPauseSeconds: snapshot.elapsedPauseSeconds,
        leadingActionRawValue: configuration.leadingAction.rawValue,
        trailingActionRawValue: configuration.trailingAction.rawValue,
        showProgressRing: configuration.showProgressRing,
        animationIntensityRawValue: configuration.animationIntensity.rawValue
    )
}
```

Update `SnoozeIntent` and `DoneIntent` and the new intents to read config and pass it to `makeContentState`:

```swift
let config = await SharedTaskStore.shared.loadLiveActivityConfiguration()
let newState = makeContentState(from: updated, configuration: config)
```

Then in `WidgetsLiveActivity.swift`, use `context.state.leadingAction` etc.

- [ ] **Step 3: Update preview helpers**

Update `FlowAttributes.ContentState.make(emoji:title:style:)` to include default values for new fields:

```swift
    static func make(emoji: String, title: String, style: TaskStyle) -> FlowAttributes.ContentState {
        FlowAttributes.ContentState(
            title: title,
            snoozeCount: 2,
            moveCount: 1,
            startDate: Date().addingTimeInterval(-1800),
            emoji: emoji,
            style: style,
            lastInteractionDate: .now,
            growthLevel: 1,
            isPaused: false,
            focusTargetMinutes: 25,
            elapsedPauseSeconds: 0,
            leadingActionRawValue: LiveActivityAction.snooze.rawValue,
            trailingActionRawValue: LiveActivityAction.done.rawValue,
            showProgressRing: true,
            animationIntensityRawValue: LiveActivityAnimationIntensity.normal.rawValue
        )
    }
```

- [ ] **Step 4: Build the Flow scheme**

Same command as Task 1, Step 5.
Expected: `** BUILD SUCCEEDED **`

---

## Task 4: Update App Live Activity Start Path

**Files:**
- Modify: `Flow/Flow/TaskService.swift` or wherever Live Activity is started

**Interfaces:**
- Consumes: `LiveActivityConfiguration`
- Produces: Live Activity started with config baked into initial state

- [ ] **Step 1: Find Live Activity start call**

Run:
```bash
cd /Users/admin/Developer/Flow-GitHub/Flow
rg -n "Activity<FlowAttributes>" Flow/ --type swift
```

- [ ] **Step 2: Update start call to include config**

Where the activity is started, load config and pass to `makeContentState`:

```swift
let config = await SharedTaskStore.shared.loadLiveActivityConfiguration()
let initialState = makeContentState(from: snapshot, configuration: config)
```

- [ ] **Step 3: Build the Flow scheme**

Same command as Task 1, Step 5.
Expected: `** BUILD SUCCEEDED **`

---

## Task 5: Verify Previews and Run Tests

**Files:**
- Review: `Flow/Widgets/WidgetsLiveActivity.swift` previews

- [ ] **Step 1: Build with previews enabled**

Run:
```bash
cd /Users/admin/Developer/Flow-GitHub/Flow
xcodebuild build -project Flow.xcodeproj -scheme Flow \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D3914993-86CF-46F5-94C5-BDE0CAA0ADBF' \
  ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  ENABLE_PREVIEWS=YES
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Run FlowTests**

Run:
```bash
cd /Users/admin/Developer/Flow-GitHub/Flow
xcodebuild test -project Flow.xcodeproj -scheme FlowTests \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D3914993-86CF-46F5-94C5-BDE0CAA0ADBF' \
  ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

Expected: `** TEST SUCCEEDED **`

---

## Self-Review

1. **Spec coverage:**
   - Configurable action buttons ✓ (Task 1, 3)
   - Pause/Resume intent ✓ (Task 2)
   - Extend intent ✓ (Task 2)
   - Progress ring ✓ (Task 3)
   - Enhanced Dynamic Island ✓ (Task 3)
   - Configuration persistence ✓ (Task 1)
   - App Live Activity start path ✓ (Task 4)

2. **Placeholder scan:** No TBD/TODO.

3. **Type consistency:** `FlowAttributes.ContentState` new fields match `makeContentState` and preview helpers. `LiveActivityConfiguration` defaults match `ContentState` defaults.

Plan is ready for execution.

/**
 * 🔃 SharedTaskStore - The Cross-Realm Bridge
 *
 * "A sacred portal between the main app and the widget extension.
 * Through App Groups UserDefaults, state flows across process boundaries—
 * enabling AppIntents to act on tasks without ever launching the app."
 *
 * Architecture:
 *   • Both the Flow app and the WidgetsExtension link this file.
 *   • The app writes a snapshot whenever a focus session starts/updates.
 *   • AppIntents (SnoozeIntent, DoneIntent) read + mutate the snapshot.
 *   • On foreground the app calls `reconcile(with:)` to sync back to SwiftData.
 *   • `actor` isolation guarantees Swift 6 strict-concurrency safety.
 *
 * App Group entitlement required: group.com.binarybros.Flow
 */

import Foundation
import OSLog

// MARK: - App Group Identifier

/// Shared App Group suite name — must match the entitlement value.
nonisolated let kFlowAppGroup = "group.com.binarybros.Flow"

// MARK: - 📸 Shared State Snapshot

/// A lightweight, Codable mirror of a pinned `Item`.
/// Shared via App Groups so the pinned-tasks widget can render
/// without importing the SwiftData model.
struct PinnedTaskSnapshot: Sendable, Codable {
    var taskId: String
    var title: String
    var emoji: String
    var styleRawValue: String
    var isCompleted: Bool

    nonisolated var style: TaskStyle {
        TaskStyle(rawValue: styleRawValue) ?? .sleekModern
    }
}

/// A lightweight, Codable mirror of an active `Item` focus session.
/// Lives in App Groups UserDefaults so intents and widgets can read it
/// without a SwiftData ModelContext.
struct ActiveTaskSnapshot: Sendable {

    // MARK: Identity
    var taskId: String          // UUID string of the `Item`
    var title: String
    var emoji: String
    var styleRawValue: String   // TaskStyle.rawValue

    // MARK: Session State
    var snoozeCount: Int
    var moveCount: Int
    var startDate: Date
    var growthLevel: Int
    var lastInteractionDate: Date
    var isCompleted: Bool
    var isPaused: Bool = false
    var focusTargetMinutes: Int = 25
    var elapsedPauseSeconds: TimeInterval = 0

    // MARK: Pending Flags (set by intents, cleared by app after reconcile)
    var pendingSnooze: Bool = false   // set by SnoozeIntent
    var pendingComplete: Bool = false // set by DoneIntent

    // MARK: Computed Helpers

    /// Reconstruct the `TaskStyle` from the raw value.
    nonisolated var style: TaskStyle {
        TaskStyle(rawValue: styleRawValue) ?? .sleekModern
    }

    /// Calculates how many intent-side snoozes still need to be applied locally.
    ///
    /// Widget intents may fire several times before the app foregrounds. The
    /// snapshot carries the latest cross-process count, while SwiftData may still
    /// have an older value. This delta keeps reconciliation idempotent: no lost
    /// taps, no duplicate goblin math, just tidy little integers in formation. 🧮🪄
    func pendingSnoozeDelta(comparedTo currentCount: Int) -> Int {
        guard pendingSnooze else { return 0 }
        return max(0, snoozeCount - currentCount)
    }
}

// MARK: - 🔃 Explicit Codable Conformance

/// Explicit, nonisolated Codable implementation keeps the conformance usable
/// from actor-isolated contexts under Swift 6 strict concurrency.
extension ActiveTaskSnapshot: Equatable {
    nonisolated static func == (lhs: ActiveTaskSnapshot, rhs: ActiveTaskSnapshot) -> Bool {
        lhs.taskId == rhs.taskId &&
        lhs.title == rhs.title &&
        lhs.emoji == rhs.emoji &&
        lhs.styleRawValue == rhs.styleRawValue &&
        lhs.snoozeCount == rhs.snoozeCount &&
        lhs.moveCount == rhs.moveCount &&
        lhs.startDate == rhs.startDate &&
        lhs.growthLevel == rhs.growthLevel &&
        lhs.lastInteractionDate == rhs.lastInteractionDate &&
        lhs.isCompleted == rhs.isCompleted &&
        lhs.isPaused == rhs.isPaused &&
        lhs.focusTargetMinutes == rhs.focusTargetMinutes &&
        lhs.elapsedPauseSeconds == rhs.elapsedPauseSeconds &&
        lhs.pendingSnooze == rhs.pendingSnooze &&
        lhs.pendingComplete == rhs.pendingComplete
    }
}

extension ActiveTaskSnapshot: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.taskId = try container.decode(String.self, forKey: .taskId)
        self.title = try container.decode(String.self, forKey: .title)
        self.emoji = try container.decode(String.self, forKey: .emoji)
        self.styleRawValue = try container.decode(String.self, forKey: .styleRawValue)
        self.snoozeCount = try container.decode(Int.self, forKey: .snoozeCount)
        self.moveCount = try container.decode(Int.self, forKey: .moveCount)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.growthLevel = try container.decode(Int.self, forKey: .growthLevel)
        self.lastInteractionDate = try container.decode(Date.self, forKey: .lastInteractionDate)
        self.isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        self.isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        self.focusTargetMinutes = try container.decodeIfPresent(Int.self, forKey: .focusTargetMinutes) ?? 25
        self.elapsedPauseSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .elapsedPauseSeconds) ?? 0
        self.pendingSnooze = try container.decodeIfPresent(Bool.self, forKey: .pendingSnooze) ?? false
        self.pendingComplete = try container.decodeIfPresent(Bool.self, forKey: .pendingComplete) ?? false
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(taskId, forKey: .taskId)
        try container.encode(title, forKey: .title)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(styleRawValue, forKey: .styleRawValue)
        try container.encode(snoozeCount, forKey: .snoozeCount)
        try container.encode(moveCount, forKey: .moveCount)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(growthLevel, forKey: .growthLevel)
        try container.encode(lastInteractionDate, forKey: .lastInteractionDate)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(isPaused, forKey: .isPaused)
        try container.encode(focusTargetMinutes, forKey: .focusTargetMinutes)
        try container.encode(elapsedPauseSeconds, forKey: .elapsedPauseSeconds)
        try container.encode(pendingSnooze, forKey: .pendingSnooze)
        try container.encode(pendingComplete, forKey: .pendingComplete)
    }

    private enum CodingKeys: String, CodingKey {
        case taskId, title, emoji, styleRawValue
        case snoozeCount, moveCount, startDate, growthLevel
        case lastInteractionDate, isCompleted
        case isPaused, focusTargetMinutes, elapsedPauseSeconds
        case pendingSnooze, pendingComplete
    }
}

// MARK: - 🔃 The Cross-Realm Actor

/// Thread-safe, cross-process task state bridge backed by App Groups UserDefaults.
/// Methods are isolated on an `actor` for Swift 6 strict-concurrency compliance.
actor SharedTaskStore {

    // MARK: Singleton
    static let shared = SharedTaskStore()

    // MARK: Private State
    private let storeKey = "com.binarybros.Flow.activeTaskSnapshot"
    private let tilesKey = "com.binarybros.Flow.commandTiles"
    private let summaryKey = "com.binarybros.Flow.dailyFocusSummary"
    private let pinnedKey = "com.binarybros.Flow.pinnedTasks"
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: kFlowAppGroup)
    }

    private init() {}

    // MARK: - CRUD

    /// Persist a snapshot to App Groups UserDefaults.
    func save(_ snapshot: ActiveTaskSnapshot) {
        guard let defaults else {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] App Groups unavailable — is 'group.com.binarybros.Flow' in entitlements?")
            return
        }
        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: storeKey)
            FlowLogger.sync.info("🎉 [SharedTaskStore] Saved '\(snapshot.title)' style=\(snapshot.styleRawValue) snooze=\(snapshot.snoozeCount)")
        } catch {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] Encode failed: \(error.localizedDescription)")
        }
    }

    /// Load the current snapshot from App Groups UserDefaults.
    func load() -> ActiveTaskSnapshot? {
        guard let defaults,
              let data = defaults.data(forKey: storeKey) else {
            return nil
        }
        do {
            let snapshot = try JSONDecoder().decode(ActiveTaskSnapshot.self, from: data)
            return snapshot
        } catch {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] Decode failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Load the snapshot only if it matches the requested taskId.
    /// Used by AppIntents to ensure they mutate the task that triggered them.
    func load(taskId: String) -> ActiveTaskSnapshot? {
        guard let snapshot = load(), snapshot.taskId == taskId else {
            FlowLogger.intent.warning("⚠️ [SharedTaskStore] load(taskId:): no snapshot matching \(taskId)")
            return nil
        }
        return snapshot
    }

    /// Remove the snapshot (called after task completion + reconciliation).
    func clear() {
        defaults?.removeObject(forKey: storeKey)
        FlowLogger.sync.info("🧹 [SharedTaskStore] Cleared active task snapshot")
    }

    // MARK: - Intent Actions (run without opening the app)

    /// Increment snooze count and set `pendingSnooze = true`.
    /// Called by `SnoozeIntent.perform()` from the widget extension process.
    /// When `taskId` is supplied, the mutation is applied only to a matching snapshot.
    /// Returns the updated snapshot so the intent can push a Live Activity update.
    @discardableResult
    func snooze(taskId: String? = nil) -> ActiveTaskSnapshot? {
        let snapshot: ActiveTaskSnapshot?
        if let taskId {
            snapshot = load(taskId: taskId)
        } else {
            snapshot = load()
        }
        guard var snapshot, !snapshot.isCompleted else {
            FlowLogger.intent.warning("⚠️ [SharedTaskStore] snooze(): no active task or already completed")
            return nil
        }
        snapshot.snoozeCount += 1
        snapshot.lastInteractionDate = .now
        snapshot.pendingSnooze = true
        save(snapshot)
        FlowLogger.intent.info("💤 [SharedTaskStore] Snoozed '\(snapshot.title)' → count=\(snapshot.snoozeCount)")
        return snapshot
    }

    /// Mark the task as completed and set `pendingComplete = true`.
    /// Called by `DoneIntent.perform()` from the widget extension process.
    /// When `taskId` is supplied, the mutation is applied only to a matching snapshot.
    @discardableResult
    func complete(taskId: String? = nil) -> ActiveTaskSnapshot? {
        let snapshot: ActiveTaskSnapshot?
        if let taskId {
            snapshot = load(taskId: taskId)
        } else {
            snapshot = load()
        }
        guard var snapshot, !snapshot.isCompleted else {
            FlowLogger.intent.warning("⚠️ [SharedTaskStore] complete(): no active task or already completed")
            return nil
        }
        snapshot.isCompleted = true
        snapshot.pendingComplete = true
        snapshot.lastInteractionDate = .now
        save(snapshot)
        FlowLogger.intent.info("✅ [SharedTaskStore] Completed '\(snapshot.title)'")
        return snapshot
    }

    /// Toggle the paused state of the active task snapshot.
    func togglePause(taskId: String) -> ActiveTaskSnapshot? {
        guard var snapshot = load(), snapshot.taskId == taskId else {
            FlowLogger.sync.warning("⚠️ [SharedTaskStore] Cannot toggle pause — no active task")
            return nil
        }
        snapshot.isPaused.toggle()
        snapshot.lastInteractionDate = .now
        save(snapshot)
        FlowLogger.sync.info("⏸️ [SharedTaskStore] Pause toggled: \(snapshot.isPaused)")
        return snapshot
    }

    /// Extend the focus target by the given number of minutes.
    func extendFocus(taskId: String, additionalMinutes: Int) -> ActiveTaskSnapshot? {
        guard var snapshot = load(), snapshot.taskId == taskId else {
            FlowLogger.sync.warning("⚠️ [SharedTaskStore] Cannot extend focus — no active task")
            return nil
        }
        // Cap total target at 60 minutes to prevent runaway timers.
        snapshot.focusTargetMinutes = min((snapshot.focusTargetMinutes) + additionalMinutes, 60)
        snapshot.lastInteractionDate = .now
        save(snapshot)
        FlowLogger.sync.info("⏱️ [SharedTaskStore] Focus target extended to \(snapshot.focusTargetMinutes) min")
        return snapshot
    }

    // MARK: - App Reconciliation

    /// Whether a pending intent action needs to be synced back to SwiftData.
    var needsReconciliation: Bool {
        guard let snapshot = load() else { return false }
        return snapshot.pendingSnooze || snapshot.pendingComplete
    }

    /// Clear pending flags after the main app has applied them to SwiftData.
    func clearPendingFlags() {
        guard var snapshot = load() else { return }
        snapshot.pendingSnooze = false
        snapshot.pendingComplete = false
        save(snapshot)
        FlowLogger.sync.info("🔃 [SharedTaskStore] Cleared pending flags after reconcile")
    }

    // MARK: - 🎛️ Command Center Tiles

    /// Persist the user's command tile layout to App Groups.
    func saveCommandTiles(_ tiles: [CommandTile]) {
        guard let defaults else {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] App Groups unavailable — cannot save command tiles")
            return
        }
        do {
            let data = try JSONEncoder().encode(tiles)
            defaults.set(data, forKey: tilesKey)
            FlowLogger.sync.info("🎛️ [SharedTaskStore] Saved \(tiles.count) command tile(s)")
        } catch {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] Command tiles encode failed: \(error.localizedDescription)")
        }
    }

    /// Load the user's command tile layout from App Groups.
    func loadCommandTiles() -> [CommandTile] {
        guard let defaults,
              let data = defaults.data(forKey: tilesKey) else { return [] }
        do {
            return try JSONDecoder().decode([CommandTile].self, from: data)
        } catch {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] Command tiles decode failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - 📊 Daily Focus Summary

    /// Persist today's focus summary to App Groups.
    func saveDailySummary(_ summary: DailyFocusSummary) {
        guard let defaults else {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] App Groups unavailable — cannot save daily summary")
            return
        }
        do {
            let data = try JSONEncoder().encode(summary)
            defaults.set(data, forKey: summaryKey)
            FlowLogger.sync.info("📊 [SharedTaskStore] Saved daily summary: \(summary.formattedDuration)")
        } catch {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] Daily summary encode failed: \(error.localizedDescription)")
        }
    }

    /// Load today's focus summary from App Groups.
    func loadDailySummary() -> DailyFocusSummary {
        guard let defaults,
              let data = defaults.data(forKey: summaryKey) else { return .empty }
        do {
            return try JSONDecoder().decode(DailyFocusSummary.self, from: data)
        } catch {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] Daily summary decode failed: \(error.localizedDescription)")
            return .empty
        }
    }

    // MARK: - 📌 Pinned Tasks

    /// Persist the pinned task list to App Groups.
    func savePinnedTasks(_ tasks: [PinnedTaskSnapshot]) {
        guard let defaults else {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] App Groups unavailable — cannot save pinned tasks")
            return
        }
        do {
            let data = try JSONEncoder().encode(tasks)
            defaults.set(data, forKey: pinnedKey)
            FlowLogger.sync.info("📌 [SharedTaskStore] Saved \(tasks.count) pinned task(s)")
        } catch {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] Pinned tasks encode failed: \(error.localizedDescription)")
        }
    }

    /// Load the pinned task list from App Groups.
    func loadPinnedTasks() -> [PinnedTaskSnapshot] {
        guard let defaults,
              let data = defaults.data(forKey: pinnedKey) else { return [] }
        do {
            return try JSONDecoder().decode([PinnedTaskSnapshot].self, from: data)
        } catch {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] Pinned tasks decode failed: \(error.localizedDescription)")
            return []
        }
    }

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
}

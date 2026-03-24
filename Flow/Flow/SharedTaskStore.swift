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

// MARK: - App Group Identifier

/// Shared App Group suite name — must match the entitlement value.
let kFlowAppGroup = "group.com.binarybros.Flow"

// MARK: - 📸 Shared State Snapshot

/// A lightweight, Codable mirror of an active `Item` focus session.
/// Lives in App Groups UserDefaults so intents and widgets can read it
/// without a SwiftData ModelContext.
struct ActiveTaskSnapshot: Codable, Sendable, Hashable {

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

    // MARK: Pending Flags (set by intents, cleared by app after reconcile)
    var pendingSnooze: Bool = false   // set by SnoozeIntent
    var pendingComplete: Bool = false // set by DoneIntent

    // MARK: Computed Helpers

    /// Reconstruct the `TaskStyle` from the raw value.
    var style: TaskStyle {
        TaskStyle(rawValue: styleRawValue) ?? .sleekModern
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

    /// Remove the snapshot (called after task completion + reconciliation).
    func clear() {
        defaults?.removeObject(forKey: storeKey)
        FlowLogger.sync.info("🧹 [SharedTaskStore] Cleared active task snapshot")
    }

    // MARK: - Intent Actions (run without opening the app)

    /// Increment snooze count and set `pendingSnooze = true`.
    /// Called by `SnoozeIntent.perform()` from the widget extension process.
    /// Returns the updated snapshot so the intent can push a Live Activity update.
    @discardableResult
    func snooze() -> ActiveTaskSnapshot? {
        guard var snapshot = load(), !snapshot.isCompleted else {
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
    @discardableResult
    func complete() -> ActiveTaskSnapshot? {
        guard var snapshot = load(), !snapshot.isCompleted else {
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
}

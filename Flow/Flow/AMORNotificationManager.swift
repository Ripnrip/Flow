/**
 * 🔔 AMORNotificationManager — iOS Notification Scheduling & Delivery
 *
 * "The voice of AMOR made audible. Where silent intelligence becomes a
 * gentle sound, a badge, a presence on the lock screen — never demanding,
 * always in service of the user's highest rhythm."
 *
 * v3.7.0 — Proactive Notification & Nudge Engine
 *
 * Translates AMORNudgeDescriptor → UNNotificationRequest.
 * Manages permissions, scheduling, deduplication, and badge counts.
 *
 * Architecture: ObservableObject (needs @MainActor for UNUserNotificationCenter).
 * The NudgeEngine is Foundation-only; this class is the iOS bridge.
 */

import Foundation
import UserNotifications

// MARK: - AMORNotificationManager

@MainActor
final class AMORNotificationManager: ObservableObject {

    // MARK: - Published State

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var pendingCount: Int = 0
    @Published var lastNudgeSummary: String = ""

    // MARK: - Constants

    private let center = UNUserNotificationCenter.current()

    // Notification identifiers for cancellation
    private let scheduledPrefix = "amor_scheduled_"
    private let immediatePrefix = "amor_immediate_"

    // MARK: - Permission Request

    /// Requests notification authorization. Should be called once on first launch.
    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [
                .alert, .badge, .sound, .timeSensitive
            ])
            await refreshAuthorizationStatus()
            if granted {
                print("[AMOR] Notification authorization granted")
            } else {
                print("[AMOR] Notification authorization denied")
            }
        } catch {
            print("[AMOR] Notification authorization error: \(error.localizedDescription)")
        }
    }

    /// Refreshes the current authorization status from the system.
    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        await MainActor.run {
            self.authorizationStatus = settings.authorizationStatus
        }
    }

    /// Returns true if notifications are authorized (or provisional).
    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    // MARK: - Process Nudge Result

    /// Processes a full nudge evaluation result — delivers immediate nudges
    /// and schedules recurring ones.
    func processNudgeResult(_ result: AMORNudgeResult) async {
        guard AMORNudgeEngine.isNotificationsEnabled() else { return }

        // 1. Cancel old scheduled nudges (we'll re-schedule fresh)
        cancelScheduled()

        // 2. Schedule recurring nudges (morning, evening, weekly)
        let scheduled = result.scheduledNudges
        for nudge in scheduled {
            if AMORNudgeEngine.isCategoryEnabled(nudge.category) {
                await schedule(nudge)
            }
        }

        // 3. Deliver immediate nudges (streak risk, cron failures, milestones)
        let immediate = result.allNudges.filter { $0.trigger == .immediate }
        let filtered = AMORNudgeEngine.filterEnabled(immediate)

        if !filtered.isEmpty {
            // Use digest if multiple alerts
            if filtered.count > 2, let digest = AMORNudgeEngine.generateDigest(from: result) {
                await deliver(digest)
            } else {
                for nudge in filtered.prefix(3) {
                    await deliver(nudge)
                }
            }
        }

        // 4. Update summary
        await MainActor.run {
            self.lastNudgeSummary = result.summary
        }

        // 5. Update pending count
        await refreshPendingCount()
    }

    // MARK: - Schedule Recurring

    /// Schedules a single recurring or one-time notification.
    func schedule(_ nudge: AMORNudgeDescriptor) async {
        let content = UNMutableNotificationContent()
        content.title = nudge.title
        content.body = nudge.body
        content.sound = nudge.priority == .critical ? .defaultCritical : .default
        content.categoryIdentifier = nudge.category.rawValue
        content.interruptionLevel = interruptionLevel(for: nudge.priority)
        content.userInfo = [
            "category": nudge.category.rawValue,
            "priority": nudge.priority.rawValue
        ]

        // Badge increment for critical alerts
        if nudge.priority == .critical {
            content.badge = NSNumber(value: 1)
        }

        let trigger: UNNotificationTrigger?

        switch nudge.trigger {
        case .immediate:
            // Fire in 2 seconds (minimum practical delay)
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)

        case .afterInterval(let interval):
            trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(interval, 1),
                repeats: false
            )

        case .daily(let hour, let minute):
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: true
            )

        case .weekly(let weekday, let hour, let minute):
            var components = DateComponents()
            components.weekday = weekday
            components.hour = hour
            components.minute = minute
            trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: true
            )
        }

        guard let trigger = trigger else { return }

        let identifier = scheduledPrefix + nudge.id
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            print("[AMOR] Failed to schedule notification \(nudge.id): \(error.localizedDescription)")
        }
    }

    // MARK: - Deliver Immediate

    /// Delivers an immediate notification (bypasses scheduling queue).
    func deliver(_ nudge: AMORNudgeDescriptor) async {
        let content = UNMutableNotificationContent()
        content.title = nudge.title
        content.body = nudge.body
        content.sound = nudge.priority == .critical ? .defaultCritical : .default
        content.categoryIdentifier = nudge.category.rawValue
        content.interruptionLevel = interruptionLevel(for: nudge.priority)
        content.userInfo = [
            "category": nudge.category.rawValue,
            "priority": nudge.priority.rawValue
        ]

        // Deduplicate: use the nudge ID + date as the request identifier
        let dateKey = AMORNudgeEngine.dateKey(.now)
        let identifier = immediatePrefix + nudge.id

        // Check if we already delivered this exact notification today
        let delivered = await center.deliveredNotifications()
        let alreadyDelivered = delivered.contains { notification in
            notification.request.identifier == identifier
        }
        if alreadyDelivered { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            print("[AMOR] Failed to deliver notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Cancellation

    /// Cancels all scheduled recurring notifications.
    func cancelScheduled() {
        center.getPendingNotificationRequests { requests in
            let scheduledIds = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(self.scheduledPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: scheduledIds)
        }
    }

    /// Cancels all immediate notifications from today.
    func cancelImmediate() {
        center.getPendingNotificationRequests { requests in
            let immediateIds = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(self.immediatePrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: immediateIds)
        }
    }

    /// Cancels ALL AMOR notifications (both pending and delivered).
    func cancelAll() {
        cancelScheduled()
        cancelImmediate()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Badge Management

    /// Clears the app badge.
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    /// Sets the badge to a specific count.
    func setBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }

    // MARK: - Status

    /// Refreshes the count of pending notifications.
    func refreshPendingCount() async {
        let requests = await center.pendingNotificationRequests()
        let amorCount = requests.filter { $0.identifier.hasPrefix(scheduledPrefix) }.count
        await MainActor.run {
            self.pendingCount = amorCount
        }
    }

    /// Returns a summary string for display.
    func statusSummary() -> String {
        if !AMORNudgeEngine.isNotificationsEnabled() {
            return "Notifications disabled"
        }
        if pendingCount > 0 {
            return "\(pendingCount) scheduled notification\(pendingCount == 1 ? "" : "s")"
        }
        return lastNudgeSummary.isEmpty ? "All clear" : lastNudgeSummary
    }

    // MARK: - Private Helpers

    private func interruptionLevel(for priority: AMORNudgePriority) -> UNNotificationInterruptionLevel {
        switch priority {
        case .critical: return .timeSensitive
        case .high:     return .active
        case .normal:   return .active
        case .low:      return .passive
        }
    }
}

// MARK: - Convenience: Full Nudge Cycle

extension AMORNotificationManager {

    /// Runs a complete nudge evaluation + delivery cycle.
    /// Call this on app foreground with fresh SwiftData context data.
    func runFullNudgeCycle(
        practices: [PracticeStreak],
        cronJobs: [CronJobHealth],
        sessions: [DailySession]
    ) async {
        let result = AMORNudgeEngine.evaluate(
            practices: practices,
            cronJobs: cronJobs,
            sessions: sessions
        )
        await processNudgeResult(result)
    }
}

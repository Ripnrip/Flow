/**
 * 🎭 The External Integration Service - The Great Synchronizer
 *
 * "A bridge between realms, where the mundane tasks of Calendar
 * and Reminders are inhaled and exhaled into the Flow,
 * gaining color, soul, and a place in the cosmic dance."
 *
 * - The Celestial Archivist of Focus Flow
 */

import Foundation
import EventKit
import OSLog
import SwiftData
import Observation

/// Sendable projection of an `EKReminder`, extracted inside EventKit's
/// completion handler so non-Sendable EventKit objects never cross actors.
private struct ReminderSnapshot: Sendable {
    let identifier: String
    let title: String
    let notes: String?
    let priority: Int
    let isCompleted: Bool
    let dueDate: Date?
}

@MainActor
@Observable
class ExternalIntegrationService {
    private var modelContext: ModelContext
    private let eventStore = EKEventStore()

    var isAuthorized = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        FlowLogger.lifecycle.info("🌐 ExternalIntegrationService initialised")
    }

    func requestPermissions() async {
        FlowLogger.network.info("🔍 Requesting access to Calendar & Reminders…")

        do {
            let calendarGranted = try await eventStore.requestFullAccessToEvents()
            let remindersGranted = try await eventStore.requestFullAccessToReminders()

            self.isAuthorized = calendarGranted && remindersGranted

            if isAuthorized {
                FlowLogger.network.info("🎉 Calendar & Reminders access granted")
            } else {
                FlowLogger.network.info("🌙 Calendar/Reminders access partially or fully denied")
            }
        } catch {
            FlowLogger.network.error("💥 Permission request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // 🌐 Inhale Calendar events into the Flow
    func inhaleCalendarEvents() async {
        guard isAuthorized else { return }
        FlowLogger.network.info("📅 Importing Calendar events…")

        let start = Date()
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else {
            FlowLogger.network.error("💥 Could not compute calendar window end date")
            return
        }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)

        for event in events {
            // 🎨 Check if already exists to avoid duplicates
            let title = event.title ?? "Untitled"
            let descriptor = FetchDescriptor<Item>(
                predicate: #Predicate<Item> { item in
                    item.title == title
                }
            )

            do {
                let existing = try modelContext.fetch(descriptor)
                if existing.isEmpty {
                    let style = autoPrioritize(event: event)
                    let newItem = Item(title: title, emoji: "sf:calendar", style: style, timestamp: event.startDate)
                    modelContext.insert(newItem)
                    FlowLogger.local.info("💎 Imported event into task: \(title, privacy: .public)")
                }
            } catch {
                FlowLogger.local.error("🌩️ Error checking existing events: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // 🌐 Inhale Reminders into the Flow
    func inhaleReminders() async {
        guard isAuthorized else { return }
        FlowLogger.network.info("📝 Importing Reminders…")

        let predicate = eventStore.predicateForReminders(in: nil)

        do {
            // Map `EKReminder` (not Sendable) to a Sendable snapshot inside the
            // callback so only Sendable values cross back to the main actor.
            let reminders: [ReminderSnapshot] = await withCheckedContinuation { continuation in
                eventStore.fetchReminders(matching: predicate) { ekReminders in
                    let mapped = (ekReminders ?? []).map { reminder in
                        ReminderSnapshot(
                            identifier: reminder.calendarItemIdentifier,
                            title: reminder.title ?? "Untitled",
                            notes: reminder.notes,
                            priority: reminder.priority,
                            isCompleted: reminder.isCompleted,
                            dueDate: reminder.dueDateComponents?.date
                        )
                    }
                    continuation.resume(returning: mapped)
                }
            }

            for reminder in reminders where !reminder.isCompleted {
                let title = reminder.title
                let reminderId = reminder.identifier
                let descriptor = FetchDescriptor<Item>(
                    predicate: #Predicate<Item> { item in
                        item.externalIdentifier == reminderId || item.title == title
                    }
                )

                let existing = try modelContext.fetch(descriptor)
                if let item = existing.first {
                    item.sourceLabel = "Reminders"
                    item.externalIdentifier = reminder.identifier
                    item.dueDate = reminder.dueDate
                    item.notesPreview = reminder.notes
                    item.timestamp = reminder.dueDate ?? item.timestamp
                } else {
                    let newItem = Item(
                        title: title,
                        emoji: reminderEmoji(for: reminder),
                        style: autoPrioritize(reminder: reminder),
                        timestamp: reminder.dueDate ?? .now
                    )
                    newItem.sourceLabel = "Reminders"
                    newItem.externalIdentifier = reminder.identifier
                    newItem.dueDate = reminder.dueDate
                    newItem.notesPreview = reminder.notes
                    modelContext.insert(newItem)
                    FlowLogger.local.info("💎 Imported reminder into immersive island queue: \(title, privacy: .public)")
                }
            }
        } catch {
            FlowLogger.local.error("💥 Reminders import failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // 🎭 Auto-prioritization Logic - Mapping event metadata to TaskStyles
    private func autoPrioritize(event: EKEvent) -> TaskStyle {
        let title = (event.title ?? "").lowercased()

        if title.contains("meeting") || title.contains("call") || title.contains("sync") {
            return .sleekModern
        } else if title.contains("workout") || title.contains("gym") || title.contains("run") {
            return .volcanicFlow
        } else if title.contains("meditate") || title.contains("yoga") || title.contains("breath") {
            return .zenFocus
        } else if title.contains("deadline") || title.contains("due") || title.contains("urgent") {
            return .neoBrutalism
        } else if title.contains("party") || title.contains("celebrate") || title.contains("dinner") {
            return .cosmicNebula
        }

        return .sleekModern
    }

    private func autoPrioritize(reminder: ReminderSnapshot) -> TaskStyle {
        let title = reminder.title.lowercased()
        let notes = (reminder.notes ?? "").lowercased()
        let text = title + " " + notes

        if reminder.priority > 0 && reminder.priority <= 3 { return .volcanicFlow }
        if text.contains("meditate") || text.contains("pray") || text.contains("gita") { return .zenFocus }
        if text.contains("monograph") || text.contains("read") || text.contains("study") { return .magicalScroll }
        if text.contains("gym") || text.contains("workout") || text.contains("exercise") { return .questMode }
        if text.contains("call") || text.contains("message") || text.contains("follow up") { return .courierPrime }
        if reminder.dueDate != nil { return .sunsetGlow }
        return .zenFocus
    }

    private func reminderEmoji(for reminder: ReminderSnapshot) -> String {
        let text = (reminder.title + " " + (reminder.notes ?? "")).lowercased()
        if text.contains("monograph") || text.contains("read") || text.contains("study") { return "📚" }
        if text.contains("gym") || text.contains("workout") || text.contains("exercise") { return "💪" }
        if text.contains("call") || text.contains("message") { return "📬" }
        if text.contains("pray") || text.contains("meditate") { return "🧘" }
        return "✅"
    }
}


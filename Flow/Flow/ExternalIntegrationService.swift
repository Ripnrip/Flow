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
    let title: String
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
            // A plain `for` loop avoids a `.map` closure inheriting `@MainActor`
            // isolation and then running on EventKit's background queue.
            let reminders: [ReminderSnapshot] = await withCheckedContinuation { continuation in
                eventStore.fetchReminders(matching: predicate) { ekReminders in
                    var mapped: [ReminderSnapshot] = []
                    for reminder in ekReminders ?? [] {
                        mapped.append(ReminderSnapshot(
                            title: reminder.title ?? "Untitled",
                            isCompleted: reminder.isCompleted,
                            dueDate: reminder.dueDateComponents?.date
                        ))
                    }
                    continuation.resume(returning: mapped)
                }
            }

            for reminder in reminders where !reminder.isCompleted {
                let title = reminder.title
                let descriptor = FetchDescriptor<Item>(
                    predicate: #Predicate<Item> { item in
                        item.title == title
                    }
                )

                let existing = try modelContext.fetch(descriptor)
                if existing.isEmpty {
                    let newItem = Item(title: title, emoji: "sf:checklist", style: .zenFocus, timestamp: reminder.dueDate ?? .now)
                    modelContext.insert(newItem)
                    FlowLogger.local.info("💎 Imported reminder into task: \(title, privacy: .public)")
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
}


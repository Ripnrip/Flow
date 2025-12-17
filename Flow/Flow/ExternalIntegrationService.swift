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
import SwiftData
import Observation

@MainActor
@Observable
class ExternalIntegrationService {
    private var modelContext: ModelContext
    private let eventStore = EKEventStore()
    
    var isAuthorized = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("🌐 ✨ EXTERNAL INTEGRATION SERVICE AWAKENS!")
    }
    
    func requestPermissions() async {
        print("🔍 🧙‍♂️ REQUESTING ACCESS TO EXTERNAL REALMS...")
        
        do {
            let calendarGranted = try await eventStore.requestFullAccessToEvents()
            let remindersGranted = try await eventStore.requestFullAccessToReminders()
            
            self.isAuthorized = calendarGranted && remindersGranted
            
            if isAuthorized {
                print("🎉 ✨ ACCESS GRANTED BY THE COSMOS!")
            } else {
                print("🌙 ⚠️ Access partially or fully denied by the seeker.")
            }
        } catch {
            print("💥 😭 PERMISSION RITUAL HALTED: \(error.localizedDescription)")
        }
    }
    
    // 🌐 Inhale Calendar events into the Flow
    func inhaleCalendarEvents() async {
        guard isAuthorized else { return }
        print("📅 ✨ COMMENCING CALENDAR INHALATION...")
        
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            print("✨ Found event: \(event.title ?? "Untitled")")
            // 🎨 Check if already exists to avoid duplicates
            let title = event.title ?? "Untitled"
            let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.title == title })
            
            do {
                let existing = try modelContext.fetch(descriptor)
                if existing.isEmpty {
                    let style = autoPrioritize(event: event)
                    let newItem = Item(title: title, emoji: "📅", style: style, timestamp: event.startDate)
                    modelContext.insert(newItem)
                    print("💎 Crystallized event into task: \(title)")
                }
            } catch {
                print("🌩️ Error checking existing events: \(error)")
            }
        }
    }
    
    // 🌐 Inhale Reminders into the Flow
    func inhaleReminders() async {
        guard isAuthorized else { return }
        print("📝 ✨ COMMENCING REMINDERS INHALATION...")
        
        let predicate = eventStore.predicateForReminders(in: nil)
        
        do {
            let reminders = try await eventStore.reminders(matching: predicate)
            for reminder in reminders where !reminder.isCompleted {
                let title = reminder.title ?? "Untitled"
                let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.title == title })
                
                let existing = try modelContext.fetch(descriptor)
                if existing.isEmpty {
                    let newItem = Item(title: title, emoji: "📝", style: .zenFocus, timestamp: reminder.dueDateComponents?.date ?? .now)
                    modelContext.insert(newItem)
                    print("💎 Crystallized reminder into task: \(title)")
                }
            }
        } catch {
            print("💥 😭 REMINDERS INHALATION FAILED: \(error)")
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


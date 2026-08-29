/**
 * 🧘 AMORService — Service Layer for AMOR Features
 *
 * "The quiet steward of daily rhythms, ensuring practices are seeded,
 * sessions are tracked, and the pulse of automation is ever-monitored."
 */

import Foundation
import SwiftData

/// Service for managing AMOR features — practices, sessions, and cron health.
@Observable
final class AMORService {
    private let modelContext: ModelContext
    
    /// Default practices to seed for new users
    static let defaultPractices: [(name: String, goal: String)] = [
        ("Gita", "daily"),
        ("Gym", "daily"),
        ("Meditation", "daily"),
        ("Journaling", "3x per week"),
        ("Reading", "daily")
    ]
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Practice Management
    
    /// Seed default practices if none exist
    func seedDefaultPracticesIfNeeded() {
        do {
            let existingCount = try modelContext.fetchCount(FetchDescriptor<PracticeStreak>())
            guard existingCount == 0 else { return }
            
            for practice in Self.defaultPractices {
                let newPractice = PracticeStreak(
                    practiceName: practice.name,
                    goal: practice.goal
                )
                modelContext.insert(newPractice)
            }
            
            try modelContext.save()
        } catch {
            // Silently fail
        }
    }
    
    // v4.7.0: getOrCreatePractice removed — dead since forging (zero call sites).
    // v4.8.0: logSession removed — zero call sites. Session writes flow through
    // the UI sheet (AMORView.saveSession, direct modelContext since v3.3.0) and
    // the intent reconciler (AMORIntentReconciler.logSession). A third path
    // that nothing calls was a lying API surface, same class as the v4.7.0 corpses.
}
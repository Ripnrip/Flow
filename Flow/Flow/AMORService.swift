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
    
    // MARK: - Session Management
    
    /// Log a new work session
    func logSession(
        title: String,
        durationMinutes: Int,
        notes: String = "",
        toolsUsed: String = "",
        skillsLearned: String = "",
        mood: String = "neutral",
        completedTasks: Int = 0
    ) -> DailySession? {
        do {
            let session = DailySession(
                date: .now,
                title: title,
                notes: notes,
                durationMinutes: durationMinutes,
                toolsUsed: toolsUsed,
                skillsLearned: skillsLearned,
                mood: mood,
                completedTasks: completedTasks
            )
            modelContext.insert(session)
            try modelContext.save()
            return session
        } catch {
            return nil
        }
    }
    
    // v4.7.0: getTodaysSessions removed — only caller was the dead updateDailySummary.
}
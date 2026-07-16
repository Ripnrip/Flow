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
    
    /// Get or create a practice by name
    func getOrCreatePractice(name: String, goal: String = "daily") -> PracticeStreak? {
        do {
            let descriptor = FetchDescriptor<PracticeStreak>(
                predicate: #Predicate { $0.practiceName == name }
            )
            let existing = try modelContext.fetch(descriptor).first
            
            if let existing = existing {
                return existing
            } else {
                let newPractice = PracticeStreak(
                    practiceName: name,
                    goal: goal
                )
                modelContext.insert(newPractice)
                try modelContext.save()
                return newPractice
            }
        } catch {
            return nil
        }
    }
    
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
    
    /// Get today's sessions
    func getTodaysSessions() -> [DailySession] {
        do {
            let descriptor = FetchDescriptor<DailySession>()
            let all = try modelContext.fetch(descriptor)
            let today = Date()
            let startOfDay = Calendar.current.startOfDay(for: today)
            return all.filter { $0.date >= startOfDay }
        } catch {
            return []
        }
    }
    
    // MARK: - Cron Job Management
    
    /// Register or update a cron job
    func registerCronJob(
        name: String,
        schedule: String,
        isEnabled: Bool = true
    ) -> CronJobHealth? {
        do {
            let descriptor = FetchDescriptor<CronJobHealth>(
                predicate: #Predicate<CronJobHealth> { $0.jobName == name }
            )
            let existing = try modelContext.fetch(descriptor).first
            
            if let existing = existing {
                existing.schedule = schedule
                existing.isEnabled = isEnabled
                try modelContext.save()
                return existing
            } else {
                let job = CronJobHealth(
                    jobName: name,
                    schedule: schedule,
                    isEnabled: isEnabled
                )
                modelContext.insert(job)
                try modelContext.save()
                return job
            }
        } catch {
            return nil
        }
    }
    
    /// Record a successful cron run
    func recordCronSuccess(jobName: String) {
        do {
            let descriptor = FetchDescriptor<CronJobHealth>(
                predicate: #Predicate<CronJobHealth> { $0.jobName == jobName }
            )
            guard let job = try modelContext.fetch(descriptor).first else { return }
            job.recordSuccess()
            try modelContext.save()
        } catch {
            // Silent
        }
    }
    
    /// Record a failed cron run
    func recordCronFailure(jobName: String, error errorMessage: String?) {
        do {
            let descriptor = FetchDescriptor<CronJobHealth>(
                predicate: #Predicate<CronJobHealth> { $0.jobName == jobName }
            )
            guard let job = try modelContext.fetch(descriptor).first else { return }
            job.recordFailure(error: errorMessage)
            try modelContext.save()
        } catch {
            // Silent
        }
    }
    
    // MARK: - Daily Summary
    
    /// Create or update today's summary
    func updateDailySummary(
        mood: String = "neutral",
        notes: String = ""
    ) -> DailySummary? {
        do {
            let today = Date()
            let startOfDay = Calendar.current.startOfDay(for: today)
            let descriptor = FetchDescriptor<DailySummary>(
                predicate: #Predicate<DailySummary> { $0.date >= startOfDay }
            )
            let existing = try modelContext.fetch(descriptor).first
            
            if let existing = existing {
                existing.mood = mood
                existing.notes = notes
                try modelContext.save()
                return existing
            } else {
                let sessions = getTodaysSessions()
                let summary = DailySummary(
                    date: today,
                    sessionCount: sessions.count,
                    totalFocusMinutes: sessions.reduce(0) { $0 + $1.durationMinutes },
                    tasksCompleted: sessions.reduce(0) { $0 + $1.completedTasks },
                    mood: mood,
                    notes: notes
                )
                modelContext.insert(summary)
                try modelContext.save()
                return summary
            }
        } catch {
            return nil
        }
    }
    
    // MARK: - Second Brain Integration
    
    /// Link a second brain note to today
    func linkSecondBrainNote(
        notePath: String,
        summary: String,
        tags: String = ""
    ) -> SecondBrainEntry? {
        do {
            let entry = SecondBrainEntry(
                notePath: notePath,
                summary: summary,
                tags: tags
            )
            modelContext.insert(entry)
            try modelContext.save()
            return entry
        } catch {
            return nil
        }
    }
}
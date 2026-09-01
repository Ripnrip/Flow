//
//  AMORGroundTruthSyncer.swift
//  Flow — AMOR v4.0.0
//
//  SwiftData upsert layer for the Ground Truth engine.
//  Runs on every scenePhase .active (idempotent):
//    • Gita   ← ~/.hermes/logs/gita_progress.json
//    • Gym    ← ~/.hermes/logs/gym_selfie_progress.json
//    • Dumps  ← ~/wiki/raw/daily-summaries/ (read-only, for the card)
//
//  SYNC LAW — positive evidence only, forward-only:
//    Ground truth can RAISE a streak, never lower one. An empty/absent
//    source file is not proof of absence — it never deletes or zeroes
//    manual entries. Repeated runs converge (max() semantics).
//

import Foundation
import SwiftData

@MainActor
enum AMORGroundTruthSyncer {

    static let lastSyncKey = "amor.groundtruth.lastSyncAt"
    static let lastResultKey = "amor.groundtruth.lastResult"

    // MARK: - Entry point

    static func sync(into modelContext: ModelContext, vaultPath: String? = nil) -> AMORGroundTruthSyncResult {
        var result = AMORGroundTruthSyncResult()

        // ── 1. Gita ────────────────────────────────────────────────
        // v5.0.0 MORTAL STREAKS: a readable ledger is TRUTH — it SETs the
        // streak (it can lower it). Only an absent/unreadable file never
        // touches anything. The old max() armor made the streak immortal:
        // one imported day could never be un-imported. Evidence can raise
        // AND lower; silence changes nothing.
        if let gita = AMORGroundTruthEngine.readGitaProgress() {
            let streakDays = AMORGroundTruthEngine.gitaStreakDays(from: gita)
            result.gitaDaysCompleted = gita.daysCompleted
            result.gitaLastCompletedDate = gita.lastCompleted?.date
            result.gitaCurrentPosition = "Ch \(gita.currentChapter) · V \(gita.currentVerse)"

            if let lcDate = gita.lastCompleted?.date,
               let completedDay = parseLocalDay(lcDate) {
                if let practice = upsertPractice(named: "Gita", into: modelContext) {
                    practice.currentStreak = streakDays
                    practice.totalCompletions = max(practice.totalCompletions, gita.daysCompleted)
                    practice.longestStreak = max(practice.longestStreak, streakDays)
                    if let existing = practice.lastCompletedDate {
                        if completedDay > existing { practice.lastCompletedDate = completedDay }
                    } else {
                        practice.lastCompletedDate = completedDay
                    }
                    result.gitaStreakUpdated = true
                }
            }
        } else {
            result.readError = "gita_progress.json unreadable"
        }

        // ── 2. Gym (positive evidence only) ────────────────────────
        if let gym = AMORGroundTruthEngine.gymProgress() {
            let recent = AMORGroundTruthEngine.gymEvidenceDates(daysBack: 14)
            result.gymEvidenceDates = recent
            if !gym.dates.isEmpty, gym.streak > 0,
               let lastDateStr = gym.dates.sorted(by: >).first,
               let lastDay = parseLocalDay(lastDateStr) {
                if let practice = upsertPractice(named: "Gym", into: modelContext) {
                    practice.currentStreak = max(practice.currentStreak, gym.streak)
                    practice.totalCompletions = max(practice.totalCompletions, gym.total)
                    practice.longestStreak = max(practice.longestStreak, gym.streak)
                    if let existing = practice.lastCompletedDate {
                        if lastDay > existing { practice.lastCompletedDate = lastDay }
                    } else {
                        practice.lastCompletedDate = lastDay
                    }
                }
            }
        }

        // ── 2.5 Meditation (v4.1.0 — positive evidence only) ──────
        if let meditation = AMORGroundTruthEngine.meditationProgress() {
            let recent = AMORGroundTruthEngine.meditationEvidenceDates(daysBack: 14)
            result.meditationEvidenceDates = recent
            if !meditation.dates.isEmpty, meditation.streak > 0,
               let lastDateStr = meditation.dates.sorted(by: >).first,
               let lastDay = parseLocalDay(lastDateStr) {
                if let practice = upsertPractice(named: "Meditation", into: modelContext) {
                    practice.currentStreak = max(practice.currentStreak, meditation.streak)
                    practice.totalCompletions = max(practice.totalCompletions, meditation.total)
                    practice.longestStreak = max(practice.longestStreak, meditation.streak)
                    if let existing = practice.lastCompletedDate {
                        if lastDay > existing { practice.lastCompletedDate = lastDay }
                    } else {
                        practice.lastCompletedDate = lastDay
                    }
                }
            }
        }

        // ── 3. EOD dumps (read-only digest for the card) ───────────
        let dumps = AMORGroundTruthEngine.readRecentDumps(daysBack: 7, vaultPath: vaultPath)
        result.dumpDaysIngested = dumps.filter { $0.date != .distantPast }.count
        result.dumpSessionsFound = dumps.reduce(0) { $0 + $1.sessionsToday }
        var tools = Set<String>()
        var skills = Set<String>()
        for dump in dumps {
            tools.formUnion(dump.tools)
            skills.formUnion(dump.skillsTouched)
        }
        result.dumpToolsDiscovered = tools.sorted()
        result.dumpSkillsDiscovered = skills.sorted()
        if let newest = dumps.first(where: { $0.date != .distantPast }) {
            result.cronOkCount = newest.cronOkCount
            result.cronErrorCount = newest.cronErrorCount
        }

        // ── 4. Persist (MANDATORY save — data-loss prevention law) ─
        try? modelContext.save()

        // ── 5. Record sync timestamp + result for the card ─────────
        let defaults = UserDefaults.standard
        defaults.set(Date().timeIntervalSince1970, forKey: lastSyncKey)
        if let encoded = try? JSONEncoder().encode(result) {
            defaults.set(encoded, forKey: lastResultKey)
        }

        return result
    }

    // MARK: - Helpers

    /// Fetch-or-create a PracticeStreak by name (mirrors AMORService pattern,
    /// kept local so this syncer has no service dependency).
    private static func upsertPractice(named name: String, into modelContext: ModelContext) -> PracticeStreak? {
        let descriptor = FetchDescriptor<PracticeStreak>(
            predicate: #Predicate { $0.practiceName == name }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let created = PracticeStreak(practiceName: name, goal: "daily")
        modelContext.insert(created)
        return created
    }

    /// Parses a local yyyy-MM-dd string into a midday-anchored Date
    /// (midday avoids any midnight/DST edge in comparisons).
    private static func parseLocalDay(_ s: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        guard let midnight = formatter.date(from: s) else { return nil }
        return Calendar.current.date(byAdding: .hour, value: 12, to: midnight)
    }

    /// Loads the last sync result (for the card, without re-syncing).
    static func loadLastResult() -> AMORGroundTruthSyncResult? {
        guard let data = UserDefaults.standard.data(forKey: lastResultKey) else { return nil }
        return try? JSONDecoder().decode(AMORGroundTruthSyncResult.self, from: data)
    }

    static func lastSyncDate() -> Date? {
        let ts = UserDefaults.standard.double(forKey: lastSyncKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }
}

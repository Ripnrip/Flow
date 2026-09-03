//
//  AMORAlibiEngine.swift
//  Flow — AMOR v5.1.0
//
//  ┌─────────────────────────────────────────────────────────────┐
//  │        THE ALIBI — v5.1.0 "THE PIPE BROKE, NOT YOU"         │
//  └─────────────────────────────────────────────────────────────┘
//
//  MISSION: v5.0.0 made streaks mortal — dates are truth, evidence
//  can lower, and a break finally SHOWS. Two days later reality
//  delivered the corollary nobody had written a law for: the Gita
//  ledger's last breath was Sept 1 because the gateway's GIL
//  pressure strangled the event loop (64 watchdog kills in 3 days,
//  150+ executions reaped to `unknown` — BOTH Gita delivery crons
//  at BOTH slots on BOTH days). The mortal streak read the missing
//  dates and rendered: 💔 "Streak broken. You hit 9 days before.
//  Begin again." — a devotion shamed for a murder the
//  infrastructure committed.
//
//  THE LAW (three clauses):
//
//    1. AN ALIBI EXCUSES, IT NEVER RESURRECTS. The streak number
//       stays exactly what the dates say (often 0). Only the
//       ATTRIBUTION changes: "the pipe broke, not the practice."
//       Honesty of arithmetic, honesty of blame.
//
//    2. EVIDENCE, NOT SYMPATHY. A missed day is excused ONLY when
//       its delivery jobs left broken attempts (failed OR reaped/
//       unknown) inside that local day AND no delivery completed.
//       A day with a completed run that didn't record is NOT
//       excused — that's a ledger-discipline disease, a different
//       card. A day with no attempts at all is not excused either.
//
//    3. PARTIAL IS PARTIAL. If the pipe explains some missed days
//       but not others, the verdict is .partial — the app never
//       launders a genuine lapse into an outage.
//
//  Attribution window: the TRAILING missed days only (the days
//  after the last evidence, up to today), capped at 14 — history's
//  interior gaps (e.g. a pruned Aug 23) are the syncer's domain,
//  not the alibi's.
//
//  Architecture: Foundation-only — type-checks with swiftc (CLT SDK)
//  and live-fire fixture-testable. Engine reasons over distilled
//  execution events; it never touches SQLite itself (the ledger
//  read stays in AMORExecutionTruth, v4.8.0 law).
//

import Foundation

// MARK: - Verdict

enum AMORAlibiVerdict: String {
    /// Every trailing missed day carries broken-delivery evidence.
    case excused
    /// The pipe explains some, but not all, of the trailing missed days.
    case partial
}

// MARK: - Execution Event (distilled, engine-shaped)

/// One delivery-relevant row from the executions ledger.
/// `status` is the ledger's own vocabulary: "completed" | "failed" |
/// "unknown" (reaped mid-run by a scheduler restart).
struct AMORAlibiExecution {
    let jobID: String
    let date: Date
    let status: String
}

// MARK: - The Alibi

/// Cause attribution for one practice's trailing break.
/// presence == the pipe left evidence; absence == the break stands
/// unattributed (and the v5.0.0 mortal message is correct as-is).
struct AMORAlibi: Identifiable {
    let id = UUID()
    let practiceName: String
    let verdict: AMORAlibiVerdict
    /// Trailing missed days (after last evidence, through today), capped at 14.
    let missedDayCount: Int
    /// The subset of missed days where delivery demonstrably broke.
    let excusedDays: [Date]

    /// "Sep 2–3" or "Sep 2" — for messages and cards.
    var excusedSpanText: String {
        guard let first = excusedDays.first, let last = excusedDays.last else { return "" }
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        df.locale = Locale(identifier: "en_US_POSIX")
        if Calendar.current.isDate(first, inSameDayAs: last) {
            return df.string(from: first)
        }
        return "\(df.string(from: first))–\(df.string(from: last))"
    }

    var headline: String {
        switch verdict {
        case .excused:
            return "🔌 \(practiceName): delivery pipeline failed on all \(missedDayCount) missed day\(missedDayCount == 1 ? "" : "s") — the pipe broke, not the practice."
        case .partial:
            return "🔌 \(practiceName): pipeline failed on \(excusedDays.count) of \(missedDayCount) missed day\(missedDayCount == 1 ? "" : "s") — partly the pipe, partly not."
        }
    }

    var detail: String {
        "Broken delivery attempts on: \(excusedSpanText). The streak number stays honest — only the blame moves."
    }
}

// MARK: - Engine

enum AMORAlibiEngine {

    /// Practice → the Hermes cron job IDs that DELIVER its evidence.
    /// Gita has two pipes (06:30 ET audio + 12:00 UTC text); gym and
    /// meditation both ride the 5 PM check-in cron.
    static let deliveryJobs: [String: [String]] = [
        "Gita": ["0b863354b307", "21831be3cadc"],
        "Gym": ["d4a6e6e4270b"],
        "Meditation": ["d4a6e6e4270b"],
    ]

    /// Attribution horizon — trailing missed days beyond this are
    /// history's interior, not the alibi's jurisdiction.
    static let attributionHorizonDays = 14

    /// Distills the executions ledger into engine-shaped events for
    /// `alibisFor` — kept public so the harness fixture path can
    /// verify the distillation itself.
    static func distillInput(executions: [AMORAlibiExecution], practiceName: String) -> [AMORAlibiExecution] {
        let jobIDs = Set(deliveryJobs[practiceName] ?? [])
        guard !jobIDs.isEmpty else { return [] }
        return executions.filter { jobIDs.contains($0.jobID) }
    }

    /// THE LAW. Attributes a practice's trailing missed days to
    /// delivery-pipeline failures when — and only when — the
    /// executions ledger carries the evidence.
    ///
    /// - Parameters:
    ///   - practiceName: e.g. "Gita" (must appear in `deliveryJobs`).
    ///   - lastEvidenceDay: the practice's last completion day
    ///     (midday-anchored is fine; startOfDay is taken).
    ///   - referenceDate: "now" (injectable for fixtures).
    ///   - executions: distilled ledger events (any jobs — filtered here).
    /// - Returns: nil when there is nothing to excuse (no trailing
    ///   miss, no delivery jobs mapped, or no broken-pipe evidence).
    static func attributed(practiceName: String,
                           lastEvidenceDay: Date?,
                           referenceDate: Date = .now,
                           executions: [AMORAlibiExecution]) -> AMORAlibi? {
        // No evidence ever → notStarted, not a break. No alibi.
        guard let lastEvidence = lastEvidenceDay else { return nil }
        let jobIDs = Set(deliveryJobs[practiceName] ?? [])
        guard !jobIDs.isEmpty else { return nil }

        let cal = Calendar.current
        let today = cal.startOfDay(for: referenceDate)

        // Trailing missed days: (lastEvidence, today], capped.
        var missed: [Date] = []
        var cursor = cal.startOfDay(for: lastEvidence)
        while missed.count < attributionHorizonDays {
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            if cursor > today { break }
            missed.append(cursor)
        }
        // Evidence today/yesterday → nothing trailing to attribute.
        guard !missed.isEmpty else { return nil }

        let relevant = executions.filter { jobIDs.contains($0.jobID) }

        var excused: [Date] = []
        for day in missed {
            guard let windowEnd = cal.date(byAdding: .day, value: 1, to: day) else { continue }
            let inWindow = relevant.filter { $0.date >= day && $0.date < windowEnd }
            // LAW 2: broken attempts present, and nothing delivered.
            let pipeBroke = inWindow.contains { $0.status == "unknown" || $0.status == "failed" }
            let delivered = inWindow.contains { $0.status == "completed" }
            if pipeBroke && !delivered {
                excused.append(day)
            }
        }
        // LAW 3: no evidence → the break stands unattributed.
        guard !excused.isEmpty else { return nil }

        let verdict: AMORAlibiVerdict = (excused.count == missed.count) ? .excused : .partial
        return AMORAlibi(practiceName: practiceName,
                         verdict: verdict,
                         missedDayCount: missed.count,
                         excusedDays: excused)
    }

    // MARK: - View-layer convenience (one ledger read, many practices)

    /// Reads the real executions ledger once and attributes every
    /// given practice. Used by the Ground Truth card, the recovery
    /// desk, and the weekly review — cheap (one 7d sqlite read).
    static func alibisFor(_ practices: [(name: String, lastEvidence: Date?)],
                          hermesHome: URL) -> [String: AMORAlibi] {
        // Only read the ledger if at least one practice is mapped.
        guard practices.contains(where: { deliveryJobs[$0.name] != nil }) else { return [:] }
        let truth = AMORExecutionTruth.read(hermesHome: hermesHome)
        guard truth.isAvailable else { return [:] }

        var out: [String: AMORAlibi] = [:]
        for practice in practices {
            if let alibi = attributed(practiceName: practice.name,
                                      lastEvidenceDay: practice.lastEvidence,
                                      executions: truth.alibiInputs) {
                out[practice.name] = alibi
            }
        }
        return out
    }
}

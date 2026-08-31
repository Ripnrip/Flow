//
//  AMORStormSentinel.swift
//  Flow — AMOR v4.9.0
//
//  ┌─────────────────────────────────────────────────────────────┐
//  │            STORM SENTINEL — v4.9.0                          │
//  └─────────────────────────────────────────────────────────────┘
//
//  MISSION: v4.8.0 gave every job its own failure memory — and that
//  is exactly how one provider outage gets rendered as THREE orange
//  chips on THREE rows, implying three broken things when the truth
//  was ONE storm that has already passed. Failures do not happen in
//  isolation; they happen in weather.
//
//  Live-proven shape (Aug 30–31 2026): provider unreachable for a
//  night → 7 failures chained across 3 jobs at 2h cadence, all
//  healed by morning. The per-job chips kept crying long after the
//  sky cleared.
//
//  LAW OF THE STORM: failure events chained in time (≤ 2.5h apart)
//  belong to ONE incident, whichever job they landed on. An incident
//  touching ≥ 2 jobs is a STORM — shared cause (provider, network,
//  host) — and gets one banner, not N chips.
//
//  VERDICT LAW (anti-wolf, v4.4.0 lineage): an incident is ACTIVE
//  only while a known member job has shown no completed-or-running
//  attempt since the incident ended AND the last event is younger
//  than a day. Everything else is history, rendered neutral. A job
//  that was deleted mid-storm cannot hold an incident hostage; a
//  quiet sky older than 24h is resolved no matter what.
//
//  Pure Foundation. No DB, no SwiftUI — clustering logic only; the
//  ledger read stays in AMORExecutionTruth, which feeds this engine.
//

import Foundation

// MARK: - Failure Event

/// One `failed` row from the executions ledger, distilled for clustering.
struct AMORFailureEvent {
    let jobID: String
    let date: Date
    let error: String?
}

// MARK: - Incident

/// A fused group of failure events chained in time — one storm.
struct AMORIncident: Identifiable {
    let id = UUID()
    /// First failure event in the chain.
    let start: Date
    /// Last failure event in the chain.
    let end: Date
    /// All events, oldest first.
    let events: [AMORFailureEvent]

    /// Jobs that took at least one failure during the incident.
    var jobIDs: Set<String> { Set(events.map { $0.jobID }) }
    var failureCount: Int { events.count }

    /// A storm touches multiple jobs → shared cause (provider-class).
    /// A single-job incident is an isolated flake — the per-job chip
    /// already tells that story; the sentinel does not duplicate it.
    var isStorm: Bool { jobIDs.count > 1 }

    /// True when every KNOWN member job has banked a completed or
    /// running attempt after the incident ended — the sky cleared.
    let recovered: Bool

    /// True while the incident may still be in progress.
    var isActive: Bool { !recovered && Date().timeIntervalSince(end) < Self.activeThresholdSeconds }

    /// The most recent error text — the actionable headline.
    var headlineError: String? {
        events.last?.error.map { String($0.prefix(120)) }
    }

    /// Compact human span: "Aug 30 8:00 PM → Aug 31 6:00 AM".
    var spanText: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return "\(f.string(from: start)) → \(f.string(from: end))"
    }

    /// One-line reflective summary for the dashboard.
    var summaryText: String {
        let who = isStorm ? "\(jobIDs.count) jobs" : "1 job"
        return "\(failureCount) failures across \(who) · \(spanText)"
    }

    /// Recovery evidence must arrive within a day of the last event,
    /// or the quiet sky itself is the verdict (anti-wolf).
    static let activeThresholdSeconds: Double = 24 * 3600
}

// MARK: - Storm Sentinel

/// Clusters ledger failure events into time-chained incidents.
enum AMORStormSentinel {

    /// Events chained by gaps no larger than this share one incident.
    /// 2.5h comfortably chains 2h-cadence cron failures (live-proven
    /// overnight-outage shape) without fusing unrelated days.
    static let chainGapSeconds: Double = 2.5 * 3600

    /// Distills failure events into incidents.
    ///
    /// - Parameters:
    ///   - events: failed rows from the ledger (7d window is natural).
    ///   - lastNonFailureByJob: per job, the newest completed/running/
    ///     claimed attempt date — recovery evidence. A *failed* attempt
    ///     is NOT recovery.
    ///   - knownJobIDs: jobs present in jobs.json. Failures from jobs
    ///     that no longer exist still shape the incident's history but
    ///     cannot keep it ACTIVE (a deleted job never "recovers").
    ///   - now: injection point for deterministic fixtures.
    static func cluster(events: [AMORFailureEvent],
                        lastNonFailureByJob: [String: Date],
                        knownJobIDs: Set<String>,
                        now: Date = Date()) -> [AMORIncident] {
        guard !events.isEmpty else { return [] }

        // 1. Chain events ≤ chainGap apart into raw groups.
        let sorted = events.sorted { $0.date < $1.date }
        var groups: [[AMORFailureEvent]] = []
        var current: [AMORFailureEvent] = [sorted[0]]
        for event in sorted.dropFirst() {
            if event.date.timeIntervalSince(current[current.count - 1].date) <= chainGapSeconds {
                current.append(event)
            } else {
                groups.append(current)
                current = [event]
            }
        }
        groups.append(current)

        // 2. Verdict each group.
        return groups.map { group in
            let end = group[group.count - 1].date
            let members = Set(group.map { $0.jobID })
            let knownMembers = members.filter { knownJobIDs.contains($0) }
            // ONE-WITNESS LAW: a storm is shared-cause by definition —
            // provider, network, host. If ANY known member ran clean
            // after the last bolt, the shared cause is gone and the
            // storm is over for all of them. Requiring every member to
            // recover is per-job thinking again — the disease v4.9.0
            // cures. A member still failing afterward starts its OWN
            // chain, and lone chains stay on their job's row chip.
            let anyWitnessFlewAfterEnd = knownMembers.contains { jobID in
                guard let since = lastNonFailureByJob[jobID] else { return false }
                return since > end
            }
            // Quiet-sky law: no recovery evidence but nothing failed for
            // a full day → the incident is over whether or not any
            // witness reported in. History, not alarm.
            let quiet = now.timeIntervalSince(end) >= AMORIncident.activeThresholdSeconds
            let allMembersGone = knownMembers.isEmpty
            let recovered = anyWitnessFlewAfterEnd || quiet || allMembersGone
            return AMORIncident(start: group[0].date, end: end, events: group, recovered: recovered)
        }
        .sorted { $0.start > $1.start }
    }
}

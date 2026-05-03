/**
 * 🧠 TaskStyleSuggester — On-Device Style Intelligence
 *
 * Uses Apple's Foundation Models (iOS 26 / macOS 26) to suggest the most
 * fitting TaskStyle for a given task title. Falls back to a fast keyword-
 * based heuristic on earlier OS versions or when the model is unavailable.
 *
 * Usage
 * ─────
 *   let style = await TaskStyleSuggester.shared.suggest(for: "Review pull requests")
 *   // → .neoBrutalism, .cyberpunk, or similar
 *
 * Architecture
 * ─────────────
 *   • `actor` isolation — safe to call from any context.
 *   • Lazy session creation — model loaded on first call, not at app launch.
 *   • `@Generable StylePrediction` — structured output constrains the model
 *     to valid style names, eliminating post-processing hallucinations.
 *   • Fallback chain: Foundation Models → keyword heuristic → .sleekModern
 */

import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Structured Output Schema

/// Structured output type that constrains Foundation Models to valid responses.
#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct StylePrediction {
    /// The raw value of a TaskStyle case (e.g. "Neo-Brutalism").
    @Guide(description: "Raw value of the best-matching TaskStyle for this task.")
    var styleName: String

    /// One sentence explaining the suggestion.
    @Guide(description: "Brief reason for the style choice (one sentence).")
    var reason: String
}
#endif

// MARK: - Suggester Actor

actor TaskStyleSuggester {

    static let shared = TaskStyleSuggester()

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private var session: LanguageModelSession?
    #endif

    private init() {}

    // MARK: - Public API

    /// Returns the best-fitting `TaskStyle` for the given task title.
    /// Always succeeds — worst case returns `.sleekModern`.
    func suggest(for taskTitle: String) async -> TaskStyle {
        guard !taskTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .sleekModern
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            if let style = await suggestWithFoundationModels(taskTitle) {
                return style
            }
        }
        #endif

        return suggestWithHeuristic(taskTitle)
    }

    // MARK: - Foundation Models Path

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func suggestWithFoundationModels(_ title: String) async -> TaskStyle? {
        // Lazy-initialise the session (model warm-up deferred to first call)
        if session == nil {
            session = LanguageModelSession()
        }
        guard let session else { return nil }

        let styleList = TaskStyle.allCases.map(\.rawValue).joined(separator: ", ")
        let prompt = """
        You are a UI theme assistant. Given this task title: "\(title)"

        Choose the single most fitting visual style from this exact list:
        \(styleList)

        Consider the mood, context, and energy of the task. Reply with the exact style name.
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: StylePrediction.self
            )
            let prediction = response.content
            FlowLogger.ai.info("🧠 Foundation Models → '\(prediction.styleName)' (\(prediction.reason))")
            return TaskStyle(rawValue: prediction.styleName)
        } catch {
            FlowLogger.ai.warning("⚠️ Foundation Models unavailable: \(error.localizedDescription) — falling back to heuristic")
            return nil
        }
    }
    #endif

    // MARK: - Keyword Heuristic Fallback

    /// O(n) keyword scan — instant, no network, works on all OS versions.
    private func suggestWithHeuristic(_ title: String) -> TaskStyle {
        let lower = title.lowercased()

        switch true {
        // Code / engineering
        case lower.contains("code") || lower.contains("pr") || lower.contains("review")
          || lower.contains("debug") || lower.contains("deploy") || lower.contains("build"):
            return .circuitBoard

        // Writing / documentation
        case lower.contains("write") || lower.contains("draft") || lower.contains("document")
          || lower.contains("blog") || lower.contains("article"):
            return .vintageNewspaper

        // Design / creative
        case lower.contains("design") || lower.contains("figma") || lower.contains("sketch")
          || lower.contains("creative") || lower.contains("art"):
            return .popArt

        // Meetings / calls
        case lower.contains("meeting") || lower.contains("call") || lower.contains("standup")
          || lower.contains("1:1") || lower.contains("sync"):
            return .timeline

        // Exercise / health
        case lower.contains("gym") || lower.contains("run") || lower.contains("workout")
          || lower.contains("exercise") || lower.contains("yoga"):
            return .questMode

        // Reading / learning
        case lower.contains("read") || lower.contains("study") || lower.contains("learn")
          || lower.contains("book") || lower.contains("course"):
            return .zenFocus

        // Nature / outdoor
        case lower.contains("garden") || lower.contains("plant") || lower.contains("outside")
          || lower.contains("walk") || lower.contains("nature"):
            return .livingGarden

        // Space / big-picture planning
        case lower.contains("plan") || lower.contains("strateg") || lower.contains("roadmap")
          || lower.contains("vision") || lower.contains("goal"):
            return .spaceMission

        // Deep focus / solo work
        case lower.contains("focus") || lower.contains("deep") || lower.contains("flow")
          || lower.contains("distraction"):
            return .zenInk

        default:
            return .sleekModern
        }
    }
}

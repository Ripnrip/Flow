/**
 * 📋 FlowLogger - The Unified Chronicle
 *
 * "Every great realm needs a scribe—structured, emoji-rich,
 * always ready to illuminate the path through cosmic data streams.
 * Use `log` (info), `warning`, `error`, and `debug` on each channel."
 *
 * Usage:
 *   FlowLogger.lifecycle.info("🌐 App did become active")
 *   FlowLogger.intent.info("🎯 SnoozeIntent fired for task \(taskId)")
 *   FlowLogger.liveActivity.info("🏝️ Updated LA state: snooze=\(count)")
 *   FlowLogger.network.warning("⚠️ Todoist request timed out, retrying…")
 *   FlowLogger.ai.info("🏠 On-device inference: style=\(style)")
 */

import OSLog

// MARK: - 🌟 Centralized Logging

/// Structured `Logger` channels for every subsystem in Flow.
/// Viewable in Console.app filtered by subsystem "com.binarybros.Flow".
enum FlowLogger {

    // 🔄 App / extension lifecycle (launch, background, foreground)
    static let lifecycle = Logger(subsystem: "com.binarybros.Flow", category: "🔄 Lifecycle")

    // 🎯 AppIntent execution (SnoozeIntent, DoneIntent, StartFocusIntent…)
    static let intent = Logger(subsystem: "com.binarybros.Flow", category: "🎯 Intent")

    // 🏝️ ActivityKit / Live Activity updates
    static let liveActivity = Logger(subsystem: "com.binarybros.Flow", category: "🏝️ LiveActivity")

    // 📱 Widget timeline provider
    static let widget = Logger(subsystem: "com.binarybros.Flow", category: "📱 Widget")

    // 🧠 AI / Foundation Models inference
    static let ai = Logger(subsystem: "com.binarybros.Flow", category: "🧠 AI")

    // 🌐 Online path — Todoist REST, Hummingbird MCP server
    static let network = Logger(subsystem: "com.binarybros.Flow", category: "🌐 Network")

    // 🏠 Offline / local path — SwiftData, on-device model
    static let local = Logger(subsystem: "com.binarybros.Flow", category: "🏠 Local")

    // 🔃 Cross-process sync — App Groups UserDefaults bridge
    static let sync = Logger(subsystem: "com.binarybros.Flow", category: "🔃 Sync")

    // 🔗 Universal Links, deep links, App Clip invocation
    static let deepLink = Logger(subsystem: "com.binarybros.Flow", category: "🔗 DeepLink")

    // ⚙️ Task CRUD, snooze/complete, SwiftData operations
    static let task = Logger(subsystem: "com.binarybros.Flow", category: "⚙️ Task")
}

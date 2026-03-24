/**
 * 🔗 FlowRoute - The Typed Navigation Atlas
 *
 * "A typed map of every destination inside the Flow realm.
 * Universal Links, App Clip invocations, and in-app deep links
 * all converge here—cold start, warm resume, and cross-app
 * promotion unified behind a single enum."
 *
 * Supported URL schemes
 * ─────────────────────
 *  Custom scheme   : flow://task/UUID
 *                    flow://gallery
 *                    flow://join/CODE
 *                    flow://clip/SOURCE
 *
 *  Universal Link  : https://flow.app/task/UUID
 *                    https://flow.app/gallery
 *                    https://flow.app/join/CODE
 *
 * AASA paths (host: flow.app)
 * ───────────────────────────
 *  /task/*    → .focus(taskId:)
 *  /gallery   → .styleGallery
 *  /join/*    → .join(code:)
 *  /clip/*    → .appClipCapture(source:)
 *  /          → .inbox
 *
 * Associated Domains entitlement:
 *   applinks:flow.app
 *   webcredentials:flow.app
 *   appclips:flow.app
 */

import Foundation

// MARK: - 🔗 Typed Routes

/// Every navigable destination in Flow, parsed from a URL or constructed in code.
enum FlowRoute: Equatable, Hashable, Sendable {

    /// The default inbox / task list.
    case inbox

    /// Open and optionally focus a specific task.
    case focus(taskId: UUID)

    /// The 42-style Visual Vault gallery.
    case styleGallery

    /// Accept a shared-task invitation via code (future collaboration feature).
    case join(code: String)

    /// App Clip quick-capture entry point (QR / NFC / Safari banner).
    case appClipCapture(source: String)
}

// MARK: - URL Parsing

extension FlowRoute {

    // MARK: init

    /// Parses a `flow://` custom-scheme URL **or** an `https://flow.app` Universal Link.
    /// Returns `nil` for unrecognised URLs so the caller can show a fallback.
    init?(url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        let host   = url.host?.lowercased()  ?? ""

        let isCustom    = scheme == "flow"
        let isUniversal = host == "flow.app" || host == "www.flow.app"

        guard isCustom || isUniversal else {
            FlowLogger.deepLink.warning("⚠️ [FlowRoute] Unrecognised URL scheme/host: \(url.absoluteString)")
            return nil
        }

        // Normalise: for `flow://task/UUID` the "host" is the first path component.
        let segments: [String]
        if isCustom {
            // flow://task/UUID → host="task", path="/UUID"
            let hostPart = url.host ?? ""
            let pathParts = url.path
                .split(separator: "/")
                .map(String.init)
                .filter { !$0.isEmpty }
            segments = [hostPart] + pathParts
        } else {
            // https://flow.app/task/UUID → pathComponents = ["/", "task", "UUID"]
            segments = url.pathComponents.filter { $0 != "/" }
        }

        FlowLogger.deepLink.info("🔗 [FlowRoute] Parsing segments: \(segments.joined(separator: "/"))")

        switch segments.first {
        case "task", "focus":
            if let rawId = segments.dropFirst().first,
               let uuid  = UUID(uuidString: rawId) {
                self = .focus(taskId: uuid)
            } else {
                // task path with no/bad UUID → fall back to inbox
                self = .inbox
            }

        case "gallery":
            self = .styleGallery

        case "join":
            if let code = segments.dropFirst().first, !code.isEmpty {
                self = .join(code: code)
            } else {
                self = .inbox
            }

        case "clip":
            let source = segments.dropFirst().first ?? "unknown"
            self = .appClipCapture(source: source)

        default:
            self = .inbox
        }
    }
}

// MARK: - URL Generation

extension FlowRoute {

    /// `flow://` custom-scheme URL for in-app navigation and widget deeplinks.
    var customURL: URL? {
        var c = URLComponents()
        c.scheme = "flow"
        switch self {
        case .inbox:
            c.host = "inbox"
        case .focus(let id):
            c.host = "task"
            c.path = "/\(id.uuidString)"
        case .styleGallery:
            c.host = "gallery"
        case .join(let code):
            c.host = "join"
            c.path = "/\(code)"
        case .appClipCapture(let source):
            c.host = "clip"
            c.path = "/\(source)"
        }
        return c.url
    }

    /// `https://flow.app/…` Universal Link — used for sharing and AASA verification.
    var universalLinkURL: URL? {
        var c = URLComponents()
        c.scheme = "https"
        c.host   = "flow.app"
        switch self {
        case .inbox:
            c.path = "/"
        case .focus(let id):
            c.path = "/task/\(id.uuidString)"
        case .styleGallery:
            c.path = "/gallery"
        case .join(let code):
            c.path = "/join/\(code)"
        case .appClipCapture(let source):
            c.path = "/clip/\(source)"
        }
        return c.url
    }
}

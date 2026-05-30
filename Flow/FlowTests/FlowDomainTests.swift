//
//  FlowDomainTests.swift
//  FlowTests
//
//  Deterministic unit tests for Flow's pure domain logic: typed deep-link
//  routing, task growth thresholds, the cross-process snapshot model, and
//  the style suggester's fast-path guards.
//

import Foundation
import Testing
@testable import Flow

// MARK: - 🔗 FlowRoute Parsing

@Suite("FlowRoute parsing")
struct FlowRouteParsingTests {

    private let sampleID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    @Test("Custom scheme: gallery, join, and clip")
    func customSchemeRoutes() throws {
        #expect(FlowRoute(url: URL(string: "flow://gallery")!) == .styleGallery)
        #expect(FlowRoute(url: URL(string: "flow://join/ABC123")!) == .join(code: "ABC123"))
        #expect(FlowRoute(url: URL(string: "flow://clip/qr")!) == .appClipCapture(source: "qr"))
    }

    @Test("Custom and universal task links resolve to the same focus route")
    func taskLinksResolveToFocus() throws {
        let custom = FlowRoute(url: URL(string: "flow://task/\(sampleID.uuidString)")!)
        let universal = FlowRoute(url: URL(string: "https://flow.app/task/\(sampleID.uuidString)")!)
        #expect(custom == .focus(taskId: sampleID))
        #expect(universal == .focus(taskId: sampleID))
    }

    @Test("Universal Link host variations are accepted")
    func universalHosts() throws {
        #expect(FlowRoute(url: URL(string: "https://flow.app/gallery")!) == .styleGallery)
        #expect(FlowRoute(url: URL(string: "https://www.flow.app/gallery")!) == .styleGallery)
        #expect(FlowRoute(url: URL(string: "https://flow.app/")!) == .inbox)
    }

    @Test("Malformed task IDs fall back to inbox rather than failing")
    func malformedTaskFallsBackToInbox() throws {
        #expect(FlowRoute(url: URL(string: "flow://task/not-a-uuid")!) == .inbox)
        #expect(FlowRoute(url: URL(string: "https://flow.app/task/")!) == .inbox)
    }

    @Test("Unrecognised schemes and hosts return nil")
    func unknownReturnsNil() throws {
        #expect(FlowRoute(url: URL(string: "https://example.com/task/123")!) == nil)
        #expect(FlowRoute(url: URL(string: "mailto:hello@flow.app")!) == nil)
    }

    @Test("Generated URLs round-trip back to the same route", arguments: [
        FlowRoute.inbox,
        FlowRoute.styleGallery,
        FlowRoute.join(code: "TEAM42"),
        FlowRoute.appClipCapture(source: "nfc")
    ])
    func customURLRoundTrips(_ route: FlowRoute) throws {
        let url = try #require(route.customURL)
        #expect(FlowRoute(url: url) == route)
    }

    @Test("Universal link generation round-trips focus and gallery")
    func universalURLRoundTrips() throws {
        let focus = FlowRoute.focus(taskId: sampleID)
        let focusURL = try #require(focus.universalLinkURL)
        #expect(FlowRoute(url: focusURL) == focus)

        let galleryURL = try #require(FlowRoute.styleGallery.universalLinkURL)
        #expect(FlowRoute(url: galleryURL) == .styleGallery)
    }
}

// MARK: - 🌱 Item growth thresholds

@Suite("Item growth level")
struct ItemGrowthTests {

    private func makeItem(style: TaskStyle, lingering: TimeInterval) -> Item {
        let item = Item(style: style)
        item.totalLingeringTime = lingering
        return item
    }

    @Test("Growth styles cross thresholds at 5/15/30 minutes")
    func growingStyleThresholds() {
        #expect(makeItem(style: .livingGarden, lingering: 0).growthLevel == 0)
        #expect(makeItem(style: .livingGarden, lingering: 301).growthLevel == 1)
        #expect(makeItem(style: .livingGarden, lingering: 901).growthLevel == 2)
        #expect(makeItem(style: .livingGarden, lingering: 1801).growthLevel == 3)
        #expect(makeItem(style: .magicalForest, lingering: 1801).growthLevel == 3)
    }

    @Test("Non-growing styles always report growth level 0")
    func nonGrowingStylesStayZero() {
        #expect(makeItem(style: .cyberpunk, lingering: 5000).growthLevel == 0)
        #expect(makeItem(style: .sleekModern, lingering: 5000).growthLevel == 0)
    }
}

// MARK: - 🔃 ActiveTaskSnapshot

@Suite("ActiveTaskSnapshot")
struct ActiveTaskSnapshotTests {

    private func makeSnapshot() -> ActiveTaskSnapshot {
        ActiveTaskSnapshot(
            taskId: UUID().uuidString,
            title: "Write tests",
            emoji: "🧪",
            styleRawValue: TaskStyle.circuitBoard.rawValue,
            snoozeCount: 2,
            moveCount: 1,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            growthLevel: 0,
            lastInteractionDate: Date(timeIntervalSince1970: 1_700_000_500),
            isCompleted: false
        )
    }

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let original = makeSnapshot()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ActiveTaskSnapshot.self, from: data)
        #expect(decoded == original)
        #expect(decoded.pendingSnooze == false)
        #expect(decoded.pendingComplete == false)
    }

    @Test("style reconstructs from raw value, with safe fallback")
    func styleReconstruction() {
        #expect(makeSnapshot().style == .circuitBoard)

        var broken = makeSnapshot()
        broken.styleRawValue = "Not A Real Style"
        #expect(broken.style == .sleekModern)
    }
}

// MARK: - 🧠 Style suggester fast path

@Suite("TaskStyleSuggester guards")
struct TaskStyleSuggesterTests {

    @Test("Blank titles short-circuit to the default style")
    func blankTitlesUseDefault() async {
        #expect(await TaskStyleSuggester.shared.suggest(for: "") == .sleekModern)
        #expect(await TaskStyleSuggester.shared.suggest(for: "   ") == .sleekModern)
    }
}

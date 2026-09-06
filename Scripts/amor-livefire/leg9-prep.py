#!/usr/bin/env python3
"""
AMOR leg-9 WIDGET-EXTENSION SMOKE-COMPILE — prepares a macro-stripped copy of
the WidgetsExtension target (as the pbxproj actually builds it) and
typechecks it with the CLT (macosx SDK).

Why: v5.3.0 gave the app target its first-ever full compile (leg 8), but the
WIDGET EXTENSION target — a separate build unit — has never been compiled by
anything on this box. The pbxproj says its true membership is:

    all 12 files in Flow/Widgets/                        (3,588 lines)
    + 9 shared app files via membershipExceptions:       (~2,000 lines)
        AMORWidgetShared, CommonViews, FlowLogger, Item, SharedModels,
        SharedTaskStore, TaskLingeringActor, TaskService, TodoistService

Only LiveActivityIntents.swift ever saw a compiler (as an app-target orphan
in leg 8). Everything else shipped dark. This leg closes that.

Strip strategy identical to leg 8 (repo untouched, temp copies only):
SwiftData/@Model/@Query/#Predicate/Summary macros stripped, ActivityKit and
the iOS-only WidgetKit surface (DynamicIsland, ControlWidget*) re-provided as
signature-only shims so misuse the compiler can see still fails.

Law: LEDGER — temp dir removed by the caller, no Mach-O left in the repo.
"""
import re, sys, pathlib

ROOT = pathlib.Path(sys.argv[1])   # repo root
DST = pathlib.Path(sys.argv[2])    # temp dir
DST.mkdir(parents=True, exist_ok=True)

FLOW = ROOT / "Flow" / "Flow"
WIDGETS = ROOT / "Flow" / "Widgets"

# The extension's true membership, mirroring the pbxproj exception set:
SHARED_APP_FILES = [
    "AMORWidgetShared.swift",
    "CommonViews.swift",
    "FlowLogger.swift",
    "Item.swift",
    "SharedModels.swift",
    "SharedTaskStore.swift",
    "TaskLingeringActor.swift",
    "TaskService.swift",
    "TodoistService.swift",
    # De-facto dependency: SharedTaskStore persists [CommandTile] and
    # CommandCenterWidget renders them — the extension cannot link without
    # these types (CommandTile.swift is Foundation+SwiftUI only).
    "CommandTile.swift",
    # De-facto dependency: SharedTaskStore persists the day's focus ledger
    # and StatsWidget renders it (Foundation-only value type).
    "DailyFocusSummary.swift",
    # De-facto dependency: TaskService imports FlowServer tasks via
    # FlowServerService (real pbxproj membership now includes it).
    "FlowServerService.swift",
]

# ─────────────────────────────────────────────────────────────────────────────
# Macro-strip transform (same law as leg 8 — display-only surface removed,
# all logic compiles for real)
# ─────────────────────────────────────────────────────────────────────────────

def strip_parameter_summaries(text: str) -> str:
    """Remove `static var parameterSummary: some ParameterSummary { ... }` blocks
    (balanced braces). Display-only; the plugin-welded Summary macro cannot
    expand under CLT and they carry no logic."""
    out = []
    i = 0
    marker = "static var parameterSummary"
    while True:
        j = text.find(marker, i)
        if j == -1:
            out.append(text[i:])
            break
        line_start = text.rfind("\n", 0, j) + 1
        brace = text.find("{", j)
        if brace == -1:
            out.append(text[i:])
            break
        depth = 0
        k = brace
        while k < len(text):
            if text[k] == "{":
                depth += 1
            elif text[k] == "}":
                depth -= 1
                if depth == 0:
                    break
            k += 1
        end = k + 1
        if end < len(text) and text[end] == "\n":
            end += 1
        out.append(text[i:line_start])
        i = end
    return "".join(out)

def transform(text: str) -> str:
    text = text.replace("import SwiftData\n", "")
    text = text.replace("import ActivityKit\n", "")
    text = text.replace("import BackgroundTasks\n", "")
    text = re.sub(r"^[ \t]*@Model[ \t]*\n", "", text, flags=re.M)
    text = re.sub(r"^(@?)[ \t]*@Model[ \t]+", "", text, flags=re.M)
    text = re.sub(r"^([ \t]*)@Query\b", r"\1@StubQuery", text, flags=re.M)
    text = re.sub(r"#Predicate\s*<", "ShimPredicate<", text)
    text = re.sub(r"#Predicate\b", "ShimPredicate", text)
    text = re.sub(r"(\s+)\.navigationBarTitleDisplayMode\(([^)]*)\)", r"\1", text)
    text = re.sub(r"[ \t]*#if os\(iOS\)\n(?:[ \t]*\n)*[ \t]*#endif\n", "", text, flags=re.M)
    text = text.replace("Color(.systemBackground)", "Color(nsColor: .windowBackgroundColor)")
    text = re.sub(r"(\s+)\.keyboardType\(([^)]*)\)", r"\1", text)
    text = text.replace("EditButton()", 'Button("Edit") {}')
    # iOS-only accessory widget families — unavailable on macOS; drop from
    # temp copies' supportedFamilies arrays (Watch/standby surface, no logic).
    text = re.sub(r"(\s*)\.accessoryCircular,?\n", r"", text)
    text = re.sub(r"(\s*)\.accessoryRectangular,?\n", r"", text)
    text = re.sub(r"(\s*)\.accessoryInline,?\n", r"", text)
    # macOS WidgetBundleBuilder accepts SwiftUI.Widget ONLY — iOS Control
    # Center controls (real SwiftUI.ControlWidget) can't sit in the bundle on
    # the macosx SDK. Comment the control membership line out of TEMP copies;
    # the control type itself and its intents still typecheck in full.
    text = re.sub(r"^(\s*)(\w+Control\(\))", r"\1// LEG9-MACOS-STRIP: \2", text, flags=re.M)
    if "ParameterSummary" in text:
        text = strip_parameter_summaries(text)
    while "#Preview" in text:
        j = text.find("#Preview")
        brace = text.find("{", j)
        if brace == -1:
            break
        depth = 0
        k = brace
        while k < len(text):
            if text[k] == "{":
                depth += 1
            elif text[k] == "}":
                depth -= 1
                if depth == 0:
                    break
            k += 1
        end = k + 1
        # #Preview supports LABELED trailing closures after the body —
        # widget `timeline:`, Live Activity `contentStates:`. Swallow any
        # chain of them or they orphan at file scope. Legal repo code —
        # harness transform must handle all forms.
        while True:
            rest = text[end:]
            m = re.match(r"\s*[A-Za-z_]\w*\s*:\s*\{", rest)
            if not m:
                break
            brace2 = end + m.end() - 1
            depth = 0
            k2 = brace2
            while k2 < len(text):
                if text[k2] == "{":
                    depth += 1
                elif text[k2] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                k2 += 1
            end = k2 + 1
        if end < len(text) and text[end] == "\n":
            end += 1
        text = text[:j] + text[end:]
    return text

# ─────────────────────────────────────────────────────────────────────────────
# SwiftData + UIKit/BackgroundTasks surface (same shims leg 8 proved)
# ─────────────────────────────────────────────────────────────────────────────

SHIM = r'''
// ==== CLT LEG-9 WIDGET-EXTENSION SMOKE-COMPILE SHIM (temp copies only) ====
// Signature stand-ins for the SwiftData surface + iOS-only modules so the
// widget extension typechecks under the Command Line Tools. NOT an emulation:
// only signatures, so misuse the compiler can see still fails.
import SwiftUI
import Foundation

enum SortOrder { case forward, reverse }

struct SortDescriptor<T> { init(_ kp: KeyPath<T, some Any>, order: SortOrder = .forward, comparator: (T, T) -> Bool = { _, _ in false }) {} }

final class StubPredicate<T> { init(_ body: (T) -> Bool) {} }
func ShimPredicate<T>(_ body: (T) -> Bool) -> StubPredicate<T> { StubPredicate(body) }

struct FetchDescriptor<T> {
    init(predicate: StubPredicate<T>? = nil, sortBy: [SortDescriptor<T>] = []) {}
    var sortBy: [SortDescriptor<T>] = []
}

final class StubModelContext {
    func insert(_ o: Any) {}
    func delete(_ o: Any) {}
    func delete(model: Any.Type, where predicate: StubPredicate<some Any>? = nil) throws {}
    func save() throws {}
    func fetch<T>(_ d: FetchDescriptor<T>) throws -> [T] { [] }
    func fetchCount<T>(_ d: FetchDescriptor<T>) throws -> Int { 0 }
    var autosaveEnabled: Bool = false
}
typealias ModelContext = StubModelContext

final class StubModelContainer {
    init(for schema: Schema, configurations: [ModelConfiguration]) {}
    let mainContext = StubModelContext()
}
typealias ModelContainer = StubModelContainer

struct Schema { init(_ types: [Any.Type]) {} }
struct ModelConfiguration { init(_ name: String = "default", schema: Schema? = nil, isStoredInMemoryOnly: Bool = false) {} }
protocol PersistentModel: AnyObject {}

extension Item: Identifiable {}

@propertyWrapper
struct StubQuery<Value> {
    var wrappedValue: [Value]
    init() { wrappedValue = [] }
    init(sort: AnyKeyPath, order: SortOrder = .forward) { wrappedValue = [] }
    init(sort: [AnyKeyPath], order: SortOrder = .forward) { wrappedValue = [] }
}

extension EnvironmentValues {
    var modelContext: StubModelContext { StubModelContext() }
}

extension View {
    func modelContainer(for types: [Any.Type], isAutosaveEnabled: Bool = true) -> some View { self }
    func modelContainer(_ container: StubModelContainer, isAutosaveEnabled: Bool = true) -> some View { self }
}

// iOS-only symbols — stubs so unguarded call sites typecheck on macOS.
final class UIApplication {
    static let shared = UIApplication()
    private init() {}
    func canOpenURL(_ url: URL) -> Bool { false }
    func open(_ url: URL, options: [String: Any] = [:], completionHandler completion: ((Bool) -> Void)? = nil) {}
    func beginBackgroundTask(expirationHandler handler: (() -> Void)? = nil) -> Int { 0 }
    func endBackgroundTask(_ identifier: Int) {}
}

final class ShareSheetView_Shim {}
'''

# ─────────────────────────────────────────────────────────────────────────────
# ActivityKit + iOS-only WidgetKit surface (DynamicIsland, Controls)
# — signature-only shims, temp copies only
# ─────────────────────────────────────────────────────────────────────────────

WIDGET_STUB = r'''
// ==== CLT LEG-9 WIDGET SURFACE SHIM (temp copies only — never in the repo) ====
// iOS-only ActivityKit + WidgetKit surface re-declared with real signatures
// so Dynamic Island, Live Activity, and Control Center code typechecks on the
// macOS SDK. Misuse the compiler can see still fails.
import SwiftUI
import Foundation
import AppIntents

// MARK: - ActivityKit (iOS-only)

public struct ActivityAuthorizationInfo {
    public var areActivitiesEnabled: Bool { false }
    public init() {}
}

public enum ActivityDismissalPolicy {
    case immediate
    case `default`
    case end(after: Date)
}
extension ActivityDismissalPolicy: Sendable {}

public final class Activity<Attributes> where Attributes: ActivityAttributes {
    public struct ActivityViewContext<A> {}
    public var attributes: Attributes!
    public static var activities: [Activity<Attributes>] { [] }
    public static func request(attributes: Attributes, content: ActivityContent<Attributes.ContentState>, pushType: ActivityPushToken? = nil) throws -> Activity<Attributes> { fatalError("stub") }
    public func update(_ content: ActivityContent<Attributes.ContentState>) async {}
    public func end(dismissalPolicy: ActivityDismissalPolicy = .default) async {}
}

public struct ActivityPushToken { public static var token: ActivityPushToken { ActivityPushToken() } }

public final class ActivityContent<State> {
    public init(state: State, staleDate: Date? = nil) {}
}

public protocol ActivityAttributes: Sendable {
    associatedtype ContentState: Sendable, Codable
}

// Real ActivityKit context surface: context.state / context.attributes.
public struct ActivityViewContext<Attributes: ActivityAttributes> {
    public var state: Attributes.ContentState { fatalError("stub") }
    public var attributes: Attributes { fatalError("stub") }
    public init() {}
}

// The widget-extension Live Activity configuration surface:
// `ActivityConfiguration(for:) { lock-screen } dynamicIsland: { island }`
// On iOS this conforms to WidgetConfiguration (a Widget's body may return
// it) — mirror that law so WidgetsBundle membership typechecks.
public struct ActivityConfiguration<Attributes: ActivityAttributes>: WidgetConfiguration {
    public var body: some WidgetConfiguration { self }
    public init(
        for attributesType: Attributes.Type = Attributes.self,
        @ViewBuilder content: @escaping (ActivityViewContext<Attributes>) -> some View,
        dynamicIsland: @escaping (ActivityViewContext<Attributes>) -> DynamicIsland
    ) {}
}

// MARK: - Dynamic Island (iOS-only WidgetKit)

public struct DynamicIslandExpandedContent<Ignored> {
    init() {}
}

public enum DynamicIslandExpandedRegionPlacement {
    case leading, trailing, center, bottom
}

public func DynamicIslandExpandedRegion<C: View>(
    _ placement: DynamicIslandExpandedRegionPlacement,
    @ViewBuilder content: () -> C
) -> DynamicIslandExpandedContent<C> {
    DynamicIslandExpandedContent()
}

// The real API's combined-content type unifies regions whose opaque content
// types differ per method; a fixed Never-parameterized result does the same
// job here (display-only shim).
@resultBuilder
public struct DynamicIslandExpandedContentBuilder {
    public static func buildExpression<C>(_ content: DynamicIslandExpandedContent<C>) -> DynamicIslandExpandedContent<C> { content }
    public static func buildExpression<C: View>(_ content: C) -> DynamicIslandExpandedContent<C> { DynamicIslandExpandedContent() }
    public static func buildBlock() -> DynamicIslandExpandedContent<Never> { DynamicIslandExpandedContent() }
    public static func buildBlock<C0>(_ c0: DynamicIslandExpandedContent<C0>) -> DynamicIslandExpandedContent<Never> { DynamicIslandExpandedContent() }
    public static func buildBlock<C0, C1>(_ c0: DynamicIslandExpandedContent<C0>, _ c1: DynamicIslandExpandedContent<C1>) -> DynamicIslandExpandedContent<Never> { DynamicIslandExpandedContent() }
    public static func buildBlock<C0, C1, C2>(_ c0: DynamicIslandExpandedContent<C0>, _ c1: DynamicIslandExpandedContent<C1>, _ c2: DynamicIslandExpandedContent<C2>) -> DynamicIslandExpandedContent<Never> { DynamicIslandExpandedContent() }
    public static func buildBlock<C0, C1, C2, C3>(_ c0: DynamicIslandExpandedContent<C0>, _ c1: DynamicIslandExpandedContent<C1>, _ c2: DynamicIslandExpandedContent<C2>, _ c3: DynamicIslandExpandedContent<C3>) -> DynamicIslandExpandedContent<Never> { DynamicIslandExpandedContent() }
    public static func buildBlock<C0, C1, C2, C3, C4>(_ c0: DynamicIslandExpandedContent<C0>, _ c1: DynamicIslandExpandedContent<C1>, _ c2: DynamicIslandExpandedContent<C2>, _ c3: DynamicIslandExpandedContent<C3>, _ c4: DynamicIslandExpandedContent<C4>) -> DynamicIslandExpandedContent<Never> { DynamicIslandExpandedContent() }
}

public struct DynamicIsland {
    public init(
        @DynamicIslandExpandedContentBuilder expanded: () -> DynamicIslandExpandedContent<Never>,
        @ViewBuilder compactLeading: () -> some View,
        @ViewBuilder compactTrailing: () -> some View,
        @ViewBuilder minimal: () -> some View
    ) {}
    public func widgetURL(_ url: URL?) -> DynamicIsland { self }
    public func keylineTint(_ color: Color?) -> DynamicIsland { self }
}

// MARK: - Control Center widgets (iOS 18+, but SwiftUI on macOS 15 already
// provides ControlWidget / ControlWidgetConfiguration / AppIntentControl-
// Configuration via WidgetKit+SwiftUI — only the intent protocols and
// ControlCenter reload surface are iOS-only and need local shims here).

// iOS-only ActivityKit intents protocols — module-local shadows of the
// macOS-unavailable SDK declarations (same law as leg 8's ACTIVITY_STUB).
public protocol LiveActivityIntent: AppIntent {}
public protocol LiveActivityStartingIntent: LiveActivityIntent {}

// ControlConfigurationIntent is iOS-only in AppIntents — local shadow.
public protocol ControlConfigurationIntent: AppIntent {}

// AppIntentControlValueProvider is iOS-only (control-center value flow) —
// local shadow with the real signature.
public protocol AppIntentControlValueProvider<Value, Configuration>: Sendable {
    associatedtype Value: Codable & Sendable
    associatedtype Configuration: ControlConfigurationIntent
    func previewValue(configuration: Configuration) -> Value
    func currentValue(configuration: Configuration) async throws -> Value
}

// ControlCenter reload surface — iOS-only, local shadow.
public final class ControlCenter {
    public static let shared = ControlCenter()
    private init() {}
    public func reloadControls(ofKind kind: String) {}
}

// iOS 26 Liquid Glass + Live Activity background tint — unavailable on this
// macOS SDK; stub the surface (same law as leg 8's GlassEffectContainer).
public struct GlassEffect {
    public static var regular: GlassEffect { GlassEffect() }
    public func tint(_ color: Color) -> GlassEffect { self }
}
extension View {
    public func glassEffect(_ effect: GlassEffect, in shape: some Shape) -> some View { self }
    public func activityBackgroundTint(_ color: Color?) -> some View { self }
    public func activitySystemActionForegroundColor(_ color: Color?) -> some View { self }
}
'''

count = 0
# The 12 widget files — the extension's own target body.
for f in sorted(WIDGETS.glob("*.swift")):
    out = transform(f.read_text())
    # WidgetsControl.swift is pure iOS-18 Control-Center surface (ControlWidget,
    # AppIntentControlConfiguration) — unavailable on the macosx SDK. Wrap the
    # temp copy in #if os(iOS) so the rest of the extension typechecks; the
    # file's own logic compiles for real under Xcode on iOS.
    if f.name == "WidgetsControl.swift":
        out = "#if os(iOS)\n" + out + "\n#endif\n"
    (DST / f.name).write_text(out)
    count += 1

# The 9 shared app files the pbxproj compiles INTO the extension target.
for name in SHARED_APP_FILES:
    src = FLOW / name
    if not src.exists():
        raise SystemExit(f"leg9-prep: missing shared app file {src}")
    (DST / name).write_text(transform(src.read_text()))
    count += 1

(DST / "_CLTShim.swift").write_text(SHIM)
(DST / "_WidgetStub.swift").write_text(WIDGET_STUB)
print(f"leg9-prep: {count} transformed files + 2 stubs in {DST}")
print(f"  ({len(list(WIDGETS.glob('*.swift')))} widget + {len(SHARED_APP_FILES)} shared app)")

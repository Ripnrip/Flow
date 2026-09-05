#!/usr/bin/env python3
"""
AMOR leg-8 view smoke-compile — prepares a macro-stripped copy of the whole
Flow app target and typechecks it with the CLT (macosx SDK).

Why: this box has no Xcode.app, so @Model / @Query / #Predicate / Summary
macros never expand (plugins ship only with Xcode). The v5.2.0 illumination
freed the ENGINES into the harness, but the VIEW layer (61 files, ~22k lines,
68 rewired snapshot call sites) has never been compiled by anything.
This leg closes that: it strips macros via text transforms into a temp dir
and typechecks everything else for real — wrong field names, bad labels,
missing bridges, and illegal interpolations all still explode.

Stripped (display-only, zero logic): SwiftData macros, parameterSummary
builder blocks (AppIntents Summary). perform() bodies and all view code
compile for real. Repo is never touched; temp dir removed by the caller.
"""
import re, sys, pathlib

SRC = pathlib.Path(sys.argv[1])   # .../Flow/Flow
DST = pathlib.Path(sys.argv[2])   # temp dir
DST.mkdir(parents=True, exist_ok=True)

SHIM = r'''
// ==== CLT VIEW SMOKE-COMPILE SHIM (temp copies only — never in the repo) ====
// Minimal stand-ins for the SwiftData surface + iOS-only modules so the view
// layer typechecks under the Command Line Tools. NOT an emulation: only
// signatures, so misuse the compiler can see still fails.
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

// Conformances the @Model macro synthesizes in Xcode (PersistentModel:
// Identifiable). The strip removes the macro, so re-declare here — the
// models all carry `var id: UUID`.
extension DailySession: Identifiable {}
extension PracticeStreak: Identifiable {}
extension CronJobHealth: Identifiable {}
extension DailySummary: Identifiable {}
extension SecondBrainEntry: Identifiable {}
extension ReflectionEntry: Identifiable {}
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
    func modelContainer(for types: [Any.Type], isAutosaveEnabled: Bool = true, onMigration: @escaping (StubModelContext, Schema) -> Void) -> some View { self }
}

extension Scene {
    func modelContainer(_ container: StubModelContainer, isAutosaveEnabled: Bool = true) -> some Scene { self }
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

// BackgroundTasks types are unavailable on macOS — stub the surface.
class BGTask {
    var expirationHandler: (() -> Void)? = nil
    func setTaskCompleted(success: Bool) {}
}
final class BGProcessingTask: BGTask {}
final class BGProcessingTaskBox {}
final class BGAppRefreshTask: BGTask {}
final class BGTaskScheduler {
    static let shared = BGTaskScheduler()
    func register(forTaskWithIdentifier id: String, using queue: DispatchQueue? = nil, launchHandler: @escaping (BGTask) -> Void) -> Bool { true }
    func submit(_ request: BGTaskRequest) throws {}
}
class BGTaskRequest {
    var earliestBeginDate: Date? = nil
}
final class BGProcessingTaskRequest: BGTaskRequest {
    var requiresNetworkConnectivity: Bool = false
    var requiresExternalPower: Bool = false
    init(identifier: String) {}
}
final class BGAppRefreshTaskRequest: BGTaskRequest {
    init(identifier: String) {}
}
'''

ACTIVITY_STUB = r'''
// CLT smoke-compile stub — signatures only, never shipped.
import Foundation
import SwiftUI

// ShareSheetView is #if canImport(UIKit)-guarded in the app (iOS-only);
// stub the symbol so unguarded iOS call sites still typecheck on macOS.
struct ShareSheetView: View {
    init(url: URL) {}
    init(text: String) {}
    var body: some View { EmptyView() }
}

// iOS 26 Liquid Glass — unavailable on this macOS SDK; stub the surface.
struct GlassEffectContainer<Content: View>: View {
    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
    var body: some View { EmptyView() }
}
struct GlassEffect {
    static var regular: GlassEffect { GlassEffect() }
    func tint(_ color: Color) -> GlassEffect { self }
}
extension View {
    func glassEffect(_ effect: GlassEffect, in shape: some Shape) -> some View { self }
}

public final class ActivityContent<State> {
    public init(state: State, staleDate: Date? = nil) {}
}

public struct ActivityAuthorizationInfo {
    public var areActivitiesEnabled: Bool { false }
    public init() {}
}

public final class Activity<Attributes> {
    public struct ActivityViewContext<A> {}
    public var attributes: Attributes!
    public static var activities: [Activity<Attributes>] { [] }
    public static func request(attributes: Attributes, content: ActivityContent<some Any>, pushType: String? = nil) throws -> Activity<Attributes> { fatalError("stub") }
    public func update(_ content: ActivityContent<some Any>) async {}
    public func end(dismissalPolicy: Int = 0) async {}
}

public struct ActivityConfiguration<Attributes> {
    public init(for: Attributes.Type = Attributes.self, dpi: Int = 1) {}
}

public protocol ActivityAttributes: Sendable {
    associatedtype ContentState: Sendable, Codable
}

extension ActivityAttributes where ContentState == EmptyContentState {
    init() { self = Self() as! Self }
}

public struct EmptyContentState: Sendable, Codable {}

// iOS-only ActivityKit protocol — stub for macOS smoke-compile.
import AppIntents
public protocol LiveActivityIntent: AppIntents.AppIntent {}
'''

def strip_parameter_summaries(text: str) -> str:
    """Remove `static var parameterSummary: some ParameterSummary { ... }` blocks
    (balanced braces). Display-only summaries; the plugin-welded Summary macro
    cannot expand under CLT, and they carry no logic."""
    out = []
    i = 0
    marker = "static var parameterSummary"
    while True:
        j = text.find(marker, i)
        if j == -1:
            out.append(text[i:])
            break
        # start of the enclosing line (keep indentation out — remove whole lines)
        line_start = text.rfind("\n", 0, j) + 1
        # find first { after marker
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
        # swallow trailing newline
        end = k + 1
        if end < len(text) and text[end] == "\n":
            end += 1
        out.append(text[i:line_start])
        i = end
    return "".join(out)

def transform(text: str, name: str) -> str:
    text = text.replace("import SwiftData\n", "")
    text = text.replace("import ActivityKit\n", "")
    text = text.replace("import BackgroundTasks\n", "")
    text = re.sub(r"^[ \t]*@Model[ \t]*\n", "", text, flags=re.M)   # bare attribute line
    text = re.sub(r"^(@?)[ \t]*@Model[ \t]+", "", text, flags=re.M) # same-line prefix
    text = re.sub(r"^([ \t]*)@Query\b", r"\1@StubQuery", text, flags=re.M)
    text = re.sub(r"#Predicate\s*<", "ShimPredicate<", text)
    text = re.sub(r"#Predicate\b", "ShimPredicate", text)
    # iOS-only display modifiers unavailable on macOS — neutralize in temp copies.
    text = re.sub(r"(\s+)\.navigationBarTitleDisplayMode\(([^)]*)\)", r"\1", text)
    # Empty #if blocks after stripping break modifier chains — remove whole guarded blocks.
    text = re.sub(r"[ \t]*#if os\(iOS\)\n(?:[ \t]*\n)*[ \t]*#endif\n", "", text, flags=re.M)
    # UIKit-only color init — swap to a macOS-available equivalent.
    text = text.replace("Color(.systemBackground)", "Color(nsColor: .windowBackgroundColor)")
    # iOS-only keyboard modifier — neutralize in temp copies.
    text = re.sub(r"(\s+)\.keyboardType\(([^)]*)\)", r"\1", text)
    # iOS-only EditButton — swap to a macOS-available stand-in in temp copies.
    text = text.replace("EditButton()", 'Button("Edit") {}')
    if "ParameterSummary" in text:
        text = strip_parameter_summaries(text)
    # #Preview macro is plugin-welded on CLT — strip display-only preview blocks.
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
        if end < len(text) and text[end] == "\n":
            end += 1
        text = text[:j] + text[end:]
    return text

count = 0
for f in sorted(SRC.glob("*.swift")):
    out = transform(f.read_text(), f.name)
    (DST / f.name).write_text(out)
    count += 1

# Widgets/LiveActivityIntents.swift is a pbxproj membershipException compiled
# into the Flow app target as well (defines LiveActivityConfiguration etc).
extra = SRC.parent / "Widgets" / "LiveActivityIntents.swift"
if extra.exists():
    (DST / extra.name).write_text(transform(extra.read_text(), extra.name))
    count += 1

(DST / "_CLTShim.swift").write_text(SHIM)
(DST / "_ActivityKitStub.swift").write_text(ACTIVITY_STUB)
print(f"prepared {count} transformed files + 2 stubs in {DST}")

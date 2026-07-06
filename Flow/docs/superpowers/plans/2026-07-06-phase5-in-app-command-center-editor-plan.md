# Phase 5: In-App Command Center Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-app Command Center editor that lets users configure command tiles, pinned tasks, and Live Activity settings.

**Architecture:** Add a `commandCenter` case to `ContentView`’s navigation, create focused SwiftUI editor views, and read/write configuration through existing `SharedTaskStore` App Groups methods.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, App Groups (`group.com.binarybros.Flow`), WidgetKit.

## Global Constraints

- iOS 26 / Swift 6.2 / Xcode 26.0
- Strict concurrency disabled (`SWIFT_STRICT_CONCURRENCY = targeted`) in current build settings
- Main app uses SwiftData `Item` model; widgets cannot reference it
- All shared configuration lives in `SharedTaskStore` and is `Codable` + `Sendable`
- Editor changes must call `WidgetCenter.shared.reloadAllTimelines()` after persistence

---

## Task 1: Add Navigation Sidebar Item

**Files:**
- Modify: `Flow/Flow/ContentView.swift`

**Interfaces:**
- Produces: `NavigationItem.commandCenter`
- Produces: sidebar label and icon for Command Center
- Produces: root `CommandCenterEditorView` destination

- [ ] **Step 1: Add `commandCenter` to `NavigationItem`**

Locate the `NavigationItem` enum in `ContentView.swift` (around line 14):

```swift
enum NavigationItem: Hashable {
    case inbox
    case gallery
    case commandCenter  // NEW
}
```

- [ ] **Step 2: Add Command Center sidebar row**

In the `sidebar` view, add a new `NavigationLink` after the gallery link:

```swift
            NavigationLink(value: NavigationItem.commandCenter) {
                Label("Command Center", systemImage: "slider.horizontal.3")
            }
```

- [ ] **Step 3: Add Command Center destination**

In the `detailColumn` computed property, add a case:

```swift
case .commandCenter:
    CommandCenterEditorView()
```

- [ ] **Step 4: Build the Flow scheme**

Run:
```bash
cd /Users/admin/Developer/Flow-GitHub/Flow
xcodebuild build -project Flow.xcodeproj -scheme Flow \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D3914993-86CF-46F5-94C5-BDE0CAA0ADBF' \
  ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

Expected: `** BUILD SUCCEEDED **`

---

## Task 2: Create CommandCenterEditorView Shell

**Files:**
- Create: `Flow/Flow/CommandCenterEditorView.swift`

**Interfaces:**
- Produces: `CommandCenterEditorView`
- Produces: tabbed sections: Tiles, Pinned Tasks, Live Activity

- [ ] **Step 1: Create `Flow/Flow/CommandCenterEditorView.swift`**

```swift
/**
 * 🎛️ CommandCenterEditorView — The Focus Command Deck
 *
 * "Where seekers of wisdom arrange their magical instruments:
 *  tiles for quick conjurations, pinned quests for the launchpad,
 *  and the Live Activity spirit for the lock screen ritual."
 *
 * - The Theatrical Command Deck Architect
 */

import SwiftUI
import WidgetKit

enum CommandCenterTab: String, CaseIterable {
    case tiles = "Tiles"
    case pinned = "Pinned Tasks"
    case liveActivity = "Live Activity"
}

struct CommandCenterEditorView: View {
    @State private var selectedTab: CommandCenterTab = .tiles

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedTab) {
                    ForEach(CommandCenterTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Group {
                    switch selectedTab {
                    case .tiles:
                        CommandTileEditorView()
                    case .pinned:
                        PinnedTaskPickerView()
                    case .liveActivity:
                        LiveActivityConfigEditorView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Command Center")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    CommandCenterEditorView()
}
```

- [ ] **Step 2: Add placeholder editor views**

Create minimal placeholder files so Task 1 compiles:

`Flow/Flow/CommandTileEditorView.swift`:
```swift
import SwiftUI

struct CommandTileEditorView: View {
    var body: some View {
        Text("Command tiles editor coming soon...")
    }
}
```

`Flow/Flow/PinnedTaskPickerView.swift`:
```swift
import SwiftUI

struct PinnedTaskPickerView: View {
    var body: some View {
        Text("Pinned task picker coming soon...")
    }
}
```

`Flow/Flow/LiveActivityConfigEditorView.swift`:
```swift
import SwiftUI

struct LiveActivityConfigEditorView: View {
    var body: some View {
        Text("Live Activity config coming soon...")
    }
}
```

- [ ] **Step 3: Build the Flow scheme**

Same command as Task 1, Step 4.
Expected: `** BUILD SUCCEEDED **`

---

## Task 3: Implement CommandTileEditorView

**Files:**
- Modify: `Flow/Flow/CommandTileEditorView.swift`

**Interfaces:**
- Consumes: `CommandTile`, `CommandTileAction`, `TaskStyle`
- Produces: editable 4-tile grid
- Produces: `CommandTileEditSheet`

- [ ] **Step 1: Replace placeholder with full editor**

```swift
/**
 * 🎨 CommandTileEditorView — The Conjuration Grid
 *
 * "Four tiles, four spells. Rearrange their essence,
 *  choose their glyph, and set their incantation."
 */

import SwiftUI
import WidgetKit

struct CommandTileEditorView: View {
    @State private var tiles: [CommandTile] = []
    @State private var editingTile: CommandTile?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach($tiles) { $tile in
                    TileConfigCell(tile: $tile) {
                        editingTile = tile
                    }
                }
            }
            .padding()
        }
        .onAppear(perform: loadTiles)
        .onChange(of: tiles) { _, _ in
            Task { await saveTiles() }
        }
        .sheet(item: $editingTile) { tile in
            CommandTileEditSheet(tile: tile) { updated in
                if let index = tiles.firstIndex(where: { $0.id == updated.id }) {
                    tiles[index] = updated
                }
            }
        }
    }

    private func loadTiles() {
        Task {
            let loaded = await SharedTaskStore.shared.loadCommandTiles()
            await MainActor.run {
                tiles = loaded.isEmpty ? CommandTile.defaultSet : loaded
            }
        }
    }

    private func saveTiles() async {
        await SharedTaskStore.shared.saveCommandTiles(tiles)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - 📱 Tile Cell

struct TileConfigCell: View {
    @Binding var tile: CommandTile
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(spacing: 8) {
                Text(tile.isSFSymbol ? Image(systemName: tile.icon) : Text(tile.icon))
                    .font(.largeTitle)
                    .foregroundStyle(tile.accentStyle.themeAccentColor())

                Text(tile.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(tile.action.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding()
            .background(tile.accentStyle.themeBackgroundColor().opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 📝 Edit Sheet

struct CommandTileEditSheet: View {
    let tile: CommandTile
    let onSave: (CommandTile) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var icon: String = ""
    @State private var isSFSymbol: Bool = false
    @State private var selectedAction: CommandTileAction = .showStats
    @State private var selectedStyle: TaskStyle = .sleekModern

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("Title", text: $title)
                }

                Section("Icon") {
                    TextField("Icon (emoji or SF Symbol)", text: $icon)
                    Toggle("Use SF Symbol", isOn: $isSFSymbol)
                }

                Section("Action") {
                    Picker("Action", selection: $selectedAction) {
                        ForEach(CommandTileAction.allCases, id: \.self) { action in
                            Text(action.displayName).tag(action)
                        }
                    }
                }

                Section("Style") {
                    Picker("Accent", selection: $selectedStyle) {
                        ForEach(TaskStyle.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                }
            }
            .navigationTitle("Edit Tile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = tile
                        updated.title = title
                        updated.icon = icon
                        updated.isSFSymbol = isSFSymbol
                        updated.action = selectedAction
                        updated.accentStyle = selectedStyle
                        onSave(updated)
                        dismiss()
                    }
                }
            }
            .onAppear {
                title = tile.title
                icon = tile.icon
                isSFSymbol = tile.isSFSymbol
                selectedAction = tile.action
                selectedStyle = tile.accentStyle
            }
        }
    }
}
```

- [ ] **Step 2: Ensure CommandTile has required helpers**

Verify `CommandTile` in `Flow/Flow/CommandTile.swift` has:
- `defaultSet` static property or ensure `CommandTile` presets exist
- `allCases` on `CommandTileAction` (or list)
- `displayName` on `CommandTileAction`

If missing, add to `CommandTile.swift`:

```swift
extension CommandTile {
    static var defaultSet: [CommandTile] {
        [
            .focusOnTask(id: UUID(), title: "Deep Work", emoji: "🎯", style: .cyberpunk),
            .snooze(),
            .syncAll(),
            .showStats()
        ]
    }
}

extension CommandTileAction: CaseIterable {
    public static var allCases: [CommandTileAction] {
        [.startFocus, .snooze, .completeTop, .syncAll, .showStats, .openInbox, .openURL, .runShortcut]
    }

    var displayName: String {
        switch self {
        case .startFocus:  "Start Focus"
        case .snooze:      "Snooze"
        case .completeTop: "Complete Top"
        case .syncAll:     "Sync All"
        case .showStats:   "Show Stats"
        case .openInbox:   "Open Inbox"
        case .openURL:     "Open URL"
        case .runShortcut: "Run Shortcut"
        }
    }
}
```

If `CommandTileAction` already has these helpers, skip this step.

- [ ] **Step 3: Build the Flow scheme**

Same command as Task 1, Step 4.
Expected: `** BUILD SUCCEEDED **`

---

## Task 4: Implement PinnedTaskPickerView

**Files:**
- Modify: `Flow/Flow/PinnedTaskPickerView.swift`

**Interfaces:**
- Consumes: SwiftData `Item` via `@Query`
- Consumes: `PinnedTaskSnapshot`
- Produces: pin/unpin + reorder UI

- [ ] **Step 1: Replace placeholder with full picker**

```swift
/**
 * 📌 PinnedTaskPickerView — The Quest Board
 *
 * "Pin the quests that matter most. Four may stand upon the launchpad;
 *  choose wisely, for the rest wait in the scroll."
 */

import SwiftUI
import SwiftData
import WidgetKit

struct PinnedTaskPickerView: View {
    @Query(sort: \Item.order, order: .forward) private var items: [Item]
    @State private var pinnedTaskIds: [String] = []

    private let maxPinned = 4

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    HStack {
                        Text(item.emoji ?? "📋")
                        Text(item.title)
                            .lineLimit(1)
                        Spacer()
                        if pinnedTaskIds.contains(item.id.uuidString) {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(.accent)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        togglePin(for: item)
                    }
                }
            } header: {
                Text("Tap to pin/unpin (max \(maxPinned))")
            }

            if !pinnedTaskIds.isEmpty {
                Section("Pinned order") {
                    ForEach(pinnedTaskIds, id: \.self) { id in
                        if let item = items.first(where: { $0.id.uuidString == id }) {
                            HStack {
                                Text(item.emoji ?? "📋")
                                Text(item.title)
                            }
                        }
                    }
                    .onMove(perform: movePinned)
                }
            }
        }
        .toolbar { EditButton() }
        .onAppear(perform: loadPinned)
        .onChange(of: pinnedTaskIds) { _, _ in
            Task { await savePinned() }
        }
    }

    private func loadPinned() {
        Task {
            let loaded = await SharedTaskStore.shared.loadPinnedTasks()
            await MainActor.run {
                pinnedTaskIds = loaded.map(\.taskId)
            }
        }
    }

    private func savePinned() async {
        let snapshots = pinnedTaskIds.compactMap { id -> PinnedTaskSnapshot? in
            guard let item = items.first(where: { $0.id.uuidString == id }) else { return nil }
            return PinnedTaskSnapshot(
                taskId: id,
                title: item.title,
                emoji: item.emoji ?? "📋",
                styleRawValue: item.style?.rawValue ?? TaskStyle.sleekModern.rawValue,
                isCompleted: item.isCompleted
            )
        }
        await SharedTaskStore.shared.savePinnedTasks(snapshots)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func togglePin(for item: Item) {
        let id = item.id.uuidString
        if pinnedTaskIds.contains(id) {
            pinnedTaskIds.removeAll { $0 == id }
        } else if pinnedTaskIds.count < maxPinned {
            pinnedTaskIds.append(id)
        }
    }

    private func movePinned(from source: IndexSet, to destination: Int) {
        pinnedTaskIds.move(fromOffsets: source, toOffset: destination)
    }
}
```

- [ ] **Step 2: Verify Item model properties**

The picker assumes `Item` has:
- `id: UUID`
- `title: String`
- `emoji: String?`
- `style: TaskStyle?` or `styleRawValue: String?`
- `isCompleted: Bool`
- `order: Int` (or another sort property)

If `Item` does not have these exact names, adapt the code. Use `rg 'struct Item' Flow/Flow/ -A 30` to inspect.

- [ ] **Step 3: Build the Flow scheme**

Same command as Task 1, Step 4.
Expected: `** BUILD SUCCEEDED **`

---

## Task 5: Implement LiveActivityConfigEditorView

**Files:**
- Modify: `Flow/Flow/LiveActivityConfigEditorView.swift`

**Interfaces:**
- Consumes: `LiveActivityConfiguration`, `LiveActivityAction`, `LiveActivityAnimationIntensity`
- Produces: settings form

- [ ] **Step 1: Replace placeholder with full editor**

```swift
/**
 * ✨ LiveActivityConfigEditorView — The Lock Screen Ritual
 *
 * "Choose the spirits that attend your focus ritual:
 *  two actions, a progress ring, and the intensity of the magic."
 */

import SwiftUI
import WidgetKit

struct LiveActivityConfigEditorView: View {
    @State private var config = LiveActivityConfiguration.default

    var body: some View {
        Form {
            Section("Action Buttons") {
                Picker("Leading", selection: $config.leadingAction) {
                    ForEach(LiveActivityAction.allCases, id: \.self) { action in
                        Text(action.displayName).tag(action)
                    }
                }

                Picker("Trailing", selection: $config.trailingAction) {
                    ForEach(LiveActivityAction.allCases, id: \.self) { action in
                        Text(action.displayName).tag(action)
                    }
                }
            }

            Section("Appearance") {
                Toggle("Show Progress Ring", isOn: $config.showProgressRing)

                Picker("Animation Intensity", selection: $config.animationIntensity) {
                    ForEach(LiveActivityAnimationIntensity.allCases, id: \.self) { intensity in
                        Text(intensity.displayName).tag(intensity)
                    }
                }
            }
        }
        .navigationTitle("Live Activity")
        .onAppear(perform: loadConfig)
        .onChange(of: config) { _, _ in
            Task { await saveConfig() }
        }
    }

    private func loadConfig() {
        Task {
            let loaded = await SharedTaskStore.shared.loadLiveActivityConfiguration()
            await MainActor.run {
                config = loaded
            }
        }
    }

    private func saveConfig() async {
        await SharedTaskStore.shared.saveLiveActivityConfiguration(config)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension LiveActivityAction {
    var displayName: String {
        switch self {
        case .snooze:      "Snooze"
        case .done:        "Done"
        case .pauseResume: "Pause / Resume"
        case .extend:      "Extend 5 min"
        }
    }
}

extension LiveActivityAnimationIntensity {
    var displayName: String {
        switch self {
        case .calm:   "Calm"
        case .normal: "Normal"
        case .lively: "Lively"
        }
    }
}
```

- [ ] **Step 2: Ensure LiveActivityAction has CaseIterable**

If `LiveActivityAction` is not already `CaseIterable`, add:

```swift
extension LiveActivityAction: CaseIterable {
    public static var allCases: [LiveActivityAction] {
        [.snooze, .done, .pauseResume, .extend]
    }
}
```

Do the same for `LiveActivityAnimationIntensity` if needed.

- [ ] **Step 3: Build the Flow scheme**

Same command as Task 1, Step 4.
Expected: `** BUILD SUCCEEDED **`

---

## Task 6: Final Verification

**Files:**
- All new/modified files above

- [ ] **Step 1: Build with previews enabled**

Run:
```bash
cd /Users/admin/Developer/Flow-GitHub/Flow
xcodebuild build -project Flow.xcodeproj -scheme Flow \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D3914993-86CF-46F5-94C5-BDE0CAA0ADBF' \
  ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  ENABLE_PREVIEWS=YES
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Run FlowTests**

Run:
```bash
cd /Users/admin/Developer/Flow-GitHub/Flow
xcodebuild test -project Flow.xcodeproj -scheme FlowTests \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D3914993-86CF-46F5-94C5-BDE0CAA0ADBF' \
  ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

Expected: `** TEST SUCCEEDED **`

---

## Self-Review

1. **Spec coverage:**
   - Command Center sidebar item ✓ (Task 1)
   - Tabbed editor shell ✓ (Task 2)
   - Command tile editor ✓ (Task 3)
   - Pinned task picker ✓ (Task 4)
   - Live Activity config editor ✓ (Task 5)
   - Persistence via SharedTaskStore + widget reload ✓ (all tasks)

2. **Placeholder scan:** No TBD/TODO.

3. **Type consistency:** `CommandTile`, `PinnedTaskSnapshot`, `LiveActivityConfiguration`, `LiveActivityAction`, and `LiveActivityAnimationIntensity` names match existing Phase 1–4 code.

Plan is ready for execution.

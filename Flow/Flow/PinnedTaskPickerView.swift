/**
 * 📌 PinnedTaskPickerView — The Quest Board
 *
 * "Pin the quests that matter most. Four may stand upon the launchpad;
 *  choose wisely, for the rest wait in the scroll."
 *
 * - The Mystical Pinned Task Curator
 */

import SwiftUI
import SwiftData
import WidgetKit

struct PinnedTaskPickerView: View {
    /// 🗂️ All tasks, newest first — `Item` stores its sort key as `timestamp`,
    ///    not `order`, so we follow the same cadence as the Focus Inbox. 🕰️
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    @State private var pinnedTaskIds: [String] = []

    private let maxPinned = 4

    var body: some View {
        List {
            allTasksSection
            pinnedOrderSection
        }
        .toolbar { EditButton() }
        .onAppear(perform: loadPinned)
        .onChange(of: pinnedTaskIds) { _, _ in
            Task { await savePinned() }
        }
        .overlay {
            if items.isEmpty {
                emptyStateView
            }
        }
    }

    /// 📋 The scroll of every task, with a pin glyph marking the chosen few.
    private var allTasksSection: some View {
        Section {
            ForEach(items) { item in
                TaskPickerRow(
                    item: item,
                    isPinned: pinnedTaskIds.contains(item.id.uuidString)
                ) {
                    togglePin(for: item)
                }
                .disabled(!pinnedTaskIds.contains(item.id.uuidString) && pinnedTaskIds.count >= maxPinned)
            }
        } header: {
            Text("Tap to pin/unpin (max \(maxPinned))")
        } footer: {
            if pinnedTaskIds.count == maxPinned {
                Text("Max \(maxPinned) pinned tasks")
            }
        }
    }

    /// 🌙 Empty-state prompt for when no tasks exist yet.
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Add a task first", systemImage: "tray.fill")
        }
    }

    /// 📌 The launchpad section: only the pinned four, draggable into order.
    @ViewBuilder
    private var pinnedOrderSection: some View {
        if !pinnedTaskIds.isEmpty {
            Section("Pinned order") {
                ForEach(pinnedTaskIds, id: \.self) { id in
                    if let item = items.first(where: { $0.id.uuidString == id }) {
                        HStack {
                            Text(item.emoji)
                            Text(item.title)
                        }
                    }
                }
                .onMove(perform: movePinned)
            }
        }
    }

    /// 📥 Loads the current pinned lineup from the App Groups bridge.
    private func loadPinned() {
        Task {
            let loaded = await SharedTaskStore.shared.loadPinnedTasks()
            await MainActor.run {
                pinnedTaskIds = loaded.map(\.taskId)
            }
        }
    }

    /// 💾 Converts the pinned IDs back into snapshots and mirrors them to App Groups,
    ///    then nudges every widget timeline to refresh. 🪄
    private func savePinned() async {
        let snapshots = pinnedTaskIds.compactMap { id -> PinnedTaskSnapshot? in
            guard let item = items.first(where: { $0.id.uuidString == id }) else { return nil }
            return PinnedTaskSnapshot(
                taskId: id,
                title: item.title,
                emoji: item.emoji,
                styleRawValue: item.styleRawValue,
                isCompleted: item.isCompleted
            )
        }
        await SharedTaskStore.shared.savePinnedTasks(snapshots)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 🧷 Tacks a task to the launchpad, or removes it if already pinned.
    ///    Enforces the sacred four-task ceiling. 🏛️
    private func togglePin(for item: Item) {
        let id = item.id.uuidString
        if pinnedTaskIds.contains(id) {
            pinnedTaskIds.removeAll { $0 == id }
        } else if pinnedTaskIds.count < maxPinned {
            pinnedTaskIds.append(id)
        }
    }

    /// 🔀 Reorders the pinned lineup when the user drags rows in edit mode.
    private func movePinned(from source: IndexSet, to destination: Int) {
        pinnedTaskIds.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - 📱 Row Helper

/// A single tappable row in the all-tasks list.
private struct TaskPickerRow: View {
    let item: Item
    let isPinned: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
            Text(item.emoji)
            Text(item.title)
                .lineLimit(1)
            Spacer()
            if isPinned {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

#Preview {
    let container: ModelContainer
    do {
        container = try ModelContainer(for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    } catch {
        fatalError("Failed to create preview container")
    }

    return PinnedTaskPickerView()
        .modelContainer(container)
}

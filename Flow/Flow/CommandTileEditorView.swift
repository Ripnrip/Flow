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
    @State private var hasLoaded = false

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(tiles) { tile in
                    TileConfigCell(tile: tile) {
                        editingTile = tile
                    }
                }
            }
            .padding()
        }
        .onAppear(perform: loadTiles)
        .onChange(of: tiles) { _, _ in
            guard hasLoaded else { return }
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
                if loaded.isEmpty {
                    tiles = CommandTile.defaultSet
                } else if loaded.count < 4 {
                    var padded = loaded
                    let defaults = CommandTile.defaultSet
                    while padded.count < 4, let next = defaults.dropFirst(padded.count).first {
                        padded.append(next)
                    }
                    tiles = padded
                } else if loaded.count > 4 {
                    tiles = Array(loaded.prefix(4))
                } else {
                    tiles = loaded
                }
                hasLoaded = true
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
    let tile: CommandTile
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(spacing: 8) {
                if tile.isSFSymbol {
                    Image(systemName: tile.icon)
                        .font(.largeTitle)
                        .foregroundStyle(tile.accentStyle.themeAccentColor())
                } else {
                    Text(tile.icon)
                        .font(.largeTitle)
                        .foregroundStyle(tile.accentStyle.themeAccentColor())
                }

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

    @State private var title: String
    @State private var icon: String
    @State private var isSFSymbol: Bool
    @State private var selectedAction: CommandTileAction
    @State private var selectedStyle: TaskStyle
    @State private var payload: String

    init(tile: CommandTile, onSave: @escaping (CommandTile) -> Void) {
        self.tile = tile
        self.onSave = onSave
        _title = State(initialValue: tile.title)
        _icon = State(initialValue: tile.icon)
        _isSFSymbol = State(initialValue: tile.isSFSymbol)
        _selectedAction = State(initialValue: tile.action)
        _selectedStyle = State(initialValue: tile.accentStyle)
        _payload = State(initialValue: tile.payload ?? "")
    }

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

                if selectedAction == .openURL || selectedAction == .runShortcut {
                    Section("Payload") {
                        TextField(selectedAction == .openURL ? "URL" : "Shortcut name", text: $payload)
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
                        updated.payload = payload.isEmpty ? nil : payload
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
    }
}

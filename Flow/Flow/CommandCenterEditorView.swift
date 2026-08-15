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

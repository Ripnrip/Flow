/**
 * 🎭 The MainNavigationFlow - The Stage of Intent
 *
 * "Where the seeker of wisdom manages their cosmic burdens.
 * Each item is a seed of potential, waiting to be focused upon."
 *
 * - The Digital Gallery Maestro
 */

import SwiftUI
import SwiftData
import ActivityKit
import Observation

struct MainNavigationFlow: View {
    
    enum NavigationItem: Hashable {
        case inbox
        case gallery
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(TaskService.self) private var taskService: TaskService
    @Environment(ExternalIntegrationService.self) private var integrationService: ExternalIntegrationService
    @Environment(TodoistService.self) private var todoistService: TodoistService
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]

    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskEmoji = "🎯"
    @State private var newTaskStyle = TaskStyle.sleekModern
    @State private var selection: NavigationItem? = .inbox

    let emojis = ["🎯", "📝", "💪", "📚", "📧", "🚀", "🎨", "💻", "🧠", "🌌", "🏗️", "📰", "📜", "🔥", "🌿", "🐙", "🕹️", "⚙️", "💎", "📦", "🚥", "🪟", "⚔️", "💧", "☀️", "🖍️", "🖤"]

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(value: NavigationItem.inbox) {
                    Label("Focus Inbox", systemImage: "tray.full.fill")
                }

                NavigationLink(value: NavigationItem.gallery) {
                    Label("Visual Vault", systemImage: "sparkles.rectangle.stack.fill")
                }
            }
            .navigationTitle("Focus Flow")
        } content: {
            switch selection {
            case .inbox:
            List {
                ForEach(items) { item in
                        TaskRow(item: item) // TaskRow must be defined elsewhere or this line will cause an error
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task {
                                        await taskService.startFocusSession(for: item)
                                    }
                                } label: {
                                    Label("Focus", systemImage: "target")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    modelContext.delete(item)
                    } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .navigationTitle("Your Intents")
                .toolbar {
                    // Item for Sync All, using default placement
                    ToolbarItem {
                        Button {
                            Task {
                                await integrationService.inhaleCalendarEvents()
                                await integrationService.inhaleReminders()
                                await todoistService.inhaleTasks()
                            }
                        } label: {
                            Label("Sync All", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                        }
                    }

                    // On macOS, EditButton is not available. 
                    // If you need editing features on macOS, you need to implement them
                    // yourself, possibly through a regular Button with a label like "Edit".
                    // Since it's a list with swipe actions, we'll omit the EditButton 
                    // to avoid the compile error.

                    // Item for Add Task, using default placement
                    ToolbarItem {
                        Button {
                            isAddingTask = true
                        } label: {
                            Label("Add Task", systemImage: "plus.circle.fill")
                                .font(.title3)
                        }
                    }
                }
            case .gallery:
                StyleGalleryView()
            case .none:
                Text("Select a realm from the sidebar")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        } detail: {
            Text("Select a task to see its journey")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $isAddingTask) {
            NavigationStack {
                Form {
                    Section("Intent Details") {
                        TextField("Task Title", text: $newTaskTitle)

                        Picker("Emoji Soul", selection: $newTaskEmoji) {
                            ForEach(emojis, id: \.self) { emoji in
                                Text(emoji).tag(emoji)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Section("Visual Resonance (Style)") {
                        Picker("Style", selection: $newTaskStyle) {
                            ForEach(TaskStyle.allCases, id: \.self) { style in
                                Label(style.rawValue, systemImage: style.icon).tag(style)
                            }
                        }
                        .pickerStyle(.menu)

                        StylePreviewSnippet(style: newTaskStyle) // StylePreviewSnippet must be defined elsewhere
                    }
                }
                .navigationTitle("New Intent")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isAddingTask = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            addItem()
                            isAddingTask = false
                        }
                        .disabled(newTaskTitle.isEmpty)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func addItem() {
    withAnimation {
        let newItem = Item(title: newTaskTitle, emoji: newTaskEmoji, style: newTaskStyle)
        modelContext.insert(newItem)
        newTaskTitle = ""
    }
}
}

#Preview {
    let container: ModelContainer
    do {
        container = try ModelContainer(for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    } catch {
        fatalError("Failed to create preview container")
    }

    return MainNavigationFlow()
        .modelContainer(container)
        .environment(TaskService(modelContext: container.mainContext))
        .environment(ExternalIntegrationService(modelContext: container.mainContext))
        .environment(TodoistService(modelContext: container.mainContext))
}
// Note: Due to missing Item definitions, the preview injection for Item.self may fail compilation outside of a complete project context.

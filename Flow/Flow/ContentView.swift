/**
 * 🎭 The ContentView - The Stage of Intent
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

enum NavigationItem: Hashable {
    case inbox
    case gallery
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TaskService.self) private var taskService: TaskService
    @Environment(ExternalIntegrationService.self) private var integrationService: ExternalIntegrationService
    @Environment(TodoistService.self) private var todoistService: TodoistService
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]

    /// Incoming deep-link / Universal Link route — set by FlowApp.onOpenURL.
    @Binding var activeRoute: FlowRoute?

    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskEmoji = "🎯"
    @State private var newTaskStyle = TaskStyle.sleekModern
    @State private var selection: NavigationItem? = .inbox

    let emojis = ["🎯", "📝", "💪", "📚", "📧", "🚀", "🎨", "💻", "🧠", "🌌", "🏗️", "📰", "📜", "🔥", "🌿", "🐙", "🕹️", "⚙️", "💎", "📦", "🚥", "🪟", "⚔️", "💧", "☀️", "🖍️", "🖤"]

    init(activeRoute: Binding<FlowRoute?> = .constant(nil)) {
        self._activeRoute = activeRoute
    }

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
                        TaskRow(item: item)
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
                    // Replaced .navigationBarLeading with .navigation
                    ToolbarItem(placement: .navigation) {
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

                    // Replaced .navigationBarTrailing with .primaryAction and made EditButton iOS/visionOS only
                    ToolbarItem(placement: .primaryAction) {
                        #if os(iOS) || os(visionOS)
                        EditButton()
                        #endif
                    }
                ToolbarItem(placement: .primaryAction) {
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
        // ── Deep-link / Universal Link routing ──────────────────
        .onChange(of: activeRoute) { _, newRoute in
            guard let route = newRoute else { return }
            FlowLogger.deepLink.info("🔗 ContentView routing to: \(String(describing: route))")
            switch route {
            case .inbox:
                selection = .inbox
            case .focus(let taskId):
                selection = .inbox
                // Start a focus session for the linked task if it exists
                Task {
                    let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == taskId })
                    if let task = try? modelContext.fetch(descriptor).first {
                        await taskService.startFocusSession(for: task)
                    }
                }
            case .styleGallery:
                selection = .gallery
            case .join, .appClipCapture:
                // Surface the new-task sheet for quick capture
                selection = .inbox
                isAddingTask = true
            }
            activeRoute = nil // consume the route
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

                        StylePreviewSnippet(style: newTaskStyle)
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

struct StylePreviewSnippet: View {
    let style: TaskStyle

    var body: some View {
        HStack {
            Image(systemName: style.icon)
                .foregroundStyle(.blue)
            Text(style.rawValue)
                .font(.caption)
            Spacer()
            Text(styleDescription)
                .font(.caption2)
                .italic()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var styleDescription: String {
        switch style {
        case .sleekModern: return "Elegant gradient design"
        case .zenFocus: return "Minimalist breathing interface"
        case .questMode: return "Gamified RPG experience"
        case .livingGarden: return "Nature-inspired growth"
        case .holographic: return "Futuristic sci-fi interface"
        case .stickyBoard: return "Physical sticky notes"
        case .timeline: return "Time-based visualization"
        case .ethereal: return "Calm, flow-state, weightless"
        case .cyberpunk: return "High-contrast neon"
        case .neoBrutalism: return "Bold, high-contrast grid"
        case .softClay: return "Soft, tactile depth"
        case .retroPixel: return "Chunky 8-bit nostalgia"
        case .frostedGlass: return "Blurred translucency"
        case .organicNature: return "Earthly tones and organic shapes"
        case .industrialTech: return "Raw metal and functional lines"
        case .popArt: return "Vibrant dots and bold colors"
        case .zenInk: return "Traditional brush strokes"
        case .cosmicNebula: return "Galactic dust and pulsing stars"
        case .blueprint: return "Architectural draft lines"
        case .sunsetSilk: return "Flowing twilight gradients"
        case .bioLuminescence: return "Glow of the deep ocean"
        case .vintageNewspaper: return "Ink-stained chronicle"
        case .abstractGeometric: return "Sharp angles and primary hues"
        case .magicalScroll: return "Enchanted parchment and spells"
        case .crystalPrism: return "Refracted light and shards"
        case .volcanicFlow: return "Molten lava and charcoal"
        case .cloudPeak: return "Airy heights and lightning"
        case .oceanFlow: return "Submerged deep-sea focus"
        case .spaceMission: return "Celestial starship command"
        case .vintageArcade: return "Neon-drenched high score"
        case .steampunk: return "Brass gears and steam"
        case .magicalForest: return "Glow of enchanted fireflies"
        case .midnightMonochrome: return "Ultra-minimal dark contrast"
        case .sunsetGlow: return "Warm twilight tranquility"
        case .cosmicVoid: return "Vast, empty starfields"
        case .industrialRust: return "Weathered metallic grit"
        case .crystalCave: return "Prismatic subterranean shards"
        case .glassmorphism: return "Frosted glass and soft blurs"
        case .opaqueBold: return "Solid, high-impact contrast"
        case .courierPrime: return "Delivery-grade tracking layout"
        case .pixelArtHero: return "16-bit hero's journey"
        case .circuitBoard: return "Electronic traces and data flow"
        case .liquidMetal: return "Flowing, reflective surfaces"
        case .velvetNight: return "Deep purple plush textures"
        case .sketchbook: return "Rough pencil and paper grain"
        case .solarFlare: return "Intense heat and solar radiation"
        case .deepSpace: return "The ultimate dark void focus"
        }
    }
}

struct TaskRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 15) {
            if item.emoji.hasPrefix("sf:") {
                Image(systemName: String(item.emoji.dropFirst(3)))
                    .font(.title2)
                    .padding(8)
                    .background(styleColor.opacity(0.1))
                    .clipShape(Circle())
            } else if item.style == .livingGarden || item.style == .magicalForest {
                Text(gardenEmoji(for: item.growthLevel))
                    .font(.title2)
                    .padding(8)
                    .background(styleColor.opacity(0.1))
                    .clipShape(Circle())
            } else {
                Text(item.emoji)
                    .font(.title2)
                    .padding(8)
                    .background(styleColor.opacity(0.1))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .strikethrough(item.isCompleted)
                    Spacer()
                    Image(systemName: item.style.icon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Label("\(item.snoozeCount)", systemImage: "zzz")
                        .contentTransition(.numericText())
                    Label("\(item.moveCount)", systemImage: "arrow.right.circle")
                        .contentTransition(.numericText())
                    Spacer()
                    Text(formatDuration(item.totalLingeringTime))
                        .font(.caption2.monospaced())
                        .contentTransition(.numericText())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var styleColor: Color {
        switch item.style {
        case .cyberpunk, .vintageArcade, .industrialRust, .volcanicFlow, .courierPrime: return .yellow
        case .neoBrutalism, .livingGarden, .magicalForest, .circuitBoard: return .green
        case .ethereal, .cosmicVoid, .cosmicNebula, .velvetNight: return .purple
        case .oceanFlow, .crystalCave, .blueprint, .liquidMetal: return .cyan
        case .spaceMission, .midnightMonochrome, .crystalPrism, .opaqueBold, .glassmorphism: return .white
        case .sunsetGlow, .questMode, .sunsetSilk, .solarFlare: return .orange
        case .steampunk, .vintageNewspaper, .sketchbook: return .brown
        case .bioLuminescence, .organicNature: return .teal
        case .popArt, .pixelArtHero: return .pink
        default: return .blue
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "0s"
    }

    private func gardenEmoji(for level: Int) -> String {
        switch level {
        case 0: return "🌱"
        case 1: return "🌿"
        case 2: return "🌳"
        case 3: return "🍎"
        default: return "🌱"
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

    return ContentView()
        .modelContainer(container)
        .environment(TaskService(modelContext: container.mainContext))
        .environment(ExternalIntegrationService(modelContext: container.mainContext))
}

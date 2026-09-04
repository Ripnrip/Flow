/**
 * 🧘 AMORDumpView — Session Dump & Export Interface
 *
 * "The bridge between inner work and outer reflection. Where the day's
 * sessions become a story, and the week's rhythm becomes a record
 * that can be carried into any second brain system."
 */

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct AMORDumpView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [DailySession]
    /// v5.2.0: engine inputs as Foundation snapshots (engines never touch @Models).
    private var sessionsSnap: [AMORSessionSnapshot] { sessions.map { $0.snapshot } }
    @Query private var practices: [PracticeStreak]
    /// v5.2.0: engine inputs as Foundation snapshots (engines never touch @Models).
    private var practicesSnap: [AMORPracticeSnapshot] { practices.map { $0.snapshot } }
    @Query private var cronJobs: [CronJobHealth]
    /// v5.2.0: engine inputs as Foundation snapshots (engines never touch @Models).
    private var cronJobsSnap: [AMORCronJobSnapshot] { cronJobs.map { $0.snapshot } }

    @State private var dumpGenerator = AMORDumpGenerator()
    @State private var tracker = AMORProgressTracker()
    @State private var selectedFormat: DumpFormat = .dailyMarkdown
    @State private var dumpContent: String = ""
    @State private var reflections: String = ""
    @State private var selectedMood: String = "neutral"
    @State private var showShareSheet = false
    @State private var showCopiedToast = false
    @State private var savedFileURL: URL?

    private let moodOptions = ["focused", "tired", "energized", "neutral", "stressed", "calm"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Format selector
                FormatSelector(selectedFormat: $selectedFormat)

                // Format-specific options
                if selectedFormat == .dailyMarkdown {
                    DailyOptionsSection(
                        mood: $selectedMood,
                        reflections: $reflections
                    )
                }

                // Generate button
                Button {
                    generateDump()
                } label: {
                    Label("Generate Dump", systemImage: "doc.text.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AMORColorPalette.deepIndigo)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }

                // Output preview
                if !dumpContent.isEmpty {
                    OutputPreviewSection(
                        content: dumpContent,
                        onCopy: copyToClipboard,
                        onSave: saveToFile,
                        onShare: { showShareSheet = true }
                    )
                }

                // Toast
                if showCopiedToast {
                    ToastView(message: "Copied to clipboard!", icon: "checkmark.circle.fill")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Session Dump")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showShareSheet) {
            if let url = savedFileURL {
                #if canImport(UIKit)
                ShareSheetView(url: url)
                #endif
            }
        }
        .animation(AMORAnimations.slowFade, value: showCopiedToast)
    }

    // MARK: - Actions

    private func generateDump() {
        switch selectedFormat {
        case .dailyMarkdown:
            dumpContent = dumpGenerator.generateDailyDump(
                sessions: sessionsSnap,
                practices: practicesSnap,
                cronJobs: cronJobsSnap,
                mood: selectedMood,
                reflections: reflections
            )
        case .weeklyMarkdown:
            dumpContent = dumpGenerator.generateWeeklyDump(
                sessions: sessionsSnap,
                practices: practicesSnap,
                cronJobs: cronJobsSnap,
                tracker: tracker
            )
        case .jsonExport:
            dumpContent = dumpGenerator.generateJSONExport(sessions: sessionsSnap) ?? "{}"
        case .csvExport:
            dumpContent = dumpGenerator.generateCSVExport(sessions: sessionsSnap)
        }
    }

    private func copyToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = dumpContent
        #endif
        withAnimation {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }

    private func saveToFile() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let ext: String
        switch selectedFormat {
        case .dailyMarkdown, .weeklyMarkdown: ext = "md"
        case .jsonExport: ext = "json"
        case .csvExport: ext = "csv"
        }

        let prefix: String
        switch selectedFormat {
        case .dailyMarkdown: prefix = "amor-daily"
        case .weeklyMarkdown: prefix = "amor-weekly"
        case .jsonExport: prefix = "amor-export"
        case .csvExport: prefix = "amor-csv"
        }

        let filename = "\(prefix)-\(dateFormatter.string(from: Date())).\(ext)"
        savedFileURL = dumpGenerator.saveDump(dumpContent, filename: filename)
    }
}

// MARK: - Format Selector

struct FormatSelector: View {
    @Binding var selectedFormat: DumpFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Format")
                .font(AMORTypography.titleFont)
                .foregroundStyle(AMORColorPalette.deepIndigo)

            VStack(spacing: 8) {
                ForEach(DumpFormat.allCases, id: \.self) { format in
                    Button {
                        withAnimation(AMORAnimations.thoughtfulAppear) {
                            selectedFormat = format
                        }
                    } label: {
                        HStack {
                            Image(systemName: iconFor(format))
                                .font(.title3)
                                .frame(width: 28)

                            Text(format.rawValue)
                                .font(AMORTypography.bodyFont)

                            Spacer()

                            if selectedFormat == format {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AMORColorPalette.sageGreen)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedFormat == format ?
                                      AMORColorPalette.deepIndigo.opacity(0.1) :
                                      Color(.systemBackground).opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedFormat == format ?
                                        AMORColorPalette.deepIndigo : Color.clear,
                                        lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func iconFor(_ format: DumpFormat) -> String {
        switch format {
        case .dailyMarkdown: return "sun.max"
        case .weeklyMarkdown: return "calendar.badge.clock"
        case .jsonExport: return "curlybraces"
        case .csvExport: return "tablecells"
        }
    }
}

// MARK: - Daily Options Section

struct DailyOptionsSection: View {
    @Binding var mood: String
    @Binding var reflections: String

    private let moodOptions = ["focused", "tired", "energized", "neutral", "stressed", "calm"]

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Reflection")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(AMORColorPalette.deepIndigo)

                Picker("Mood", selection: $mood) {
                    ForEach(moodOptions, id: \.self) { option in
                        Text(option.capitalized).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading) {
                    Text("Daily Reflection")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $reflections)
                        .frame(minHeight: 80)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemBackground).opacity(0.5)))
                }
            }
        }
    }
}

// MARK: - Output Preview Section

struct OutputPreviewSection: View {
    let content: String
    let onCopy: () -> Void
    let onSave: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(AMORColorPalette.deepIndigo)

                Spacer()

                // Action buttons
                HStack(spacing: 12) {
                    Button(action: onCopy) {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }

                    Button(action: onSave) {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .font(.caption)
                    }

                    Button(action: onShare) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                }
            }

            ScrollView {
                Text(content)
                    .font(AMORTypography.monospaceFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxHeight: 400)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground).opacity(0.8)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AMORColorPalette.charcoal.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    let message: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.green)
            Text(message)
                .font(.subheadline.bold())
        }
        .padding()
        .background(Capsule().fill(.ultraThinMaterial))
        .shadow(radius: 4)
        .frame(maxWidth: .infinity)
        .padding(.bottom)
    }
}

// MARK: - Share Sheet

#if canImport(UIKit)
struct ShareSheetView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Preview

#if DEBUG
#Preview("Dump") {
    NavigationStack {
        AMORDumpView()
            .modelContainer(for: [Item.self, DailySession.self, PracticeStreak.self, CronJobHealth.self, DailySummary.self, SecondBrainEntry.self])
    }
}
#endif

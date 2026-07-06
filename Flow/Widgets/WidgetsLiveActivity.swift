/**
 * 🏝️ WidgetsLiveActivity — The Peripheral Island Experience
 *
 * "A live window into your current focus session—visible on the
 *  Lock Screen, in Dynamic Island, and on StandBy. Rich hierarchy,
 *  purposeful motion, and one-tap actions that never open the app."
 *
 * Layout matrix
 * ──────────────────────────────────────────────────────────────
 *  Presentation           │ Primary content
 * ──────────────────────────────────────────────────────────────
 *  Lock Screen / Banner   │ StyleBackground + emoji + title +
 *                         │ elapsed timer + configurable actions
 *  Dynamic Island Compact │ Leading: animated emoji
 *                         │ Trailing: live elapsed timer
 *  Dynamic Island Minimal │ Animated emoji only
 *  Dynamic Island Expanded│ Leading: emoji | Center: title
 *                         │ Trailing: timer | Bottom: progress +
 *                         │ Liquid Glass action buttons
 * ──────────────────────────────────────────────────────────────
 *
 * Motion principles (aligned with HIG "Motion" guidelines)
 *   • SF Symbols `.pulse` — subtle on ambient state badges
 *   • SF Symbols `.bounce` — momentary on button icon at appear
 *   • SF Symbols `.wiggle` — calls out the snooze count increment
 *   • `FluidWaveView` transition wave — fires only on state changes,
 *     not on idle renders, so it never becomes gratuitous
 *
 * Action buttons
 *   • Configurable leading/trailing actions via `LiveActivityConfiguration`.
 *   • Each uses `Button(intent:)` backed by a `LiveActivityIntent`.
 *   • Liquid Glass styling applied on iOS 26+ via `.glassEffect()`.
 *
 * HIG: developer.apple.com/design/human-interface-guidelines/live-activities
 */

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 🧮 Progress Helpers

extension FlowAttributes.ContentState {
    /// Elapsed focus time, excluding paused periods.
    var effectiveElapsed: TimeInterval {
        let raw = Date().timeIntervalSince(startDate)
        return max(0, raw - elapsedPauseSeconds)
    }

    /// Progress toward the focus target (0...1).
    var progress: Double {
        let target = TimeInterval(focusTargetMinutes * 60)
        guard target > 0 else { return 0 }
        return min(effectiveElapsed / target, 1.0)
    }
}

// MARK: - 🎨 Progress Ring View

struct ProgressRingView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let animate: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(animate ? .easeInOut(duration: 0.6) : .none, value: progress)
        }
    }
}

// MARK: - ✨ Symbol Effect Helper

/// A tiny shim that lets us pass symbol effects around as values.
/// Real SwiftUI SymbolEffects are protocol types, so we wrap the cases
/// we actually use in the Live Activity for easy conditional animation. 🎭
enum SymbolWiggleEffect {
    case wiggle(value: Int)
    case bounce(value: Bool)
}

extension Image {
    @ViewBuilder
    func liveActivitySymbolEffect(_ effect: SymbolWiggleEffect?) -> some View {
        switch effect {
        case .wiggle(let value):
            self.symbolEffect(.wiggle, value: value)
        case .bounce(let value):
            self.symbolEffect(.bounce, value: value)
        case .none:
            self
        }
    }
}

// MARK: - 🔘 Configurable Action Button

struct LiveActivityActionButton: View {
    let action: LiveActivityAction
    let taskId: String
    let style: TaskStyle
    let snoozeCount: Int
    let isPaused: Bool
    let animationIntensity: LiveActivityAnimationIntensity

    var body: some View {
        switch action {
        case .snooze:
            actionIntentButton(
                intent: SnoozeIntent(taskId: taskId),
                icon: "bed.double.fill",
                label: "Snooze",
                color: style.themeForegroundColor(),
                symbolEffect: animationIntensity == .calm ? nil : .wiggle(value: snoozeCount)
            )
        case .done:
            actionIntentButton(
                intent: DoneIntent(taskId: taskId),
                icon: "checkmark.circle.fill",
                label: liveActivityDoneLabel(for: style),
                color: .white,
                background: style.themeAccentColor(),
                symbolEffect: animationIntensity == .calm ? nil : .bounce(value: true)
            )
        case .pauseResume:
            actionIntentButton(
                intent: PauseResumeIntent(taskId: taskId),
                icon: isPaused ? "play.fill" : "pause.fill",
                label: isPaused ? "Resume" : "Pause",
                color: style.themeForegroundColor(),
                symbolEffect: nil
            )
        case .extend:
            actionIntentButton(
                intent: ExtendFocusIntent(taskId: taskId),
                icon: "plus.circle.fill",
                label: "+5 min",
                color: style.themeForegroundColor(),
                symbolEffect: nil
            )
        }
    }

    private func actionIntentButton<I: LiveActivityIntent>(
        intent: I,
        icon: String,
        label: String,
        color: Color,
        background: Color? = nil,
        symbolEffect: SymbolWiggleEffect?
    ) -> some View {
        Button(intent: intent) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .liveActivitySymbolEffect(symbolEffect)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .background(background ?? style.themeForegroundColor().opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

// MARK: - 🏝️ Live Activity Widget

struct WidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlowAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                expandedLeading(context: context)
                expandedTrailing(context: context)
                expandedCenter(context: context)
                expandedBottom(context: context)
            } compactLeading: {
                compactLeadingView(context: context)
            } compactTrailing: {
                compactTrailingView(context: context)
            } minimal: {
                minimalView(context: context)
            }
            .widgetURL(FlowRoute.focus(
                taskId: UUID(uuidString: context.attributes.taskId) ?? UUID()
            ).customURL)
            .keylineTint(context.state.style.themeAccentColor())
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - 📱 Lock Screen / Banner
    // ─────────────────────────────────────────────────────────

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<FlowAttributes>) -> some View {
        let style = context.state.style

        ZStack {
            StyleBackground(style: style)
            StyleTransitionWave(style: style, triggerDate: context.state.lastInteractionDate)

            VStack(spacing: 12) {
                // ── Top row: emoji / title / metric ──────────────────
                HStack(spacing: 12) {
                    BreathingEmojiView(
                        emoji: context.state.emoji,
                        style: style,
                        compact: false,
                        growthLevel: context.state.growthLevel
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(style.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(style.themeAccentColor())

                        Text(context.state.title)
                            .font(style.themeFont(size: .headline))
                            .foregroundStyle(style.themeForegroundColor())
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .symbolEffect(.pulse, isActive: true)
                                .font(.caption2)
                                .foregroundStyle(style.themeAccentColor())
                            Text(context.state.startDate, style: .timer)
                                .font(.caption2.monospacedDigit().bold())
                                .foregroundStyle(style.themeForegroundColor().opacity(0.7))
                        }
                    }

                    Spacer()

                    StyleMetricView(
                        style: style,
                        snoozeCount: context.state.snoozeCount,
                        moveCount: context.state.moveCount
                    )
                }

                // ── Bottom row: configurable action buttons ───────────
                HStack(spacing: 10) {
                    LiveActivityActionButton(
                        action: context.state.leadingAction,
                        taskId: context.attributes.taskId,
                        style: style,
                        snoozeCount: context.state.snoozeCount,
                        isPaused: context.state.isPaused,
                        animationIntensity: context.state.animationIntensity
                    )
                    LiveActivityActionButton(
                        action: context.state.trailingAction,
                        taskId: context.attributes.taskId,
                        style: style,
                        snoozeCount: context.state.snoozeCount,
                        isPaused: context.state.isPaused,
                        animationIntensity: context.state.animationIntensity
                    )
                }
            }
            .padding(14)
        }
        .activityBackgroundTint(style.themeBackgroundColor())
        .activitySystemActionForegroundColor(style.themeForegroundColor())
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - 🌟 Dynamic Island — Expanded Regions
    // ─────────────────────────────────────────────────────────

    @DynamicIslandExpandedContentBuilder
    private func expandedLeading(context: ActivityViewContext<FlowAttributes>) -> DynamicIslandExpandedContent<some View> {
        DynamicIslandExpandedRegion(.leading) {
            BreathingEmojiView(
                emoji: context.state.emoji,
                style: context.state.style,
                compact: false,
                growthLevel: context.state.growthLevel
            )
            .frame(width: 36, height: 36)
            .padding(.leading, 6)
        }
    }

    @DynamicIslandExpandedContentBuilder
    private func expandedTrailing(context: ActivityViewContext<FlowAttributes>) -> DynamicIslandExpandedContent<some View> {
        DynamicIslandExpandedRegion(.trailing) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(context.state.startDate, style: .timer)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(context.state.style.themeAccentColor())

                // Snooze count badge
                if context.state.snoozeCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "zzz")
                            .symbolEffect(.wiggle, value: context.state.snoozeCount)
                            .font(.system(size: 9))
                        Text("\(context.state.snoozeCount)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(context.state.style.themeForegroundColor().opacity(0.6))
                }
            }
            .padding(.trailing, 6)
        }
    }

    @DynamicIslandExpandedContentBuilder
    private func expandedCenter(context: ActivityViewContext<FlowAttributes>) -> DynamicIslandExpandedContent<some View> {
        DynamicIslandExpandedRegion(.center) {
            Text(context.state.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(context.state.style.themeForegroundColor())
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
    }

    @DynamicIslandExpandedContentBuilder
    private func expandedBottom(context: ActivityViewContext<FlowAttributes>) -> DynamicIslandExpandedContent<some View> {
        DynamicIslandExpandedRegion(.bottom) {
            let style = context.state.style
            VStack(spacing: 8) {
                // Progress indicator — ring or bar, configured by the user.
                if context.state.showProgressRing {
                    ProgressRingView(
                        progress: context.state.progress,
                        color: style.themeAccentColor(),
                        lineWidth: 4,
                        animate: context.state.animationIntensity != .calm
                    )
                    .frame(width: 28, height: 28)
                } else {
                    // 🎯 Linear fallback uses the same progress math as the ring,
                    //    honoring pause time and the user's focus target.
                    let progress = context.state.progress
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(style.themeForegroundColor().opacity(0.15))
                            Capsule()
                                .fill(style.themeAccentColor())
                                .frame(width: geo.size.width * progress)
                                .animation(context.state.animationIntensity != .calm ? .easeInOut(duration: 0.6) : .none, value: progress)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 14)
                }

                // Action buttons with Liquid Glass
                HStack(spacing: 8) {
                    LiveActivityActionButton(
                        action: context.state.leadingAction,
                        taskId: context.attributes.taskId,
                        style: style,
                        snoozeCount: context.state.snoozeCount,
                        isPaused: context.state.isPaused,
                        animationIntensity: context.state.animationIntensity
                    )
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))

                    LiveActivityActionButton(
                        action: context.state.trailingAction,
                        taskId: context.attributes.taskId,
                        style: style,
                        snoozeCount: context.state.snoozeCount,
                        isPaused: context.state.isPaused,
                        animationIntensity: context.state.animationIntensity
                    )
                    .glassEffect(.regular.tint(style.themeAccentColor()), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 10)
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - 🔸 Compact & Minimal
    // ─────────────────────────────────────────────────────────

    @ViewBuilder
    private func compactLeadingView(context: ActivityViewContext<FlowAttributes>) -> some View {
        BreathingEmojiView(
            emoji: context.state.emoji,
            style: context.state.style,
            compact: true,
            growthLevel: context.state.growthLevel
        )
        .padding(.leading, 2)
    }

    @ViewBuilder
    private func compactTrailingView(context: ActivityViewContext<FlowAttributes>) -> some View {
        // Live timer is more informative than a static snooze count in compact.
        Text(context.state.startDate, style: .timer)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(context.state.style.themeAccentColor())
            .padding(.trailing, 2)
    }

    @ViewBuilder
    private func minimalView(context: ActivityViewContext<FlowAttributes>) -> some View {
        BreathingEmojiView(
            emoji: context.state.emoji,
            style: context.state.style,
            compact: true,
            growthLevel: context.state.growthLevel
        )
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - 🎨 Style Helpers
    // ─────────────────────────────────────────────────────────
}

/// 🏷️ Maps a task style to a thematic "complete" label for the Done action.
private func liveActivityDoneLabel(for style: TaskStyle) -> String {
    switch style {
    case .questMode:     return "Slay"
    case .magicalScroll: return "Cast"
    case .volcanicFlow:  return "Extinguish"
    case .livingGarden:  return "Harvest"
    case .spaceMission:  return "Deploy"
    case .courierPrime:  return "Delivered"
    default:             return "Done"
    }
}

// MARK: - 🧪 Preview Support

extension FlowAttributes {
    static var preview: FlowAttributes { FlowAttributes(taskId: UUID().uuidString) }
}

extension FlowAttributes.ContentState {

    static var focusSession: FlowAttributes.ContentState {
        make(emoji: "💻", title: "Review Codebase Logic", style: .cyberpunk)
    }
    static var gardenSession: FlowAttributes.ContentState {
        make(emoji: "🌿", title: "Write Weekly Report", style: .livingGarden)
    }
    static var cyberpunk: FlowAttributes.ContentState {
        make(emoji: "💻", title: "Cyberpunk Flow", style: .cyberpunk)
    }
    static var livingGarden: FlowAttributes.ContentState {
        make(emoji: "🌿", title: "Living Garden", style: .livingGarden)
    }
    static var volcanicFlow: FlowAttributes.ContentState {
        make(emoji: "🌋", title: "Volcanic Flow", style: .volcanicFlow)
    }
    static var cosmicNebula: FlowAttributes.ContentState {
        make(emoji: "✨", title: "Cosmic Nebula", style: .cosmicNebula)
    }
    static var spaceMission: FlowAttributes.ContentState {
        make(emoji: "🚀", title: "Space Mission", style: .spaceMission)
    }
    static var oceanFlow: FlowAttributes.ContentState {
        make(emoji: "🌊", title: "Ocean Flow", style: .oceanFlow)
    }
    static var solarFlare: FlowAttributes.ContentState {
        make(emoji: "☀️", title: "Solar Flare", style: .solarFlare)
    }
    static var questMode: FlowAttributes.ContentState {
        make(emoji: "⚔️", title: "Quest Mode", style: .questMode)
    }
    static var magicalScroll: FlowAttributes.ContentState {
        make(emoji: "📜", title: "Magical Scroll", style: .magicalScroll)
    }
    static var courierPrime: FlowAttributes.ContentState {
        make(emoji: "📦", title: "Courier Prime", style: .courierPrime)
    }

    static func make(emoji: String, title: String, style: TaskStyle) -> FlowAttributes.ContentState {
        FlowAttributes.ContentState(
            title: title,
            snoozeCount: 2,
            moveCount: 1,
            startDate: Date().addingTimeInterval(-1800),
            emoji: emoji,
            style: style,
            lastInteractionDate: .now,
            growthLevel: 1,
            isPaused: false,
            focusTargetMinutes: 25,
            elapsedPauseSeconds: 0,
            leadingActionRawValue: LiveActivityAction.snooze.rawValue,
            trailingActionRawValue: LiveActivityAction.done.rawValue,
            showProgressRing: true,
            animationIntensityRawValue: LiveActivityAnimationIntensity.normal.rawValue
        )
    }
}

// MARK: Previews

#Preview("Lock Screen", as: .content, using: FlowAttributes.preview) {
    WidgetsLiveActivity()
} contentStates: {
    FlowAttributes.ContentState.cyberpunk
    FlowAttributes.ContentState.livingGarden
    FlowAttributes.ContentState.volcanicFlow
    FlowAttributes.ContentState.cosmicNebula
    FlowAttributes.ContentState.spaceMission
    FlowAttributes.ContentState.questMode
    FlowAttributes.ContentState.courierPrime
}

#Preview("Dynamic Island — Compact", as: .dynamicIsland(.compact), using: FlowAttributes.preview) {
    WidgetsLiveActivity()
} contentStates: {
    FlowAttributes.ContentState.cyberpunk
    FlowAttributes.ContentState.livingGarden
    FlowAttributes.ContentState.volcanicFlow
}

#Preview("Dynamic Island — Minimal", as: .dynamicIsland(.minimal), using: FlowAttributes.preview) {
    WidgetsLiveActivity()
} contentStates: {
    FlowAttributes.ContentState.cyberpunk
    FlowAttributes.ContentState.livingGarden
}

#Preview("Dynamic Island — Expanded", as: .dynamicIsland(.expanded), using: FlowAttributes.preview) {
    WidgetsLiveActivity()
} contentStates: {
    FlowAttributes.ContentState.cyberpunk
    FlowAttributes.ContentState.livingGarden
    FlowAttributes.ContentState.volcanicFlow
    FlowAttributes.ContentState.cosmicNebula
    FlowAttributes.ContentState.spaceMission
    FlowAttributes.ContentState.magicalScroll
}

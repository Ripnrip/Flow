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
    /// While paused we also subtract the in-progress pause interval so
    /// the timer actually freezes instead of sneaking forward. 🧊⏱️
    var effectiveElapsed: TimeInterval {
        let raw = Date().timeIntervalSince(startDate)
        var pauseDuration = elapsedPauseSeconds
        if isPaused, let pauseStartDate {
            pauseDuration += Date().timeIntervalSince(pauseStartDate)
        }
        return max(0, raw - pauseDuration)
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
    var intensity: LiveActivityAnimationIntensity = .normal

    /// The static ring — background track + progress arc.
    private var ringContent: some View {
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

    var body: some View {
        if intensity == .lively {
            // 🎠 Keep the ring twirling in the lively intensity so it feels
            //    more energetic than the calm/normal variants.
            TimelineView(.animation(minimumInterval: 0.05, paused: false)) { timeline in
                ringContent
                    .rotationEffect(.degrees(timeline.date.timeIntervalSinceReferenceDate * 180))
            }
        } else {
            ringContent
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
    case pulse(isActive: Bool)
}

extension Image {
    @ViewBuilder
    func liveActivitySymbolEffect(_ effect: SymbolWiggleEffect?) -> some View {
        switch effect {
        case .wiggle(let value):
            self.symbolEffect(.wiggle, value: value)
        case .bounce(let value):
            self.symbolEffect(.bounce, value: value)
        case .pulse(let isActive):
            self.symbolEffect(.pulse, isActive: isActive)
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
                symbolEffect: animationIntensity == .calm
                    ? nil
                    : .wiggle(value: animationIntensity == .lively ? snoozeCount + 1 : snoozeCount)
            )
        case .done:
            actionIntentButton(
                intent: DoneIntent(taskId: taskId),
                icon: "checkmark.circle.fill",
                label: liveActivityDoneLabel(for: style),
                color: .white,
                background: style.themeAccentColor(),
                symbolEffect: animationIntensity == .calm
                    ? nil
                    : .bounce(value: animationIntensity == .lively ? snoozeCount.isMultiple(of: 2) : true)
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
                    .liveActivitySymbolEffect(effectiveSymbolEffect(for: symbolEffect))
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(color)
            .scaleEffect(animationIntensity == .lively ? 1.05 : 1.0)
            .animation(
                animationIntensity == .lively
                    ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                    : .default,
                value: animationIntensity == .lively
            )
        }
        .buttonStyle(.plain)
        .background(background ?? style.themeForegroundColor().opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    /// If the caller didn't supply a symbol effect, `.lively` gets a gentle
    /// pulse so every button participates in the more energetic mode. ✨
    private func effectiveSymbolEffect(for effect: SymbolWiggleEffect?) -> SymbolWiggleEffect? {
        if let effect { return effect }
        if animationIntensity == .lively { return .pulse(isActive: true) }
        return nil
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
            .widgetURL(URL(string: "flow://task/\(context.attributes.taskId)"))
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
                    ZStack {
                        if context.state.showProgressRing {
                            ProgressRingView(
                                progress: context.state.progress,
                                color: style.themeAccentColor(),
                                lineWidth: 5,
                                animate: context.state.animationIntensity != .calm,
                                intensity: context.state.animationIntensity
                            )
                            .frame(width: 62, height: 62)
                        }

                        BreathingEmojiView(
                            emoji: context.state.emoji,
                            style: style,
                            compact: false,
                            growthLevel: context.state.growthLevel
                        )
                        .frame(width: 48, height: 48)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(eyebrow(for: context.state))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(style.themeAccentColor())

                        Text(context.state.title)
                            .font(style.themeFont(size: .headline))
                            .foregroundStyle(style.themeForegroundColor())
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        HStack(spacing: 6) {
                            Image(systemName: context.state.sourceLabel == "Reminders" ? "bell.badge.fill" : "timer")
                                .symbolEffect(.pulse, isActive: true)
                                .font(.caption2)
                                .foregroundStyle(style.themeAccentColor())
                            Text(detailBadge(for: context.state))
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
        .overlay(completionFlash(didComplete: context.state.didComplete))
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
                Text(context.state.sourceLabel == "Reminders" ? detailBadge(for: context.state) : timerText(for: context.state))
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
            VStack(spacing: 2) {
                Text(eyebrow(for: context.state))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(context.state.style.themeAccentColor())
                Text(context.state.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(context.state.style.themeForegroundColor())
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    @DynamicIslandExpandedContentBuilder
    private func expandedBottom(context: ActivityViewContext<FlowAttributes>) -> DynamicIslandExpandedContent<some View> {
        DynamicIslandExpandedRegion(.bottom) {
            let style = context.state.style
            let queue = context.state.reminderQueue
            let isReminderQueue = !queue.isEmpty

            VStack(spacing: 8) {
                // ── Rich Reminder Queue Strip ─────────────────────────
                // Only show for Apple Reminders — a horizontal scroll of
                // themed mini-cards, each carrying its own style accent.
                if isReminderQueue {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(queue.enumerated()), id: \.element.id) { index, item in
                                ReminderQueueCard(
                                    item: item,
                                    isActive: index == 0,
                                    accentColor: item.style.themeAccentColor()
                                )
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                    .frame(height: 56)
                }

                // ── Progress bar (focus session only) ─────────────────
                if !isReminderQueue {
                    let elapsed  = min(Date().timeIntervalSince(context.state.startDate), 1800)
                    let progress = elapsed / 1800.0
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(style.themeForegroundColor().opacity(0.15))
                            Capsule()
                                .fill(style.themeAccentColor())
                                .frame(width: geo.size.width * progress)
                                .animation(.easeInOut(duration: 0.6), value: progress)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 14)
                }

                // ── Queue summary badge ───────────────────────────────
                if let queueBadge = queueBadge(for: context.state) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.stack.3d.up.fill")
                        Text(queueBadge)
                        if let notes = context.state.notesPreview, !notes.isEmpty {
                            Text("•")
                            Text(notes).lineLimit(1)
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(style.themeForegroundColor().opacity(0.75))
                    .padding(.horizontal, 14)
                }

                // ── Action buttons with Liquid Glass ──────────────────
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

                    if isReminderQueue {
                        // ── Reminder-queue mode: Next + Done ──────────────
                        if queue.count > 1 {
                            Button(intent: NextReminderIntent(taskId: context.attributes.taskId)) {
                                HStack(spacing: 4) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 13))
                                    Text("Next")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .foregroundStyle(style.themeForegroundColor())
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                        }

                        Button(intent: DoneIntent(taskId: context.attributes.taskId)) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .symbolEffect(.bounce, value: true)
                                    .font(.system(size: 13))
                                Text(doneLabel(for: style))
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(style.themeAccentColor()), in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        // ── Focus mode: user-configured action buttons ────
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
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 10)
            .overlay(completionFlash(didComplete: context.state.didComplete))
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - 🔸 Compact & Minimal
    // ─────────────────────────────────────────────────────────

    @ViewBuilder
    private func compactLeadingView(context: ActivityViewContext<FlowAttributes>) -> some View {
        ZStack {
            if context.state.showProgressRing {
                ProgressRingView(
                    progress: context.state.progress,
                    color: context.state.style.themeAccentColor(),
                    lineWidth: 3,
                    animate: context.state.animationIntensity != .calm,
                    intensity: context.state.animationIntensity
                )
                .frame(width: 34, height: 34)
            }

            BreathingEmojiView(
                emoji: context.state.emoji,
                style: context.state.style,
                compact: true,
                growthLevel: context.state.growthLevel
            )
            .frame(width: 26, height: 26)
        }
        .padding(.leading, 2)
    }

    @ViewBuilder
    private func compactTrailingView(context: ActivityViewContext<FlowAttributes>) -> some View {
        let queueCount = context.state.reminderQueue.count
        let isReminder = context.state.sourceLabel == "Reminders"

        HStack(spacing: 2) {
            Text(isReminder ? detailBadge(for: context.state) : timerText(for: context.state))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(context.state.style.themeAccentColor())

            // Queue count badge for reminders
            if isReminder && queueCount > 1 {
                Text("\(queueCount)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(context.state.style.themeForegroundColor().opacity(0.6))
            }
        }
        .padding(.trailing, 2)
    }

    @ViewBuilder
    private func minimalView(context: ActivityViewContext<FlowAttributes>) -> some View {
        let queueCount = context.state.reminderQueue.count
        if queueCount > 1 {
            // Show count badge overlay for minimal mode
            ZStack(alignment: .topTrailing) {
                BreathingEmojiView(
                    emoji: context.state.emoji,
                    style: context.state.style,
                    compact: true,
                    growthLevel: context.state.growthLevel
                )
                Text("\(queueCount)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(2)
                    .background(Circle().fill(context.state.style.themeAccentColor()))
                    .offset(x: 8, y: -6)
            }
        } else {
            BreathingEmojiView(
                emoji: context.state.emoji,
                style: context.state.style,
                compact: true,
                growthLevel: context.state.growthLevel
            )
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - 🎨 Style Helpers
    // ─────────────────────────────────────────────────────────

    /// A brief green flash + checkmark burst shown the moment a task is
    /// completed. `DoneIntent` sets `didComplete = true`, pushes the state,
    /// waits ~0.6s, then ends the activity. 🎉✅
    @ViewBuilder
    private func completionFlash(didComplete: Bool) -> some View {
        if didComplete {
            ZStack {
                Color.green.opacity(0.35)
                    .ignoresSafeArea()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: true)
            }
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.2), value: didComplete)
        }
    }

    private func eyebrow(for state: FlowAttributes.ContentState) -> String {
        state.sourceLabel == "Reminders" ? "REMINDER" : state.style.rawValue.uppercased()
    }

    private func detailBadge(for state: FlowAttributes.ContentState) -> String {
        guard state.sourceLabel == "Reminders" else { return timerText(for: state) }
        guard let dueDate = state.dueDate else { return "No time" }
        let delta = dueDate.timeIntervalSince(.now)
        if delta < -60 { return "Overdue" }
        if delta <= 60 * 60 { return "Due soon" }
        if Calendar.current.isDateInToday(dueDate) { return "Today" }
        if Calendar.current.isDateInTomorrow(dueDate) { return "Tomorrow" }
        return "Upcoming"
    }

    private func queueBadge(for state: FlowAttributes.ContentState) -> String? {
        guard let queueTotal = state.queueTotal, queueTotal > 1 else { return nil }
        return "\(queueTotal) reminders in orbit"
    }

    private func timerText(for state: FlowAttributes.ContentState) -> String {
        let elapsed = max(0, Int(Date().timeIntervalSince(state.startDate)))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - 🃏 Reminder Queue Card

/// A rich themed mini-card for a single reminder in the Dynamic Island queue strip.
/// The active (first) card gets a highlighted border; overdue items pulse red.
struct ReminderQueueCard: View {
    let item: ReminderQueueItem
    let isActive: Bool
    let accentColor: Color

    var body: some View {
        HStack(spacing: 7) {
            // Emoji with subtle breathing for active card
            Text(item.emoji)
                .font(.system(size: 20))
                .scaleEffect(isActive ? 1.1 : 1.0)
                .symbolEffect(.bounce, value: isActive)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: 120, alignment: .leading)

                HStack(spacing: 3) {
                    if item.isOverdue {
                        Circle()
                            .fill(.red)
                            .frame(width: 5, height: 5)
                            .symbolEffect(.pulse, isActive: item.isOverdue)
                    }
                    Text(item.dueBadge)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(item.isOverdue ? .red.opacity(0.9) : accentColor)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.black.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isActive ? accentColor.opacity(0.8) : accentColor.opacity(0.2),
                    lineWidth: isActive ? 1.5 : 0.5
                )
        )
        .glassEffect(
            isActive ? .regular.tint(accentColor.opacity(0.15)) : .regular,
            in: RoundedRectangle(cornerRadius: 10)
        )
    }
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

    /// Preview state with a rich multi-reminder queue for Dynamic Island testing.
    static var reminderQueue: FlowAttributes.ContentState {
        var state = make(emoji: "📚", title: "Read monographs — Chapter 4", style: .magicalScroll)
        state.sourceLabel = "Reminders"
        state.dueDate = Date().addingTimeInterval(30 * 60)
        state.reminderQueue = [
            ReminderQueueItem(id: "1", title: "Read monographs — Chapter 4", emoji: "📚", styleRawValue: "Magical Scroll", dueDate: Date().addingTimeInterval(30*60), isOverdue: false, notesPreview: nil),
            ReminderQueueItem(id: "2", title: "Morning meditation", emoji: "🧘", styleRawValue: "Zen Focus", dueDate: Date().addingTimeInterval(2*60*60), isOverdue: false, notesPreview: nil),
            ReminderQueueItem(id: "3", title: "Follow up with Sam", emoji: "📬", styleRawValue: "Courier Prime", dueDate: Date().addingTimeInterval(-30*60), isOverdue: true, notesPreview: nil),
            ReminderQueueItem(id: "4", title: "Gym session", emoji: "💪", styleRawValue: "Quest Mode", dueDate: Date().addingTimeInterval(5*60*60), isOverdue: false, notesPreview: "Leg day"),
            ReminderQueueItem(id: "5", title: "Review PR #42", emoji: "✅", styleRawValue: "Sleek Modern", dueDate: nil, isOverdue: false, notesPreview: nil)
        ]
        state.queueTotal = state.reminderQueue.count
        return state
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
    FlowAttributes.ContentState.reminderQueue
}

# Always-Visible Productivity Companion (HLD)

## Platform
iOS (Dynamic Island, Live Activities), watchOS, macOS

## Status
Concept / Vision

---

## 1. Vision & Problem Statement

Modern productivity systems rely heavily on time-based reminders and notifications, which are easy to miss or dismiss. As tasks spread across calendars, reminders, and third-party tools, users lose continuous awareness of what actually matters *right now*.

**Vision:**  
Create an always-present, glanceable, elegant productivity companion that lives in system surfaces like Dynamic Island, Live Activities, widgets, and watch complications—providing persistent awareness without noise or anxiety.

This is not another reminder app.  
This is **ambient productivity visibility**.

---

## 2. Core Concept

A Live Activity–driven productivity layer that:
- Is always accessible
- Gently animates to maintain awareness
- Surfaces contextually relevant tasks
- Syncs across Apple devices
- Feels calm, intentional, and alive

> “My day, breathing quietly at the top of my screen.”

---

## 3. System Surfaces

### iOS
- Dynamic Island (minimal, compact, expanded)
- Live Activities (Lock Screen)
- Home Screen Widgets (WidgetKit)
- Siri + App Intents

### watchOS
- Live Activity mirroring
- Complications
- Contextual haptics

### macOS
- Menu bar presence
- Notification Center widgets
- Continuity sync

---

## 4. Dynamic Island Interaction Model

### Minimal / Idle
- Subtle pulse or breathing animation
- Indicates presence of important tasks
- No text overload

### Compact / Active
- Shows next priority task or event
- Progress ring or countdown
- Tap to expand

### Expanded
- Mini dashboard
- Top 3 tasks
- One primary action (done, snooze, focus)
- No scrolling

---

## 5. Intelligence & Prioritization

### Inputs
- Apple Calendar
- Apple Reminders
- Todoist API
- Trello API

### Signals
- Time proximity
- Priority
- Estimated duration
- Focus mode
- Historical behavior

### Output
- One clear “what matters now” signal

---

## 6. Sync Philosophy

All tasks normalize into a unified internal model:
- Task
- Event
- Block
- Deadline
- Floating priority

Source is invisible to the user.

---

## 7. Customization

User controls:
- Allowed sources
- Max surfaced items
- Animation intensity
- Focus modes

Defaults should be excellent.

---

## 8. Visual & Motion Design

- SF Symbols (variable rendering)
- Subtle kinetic motion
- Translucency and depth
- Motion communicates state, not decoration

---

## 9. Accessibility

- Respects Apple HIG
- High contrast
- Reduced motion
- VoiceOver friendly
- Never relies on color alone

---

## 10. Success Criteria

- Fewer missed priorities
- Reduced anxiety
- Habitual glance usage
- Feels native to the OS

---

## 11. Next Steps

- Visual exploration
- Motion prototypes
- Live Activity POC
- Priority logic testing
- Watch + Mac expansion

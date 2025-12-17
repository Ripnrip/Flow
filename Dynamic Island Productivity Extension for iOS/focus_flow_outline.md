# Focus Flow: Dynamic Island Productivity Extension Outline

## 1. Core Concept and Vibe

**Name:** Focus Flow
**Concept:** A unified, glanceable productivity hub delivered via a **Live Activity** that surfaces the single most critical task or reminder from multiple sources directly in the Dynamic Island. It is designed to be a "little productivity companion" that is **always there but never overwhelming**.
**Vibe:** Modern, elegant, and slightly playful, utilizing smooth, subtle animations and a clean, high-contrast aesthetic suitable for the Dynamic Island's black background.

## 2. Data Integration and Prioritization Logic

The extension acts as a unified command center, requiring secure, user-authorized access to multiple third-party APIs.

### Data Sources
*   **Native:** Apple Reminders, Apple Calendar (events starting within a configurable window, e.g., 30 minutes).
*   **Third-Party:** ToDoist (via API), Trello (via API).

### Prioritization Logic (Determining the "Top Task")
The Live Activity will display the single most relevant item based on the following hierarchy:

1.  **User-Defined Focus Task:** A task manually pinned by the user in the main Focus Flow app.
2.  **Highest Priority Task:** Tasks marked as Priority 1 in ToDoist or tagged as "Urgent" in Trello.
3.  **Imminent Calendar Event:** The next event starting within the next 30 minutes.
4.  **Closest Due Date/Time:** The task with the nearest due time from any source.
5.  **New Reminder/Task:** Any item added in the last 5 minutes (to provide immediate feedback).
6.  **Default State:** If no tasks meet the criteria, the Island displays a simple "All Clear" status or a motivational quote.

## 3. Visual States and HIG Mapping

The user's requested states are mapped directly to the technical presentations required by the Dynamic Island's Live Activity framework [1].

| User State | HIG Presentation | Trigger/Condition | Content and Purpose |
| :--- | :--- | :--- | :--- |
| **Idle State** (Subtle Pulse) | **Compact Presentation** | One Live Activity active; a "Top Task" is present. | **Leading:** App Icon + Subtle Pulse Animation (indicating a task is active). **Trailing:** Glanceable metric, e.g., "3 Tasks" (total for the day) or "Due 10:30" (time of the Top Task). *Purpose: Non-intrusive awareness.* |
| **Idle State** (Secondary) | **Minimal Presentation** | Multiple Live Activities active. | A small, circular/oval icon with a single letter or number representing the task count (e.g., "F" for Focus Flow, or "3"). *Purpose: Minimal presence when sharing the Island.* |
| **Active State** (Dashboard) | **Expanded Presentation** | User performs a **Touch and Hold** gesture on the Compact or Minimal view. | A small dashboard showing the **Top Task** with a progress bar, quick actions, and a list of the next two tasks. *Purpose: Quick interaction and detailed context.* |
| **No Task State** | **Compact Presentation** | No tasks meet the prioritization criteria. | **Leading:** App Icon + Gentle Wave Animation (purely aesthetic). **Trailing:** "All Clear" or a short, rotating motivational quote. *Purpose: Playful companion, never empty.* |

## 4. Interaction Model

| Interaction | Resulting Action | HIG Compliance |
| :--- | :--- | :--- |
| **Tap** (on Compact or Minimal) | Opens the main Focus Flow app to the "Top Task" detail screen. | Standard Live Activity behavior [1]. |
| **Touch and Hold** (on Compact or Minimal) | Transitions to the **Expanded Presentation** (Active State Dashboard). | Standard Live Activity behavior [1]. |
| **Quick Action Button** (in Expanded View) | **"Done" Button:** Marks the Top Task as complete in its source application (e.g., ToDoist API call). The Live Activity immediately updates to the next Top Task. | Interactive elements are supported in the Expanded View [1]. |
| **Quick Action Button** (in Expanded View) | **"Snooze" Button:** Snoozes the Top Task for a user-defined period (e.g., 15 minutes). The Live Activity immediately updates to the next Top Task. | Interactive elements are supported in the Expanded View [1]. |

## References
[1] [Live Activities | Apple Developer Documentation](https://developer.apple.com/design/human-interface-guidelines/live-activities) - The Human Interface Guidelines for Live Activities, which govern the design and behavior of Dynamic Island extensions.

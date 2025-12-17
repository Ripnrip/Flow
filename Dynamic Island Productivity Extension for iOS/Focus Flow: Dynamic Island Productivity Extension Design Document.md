# Focus Flow: Dynamic Island Productivity Extension Design Document

## Executive Summary

The **Focus Flow** Dynamic Island extension is a unified, glanceable productivity hub designed to be an **always-available, non-overwhelming companion** for the user. It leverages Apple's **Live Activities** framework to surface the single most critical task or reminder from multiple integrated sources (Apple Reminders, Calendar, ToDoist, Trello) directly in the Dynamic Island. The design adheres to the user's request for a **modern, elegant, and slightly playful** aesthetic, utilizing smooth animations and a high-contrast visual style.

---

## 1. Core Concept and Vibe

The extension's design is built on the concept of **"Glanceable Elegance"**, prioritizing clarity, high contrast, and subtle, meaningful animation against the Dynamic Island's black background.

| Attribute | Specification |
| :--- | :--- |
| **Name** | Focus Flow |
| **Vibe** | Modern, elegant, and slightly playful—a little productivity companion that’s always there but never overwhelming. |
| **Technology** | iOS Live Activity, supporting Compact, Minimal, and Expanded presentations [1]. |
| **Color Palette** | Monochromatic with a single, vibrant accent color: **Focus Purple** (Hex: #7A5AF8) for animations, progress, and interactive elements. |
| **Typography** | System's San Francisco font, with medium to semibold weights for maximum legibility [1]. |

## 2. Data Integration and Prioritization Logic

Focus Flow acts as a unified mini command center, requiring secure, user-authorized access to multiple data sources.

### 2.1. Data Sources and Customization
The UI allows customization of which task types appear, pulling data from the following sources:
*   **Native:** Apple Reminders, Apple Calendar (events starting within a configurable window, e.g., 30 minutes).
*   **Third-Party:** ToDoist (via API), Trello (via API).

### 2.2. Prioritization Logic (Determining the "Top Task")
The Live Activity displays the single most relevant item based on the following hierarchy:

1.  **User-Defined Focus Task:** A task manually pinned by the user in the main Focus Flow app.
2.  **Highest Priority Task:** Tasks marked as Priority 1 in ToDoist or tagged as "Urgent" in Trello.
3.  **Imminent Calendar Event:** The next event starting within the next 30 minutes.
4.  **Closest Due Date/Time:** The task with the nearest due time from any source.
5.  **New Reminder/Task:** Any item added in the last 5 minutes (to provide immediate feedback).
6.  **Default State:** If no tasks meet the criteria, the Island displays a simple "All Clear" status.

## 3. Visual States and Interaction Model

The user's requested states are mapped directly to the technical presentations required by the Dynamic Island's Live Activity framework [1].

### 3.1. Idle State (Subtle Pulse) - Compact Presentation

This state is active when a "Top Task" is present. It is designed to be **non-intrusive but noticeable**.

| Element | Visual Specification | Purpose |
| :--- | :--- | :--- |
| **Leading Side** | **Focus Flow Icon** with a **Subtle Pulse Animation**. The pulse is a gentle, slow-moving ring of **Focus Purple** that expands and fades out every 5 seconds, indicating an active task. | Non-intrusive awareness of an active task. |
| **Trailing Side** | **Glanceable Metric:** Displays the most relevant secondary information, such as "Due 10:30" or "3 Tasks" (total remaining for the day). | Quick context without needing to expand. |
| **Interaction** | **Tap:** Opens the main Focus Flow app to the Top Task detail screen. | Standard Live Activity behavior [1]. |

### 3.2. Idle State (Secondary) - Minimal Presentation

This state is active when the Dynamic Island is shared with another Live Activity.

| Element | Visual Specification | Purpose |
| :--- | :--- | :--- |
| **Visual** | A small, circular icon with a single white letter "F" or a number representing the count of remaining tasks. Background is solid **Focus Purple**. | Minimal presence when sharing the Island. |
| **Interaction** | **Tap:** Opens the main Focus Flow app. **Touch and Hold:** Transitions to the Expanded Presentation. | Standard Live Activity behavior [1]. |

### 3.3. Active State (Dashboard) - Expanded Presentation

This state is triggered by a **Touch and Hold** gesture, transforming the Island into a small, interactive dashboard for **quick action and detailed context**.

| Element | Visual Specification | Interaction |
| :--- | :--- | :--- |
| **Layout** | A unified view that wraps tightly around the TrueDepth camera [1], divided into Top Task, Progress Bar, and Quick Actions. | **Tap (outside buttons):** Opens the main Focus Flow app. |
| **Top Task Display** | **Title:** Task title (e.g., "Draft Q3 Report"). **Source Icon:** Small, colored icon (e.g., blue for Reminders) next to the title. | Provides immediate context of the current focus. |
| **Progress Bar** | A thin, horizontal bar filled with **Focus Purple** to represent estimated completion progress. | Visual indicator of task status. |
| **Quick Actions** | Two distinct, interactive buttons placed on the right side. | |
| **"Done" Button** | Circular button with a white checkmark. Background is **Focus Purple**. | **Tap:** Marks task complete via API call. Live Activity immediately updates to the next Top Task with a smooth transition. |
| **"Snooze" Button** | Circular button with a white clock icon. Background is light gray with slight transparency. | **Tap:** Snoozes the task for 15 minutes. Live Activity immediately updates to the next Top Task with a smooth transition. |
| **Next Tasks Preview** | Subtle, secondary area listing the next two tasks (e.g., "Next: Call client, Review deck"). | Provides a forward-looking view of the day. |

### 3.4. No Task State - Compact Presentation

This state is active when no tasks meet the prioritization criteria, fulfilling the "never overwhelming" requirement.

| Element | Visual Specification | Purpose |
| :--- | :--- | :--- |
| **Leading Side** | Focus Flow Icon with a **Gentle Wave Animation**. A slow, continuous, horizontal ripple of light gray crosses the icon. | Playful companion, signifying an "All Clear" and relaxed mood. |
| **Trailing Side** | "All Clear" or a short, rotating motivational quote (e.g., "Breathe," "You got this"). | Positive reinforcement and playful touch. |

## 4. Animation and Polish

The overall vibe is heavily dependent on **smooth, fluid transitions** and subtle animations.

*   **Expansion/Contraction:** The transition between the Compact and Expanded states will use a smooth, spring-based animation, adhering to the system's visual language for Live Activity expansion.
*   **Data Update:** When a task is completed, the content will fade out and the new content will fade in, ensuring a smooth, non-jarring update.
*   **Playful Element:** The "Gentle Wave Animation" and "Subtle Pulse Animation" provide the requested **"slightly playful"** touch, ensuring the Dynamic Island feels like a living, breathing companion rather than a static notification.

## References
[1] [Live Activities | Apple Developer Documentation](https://developer.apple.com/design/human-interface-guidelines/live-activities) - The Human Interface Guidelines for Live Activities, which govern the design and behavior of Dynamic Island extensions.

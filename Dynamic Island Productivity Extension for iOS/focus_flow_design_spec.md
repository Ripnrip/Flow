# Focus Flow: Detailed Visual and Interaction Design Specification

This document details the visual and interaction design for the "Focus Flow" Dynamic Island extension, ensuring it meets the user's requirements for a modern, elegant, and slightly playful productivity companion while adhering to Apple's Human Interface Guidelines (HIG) for Live Activities [1].

## 1. Visual Design Principles

The design is built on the concept of **"Glanceable Elegance"**, prioritizing clarity, high contrast, and subtle, meaningful animation.

*   **Color Palette:** Primarily monochromatic with a single, vibrant accent color (e.g., a deep, calming **Focus Purple** - Hex: #7A5AF8) used for the pulse animation, progress indicators, and quick action buttons. All text will be white or light gray for maximum contrast against the Dynamic Island's black background.
*   **Typography:** Use the system's San Francisco font family. Text should be medium weight or higher, with minimal use of small text, as recommended by the HIG [1].
    *   **Top Task Title:** Medium weight, 12pt.
    *   **Metric/Time:** Semibold weight, 10pt.
*   **Iconography:** Utilize Apple's SF Symbols for all icons, ensuring system consistency and automatic support for different weights and scales.

## 2. State-by-State Visual and Interaction Breakdown

### 2.1. Idle State (Compact Presentation)

This state is active when a "Top Task" is present, but the user is not actively interacting with the Island. It is designed to be **non-intrusive but noticeable**.

| Element | Visual Specification | Interaction |
| :--- | :--- | :--- |
| **Leading Side** (Left of TrueDepth Camera) | **Focus Flow Icon** (e.g., a stylized "F" or a checkmark/target symbol). The icon is surrounded by a **Subtle Pulse Animation**. The pulse is a gentle, slow-moving ring of **Focus Purple** that expands and fades out from the icon every 5 seconds. | **Tap:** Opens the main Focus Flow app to the Top Task detail screen. |
| **Trailing Side** (Right of TrueDepth Camera) | **Glanceable Metric:** Displays the most relevant secondary information. E.g., "Due 10:30" (if the task has a time) or "3 Tasks" (total remaining for the day). Text is white, Semibold, 10pt. | **Tap:** Opens the main Focus Flow app to the Top Task detail screen. |
| **No Task State** (Compact) | **Leading:** Focus Flow Icon with a **Gentle Wave Animation**. The wave is a slow, continuous, horizontal ripple of light gray that crosses the icon, signifying "All Clear" and a playful, relaxed mood. **Trailing:** "All Clear" or a short, rotating motivational quote (e.g., "Breathe," "You got this"). | **Tap:** Opens the main Focus Flow app to the Home Screen. |

### 2.2. Idle State (Minimal Presentation)

This state is active when the Dynamic Island is shared with another Live Activity.

| Element | Visual Specification | Interaction |
| :--- | :--- | :--- |
| **Visual** | A small, circular icon with a single white letter "F" (for Focus Flow) or a number representing the count of remaining tasks (e.g., "3"). The icon's background is a solid **Focus Purple**. | **Tap:** Opens the main Focus Flow app. **Touch and Hold:** Transitions to the Expanded Presentation. |

### 2.3. Active State (Expanded Presentation)

This state is triggered by a **Touch and Hold** gesture, transforming the Island into a small, interactive dashboard. It is designed for **quick action and detailed context**.

| Element | Visual Specification | Interaction |
| :--- | :--- | :--- |
| **Layout** | A single, unified view that wraps tightly around the TrueDepth camera [1]. The view is divided into three main sections: **Top Task**, **Progress Bar**, and **Quick Actions**. | **Tap (anywhere outside buttons):** Opens the main Focus Flow app. |
| **Top Task Display** | **Title:** The task title (e.g., "Draft Q3 Report"). White text, Medium weight, 12pt. **Source Icon:** A small, colored icon (e.g., blue for Reminders, red for ToDoist) next to the title to indicate the source. | N/A |
| **Progress Bar** | A thin, horizontal progress bar directly below the title. The bar is filled with **Focus Purple** to represent the estimated completion progress (based on user-defined subtasks or time estimates). | N/A |
| **Quick Actions** | Two distinct, interactive buttons placed on the right side of the expanded view. | |
| **"Done" Button** | A solid, circular button with a white checkmark icon. Background is **Focus Purple**. | **Tap:** Marks the task as complete. Live Activity immediately updates to the next Top Task with a smooth transition. |
| **"Snooze" Button** | A circular button with a white clock icon. Background is a light gray with a slight transparency. | **Tap:** Snoozes the task for 15 minutes. Live Activity immediately updates to the next Top Task with a smooth transition. |
| **Next Tasks Preview** | A subtle, secondary area at the bottom of the expanded view listing the next two tasks (e.g., "Next: Call client, Review deck"). Light gray text, 8pt. | N/A |

## 3. Animation and Polish

The overall vibe is achieved through **smooth, fluid transitions** and subtle animations.

*   **Expansion/Contraction:** The transition between the Compact and Expanded states must use a smooth, spring-based animation, adhering to the system's visual language for Live Activity expansion.
*   **Data Update:** When a task is marked "Done" and the next task loads, the content should fade out and the new content should fade in, rather than abruptly snapping. The progress bar should animate its fill level.
*   **Playful Element:** The "Gentle Wave Animation" in the No Task State and the "Subtle Pulse Animation" in the Idle State provide the requested **"slightly playful"** touch, ensuring the Dynamic Island feels like a living, breathing companion.

## References
[1] [Live Activities | Apple Developer Documentation](https://developer.apple.com/design/human-interface-guidelines/live-activities) - The Human Interface Guidelines for Live Activities, which govern the design and behavior of Dynamic Island extensions.

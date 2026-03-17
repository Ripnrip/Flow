<div align="center">

# Flow

### Dynamic Island iOS App

<img src="docs/images/flow-ghibli.png" width="800" alt="Flow — A Ghibli-style illustration of a magical iPhone in a serene Japanese garden" style="border-radius: 16px;">

<br />

[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-007AFF?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/swiftui/)
[![iOS](https://img.shields.io/badge/iOS-17+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![Dynamic Island](https://img.shields.io/badge/Dynamic_Island-Supported-9E7AFF?style=for-the-badge)](https://developer.apple.com/documentation/activitykit)

*A uniquely Apple iOS app that transforms the Dynamic Island into a living, breathing interface — combining fluid animations, haptic feedback, and contextual awareness into an experience that feels like it was designed in Cupertino.*

</div>

---

## Overview

Flow reimagines what's possible with Apple's Dynamic Island API. Instead of treating it as a simple notification area, Flow turns it into an adaptive, context-aware companion that responds to your day with beautiful animations and meaningful interactions.

Built entirely in SwiftUI with a focus on Apple's Human Interface Guidelines, Flow demonstrates how the Dynamic Island can serve as a persistent, non-intrusive layer of intelligence in your daily workflow.

## Key Features

**Live Activities & Dynamic Island** — Real-time updates that morph seamlessly between compact, minimal, and expanded presentations. The island breathes with your content.

**Fluid Animations** — Every transition uses spring-based physics for that signature Apple feel. Matched geometry effects ensure elements flow naturally between states.

**Haptic Choreography** — Subtle haptic patterns that complement visual transitions, creating a multi-sensory experience that feels premium.

**Adaptive Theming** — Automatically adjusts its visual language based on time of day, system appearance, and user activity patterns.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **UI Framework** | SwiftUI 5, WidgetKit, ActivityKit |
| **Architecture** | MVVM + Combine reactive streams |
| **Animations** | Spring physics, matched geometry effects |
| **Platform APIs** | Dynamic Island, Live Activities, Haptics |
| **Minimum Target** | iOS 17.0+ |

## Architecture

```
Flow/
├── App/                  # App entry point & lifecycle
├── Features/
│   ├── DynamicIsland/    # Island presentations & states
│   ├── LiveActivities/   # ActivityKit integration
│   └── Animations/       # Spring configs & choreography
├── Design/
│   ├── Theme/            # Adaptive color system
│   └── Components/       # Reusable SwiftUI views
└── Utilities/            # Haptics, state management
```

## Getting Started

```bash
# Clone the repository
git clone https://github.com/Ripnrip/Flow.git
cd Flow

# Open in Xcode
open Flow.xcodeproj

# Build & Run on iPhone 14 Pro or later (Dynamic Island required)
# ⌘ + R
```

> **Note**: Dynamic Island features require a physical device with iPhone 14 Pro or later. The Simulator provides limited Dynamic Island support.

## Why Flow?

The Dynamic Island is one of Apple's most innovative UI paradigms, yet most apps treat it as an afterthought. Flow was built to prove that with careful attention to animation timing, haptic design, and contextual awareness, the Dynamic Island can become the centerpiece of an app's experience — not just a notification badge.

---

<div align="center">
  <br />
  <p>Built with ✨ by <a href="https://guriboycodes.com"><strong>GuriboyCodes</strong></a></p>
  <sub>Staff Software Engineer — Mobile & AI</sub>
  <br /><br />
  <a href="https://guriboycodes.com">Portfolio</a> · <a href="https://github.com/Ripnrip">GitHub</a> · <a href="https://linkedin.com/in/gurindersingh">LinkedIn</a>
</div>

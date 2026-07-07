# 🍩 Flow Changelog — Where Every Commit Tells a Story

---

## 2026-07-07 — The Plot Thickens: A Rogue `.map` Closure Nearly Killed the Vibe 🥀🍩

**What we did:**
- 🕵️ Tracked down the "tap sends app home" haunting on a physical iPhone 14 Pro — turns out it wasn't a ghost, it was a SIGTRAP.
- 🔍 Pulled crash logs and found the smoking gun: `ExternalIntegrationService.inhaleReminders()` was running a `.map` closure inside EventKit's background completion handler, but Swift 6 had politely marked that closure as `@MainActor`. Cue `_dispatch_assert_queue_fail` and an unceremonious ejection to the Home Screen.
- 🛠️ Replaced the rebellious `.map` with a plain `for` loop, stripping away the inferred MainActor isolation and letting EventKit do its thing on its own queue.
- 📲 Built, signed, installed, and tested a fresh debug IPA over the air — taps now behave like civilized UI gestures instead of self-destruct buttons.
- 🧪 Confirmed the simulator build still passes, because we don't fix one stage only to set fire to another.

**What's still TODO:**
- 🔑 Enable the `group.com.binarybros.Flow` App Group in the Apple Developer Portal — the original portal quest continues.
- 📲 Re-archive with a real provisioning profile once App Groups is registered.
- 🚀 Upload the signed IPA to TestFlight and watch that "Processing" badge turn into "Ready for Beta Testing".

**Reflections from the trenches:**
> This was the debugging equivalent of thinking your fixie had a flat tire, then discovering the entire rear hub was about to fall off. The `.map` closure looked innocent — just a little functional sugar — but under Swift 6's strict concurrency rules it became a ticking time bomb. Physical devices, with their real queues and real assertions, exposed what the simulator happily glossed over. There's something poetic about a crash that only happens when you touch the screen: the app was literally saying "don't touch me, I'm not ready." Well, now it's ready. The Reminders sync purrs, the UI stays put, and the road to TestFlight is clearer than a freshly wiped Chemex. ☕️🚀

---

## 2026-07-07 — Twinkie Tantrum: Signing Fixed, Widgets Prepped, Portal Almost Purring 🍩✨

**What we did:**
- 🗑️ Purged the unconfigured Associated Domains entitlement from `Flow/Flow.entitlements` — because nothing says "bad first impression" like a build that fails before it even leaves the launchpad.
- 🧁 Added `ExportOptions.plist` with `manageAppVersionAndBuildNumber = true` and `uploadSymbols = true`, so TestFlight can sip our IPA like a perfectly brewed pour-over.
- 🎨 Fixed `PinnedTaskPickerView` so SF Symbols and emoji stop ghosting us in the UI.
- 🖼️ Patched `Widgets/PinnedTasksWidget.swift` to render emoji/SF Symbol task markers correctly instead of showing empty little squares of disappointment.
- 🌐 Tightened `FlowServerService.swift` so widget intent updates flow through the proper cosmic channels.
- 🧪 Verified a clean iPhone 17 simulator build with `xcodebuild` — green lights across the board, no smoke, no mirrors.

**What's still TODO:**
- 🔑 Enable the `group.com.binarybros.Flow` App Group in the Apple Developer Portal — the one brain architecture demands it, and widgets can't gossip without it.
- 📲 Re-archive with a real provisioning profile once App Groups is happy.
- 🚀 Upload the signed IPA to TestFlight and see that sweet "Processing" badge.

**Reflections from the trenches:**
> This session felt like tuning a vintage synth — lots of knobs, one wrong move and the whole track squeals. The Associated Domains entitlement was the silent killer: harmless on local sim builds, fatal the moment we asked Xcode to produce something Apple would accept. Removing it was the equivalent of finding out your artisanal cold brew was actually decaf and fixing it before anyone noticed. Widgets are now visually coherent, the export pipeline is dressed for the App Store, and the codebase is one portal toggle away from flight. Next stop: App Groups, then the cloud. ☁️🚀

---

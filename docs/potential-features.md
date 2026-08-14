# Potential features

A backlog of ideas that have been considered but not built. Nothing here is committed to. Each entry records what it is, why it might be worth doing, and what makes it non-trivial — so a future session (or a new contributor) does not have to rediscover the reasoning.

Ordered roughly by expected value, highest first.

---

## Camera mode — count taps from hand motion

> **Status: not started. The largest item on this list by a wide margin** — treat it as a project rather than a feature, and expect it to touch privacy, permissions, performance and UI all at once.

**What:** An opt-in mode where the Mac's camera watches for a repeated hand gesture — a clap, a snap, a tap in the air — and increments the counter each time it sees one.

**Strictly a mode, never ambient.** The camera opens only after the user explicitly clicks "Camera Mode" in the UI, and closes when they leave it. It must never start on launch, never run in the background, and never be the default. A tap counter that silently watches you is a different and much worse product.

**Why:** It removes the click from the loop entirely — the counter tracks something you are already doing with your hands, rather than something you have to stop and do to the app.

### Considerations

**Permissions and entitlements.** Needs `NSCameraUsageDescription` (as `INFOPLIST_KEY_NSCameraUsageDescription`, since the Info.plist is generated) and the `com.apple.security.device.camera` sandbox entitlement. macOS will show a TCC prompt the first time. Handle refusal and later revocation gracefully — the mode should explain and offer a way to Settings, not fail silently or wedge.

**Detection approach is the main design decision, and video may be the wrong tool.**

- **Vision, `VNDetectHumanHandPoseRequest`** gives 21 hand landmarks per hand. Workable for a clap (two hands converging then separating) and for a deliberate air-tap. **Snapping is genuinely hard to see** — the motion is small, fast, and often self-occluded.
- **Frame differencing** is far cheaper but cannot distinguish a clap from someone walking past, so it will miscount constantly.
- **Audio is very likely the better sensor for claps and snaps.** Both have sharp, distinctive transients that are much easier to detect reliably in audio than in video, and a microphone costs a fraction of the power. Worth prototyping the audio version first and treating "camera mode" as the name rather than the mechanism — or offering both.

**False positives are the feature's whole risk.** Every miscount corrupts real history, which is the one thing this app is supposed to protect. Needs a refractory period so one gesture cannot register twice, a confidence threshold, and — importantly — a visible live indication of what the app thinks it is seeing, so a user can tell immediately whether it is working. Consider not writing to the real history at all until the user confirms the session.

**The popover cannot host this.** It is `.transient`, so it dismisses the moment the user clicks or moves away — the exact things a camera mode needs to survive. Camera mode needs its own window, with a preview, a live count, and an unmistakable stop control. That is a real addition to `WindowCoordinator`, not a new tab.

**Performance and battery.** Continuous capture plus per-frame Vision inference is expensive for a menu bar app that otherwise costs nothing. Throttle the analysis frame rate well below the capture rate, stop capture the instant the window closes, and measure the energy impact before shipping. The green camera indicator will be lit the whole time — that is good for trust, but it also makes any leak of this mode into the background immediately visible and embarrassing.

**Data model.** Camera-sourced taps should count as ordinary taps, but it would be worth recording *how* a tap was registered so a miscounted session can be identified later. That is a schema change on `DayRecord` (or a new per-tap entity), so it needs a `SchemaMigrationPlan` — see the idle-game mechanics entry.

**Testing.** Cannot be covered by the existing unit-test approach. The gesture-recognition layer should be structured to take frames or landmark observations as input and return detections, so it can be tested against recorded fixtures rather than a live camera. Keep the capture session itself thin and at the edge, in line with the Actions/Calculations split.

**Open-sourcing implications.** A camera feature changes what the README and SECURITY policy have to say. Both currently state plainly that the app has no network code and collects nothing; that stays true, but "the camera is used, only in this mode, and frames never leave the machine" needs to be stated explicitly and prominently.

---

## Global tap shortcut

**What:** A system-wide keyboard shortcut that records a tap without opening the popover.

**Why:** Today every tap requires clicking the menu bar icon, waiting for the popover, then clicking the button. That interrupts whatever you were doing, which defeats the point of an ambient counter. A shortcut turns tapping into something you can do while reading or working.

**Considerations:**

- Use `NSEvent.addGlobalMonitorForEvents` only for keys the app owns, or register a proper hotkey through Carbon's `RegisterEventHotKey` / a modern equivalent. A global keyboard monitor requires Accessibility permission; a registered hotkey does not. **Prefer the registered hotkey** — asking for Accessibility for a tap counter is disproportionate, and users are right to refuse it.
- The shortcut must be user-configurable and must not collide with a shortcut owned by whatever app is frontmost. Ship with no default binding rather than guessing.
- Needs visible feedback, since the popover will not be open. Options: briefly flash the menu bar count, or a short unobtrusive sound.
- Scope it carefully: it should fire regardless of which app is active (that is the point), but it must not fire while the user is typing into a text field in *our* Settings window.

---

## Milestone visual effects

**What:** A particle burst when the day's count crosses a milestone — every 100 taps by default, with the interval configurable. Plus a **"Show visual effects"** toggle in Settings, **default on**, so anyone who finds it distracting can turn it off.

**Why:** The counter currently gives no sense of occasion. A brief celebration at round numbers is the cheapest way to make a tally feel like a game, and milestones are already the natural rhythm of the thing.

### Considerations

**Milestone detection belongs in the calculation layer.** Something like `MilestoneCalculator.crossed(from:to:interval:)`, taking the previous and new counts and returning the milestone reached, if any. Pure and directly testable — and the edge cases genuinely need tests:

- An increment larger than the interval must not fire several bursts at once, or silently skip the milestone
- The daily reset takes the count back to zero; crossing 100 the next day is a new milestone, not a repeat
- Interval changes mid-day must not retroactively fire for counts already passed
- An interval of zero or a negative number must not divide by zero or loop forever — clamp it, per the project's rule that every default is valid and functional

**Respect Reduce Motion — this is not optional.** A burst of moving particles is precisely what `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` exists to suppress. When it is on, fall back to something static: a colour pulse, a brief label, no motion. Honour it independently of the user's own toggle, since the two mean different things.

**Rendering approach.** In rough order of preference:

- **SwiftUI `Canvas` + `TimelineView`** — no new framework, stays inside the existing view layer, easy to clip to the popover
- **`CAEmitterLayer`** via an `NSViewRepresentable` — purpose-built for particles and cheap, at the cost of dropping into AppKit
- **SpriteKit** — capable but far too much machinery for a 260-point-wide popover

**Performance is the real constraint.** The effect fires during exactly the moment the user is tapping fastest, and the tap path is already debounced for a reason. The animation must never block or delay the increment, and it must not drop frames on an integrated GPU. Cap the particle count, and make sure a second milestone arriving mid-animation replaces the first cleanly rather than stacking emitters.

**The popover is small and transient.** Effects must be clipped to its bounds — no particles spilling outside the window — and must tear down immediately if the popover dismisses mid-burst. Anything that outlives its window is a leak.

**The setting.** A new `showVisualEffects` key in `AppSettings`, defaulting to `true`, alongside the existing preferences. The milestone interval could live there too, though it may be better kept as a constant until there is evidence anyone wants to change it — an option nobody adjusts is just surface area.

**Worth deciding early:** whether the effect belongs only in the popover, or whether the menu bar item should also acknowledge a milestone. A menu bar flash is more visible but much more intrusive, and it competes with the fixed-width guarantee the status item currently maintains.

---

## Custom-drawn icon artwork

> **Partly done.** A full icon set now exists, generated from the `hand.tap.fill` SF Symbol by `scripts/generate-app-icon.swift`. What remains is bespoke artwork, if the symbol-derived icon ever stops feeling good enough.

**What:** Replace the generated icon with hand-drawn artwork, and optionally a custom menu bar glyph in place of the stock SF Symbol.

**Why:** The current icon is deliberately derived from the menu bar symbol so the two can never drift, which is the right trade while the app is young. A hand-drawn icon could be more distinctive, at the cost of that guarantee.

**Considerations:**

- Regenerate rather than hand-edit while the symbol-derived icon is in use: `swift scripts/generate-app-icon.swift` rewrites all ten sizes and `Contents.json`. Editing the PNGs directly means the next run silently overwrites the work.
- Any menu bar glyph must be a **template image** so macOS can invert it for light and dark menu bars and reduced-transparency mode. Draw it as a flat silhouette — internal shading looks wrong inverted.
- Keep it legible at 16 points. The SF Symbol survives that size because it was drawn for it; bespoke artwork often does not.
- If the menu bar glyph and the app icon stop coming from the same source, they will eventually diverge. Decide deliberately rather than by accident.

---

## Idle-game mechanics

> **Partly done.** Achievements and milestones shipped: a fixed catalog of nine achievements (`AchievementCatalog`) evaluated against `TapStats` by `AchievementCalculator`, persisted one row per unlock in `AchievementRecord`, plus a per-day, non-persisted milestone banner every 100 taps (`MilestoneCalculator`). What remains is the currency/upgrade economy below — a materially bigger scope, since it needs balancing decisions the achievements did not (what taps buy, at what rate, spent on what).

**What:** Upgrades and currencies — a spendable resource earned from taps, and purchases that change tap value or unlock cosmetics.

**Why:** This is the reason SwiftData was chosen over flat files. Relational data with real queries is exactly where it earns its keep.

**Considerations:**

- New `@Model` types with `@Relationship` links to `DayRecord` or to a new session entity, if a purchase needs to reference when it happened.
- At that point `#Predicate` and `SortDescriptor` start earning their keep, and the current fetch-all-and-filter approach in `SwiftDataTapRepository` should be revisited — it was still the right call for the achievements table, which holds at most one row per catalog entry, but an economy with a purchase history will not stay that small. See the note in `CONTRIBUTING.md` about key paths and strict concurrency.
- Purchase/upgrade evaluation belongs in the pure calculation layer, the same way achievement evaluation does now — take state in, return the new state, no I/O.
- Adding these models is additive, the same as `AchievementRecord` was: no `SchemaMigrationPlan` needed unless a change also touches `DayRecord`'s or `AchievementRecord`'s existing stored properties incompatibly.

See also **Milestone visual effects** above — the particle-burst celebration is still unbuilt; the milestone banner that shipped here is deliberately plain (text and an SF Symbol, no motion) and does not replace it.

---

## Per-session and per-hour breakdowns

**What:** Record when taps happened within a day, not just the daily total.

**Why:** Enables "your most active hour", tap-rate charts, and session detection. Also the natural substrate for idle mechanics above.

**Considerations:**

- Changes the write pattern fundamentally: one row per day becomes potentially hundreds per day. The current "fetch everything and filter in Swift" approach stops being appropriate, and the debounce strategy needs rethinking — probably buffering taps into a bucket and writing the bucket.
- Storage growth becomes real for the first time. Consider aggregating older data down to daily totals past some age.
- Privacy: timestamped activity is meaningfully more sensitive than a daily count. Worth an explicit opt-in, and worth stating in the README.

---

## iCloud sync and an iOS companion

**What:** Sync history across devices via CloudKit; optionally an iOS app sharing the same models.

**Why:** The single strongest argument for SwiftData over a JSON file. With CloudKit it is close to a configuration change; hand-rolled it is weeks of work.

**Considerations:**

- CloudKit imposes model constraints: **every property must be optional or have a default, and `@Attribute(.unique)` is not supported.** `DayRecord.dayStart` currently relies on a unique constraint to prevent double-inserts across a midnight race, so that guarantee would have to move into application logic first. Do this migration deliberately, not as a side effect of flipping a flag.
- Requires an Apple Developer account and the iCloud entitlement, which raises the barrier for contributors cloning an open-source repo. Consider gating it behind a build configuration so the default checkout still builds with no account.
- Sync introduces conflicts: two devices tapping on the same day need a merge policy. Summing both sides is probably right for a counter, but it is a real decision and should be tested.

---

## Data import

**What:** Read back the JSON that Settings → Export History produces.

**Why:** Export without import is a one-way door. Users migrating Macs, or restoring after deleting history by accident, currently have no path back.

**Considerations:**

- Needs a merge policy for days that already exist: replace, sum, or keep the larger. Ask rather than guess.
- Validate aggressively — a hand-edited file will contain surprises. Reject the whole import on malformed input rather than partially applying it.
- Must be reversible, or at minimum preceded by an automatic backup of the existing store.

---

## Widgets and Control Center

**What:** A WidgetKit widget showing today's count, and possibly a Control Center control for tapping.

**Why:** Ambient visibility without opening anything.

**Considerations:**

- Widgets run in a separate process, so the SwiftData store has to move into an **App Group** container. That is a migration of the existing store location — plan it, and handle the case where users have data in the old location.
- Widget timelines refresh on a budget set by the system; a live-updating tap count is not something WidgetKit is designed for. Set expectations accordingly.

---

## Multiple counters

**What:** More than one thing to count, each with its own history.

**Why:** The most common way a single-purpose counter gets requested to grow.

**Considerations:**

- Turns `DayRecord` from one-row-per-day into one-row-per-day-per-counter, and the unique constraint becomes a compound one.
- Significant UI implications: the popover is deliberately a single button and a single number. Adding a picker risks losing what makes it pleasant. Consider carefully whether this is the same app.

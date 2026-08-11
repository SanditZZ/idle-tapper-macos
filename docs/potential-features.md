# Potential features

A backlog of ideas that have been considered but not built. Nothing here is committed to. Each entry records what it is, why it might be worth doing, and what makes it non-trivial — so a future session (or a new contributor) does not have to rediscover the reasoning.

Ordered roughly by expected value, highest first.

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

## App icon and menu bar glyph

**What:** A real `AppIcon` set, plus a custom menu bar icon instead of the stock `hand.tap.fill` SF Symbol.

**Why:** `Assets.xcassets/AppIcon.appiconset` is currently an empty placeholder, so the app has no icon in Finder, the Dock (when shown) or System Settings → Login Items. That reads as unfinished, and it matters more once the repo is public.

**Considerations:**

- Needs the full macOS set: 16, 32, 128, 256 and 512 points, each at 1× and 2×.
- The menu bar glyph must be a **template image** so macOS can invert it for light and dark menu bars and for reduced-transparency mode. Design it as a flat silhouette; anything with internal shading will look wrong when inverted.
- Keep it legible at 16 points. The current SF Symbol is a reasonable placeholder precisely because it was drawn for that size.

---

## Idle-game mechanics

**What:** Upgrades, achievements, currencies, milestones — the things the "idle" in the name implies.

**Why:** This is the reason SwiftData was chosen over flat files. Relational data with real queries is exactly where it earns its keep.

**Considerations:**

- New `@Model` types with `@Relationship` links to `DayRecord` or to a new session entity.
- At that point `#Predicate` and `SortDescriptor` start earning their keep, and the current fetch-all-and-filter approach in `SwiftDataTapRepository` should be revisited. See the note in `CONTRIBUTING.md` about key paths and strict concurrency.
- Achievement evaluation belongs in the pure calculation layer, taking a history and returning which achievements are unlocked. Keep it out of the persistence layer.
- A schema change needs a `SchemaMigrationPlan`. Add one *before* the first release that ships new models, not after.

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

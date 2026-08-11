# Idle Tapper

**A native macOS menu bar tap counter — one big button, one number, a fresh start every day.**

![macOS](https://img.shields.io/badge/macOS-14.0+-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.0+-orange?style=flat-square&logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-blue?style=flat-square&logo=swift)
![SwiftData](https://img.shields.io/badge/SwiftData-purple?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)

---

## Overview

Idle Tapper lives in your menu bar. Click the status item and a popover drops down with today's total, a big rounded button, and a week of history. Tap the button; the number goes up. At local midnight the counter returns to zero and the day just finished is filed away in your history.

That is the whole app. It does not sync, does not phone home, and does not ask for an account.

### Features

- **Menu bar native** — an accessory app with no Dock icon and no window in your way
- **One big button** — counts on press-down, so fast tapping never drops a tap
- **Automatic daily reset** — the counter zeroes at your Mac's local midnight
- **History that persists** — every past day is kept, with streaks, best day, and daily average
- **Live count in the menu bar** — icon, icon plus count, or count alone, in a fixed-width item that never shifts the menu bar as the number grows
- **Sparkline** — the last seven days at a glance in the popover, longer ranges in the History window
- **Export** — your history as portable JSON, any time
- **Launch at login** — optional, via the system login items API
- **Local and private** — a SwiftData database on your Mac; no network code anywhere in this repo

---

## Requirements

| | |
|---|---|
| macOS | 14.0 (Sonoma) or later |
| Xcode | 16.0 or later (developed on 26.3) |
| Swift | 5.0 language mode, Swift 6.2 toolchain |

No third-party dependencies. No package manager step. Clone and build.

---

## Building

```bash
git clone https://github.com/<your-account>/idle-tapper-macos.git
cd idle-tapper-macos
open IdleTapper.xcodeproj
```

Then press ⌘R.

From the command line:

```bash
# Build
xcodebuild -project IdleTapper.xcodeproj -scheme IdleTapper -configuration Debug build

# Test
xcodebuild -project IdleTapper.xcodeproj -scheme IdleTapper -configuration Debug test
```

The project signs ad-hoc (`CODE_SIGN_IDENTITY = "-"`), so **no Apple Developer account is needed** to build and run it locally.

---

## How the daily reset works

This is the part most worth understanding, because it is deliberately not what you might expect.

There is **no midnight timer**. Nothing is scheduled, and nothing fires at 00:00.

Instead, "today's count" is defined as *the record belonging to the day that contains `Date()` right now*. A new day has no record yet, so it reads as zero. Crossing midnight is not an event the app handles — it is simply a different answer to the same question.

```
tap at 23:59 ──▶ dayStart = Mar 15 00:00 ──▶ record(Mar 15).tapCount += 1
tap at 00:01 ──▶ dayStart = Mar 16 00:00 ──▶ no record yet → create → count = 1
```

This matters because timers are unreliable in exactly the situations that occur constantly on a laptop:

| Situation | Timer-based reset | This design |
|---|---|---|
| Mac asleep across midnight | Timer never fires; count is stale | Correct on next read |
| Mac asleep across three days | One missed reset | Correct on next read |
| App launched at 09:00 | Nothing reset it | Correct immediately |
| Clock or time zone changed | Timer fires at the wrong moment | Correct on next read |
| Daylight saving (23- or 25-hour day) | Off by an hour | Correct — calendar arithmetic, not `86400` |

The app *does* observe `NSCalendarDayChanged`, wake-from-sleep, clock changes and time zone changes — but only to refresh a popover that happens to be open. Remove those observers and the reset still works; you would just have to reopen the popover to see it.

The local calendar (`Calendar.current`) supplies the midnight boundary, so the reset follows whatever your Mac's System Settings say — machine time, as intended.

---

## Where your data lives

SwiftData, which stores to SQLite via Core Data's persistence layer. Because the app is sandboxed:

```
~/Library/Containers/com.kkpon3.IdleTapper/Data/Library/Application Support/
    default.store        ← the SQLite database
    default.store-wal    ← write-ahead log
    default.store-shm    ← shared memory
```

All three files together are the database. Copying only `default.store` can lose recent writes.

You can open it with `sqlite3`, but the schema is Core Data's (`ZDAYRECORD`, `Z_PK`, `ZTAPCOUNT`) rather than one designed to be read. **Treat it as an implementation detail** — Apple can change it. Use **Settings → Export History** for a stable format:

```json
[
  { "dayStart": "2026-03-14T00:00:00Z", "tapCount": 412 },
  { "dayStart": "2026-03-15T00:00:00Z", "tapCount": 87 }
]
```

Preferences (menu bar style, history range) live in `UserDefaults`, not in the database.

---

## Troubleshooting

### The menu bar icon is missing

Almost always a **full menu bar**, not a crash. On a Mac with a notch, when there is no room left to the right of the camera housing, macOS places the newest status item *behind* the notch — on screen, correctly sized, and completely invisible.

Idle Tapper detects this and tells you: it shows an alert offering to switch to the more compact "Icon only" style, and logs a warning. To confirm what happened, open Console.app and filter by subsystem `com.kkpon3.IdleTapper`:

```
[MenuBar] The status item was placed behind the display notch and cannot be seen.
```

**The fix is to free a menu bar slot** — quit or hide another menu bar app, or use a menu bar manager. Switching Idle Tapper to "Icon only" in Settings helps but is not guaranteed to be enough on a very crowded bar.

### Launch at login will not turn on

macOS refuses to register a login item for an app running outside a normal install location. Move Idle Tapper to `/Applications` and try again. If the toggle turns on and then reverts, check System Settings → General → Login Items — the item may be registered but switched off there.

---

## Architecture

The codebase separates **Actions**, **Calculations** and **Data**, and keeps views presentational.

```
IdleTapper/
├── App/
│   ├── IdleTapperApp.swift        @main — menu bar only, no default window
│   ├── AppDelegate.swift          Lifecycle; flushes pending taps before exit
│   └── AppEnvironment.swift       Composition root — the only place concrete types are chosen
├── MenuBar/
│   ├── MenuBarController.swift    NSStatusItem + NSPopover
│   ├── StatusItemRenderer.swift   Pure formatting for the status item
│   └── WindowCoordinator.swift    History and Settings windows
├── Views/
│   ├── PopoverContentView.swift   The main interface
│   ├── HistoryView.swift          Chart plus day list
│   ├── SettingsView.swift         Preferences, export, delete
│   └── Components/                TapButton, SparklineView, StatTile
├── DesignSystem/
│   ├── DesignTokens.swift         Typography, spacing, radii, motion
│   ├── AppColors.swift            Semantic, appearance-adaptive palette
│   └── CardModifier.swift         Shared container styling
└── Shared/
    ├── Models/                    DayRecord (@Model), DaySnapshot, TapStats
    ├── Logic/                     DayBoundary, StatsCalculator, StatusItemPlacement — pure, no I/O
    ├── Persistence/               TapRepository protocol + SwiftData implementation
    ├── Services/                  TapTracker (observable state), AppSettings, LaunchAtLoginService
    └── Support/                   AppLog, ObserverBag, EventMonitor
```

### The three layers

**Calculations** (`Shared/Logic/`) are pure functions over value types. `DayBoundary` and `StatsCalculator` never touch SwiftData, never perform I/O, and never read reactive state — the same input always gives the same output. Every branch in them is unit-tested.

**Actions** (`Shared/Services/`, `Shared/Persistence/`) hold the side effects: database writes, notification observers, timers. `TapTracker` is the single observable object the UI watches.

**Data** (`Shared/Models/`) is split deliberately. `DayRecord` is the `@Model` class bound to a `ModelContext`; `DaySnapshot` is the plain `Sendable` value type that crosses into the calculation layer. Pure logic never sees a managed object.

### Why `TapRepository` exists

Views and game logic talk to a protocol, never to `ModelContext`. That gives three things: SwiftData stays swappable, tests run against an in-memory container without ceremony, and the persistence strategy (below) is invisible to callers.

### Two performance decisions

A tapper generates writes far faster than a normal app, so:

1. **Autosave is off and saves are debounced.** The in-memory object graph updates on every tap — reads are always correct immediately — but SQLite is only touched once you pause for a second. Writes are also forced before sleep, before termination, and when the popover closes, bounding what an abrupt quit could lose.
2. **Today's record is cached.** Resolving it per tap would run a query on every click. It is fetched once per day and reused, and the cache invalidates itself when the day rolls over.

---

## Testing

47 tests across 5 suites, using [Swift Testing](https://developer.apple.com/documentation/testing).

```bash
xcodebuild -project IdleTapper.xcodeproj -scheme IdleTapper test
```

The suites deliberately target the things that would silently corrupt data rather than chasing coverage:

- **Day boundaries** — midnight splits, 23- and 25-hour daylight saving days, month and year rollovers
- **Statistics** — streak grace day, gap-broken streaks, zero-count days, chart gap filling, divide-by-zero peaks
- **Repository** — real SwiftData stack on an in-memory store: accumulation, the daily reset, persistence across contexts, deletion
- **Menu bar rendering** — count abbreviation thresholds
- **Status item placement** — notch overlap detection, using real geometry captured from a 16-inch MacBook Pro

Tests pin the calendar to UTC (and to `America/New_York` for the daylight saving cases) so results never depend on the machine's time zone.

---

## Roadmap

Idle Tapper is a tap counter today. SwiftData was chosen over flat files because the natural next steps are relational: upgrades and achievements, per-session breakdowns, and eventually iCloud sync with an iOS companion.

The full backlog — including what makes each item non-trivial — is in **[docs/potential-features.md](docs/potential-features.md)**.

---

## Contributing

Contributions are welcome. See **[CONTRIBUTING.md](CONTRIBUTING.md)** for the architecture rules, coding standards and pull request process, and **[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)** for community expectations.

Security issues: please follow **[SECURITY.md](SECURITY.md)** rather than opening a public issue.

---

## License

MIT — see [LICENSE](LICENSE).

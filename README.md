# Idle Tapper

**A native macOS menu bar tap counter — one big button, one number, a fresh start every day.**

![macOS](https://img.shields.io/badge/macOS-14.0+-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.0+-orange?style=flat-square&logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-blue?style=flat-square&logo=swift)
![SwiftData](https://img.shields.io/badge/SwiftData-purple?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![README hits](https://hits.sh/github.com/SanditZZ/idle-tapper-macos.svg?style=flat-square&label=README%20hits&color=lightgrey)

---

## Overview

Idle Tapper lives in your menu bar. Click the status item and a popover drops down with today's total, a big rounded button, and a week of history. Tap the button; the number goes up. At local midnight the counter returns to zero and the day just finished is filed away in your history.

That is the whole app. It does not sync and does not ask for an account. The only thing it ever sends over the network is a daily request to its own update feed, asking whether a newer version exists — no identifiers, no usage data, and you can switch it off in Settings.

### Features

- **Menu bar native** — an accessory app with no Dock icon and no window in your way
- **One big button** — counts on press-down, so fast tapping never drops a tap
- **Automatic daily reset** — the counter zeroes at your Mac's local midnight
- **History that persists** — every past day is kept, with streaks, best day, and daily average
- **Live count in the menu bar** — icon, icon plus count, or count alone, in a fixed-width item that never shifts the menu bar as the number grows
- **Sparkline** — the last seven days at a glance in the popover, longer ranges in the History window
- **Export** — your history as portable JSON, any time
- **Launch at login** — on by default, via the system login items API, and switchable in Settings
- **Automatic updates** — a daily check against the project's release feed, installed in place with one click
- **Local and private** — a SwiftData database on your Mac; the update check is the only network request the app makes

---

## Requirements

| | |
|---|---|
| macOS | 14.0 (Sonoma) or later |
| Xcode | 16.0 or later (developed on 26.3) |
| Swift | 5.0 language mode, Swift 6.2 toolchain |

One dependency: [Sparkle](https://sparkle-project.org), which powers automatic updates. Swift Package Manager resolves it on first build — there is no separate install step.

---

## Installation

### Homebrew

```bash
brew install sanditzz/tap/idle-tapper
```

This installs the same DMG the release page offers, clears the Gatekeeper quarantine flag automatically (see below), and drops the app in `/Applications`. The cask is updated the moment a new version is released — see [RELEASING.md](RELEASING.md).

### Download a release

Grab the latest **[release](https://github.com/SanditZZ/idle-tapper-macos/releases/latest)** and take either file:

| | |
|---|---|
| `IdleTapper-x.y.z.dmg` | Open it and drag **Idle Tapper** to Applications. The usual choice. |
| `IdleTapper-x.y.z.zip` | Unzip and move the app to Applications yourself. |

**Install to `/Applications`.** Launch at login only works from a normal install location — macOS refuses to register a login item for an app sitting in a Downloads folder.

### First launch: you will have to get past Gatekeeper

**Skip this section if you installed via Homebrew** — the cask clears the quarantine flag for you. It only applies to a manual DMG/zip download, which macOS treats like any browser download.

Idle Tapper is **not notarized by Apple**. Notarization requires the paid Apple Developer Program, which this project does not have, so on first launch macOS says:

> "Apple could not verify 'IdleTapper' is free of malware."

This is Apple declining to vouch for the app, not a malware finding. Clear the quarantine flag once:

```bash
xattr -dr com.apple.quarantine /Applications/IdleTapper.app
```

Or, without the terminal: try to open the app, then go to **System Settings → Privacy & Security**, scroll to the message about Idle Tapper, and click **Open Anyway**.

**On macOS 15 and later, Control-clicking the app no longer works** — Apple removed that bypass. Use one of the two routes above.

**This is a one-time cost.** Updates from then on are installed by Sparkle rather than downloaded by your browser, so they never pick up a quarantine flag and never ask again.

### Verify your download

Each release ships a `checksums-x.y.z.txt`. From the folder holding the downloads:

```bash
shasum -a 256 -c checksums-0.1.0.txt
```

### Updating

Idle Tapper checks for a new version once a day and offers to install it. **Settings → Updates** has a *Check Now* button and a switch to turn automatic checks off.

Updates are verified by an EdDSA signature that only this project can produce, checked against a public key compiled into the app. An archive that fails that check is refused — which is what keeps automatic updating safe on an app Apple has not notarized.

### Uninstalling

Drag the app to the Trash. Its data is at `~/Library/Application Support/IdleTapper/` and its preferences at `~/Library/Preferences/com.kkpon3.IdleTapper.plist`.

---

## Building

```bash
git clone https://github.com/SanditZZ/idle-tapper-macos.git
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

A debug build checks the same update feed as a release build. If you would rather it did not, turn automatic checks off in Settings.

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

SwiftData, which stores to SQLite via Core Data's persistence layer:

```
~/Library/Application Support/IdleTapper/
    IdleTapper.store        ← the SQLite database
    IdleTapper.store-wal    ← write-ahead log
    IdleTapper.store-shm    ← shared memory
```

All three files together are the database. Copying only `IdleTapper.store` can lose recent writes — the write-ahead log routinely holds committed taps that have not been folded back into the main file yet.

### Why it is not in a sandbox container

The app is **not sandboxed**, and that is a deliberate trade. Sparkle installs an update by replacing the application bundle in `/Applications`, which a sandboxed app cannot do. Sparkle can be coaxed into working inside the sandbox through XPC installer services, but that arrangement is considerably more fragile, and the sandbox was protecting very little here — the app takes no untrusted input, reads no files it did not write, and makes exactly one network request.

Builds before v0.1.0 were sandboxed and kept their database at `~/Library/Containers/com.kkpon3.IdleTapper/…`. The first launch of an unsandboxed build **copies** that store to the new location, sidecars included. It is a copy, not a move: if anything goes wrong the original is untouched, exactly where it always was.

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

### The app icon is blank, or shows a grey grid

That grid is Apple's icon placeholder, and it means macOS has a **stale cached icon** — not that the icon is missing from the app.

macOS caches an app's icon against its bundle path in the Launch Services database. A development build keeps the same path across rebuilds, so once a placeholder is cached it survives any number of rebuilds. Refresh it:

```bash
./scripts/refresh-icon-cache.sh
```

Then check Finder, the Dock or Spotlight again. The bundle itself is almost certainly fine — you can confirm by looking at `Contents/Resources/AppIcon.icns` inside the built app.

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
    ├── Logic/                     DayBoundary, StatsCalculator, StatusItemPlacement, PressAnimationTiming, StoreMigration — pure
    ├── Persistence/               TapRepository protocol + SwiftData implementation, StoreLocations, StoreMigrator
    ├── Services/                  TapTracker (observable state), AppSettings, LaunchAtLoginService, UpdateService
    └── Support/                   AppLog, ObserverBag, EventMonitor
```

### The three layers

**Calculations** (`Shared/Logic/`) are pure functions over value types. `DayBoundary`, `StatsCalculator` and `StoreMigration` never touch SwiftData, never perform I/O, and never read reactive state — the same input always gives the same output. Every branch in them is unit-tested.

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

64 tests across 7 suites, using [Swift Testing](https://developer.apple.com/documentation/testing).

```bash
xcodebuild -project IdleTapper.xcodeproj -scheme IdleTapper test
```

The suites deliberately target the things that would silently corrupt data rather than chasing coverage:

- **Day boundaries** — midnight splits, 23- and 25-hour daylight saving days, month and year rollovers
- **Statistics** — streak grace day, gap-broken streaks, zero-count days, chart gap filling, divide-by-zero peaks
- **Repository** — real SwiftData stack on an in-memory store: accumulation, the daily reset, persistence across contexts, deletion
- **Menu bar rendering** — count abbreviation thresholds
- **Status item placement** — notch overlap detection, using real geometry captured from a 16-inch MacBook Pro
- **Store migration** — the move out of the sandbox container: that the write-ahead log comes too, that a second run is a no-op, and that an occupied destination is never overwritten

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

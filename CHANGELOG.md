# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A daily tap goal. Set a target in Settings → General and the popover draws it as a ring around the counter, filling as the day goes on and turning green the moment you reach it — with the same burst of colour a milestone gets. It is off by default
- A "Goal progress" option for the menu bar, showing how far through today's goal you are as a percentage instead of a count. It keeps the same fixed width as every other style, so nothing in your menu bar moves
- An optional reminder when your streak is at risk: a notification at an hour you choose, on a day that has not met its goal yet and has a streak on the line. It is withdrawn the moment you reach the goal, so it can only ever arrive while it is still true. Clicking it opens the popover
- A new Silver achievement, Overachiever, for finishing a day with twice your daily goal

### Changed

- **While a daily goal is set, a day counts toward your streak once it reaches that goal rather than on any tap at all.** Days already recorded are unaffected: each day keeps the goal that was in effect when you tapped it, so changing your target in Settings only ever applies from today onwards, and every day recorded before this version — or with the goal switched off — still counts on a single tap. Nobody's existing streak changed
- Week Streak, Month Streak and Hundred Day Streak therefore become goal achievements for anyone who sets a goal, without changing what they say or taking back one already earned
- Exported JSON now carries each day's goal alongside its count, for days that had one

## [0.6.0] — 2026-08-18

### Added

- The Settings, History and Achievements windows can now be reached with the app switcher. While one of them is open Idle Tapper appears in ⌘-Tab and in the Dock, so a window you have clicked away from can be brought back the same way as any other app's. Closing the last one returns it to being a menu bar app, with no Dock icon. The popover is not included: it closes as soon as you click away from it
- The History window now shows this week's and this month's totals alongside the existing statistics. Both are calendar periods rather than rolling windows: "this week" is the week you are in, starting on whichever day your region starts its weeks on, and it resets on that day rather than seven days after your last tap. Both count your whole history, so they stay correct whichever range the picker is set to
- Six more achievements, taking the set from nine to fifteen: Fifty Thousand Club, Marathon Day, Hundred Day Streak, Hundred Days, and two built on your average across active days — Consistent at 100 and Relentless at 500
- Achievements are now sorted into Bronze, Silver and Gold tiers. The Achievements window is grouped under those headings, each showing how many of its own are unlocked, and an unlocked badge is coloured by its tier so a Gold one is recognisable from the card alone. The banner shown when you unlock one takes its tier's colour too
- Each unlocked achievement now shows the date it was earned, in place of the plain "Unlocked". Dates are read from what was already recorded, so achievements unlocked in earlier versions show their real date rather than today's

### Changed

- The History window's statistics now sit in two rows rather than one. Seven of them in a single row left each one too narrow to read at the window's smallest size
- An achievement you had already earned before it existed is granted the moment you open this version, with no banner. Six new achievements arriving at once would otherwise have greeted long-time users with a banner for something they did months ago
- Every achievement card is now the same size, whether it is unlocked or still in progress and however long its description runs. Unlocking one no longer changes the size of its card or moves the cards around it

## [0.5.1] — 2026-08-14

### Fixed

- The line down the middle of the Settings window, between the sidebar and the page beside it, no longer looks wrong in dark mode. It was drawn brighter than both the sidebar and the page, so it read as a raised ridge rather than the edge where the two meet; it is now a quiet recess, as it already was in light mode
- Every dividing line in the app now looks the same. The Settings pages, the History day list and the popover each drew theirs at a different strength, so the same kind of line was faint in one window and strong in another. They are now drawn once, from one place, and matched to what macOS uses in its own windows
- Cards in every window now have the outline they were always meant to have. It was too faint to be drawn at all, in either light or dark mode, so cards ran straight into the background behind them

### Changed

- Dividing lines are now a true hairline on Retina displays rather than a doubled line

## [0.5.0] — 2026-08-14

### Added

- Right-clicking the TAP button now counts a tap, just as a left-click does, with the same press animation and the same effect on milestones and achievements. Right-clicking the menu bar icon still opens its menu, and right-clicking anywhere else in the popover still does nothing
- A "Count a right-click as a tap" switch on the General settings page turns the above off, for anyone who right-clicks by habit and would rather it did not count. It is on by default and takes effect immediately

## [0.4.0] — 2026-08-14

### Added

- Achievements: nine permanent milestones for lifetime taps, single-day totals, streaks and active days, viewable from a new Achievements window (popover footer, right-click menu). Unlocking one shows a brief banner in the popover
- Milestones: crossing every 100 taps in a day shows a brief banner in the popover. Unlike achievements, milestones are not persisted, so the same figure can be reached again on a later day
- Crossing a milestone now throws a short burst of colour out of the tap button. A new "Celebrate milestones" switch on the General settings page turns it off; the milestone message stays either way. The burst is also suppressed on its own whenever macOS Reduce Motion is on

## [0.3.1] — 2026-08-13

### Fixed

- There is now one Settings window rather than two. Opening Settings from the popover or the menu bar item gave a different window than ⌘, did, so the same settings could be open twice at once, in two different-looking windows. ⌘, now opens the same window as everything else

## [0.3.0] — 2026-08-13

### Added

- History can now be exported as CSV as well as JSON. Pick the format in the save panel: CSV opens directly in a spreadsheet, JSON keeps the exact data for reading back in

### Fixed

- Exported dates now name the day the taps were recorded. Days are counted from local midnight, but the JSON export wrote them converted to UTC, so anyone outside that zone got a file dated up to a day out — every export before this one is affected

## [0.2.0] — 2026-08-13

### Accessibility

- The tap button can now be activated with VoiceOver. It could be reached and was described correctly, but activating it did nothing, so the app's one control was unusable without a mouse
- The tap button reports the running total as its value, so each tap is spoken back rather than leaving the last figure standing
- The chart describes itself in one sentence, covering how many taps over how many days, how many of those days had any, the best day and today. It previously read out every bar in turn, which at the longer ranges meant up to 365 fragments in a row
- Each row in the day list is announced as one item, a date and its total, instead of the date, the "today" marker and the number arriving as three unrelated pieces
- The date at the top of the popover is announced as one item rather than two halves

### Changed

- Settings has been rebuilt around a sidebar, with a page per section instead of one long scroll. History has been restyled to match, so the two windows now read as parts of the same app
- Choosing what the menu bar item shows is now a row of previews rather than a list of names: each option draws the item as it would actually look, using your own count. It has also moved onto the General page, where it is found without going looking for it
- The General page groups launch-at-login and the tap click together instead of giving each its own heading
- The chart no longer draws a mark for a day with no taps. Those marks lined up into what looked like a dashed line ruled across the chart, which was most misleading when there was least history to show. There is now a single quiet baseline, and a day with no taps simply has no bar
- The history chart names its tallest day, so a bar can be read without checking it against the list underneath
- The statistic previously labelled "Daily average" is now "Avg. active day". The figure has not changed: it always averaged over the days that have taps, not over every day in the range, and the old label claimed otherwise
- The list of days now ends where its rows end, rather than stretching to the bottom of the window and leaving an empty panel beneath the last entry
- The version is shown in one place, on the About page, instead of also sitting in the sidebar under every other page

### Fixed

- The Settings window opens tall enough for its longest page. Folding the menu bar options into General made that page the longest, and at the previous height it opened with "Restore Defaults" under the bottom edge

## [0.1.2] — 2026-08-13

### Fixed

- The History and Settings windows now open at the size they were designed around, rather than the smallest size they are allowed to shrink to. Settings was the worst affected: it opened too short to reach the Data section, so exporting history, deleting history, and any message reporting a failed export were all below the bottom edge of the window
- Both windows now open centred on screen, instead of slightly off-centre

## [0.1.1] — 2026-08-11

### Fixed

- The update feed is now published automatically when a release is created, instead of needing to be generated by hand. Version 0.1.0 was released without one, so nothing running that version was ever told an update existed

## [0.1.0] — 2026-08-11

Initial version.

### Added

- Menu bar status item showing today's tap total, with a choice of icon only, icon and count, or count only
- Fixed-width menu bar item so the count never resizes as it grows: the status item length is pinned, the count renders in a fully monospaced font, and abbreviations are capped at four characters, saturating to "999+" beyond 999 trillion
- Popover with today's count, a large rounded tap button, all-time and best-day statistics, current streak, and a seven-day sparkline
- Tap button that registers on press-down so rapid tapping does not drop taps, with the press animation held for a minimum duration so a soft trackpad tap gives the same feedback as a firm click
- Automatic daily reset at local midnight, derived from the current date rather than a scheduled timer, so it stays correct across sleep, wake, clock changes, time zone changes and daylight saving transitions
- History window with a configurable range of 7, 30, 90 or 365 days, a bar chart, per-day list, and summary statistics including longest streak and daily average
- Settings window covering menu bar display style, history range, tap sound, and confirmation before deletion
- History export to portable JSON
- Automatic updates via Sparkle: a daily check, a one-click install, and a Settings section with a manual check and a switch to turn automatic checking off
- Update archives verified by an EdDSA signature rather than by Apple notarization, so an update that was not published by this project is refused
- Launch at login, backed by the system login items API, reflecting the real system state rather than a cached preference, and enabled by default on first run
- Detection of a status item placed behind the display notch, with an alert explaining the cause and offering the more compact icon-only style, plus a way to re-enable the warning after dismissing it
- Delete-all-history action with confirmation
- Local persistence via SwiftData, behind a `TapRepository` protocol, stored in a directory the app owns rather than a generic filename in shared Application Support
- One-time carry-over of the database left behind by earlier sandboxed builds, copied rather than moved so the original stays intact
- Debounced writes and a cached daily record so sustained tapping does not hit the disk on every tap
- Graceful fallback to an in-memory store when the database cannot be opened, with a visible warning that history is not being saved
- Design system of typography, spacing, radius, motion and semantic color tokens, adaptive to light and dark appearance
- App icon generated from the same symbol as the menu bar item, so the two cannot drift apart, via a re-runnable script
- 64 unit tests across day boundaries, statistics, the repository, menu bar rendering, status item placement, press animation timing, and store migration

[Unreleased]: https://github.com/SanditZZ/idle-tapper-macos/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/SanditZZ/idle-tapper-macos/compare/v0.5.1...v0.6.0
[0.5.1]: https://github.com/SanditZZ/idle-tapper-macos/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/SanditZZ/idle-tapper-macos/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/SanditZZ/idle-tapper-macos/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/SanditZZ/idle-tapper-macos/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/SanditZZ/idle-tapper-macos/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/SanditZZ/idle-tapper-macos/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/SanditZZ/idle-tapper-macos/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/SanditZZ/idle-tapper-macos/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/SanditZZ/idle-tapper-macos/releases/tag/v0.1.0

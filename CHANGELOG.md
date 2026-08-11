# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-08-11

Initial version.

### Added

- Menu bar status item showing today's tap total, with a choice of icon only, icon and count, or count only
- Fixed-width menu bar item so the count never resizes as it grows: the status item length is pinned, the count renders in a fully monospaced font, and abbreviations are capped at four characters, saturating to "999+" beyond 999 trillion
- Popover with today's count, a large rounded tap button, all-time and best-day statistics, current streak, and a seven-day sparkline
- Tap button that registers on press-down so rapid tapping does not drop taps
- Automatic daily reset at local midnight, derived from the current date rather than a scheduled timer, so it stays correct across sleep, wake, clock changes, time zone changes and daylight saving transitions
- History window with a configurable range of 7, 30, 90 or 365 days, a bar chart, per-day list, and summary statistics including longest streak and daily average
- Settings window covering menu bar display style, history range, tap sound, and confirmation before deletion
- History export to portable JSON
- Launch at login, backed by the system login items API, reflecting the real system state rather than a cached preference
- Detection of a status item placed behind the display notch, with an alert explaining the cause and offering the more compact icon-only style, plus a way to re-enable the warning after dismissing it
- Delete-all-history action with confirmation
- Local persistence via SwiftData, behind a `TapRepository` protocol
- Debounced writes and a cached daily record so sustained tapping does not hit the disk on every tap
- Graceful fallback to an in-memory store when the database cannot be opened, with a visible warning that history is not being saved
- Design system of typography, spacing, radius, motion and semantic color tokens, adaptive to light and dark appearance
- 47 unit tests across day boundaries, statistics, the repository, menu bar rendering, and status item placement

[Unreleased]: https://github.com/kk-pon3/idle-tapper-macos/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/kk-pon3/idle-tapper-macos/releases/tag/v0.1.0

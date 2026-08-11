# Contributing to Idle Tapper

Thanks for your interest. This document covers how to get set up, the architecture rules that keep the codebase coherent, and what a good pull request looks like.

---

## Getting started

```bash
git clone https://github.com/SanditZZ/idle-tapper-macos.git
cd idle-tapper-macos
open IdleTapper.xcodeproj
```

There is nothing to install by hand: Swift Package Manager resolves the one dependency, [Sparkle](https://sparkle-project.org), on the first build. The project signs ad-hoc, so you do **not** need an Apple Developer account to build or run it.

## Before you push

Run the CI checks locally. They must pass:

```bash
./scripts/ci-local.sh
```

That runs exactly what GitHub Actions runs — the same two `xcodebuild` invocations with the same flags — so a red pipeline is caught before you push rather than after.

```bash
./scripts/ci-local.sh build   # build only
./scripts/ci-local.sh test    # tests only
```

The build must stay **warning-free**; CI treats Swift warnings as errors. If your change introduces a warning you genuinely cannot avoid, say so in the pull request and explain why — do not weaken the check.

If you change the flags in `scripts/ci-local.sh`, change `.github/workflows/ci.yml` to match, and vice versa. If the two drift, "it passed locally" stops meaning anything.

After pushing, confirm the real run went green — a local pass is strong evidence, not proof, since the runner has a different Xcode and a clean checkout:

```bash
./scripts/ci-watch.sh
```

---

## Architecture rules

The codebase separates Actions, Calculations and Data. Please keep changes on the right side of those lines — it is what makes the logic testable.

### Calculations are pure

Anything in `Shared/Logic/` must be a pure function: same input, same output, no I/O, no mutation, no reactive reads, no SwiftData types. `DayBoundary` and `StatsCalculator` follow this strictly.

If you need to compute something in a view or a service, write the computation as a pure function in `Shared/Logic/`, unit-test it, and call it. Do not inline logic into a `body` or a `didSet`.

### Actions own the side effects

Database writes, notification observers, timers and window management live in `Shared/Services/`, `Shared/Persistence/` and `MenuBar/`. These may be stateful and main-actor bound.

### Views are presentational

A SwiftUI view imports and calls logic; it does not implement it. Reactive lines (`@State`, `.onChange`, `.task`) stay in the view, but their **bodies** should delegate to a service or a pure function.

### Never talk to SwiftData directly outside the persistence layer

Views and services use the `TapRepository` protocol. `ModelContext`, `FetchDescriptor` and `@Model` types appear only inside `Shared/Persistence/`. `DayRecord` must not leak past that boundary — convert to `DaySnapshot` instead.

### Keep files small

If a file approaches roughly 400 lines, split it before adding more. Extract pure functions into a logic module, or split self-contained markup plus its styling into a child view. This is much cheaper done as you go than as a retrofit.

---

## Design system

**Do not hardcode fonts, spacing, radii or colors.** Use `DesignTokens` and `AppColors`:

```swift
// Yes
.font(DesignTokens.Typography.bodyMedium)
.padding(DesignTokens.Spacing.medium)
.foregroundStyle(AppColors.textSecondary)

// No
.font(.system(size: 13, weight: .medium))
.padding(12)
.foregroundStyle(.secondary)
```

If a token does not exist, add it to `DesignTokens` or `AppColors` rather than writing a one-off literal. Colors must be appearance-adaptive or translucent so they work on the popover's vibrancy material in both light and dark mode — check both before submitting.

**Icons are SF Symbols**, never emoji. Emoji render differently across systems and cannot be tinted or sized reliably.

---

## Error handling

The app should never crash on a recoverable condition, and it should never fail silently.

- Catch errors, log them with the relevant `AppLog` category, and degrade gracefully
- A failed tap write must not interrupt the game — capture the message, surface it in the UI, let the next tap retry
- Every default value must be valid and functional; no placeholder defaults
- Validate inputs at boundaries and handle `nil` explicitly

---

## Logging

Use the `AppLog` namespace, with a `[Module]` prefix in the message:

```swift
AppLog.persistence.info("[Persistence] Saved")
AppLog.tap.error("[Tap] Increment failed: \(error.localizedDescription, privacy: .public)")
```

Log success, failure and significant state transitions. Do not log on every tap — that is a hot path.

Mark interpolations `privacy: .public` only when the value is genuinely not user data. Tap counts and dates are personal; prefer logging that something happened over logging what the value was.

---

## Testing

Tests use [Swift Testing](https://developer.apple.com/documentation/testing) (`import Testing`, `@Test`, `#expect`), not XCTest.

Write **high-value tests only**. We want tests for:

- Core logic and its edge cases — day boundaries, streak rules, aggregate math
- Failure scenarios — empty history, zero peaks, missing days, divide-by-zero
- Anything that could silently corrupt a user's history

We do not want tests that assert a property returns what was just assigned to it, or that exercise SwiftUI layout.

**Pin time in tests.** Use `TestSupport.utcCalendar` and explicit dates. A test that depends on the machine's time zone or on when it runs will eventually fail for someone else. Daylight saving cases use `TestSupport.newYorkCalendar` deliberately.

Repository tests run against a real SwiftData stack via `ModelContainerFactory.makeInMemory()` — no mocks, no disk.

---

## Swift concurrency

The project builds in Swift 5 language mode with `SWIFT_STRICT_CONCURRENCY = targeted`.

Almost all state is `@MainActor` bound, which is appropriate for a UI-driven app of this size. When you add a type that holds mutable state touched by the UI, mark it `@MainActor`.

One deliberate constraint worth knowing: `#Predicate` and `SortDescriptor` generate key paths that are not yet `Sendable`, which trips strict concurrency checking. `SwiftDataTapRepository` therefore fetches all records and filters in Swift. This is a sound trade at the current scale — the table holds one row per day, so a decade of use is a few thousand rows. If the schema ever grows finer-grained rows, real predicates start to earn their keep and the trade should be revisited.

Moving to full Swift 6 language mode is desirable but currently blocked on SwiftData's key paths gaining `Sendable` conformance.

---

## Commits and pull requests

**Commit messages** are one sentence, capitalised, past tense, describing one logical change:

```
Added streak calculation to the history window
Fixed the daily reset across daylight saving transitions
```

Split unrelated changes into separate commits.

**Pull requests** should:

- Describe what changed and why, not just what
- Note anything you deliberately did not do, and why
- Include tests for new logic
- Confirm the build is warning-free and all tests pass
- For UI changes, say what you checked manually — including light mode, dark mode, and any empty or error state

Keep pull requests focused. A large mixed change is hard to review and hard to revert.

---

## Reporting bugs

Open an issue with:

- Your macOS version and how you installed the app
- What you expected and what happened instead
- Reproduction steps, and whether it is consistent
- Anything relevant from Console.app filtered by the `IdleTapper` subsystem

Bugs involving the daily reset are especially worth reporting — please include your time zone and whether the Mac had been asleep.

---

## Security

Do not open a public issue for a security problem. See [SECURITY.md](SECURITY.md).

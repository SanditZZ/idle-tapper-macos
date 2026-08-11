# CLAUDE.md — Idle Tapper

Project-specific instructions. These apply to this repository only and take precedence over general habits.

---

## 1. 🚨 CI must pass locally BEFORE any push

**Never push without running the CI checks locally first, and never push when they fail.**

```bash
./scripts/ci-local.sh
```

That script runs **exactly** what `.github/workflows/ci.yml` runs — the same two `xcodebuild` invocations with the same flags — so a red pipeline is caught before anything leaves the machine. GitHub Actions only reports *after* a push, which is too late to be a gate.

**The rule, in order:**

1. Run `./scripts/ci-local.sh`. It must exit `0`.
2. Only then push.
3. **After pushing, confirm the real run went green** — a local pass is strong evidence, not proof, because the runner has a different Xcode and a clean checkout:
   ```bash
   ./scripts/ci-watch.sh
   ```
   It resolves the latest run for the current branch, waits for it, and exits non-zero if it failed. (`gh run watch` on its own requires an explicit run id when not attached to a terminal, and would otherwise use the wrong GitHub account.)
4. If the remote run fails, **fix it immediately** — do not leave `main` or an open PR red, and do not move on to other work first.

**Do not weaken the checks to make them pass.** If a warning is genuinely unavoidable, say so explicitly and explain why rather than removing `SWIFT_TREAT_WARNINGS_AS_ERRORS` or deleting a test.

**Keep the two in step.** `scripts/ci-local.sh` and `.github/workflows/ci.yml` must use identical flags. If one gains a flag, so must the other, or "it passed locally" stops meaning anything.

### What CI enforces

| Check | Command | Notes |
|---|---|---|
| Build | `xcodebuild build … SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` | The build must stay **warning-free** |
| Test | `xcodebuild test …` | All tests must pass |

CI runs on every branch push and on pull requests into `main`, deduplicated by a concurrency group keyed on the branch name.

---

## 2. Git and GitHub for this repo

**This is a personal project.** It must never be pushed or attributed under the work account.

| | |
|---|---|
| Repo | `SanditZZ/idle-tapper-macos` (private) |
| Git identity | Local config only: `kk.pon3 <kk.pon3@gmail.com>` — **never** change the global config |
| Remote | `git@github.com-personal:SanditZZ/idle-tapper-macos.git` |

**⚠️ The SSH alias is not optional.** Plain `git@github.com` resolves to the **work** account on this machine:

```
ssh -T git@github.com            → "Hi po-planify!"     ← WRONG account
ssh -T git@github.com-personal   → "Hi SanditZZ!"       ← correct
```

**⚠️ `gh` defaults to the work account too.** Pass the personal token per command rather than running `gh auth switch`, so other sessions are not affected:

```bash
GH_TOKEN="$(gh auth token --user SanditZZ)" gh <command>
```

**Branching.** All work goes on a feature branch; `main` is written only through a pull request. Never commit or merge onto `main` locally.

**Commit messages.** One sentence, capitalised, past tense, describing one logical change. Split unrelated changes into separate commits.

```
Added streak calculation to the history window
Fixed the daily reset across daylight saving transitions
```

**Never add an AI or co-author trailer** to a commit message.

---

## 3. Architecture — Actions, Calculations, Data

**Calculations** (`Shared/Logic/`) are pure: same input, same output, no I/O, no mutation, no reactive reads, no SwiftData types. Every branch is unit-tested. If a view or service needs a computation, write it here and call it — do not inline logic into a `body` or a `didSet`.

**Actions** (`Shared/Services/`, `Shared/Persistence/`, `MenuBar/`) own the side effects: database writes, observers, timers, windows. Stateful and usually `@MainActor`.

**Data** (`Shared/Models/`) is split deliberately: `DayRecord` is the `@Model` bound to a `ModelContext`; `DaySnapshot` is the plain `Sendable` value type that crosses into the calculation layer.

**Never touch SwiftData outside `Shared/Persistence/`.** Views and services use the `TapRepository` protocol. `ModelContext`, `FetchDescriptor` and `@Model` types stay behind that boundary, and `DayRecord` is converted to `DaySnapshot` before it leaves.

**Views are presentational.** They import and call logic; they do not implement it.

**Keep files small.** At roughly 400 lines, split before adding more.

---

## 4. Design system

**Never hardcode fonts, spacing, radii or colors.** Use `DesignTokens` and `AppColors`; if a token does not exist, add it there rather than writing a literal.

```swift
.font(DesignTokens.Typography.bodyMedium)     // yes
.font(.system(size: 13, weight: .medium))     // no
```

Colors must be appearance-adaptive or translucent — they sit on the popover's vibrancy material. **Check light and dark before calling a UI change done.**

**Icons are SF Symbols, never emoji.**

**The app icon is generated, not hand-edited.** `scripts/generate-app-icon.swift` renders it from the same symbol the menu bar uses (`StatusItemRenderer.symbolName`), so the two cannot drift. Editing the PNGs in `AppIcon.appiconset` directly is pointless — the next run overwrites them. To change the icon, change the script and re-run:

```bash
swift scripts/generate-app-icon.swift
```

---

## 5. Testing

Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest.

**High-value tests only:** core logic and edge cases, failure scenarios, and anything that could silently corrupt a user's history. Do not test that a property returns what was just assigned to it.

**Pin time.** Use `TestSupport.utcCalendar` and explicit dates; daylight saving cases use `TestSupport.newYorkCalendar`. A test that depends on the machine's time zone or on when it runs will fail for someone else.

Repository tests run against a real SwiftData stack via `ModelContainerFactory.makeInMemory()` — no mocks, no disk.

---

## 6. Things that are easy to get wrong

**The daily reset has no timer, and must not gain one.** "Today" is whichever day contains `Date()`; a new day has no record and reads zero. This is what makes it correct across sleep, clock changes and daylight saving. The day-change, wake and clock observers exist only to refresh an open popover — they do not perform the reset.

**Day arithmetic uses `Calendar`, never `86400`.** Daylight saving days are 23 or 25 hours long.

**The menu bar item is a fixed width on purpose.** `StatusItemRenderer` pads titles to a fixed field and the item's `length` is pinned, because a self-sizing item drags every other status item along with it as the count grows. Abbreviations are capped at four characters for the same reason.

**The tap button's press animation is held for a minimum duration on purpose.** A trackpad tap-to-click lasts a few milliseconds; driving the animation straight off the gesture means it never renders.

**Anything rendered in the popover is transient.** The popover dismisses on outside click, so it cannot host anything long-running — that needs its own window via `WindowCoordinator`.

**Errors never crash and never fail silently.** Catch, log through the relevant `AppLog` category, degrade gracefully, and surface the message in the UI. A failed tap write must not interrupt the game.

---

## 7. Before proposing a "new" feature

Read `docs/potential-features.md` first. It already captures the camera mode, global tap shortcut, idle-game mechanics, iCloud sync, widgets, data import and more — each with the constraint that makes it non-trivial. Add to it rather than duplicating it.

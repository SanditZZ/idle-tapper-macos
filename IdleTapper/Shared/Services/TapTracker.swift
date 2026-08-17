//
//  TapTracker.swift
//  Idle Tapper — Actions layer
//
//  The single source of truth the UI observes. Owns no persistence logic of its
//  own: it drives a `TapRepository` and hands the results to the pure
//  calculation layer.
//
//  Daily reset is deliberately *not* implemented with a midnight timer. The
//  count for "today" is whatever the repository holds for the day containing
//  `Date()`, so crossing midnight — including while the Mac was asleep — yields
//  zero with no scheduled work. The observers below exist only to refresh a
//  visible UI, never to perform the reset.
//

import Foundation
import Observation
import AppKit

@MainActor
@Observable
final class TapTracker {

    // MARK: - Published Data

    /// Taps recorded today. Updated synchronously on every tap.
    private(set) var todayCount: Int = 0

    /// Aggregate statistics across all history. Recomputed on a short debounce.
    private(set) var stats: TapStats = .empty

    /// Bars for the popover sparkline, oldest first.
    private(set) var recentBars: [DayBar] = []

    /// The full achievement catalog with current locked/unlocked state and
    /// progress. Recomputed alongside `stats`.
    private(set) var achievementProgress: [AchievementProgress] = []

    /// The achievement most recently unlocked, for a transient popover
    /// banner. Clears itself after `bannerDuration`.
    private(set) var latestUnlock: AchievementDefinition?

    /// The milestone most recently crossed today, for a transient popover
    /// banner. Clears itself after `bannerDuration`.
    private(set) var activeMilestone: Int?

    /// Human-readable description of the last failure, or `nil` when healthy.
    /// Surfaced in the UI so a silent persistence failure cannot go unnoticed.
    private(set) var lastErrorMessage: String?

    /// True when history is held only in memory because the on-disk store could
    /// not be opened.
    let isEphemeral: Bool

    // MARK: - Dependencies

    /// Not `private`, unlike its neighbours, because `TapTracker+Export.swift`
    /// is a separate file and Swift's `private` is file-scoped. The export
    /// moved out when this file reached the size at which it has to be split.
    @ObservationIgnored let repository: any TapRepository

    @ObservationIgnored private let settings: AppSettings

    /// See `repository` for why this is not `private` either.
    @ObservationIgnored let calendar: Calendar

    @ObservationIgnored private let now: () -> Date

    /// Debounce for recomputing derived statistics. Taps update the counter
    /// immediately; the heavier full-history aggregation waits for a pause.
    @ObservationIgnored private let derivedDebounce: Duration
    @ObservationIgnored private var pendingDerivedRefresh: Task<Void, Never>?

    /// How long `latestUnlock` / `activeMilestone` stay up before clearing.
    @ObservationIgnored private let bannerDuration: Duration
    @ObservationIgnored private var pendingUnlockClear: Task<Void, Never>?
    @ObservationIgnored private var pendingMilestoneClear: Task<Void, Never>?

    /// Achievements already unlocked, as persisted, keyed to when they were
    /// earned. This — not a live recomputation from `stats` — is the source of
    /// truth for what counts as unlocked, so an achievement earned once stays
    /// earned even if history is later deleted. See
    /// `SwiftDataTapRepository.deleteAll()`.
    @ObservationIgnored private var unlockDates: [AchievementID: Date] = [:]

    /// Whether `evaluateAchievements` has run at least once this launch.
    ///
    /// The first evaluation happens in `init`, before the user can have
    /// tapped, so anything newly satisfied then was already true when the app
    /// opened — a release that adds catalog entries, most often. Those are
    /// granted silently; a banner celebrating something the user did months
    /// ago, at the moment they open the app, is noise.
    @ObservationIgnored private var hasEvaluatedAchievements = false

    /// Highest milestone already shown today, kept with the day it applies
    /// to so a rollover resets it the same way the repository's own record
    /// cache resets on a new day.
    @ObservationIgnored private var lastMilestoneDay: (dayStart: Date, highest: Int)?

    /// Retains notification tokens and unregisters them automatically.
    @ObservationIgnored private let observers = ObserverBag()

    /// Number of bars in the popover sparkline.
    static let sparklineDayCount = 7

    // MARK: - Lifecycle

    /// - Parameters:
    ///   - repository: Persistence boundary.
    ///   - settings: User preferences, used for the history range.
    ///   - isEphemeral: True when the repository is an in-memory fallback.
    ///   - calendar: Calendar for day boundaries. Injectable for tests.
    ///   - derivedDebounce: Quiet period before recomputing statistics.
    ///   - bannerDuration: How long an unlock/milestone banner stays up.
    ///   - now: Clock, injectable for tests.
    init(
        repository: any TapRepository,
        settings: AppSettings,
        isEphemeral: Bool = false,
        calendar: Calendar = .current,
        derivedDebounce: Duration = .milliseconds(400),
        bannerDuration: Duration = .seconds(4),
        now: @escaping () -> Date = { Date() }
    ) {
        self.repository = repository
        self.settings = settings
        self.isEphemeral = isEphemeral
        self.calendar = calendar
        self.derivedDebounce = derivedDebounce
        self.bannerDuration = bannerDuration
        self.now = now

        refresh()
        startObserving()
    }

    deinit {
        pendingDerivedRefresh?.cancel()
        pendingUnlockClear?.cancel()
        pendingMilestoneClear?.cancel()
        // `observers` unregisters itself when released.
    }

    // MARK: - Actions

    /// Record a single tap.
    ///
    /// Never throws: a failed write must not interrupt the game. The error is
    /// captured for display and the next tap retries.
    func tap() {
        let tapDate = now()
        let previousToday = todayCount

        do {
            todayCount = try repository.increment(by: 1, at: tapDate)
            lastErrorMessage = nil
            evaluateMilestone(previousToday: previousToday, newToday: todayCount, at: tapDate)
            scheduleDerivedRefresh()
        } catch {
            lastErrorMessage = error.localizedDescription
            AppLog.tap.error("[Tap] Increment failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Reload today's count and all derived statistics from the repository.
    ///
    /// Called on launch, on day change, on wake, and whenever the popover is
    /// about to be shown.
    func refresh() {
        let currentDate = now()

        do {
            todayCount = try repository.count(on: currentDate)
            let history = try repository.allDays()

            stats = StatsCalculator.stats(from: history, now: currentDate, calendar: calendar)
            recentBars = StatsCalculator.series(
                from: history,
                days: Self.sparklineDayCount,
                endingOn: currentDate,
                calendar: calendar
            )

            unlockDates = AchievementCalculator.unlockDates(from: try repository.unlockedAchievements())
            evaluateAchievements(at: currentDate)
            achievementProgress = AchievementCalculator.progress(
                stats: stats,
                unlocked: unlockDates
            )

            resetMilestoneTrackingIfNeeded(at: currentDate)

            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
            AppLog.tap.error("[Tap] Refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Bars covering the user's configured history range, for the History window.
    func historyBars() -> [DayBar] {
        do {
            let history = try repository.allDays()
            return StatsCalculator.series(
                from: history,
                days: settings.historyRangeDays,
                endingOn: now(),
                calendar: calendar
            )
        } catch {
            lastErrorMessage = error.localizedDescription
            AppLog.tap.error("[Tap] History fetch failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Delete all recorded history. Irreversible.
    func deleteAllHistory() {
        do {
            try repository.deleteAll()
            AppLog.tap.info("[Tap] History deleted by user")
            refresh()
        } catch {
            lastErrorMessage = error.localizedDescription
            AppLog.tap.error("[Tap] Delete-all failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Force pending writes to disk. Call before termination.
    func flush() {
        pendingDerivedRefresh?.cancel()
        do {
            try repository.flush()
        } catch {
            AppLog.tap.error("[Tap] Flush failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // Export lives in `TapTracker+Export.swift`.

    // MARK: - Achievements & Milestones

    /// Persist any achievement newly satisfied by `stats`, and show the
    /// first one (in catalog order) as a banner.
    ///
    /// A refresh that satisfies several achievements at once — for example
    /// right after a big backfill — still persists every one of them; only
    /// the banner is limited to one at a time. The rest are already visible
    /// in the Achievements window with no banner needed.
    ///
    /// The very first evaluation of a launch grants **silently**: see
    /// `hasEvaluatedAchievements`. The flag is read and set here at the top,
    /// above the early return, because a launch where nothing is newly
    /// satisfied is the common case — leaving it below would mean the first
    /// *real* unlock of the session was mistaken for the initial one and lost
    /// its banner.
    private func evaluateAchievements(at date: Date) {
        let isInitialEvaluation = !hasEvaluatedAchievements
        hasEvaluatedAchievements = true

        let currentlyMet = AchievementCalculator.unlocked(from: stats)
        let newlyUnlocked = AchievementCalculator.newlyUnlocked(
            previously: Set(unlockDates.keys),
            now: currentlyMet
        )
        guard !newlyUnlocked.isEmpty else { return }

        for id in newlyUnlocked {
            do {
                try repository.unlockAchievement(id, at: date)
                unlockDates[id] = date
            } catch {
                lastErrorMessage = error.localizedDescription
                AppLog.tap.error(
                    "[Tap] Failed to persist achievement \(id.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        guard !isInitialEvaluation else {
            AppLog.tap.info(
                "[Tap] Granted \(newlyUnlocked.count, privacy: .public) already-earned achievement(s) on launch, without a banner"
            )
            return
        }

        if let definition = AchievementCatalog.all.first(where: { newlyUnlocked.contains($0.id) }) {
            latestUnlock = definition
            pendingUnlockClear?.cancel()
            pendingUnlockClear = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: self.bannerDuration)
                guard !Task.isCancelled else { return }
                self.latestUnlock = nil
            }
        }
    }

    /// Start a fresh milestone count for a day not seen before, so a rollover
    /// does not carry yesterday's "already shown" state into today.
    private func resetMilestoneTrackingIfNeeded(at date: Date) {
        let todayStart = DayBoundary.dayStart(for: date, calendar: calendar)
        if lastMilestoneDay?.dayStart != todayStart {
            lastMilestoneDay = (todayStart, 0)
        }
    }

    /// Show a milestone banner if `newToday` crosses one past whatever was
    /// last shown today.
    private func evaluateMilestone(previousToday: Int, newToday: Int, at date: Date) {
        resetMilestoneTrackingIfNeeded(at: date)

        guard let crossed = MilestoneCalculator.crossed(
            from: previousToday,
            to: newToday,
            interval: MilestoneCalculator.defaultInterval
        ), crossed > (lastMilestoneDay?.highest ?? 0) else { return }

        let todayStart = DayBoundary.dayStart(for: date, calendar: calendar)
        lastMilestoneDay = (todayStart, crossed)

        activeMilestone = crossed
        pendingMilestoneClear?.cancel()
        pendingMilestoneClear = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.bannerDuration)
            guard !Task.isCancelled else { return }
            self.activeMilestone = nil
        }
    }

    // MARK: - Derived Refresh

    private func scheduleDerivedRefresh() {
        pendingDerivedRefresh?.cancel()
        pendingDerivedRefresh = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.derivedDebounce)
            guard !Task.isCancelled else { return }
            self.refresh()
        }
    }

    // MARK: - Observers

    /// Refresh a visible UI when the day changes or the Mac wakes.
    ///
    /// These do not perform the reset — the reset is implicit in reading the
    /// current day — they only keep an already-open popover from showing a
    /// stale count.
    private func startObserving() {
        // Local midnight passed.
        observers.observe(.NSCalendarDayChanged) { [weak self] _ in
            MainActor.assumeIsolated {
                AppLog.tap.info("[Tap] Calendar day changed — refreshing")
                self?.refresh()
            }
        }

        // The Mac may have slept across one or more midnights.
        observers.observe(
            NSWorkspace.didWakeNotification,
            on: NSWorkspace.shared.notificationCenter
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                AppLog.tap.debug("[Tap] Woke from sleep — refreshing")
                self?.refresh()
            }
        }

        // The system clock or time zone moved, which can change what "today" is.
        observers.observe(.NSSystemClockDidChange) { [weak self] _ in
            MainActor.assumeIsolated {
                AppLog.tap.info("[Tap] System clock changed — refreshing")
                self?.refresh()
            }
        }

        observers.observe(.NSSystemTimeZoneDidChange) { [weak self] _ in
            MainActor.assumeIsolated {
                AppLog.tap.info("[Tap] Time zone changed — refreshing")
                self?.refresh()
            }
        }
    }
}

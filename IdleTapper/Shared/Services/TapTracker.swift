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

    @ObservationIgnored private let repository: any TapRepository
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date

    /// Debounce for recomputing derived statistics. Taps update the counter
    /// immediately; the heavier full-history aggregation waits for a pause.
    @ObservationIgnored private let derivedDebounce: Duration
    @ObservationIgnored private var pendingDerivedRefresh: Task<Void, Never>?

    /// How long `latestUnlock` / `activeMilestone` stay up before clearing.
    @ObservationIgnored private let bannerDuration: Duration
    @ObservationIgnored private var pendingUnlockClear: Task<Void, Never>?
    @ObservationIgnored private var pendingMilestoneClear: Task<Void, Never>?

    /// Achievements already unlocked, as persisted. This — not a live
    /// recomputation from `stats` — is the source of truth for what counts as
    /// unlocked, so an achievement earned once stays earned even if history
    /// is later deleted. See `SwiftDataTapRepository.deleteAll()`.
    @ObservationIgnored private var unlockedAchievementIDs: Set<AchievementID> = []

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

            unlockedAchievementIDs = Set(try repository.unlockedAchievements().map(\.id))
            evaluateAchievements(at: currentDate)
            achievementProgress = AchievementCalculator.progress(
                stats: stats,
                unlocked: unlockedAchievementIDs
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

    /// Export the full history as JSON, for the Settings export action.
    ///
    /// Deliberately not the raw SQLite store: that schema is SwiftData's
    /// private implementation detail, whereas this is a stable, portable format.
    ///
    /// Dates carry the recording zone's offset rather than being converted to
    /// UTC. `JSONEncoder`'s stock `.iso8601` strategy does convert, and since
    /// `dayStart` is *local* midnight that pushed the date part onto the
    /// neighbouring day for every user not on UTC — see `ExportDateFormat`.
    func exportJSON() throws -> Data {
        let history = try repository.allDays()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let timeZone = calendar.timeZone
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ExportDateFormat.iso8601(date, timeZone: timeZone))
        }

        return try encoder.encode(history)
    }

    /// Export the full history as CSV, for the Settings export action.
    ///
    /// The spreadsheet-shaped sibling of `exportJSON()`. Not a round-trippable
    /// format — it drops nothing today, but JSON is the one to re-import.
    func exportCSV() throws -> Data {
        let history = try repository.allDays()
        let text = HistoryCSV.make(from: history, timeZone: calendar.timeZone)
        return Data(text.utf8)
    }

    // MARK: - Achievements & Milestones

    /// Persist any achievement newly satisfied by `stats`, and show the
    /// first one (in catalog order) as a banner.
    ///
    /// A refresh that satisfies several achievements at once — for example
    /// right after a big backfill — still persists every one of them; only
    /// the banner is limited to one at a time. The rest are already visible
    /// in the Achievements window with no banner needed.
    private func evaluateAchievements(at date: Date) {
        let currentlyMet = AchievementCalculator.unlocked(from: stats)
        let newlyUnlocked = AchievementCalculator.newlyUnlocked(
            previously: unlockedAchievementIDs,
            now: currentlyMet
        )
        guard !newlyUnlocked.isEmpty else { return }

        for id in newlyUnlocked {
            do {
                try repository.unlockAchievement(id, at: date)
                unlockedAchievementIDs.insert(id)
            } catch {
                lastErrorMessage = error.localizedDescription
                AppLog.tap.error(
                    "[Tap] Failed to persist achievement \(id.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
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

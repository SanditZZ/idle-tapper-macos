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
    ///   - now: Clock, injectable for tests.
    init(
        repository: any TapRepository,
        settings: AppSettings,
        isEphemeral: Bool = false,
        calendar: Calendar = .current,
        derivedDebounce: Duration = .milliseconds(400),
        now: @escaping () -> Date = { Date() }
    ) {
        self.repository = repository
        self.settings = settings
        self.isEphemeral = isEphemeral
        self.calendar = calendar
        self.derivedDebounce = derivedDebounce
        self.now = now

        refresh()
        startObserving()
    }

    deinit {
        pendingDerivedRefresh?.cancel()
        // `observers` unregisters itself when released.
    }

    // MARK: - Actions

    /// Record a single tap.
    ///
    /// Never throws: a failed write must not interrupt the game. The error is
    /// captured for display and the next tap retries.
    func tap() {
        do {
            todayCount = try repository.increment(by: 1, at: now())
            lastErrorMessage = nil
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

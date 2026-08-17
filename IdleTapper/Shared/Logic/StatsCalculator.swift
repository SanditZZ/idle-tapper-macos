//
//  StatsCalculator.swift
//  Idle Tapper — Calculations (pure)
//
//  Derives every displayed statistic from a list of day snapshots. Pure
//  functions only: same input, same output, no I/O and no SwiftData types, so
//  the whole thing is directly unit-testable.
//

import Foundation

/// Aggregations over tap history.
enum StatsCalculator {

    // MARK: - Aggregate Statistics

    /// Derive the full statistics summary from a history of day snapshots.
    ///
    /// - Parameters:
    ///   - snapshots: Every recorded day, in any order. Days with a zero count
    ///     are tolerated and treated as inactive.
    ///   - now: The instant treated as "now". Injected so tests can pin it.
    ///   - calendar: Calendar used for day arithmetic.
    static func stats(
        from snapshots: [DaySnapshot],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TapStats {
        guard !snapshots.isEmpty else { return .empty }

        let todayStart = DayBoundary.dayStart(for: now, calendar: calendar)
        let today = snapshots.first { $0.dayStart == todayStart }?.tapCount ?? 0

        let active = snapshots.filter { $0.tapCount > 0 }
        let allTime = snapshots.reduce(0) { $0 + $1.tapCount }
        let best = active.max { $0.tapCount < $1.tapCount }

        return TapStats(
            today: today,
            thisWeek: total(from: snapshots, in: .weekOfYear, containing: now, calendar: calendar),
            thisMonth: total(from: snapshots, in: .month, containing: now, calendar: calendar),
            allTime: allTime,
            bestDay: best?.tapCount ?? 0,
            bestDayDate: best?.dayStart,
            currentStreak: currentStreak(from: snapshots, now: now, calendar: calendar),
            longestStreak: longestStreak(from: snapshots, calendar: calendar),
            activeDays: active.count,
            averagePerActiveDay: active.isEmpty
                ? 0
                : Double(allTime) / Double(active.count)
        )
    }

    // MARK: - Calendar Periods

    /// Total taps across the calendar period of `component` containing `now`.
    ///
    /// `Calendar.dateInterval(of:for:)` decides the boundaries, which is the
    /// whole point: a week begins on whichever day `calendar.firstWeekday`
    /// names, and a month is however many days that month actually has. A
    /// rolling window of seven or thirty days is a *different* statistic that
    /// merely agrees with this one at the start of a period — computing it that
    /// way would report a Saturday's taps as part of the following week.
    ///
    /// A day counts when its `dayStart` falls inside the interval. That keeps
    /// the comparison on day boundaries, where both sides were built, rather
    /// than on elapsed seconds — a daylight saving day is 23 or 25 hours long,
    /// so any arithmetic in seconds lands a day either side of the truth twice
    /// a year.
    ///
    /// The range is compared **half-open** by hand rather than with
    /// `DateInterval.contains(_:)`, which is `start...end` *inclusive of the
    /// end instant*. A period's `end` is the very instant its successor begins —
    /// midnight on the 1st of the next month, midnight on the next week's first
    /// day — and that instant is exactly the `dayStart` of a real recorded day.
    /// Using `contains` therefore counted the first day of April in March, and
    /// only on the boundary, which is the one case a casual test would miss.
    ///
    /// - Returns: Zero when the calendar cannot form the interval, which it
    ///   only fails to do for dates outside the calendar's own range.
    static func total(
        from snapshots: [DaySnapshot],
        in component: Calendar.Component,
        containing now: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard let interval = calendar.dateInterval(of: component, for: now) else {
            AppLog.tap.error("[StatsCalculator] No \(String(describing: component), privacy: .public) interval for the given date")
            return 0
        }

        return snapshots
            .filter { $0.dayStart >= interval.start && $0.dayStart < interval.end }
            .reduce(0) { $0 + $1.tapCount }
    }

    // MARK: - Streaks

    /// Consecutive days with at least one tap, counting backwards.
    ///
    /// Today is included when it already has a tap. When today has none, the
    /// streak is measured from yesterday instead — an untapped day in progress
    /// does not break a streak until it is over.
    static func currentStreak(
        from snapshots: [DaySnapshot],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let activeDays = Set(snapshots.filter { $0.tapCount > 0 }.map(\.dayStart))
        guard !activeDays.isEmpty else { return 0 }

        let todayStart = DayBoundary.dayStart(for: now, calendar: calendar)

        // Start at today if it counts, otherwise allow the in-progress grace day.
        var offset = activeDays.contains(todayStart) ? 0 : 1
        var streak = 0

        while true {
            let day = DayBoundary.dayStart(daysAgo: offset, from: now, calendar: calendar)
            guard activeDays.contains(day) else { break }
            streak += 1
            offset += 1
        }

        return streak
    }

    /// Longest run of consecutive tapped days anywhere in the history.
    static func longestStreak(
        from snapshots: [DaySnapshot],
        calendar: Calendar = .current
    ) -> Int {
        let days = Set(snapshots.filter { $0.tapCount > 0 }.map(\.dayStart)).sorted()
        guard let first = days.first else { return 0 }

        var longest = 1
        var run = 1
        var previous = first

        for day in days.dropFirst() {
            let gap = calendar.dateComponents([.day], from: previous, to: day).day ?? 0
            run = (gap == 1) ? run + 1 : 1
            longest = max(longest, run)
            previous = day
        }

        return longest
    }

    // MARK: - Series

    /// Build a fixed-length, evenly spaced series for the history chart.
    ///
    /// Days with no record are emitted with a zero count rather than omitted,
    /// so the chart keeps a stable x-axis and gaps read as gaps.
    static func series(
        from snapshots: [DaySnapshot],
        days: Int,
        endingOn now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DayBar] {
        let countsByDay = Dictionary(
            snapshots.map { ($0.dayStart, $0.tapCount) },
            uniquingKeysWith: { lhs, rhs in max(lhs, rhs) }
        )
        let todayStart = DayBoundary.dayStart(for: now, calendar: calendar)

        return DayBoundary
            .recentDayStarts(count: days, endingOn: now, calendar: calendar)
            .map { day in
                DayBar(
                    dayStart: day,
                    tapCount: countsByDay[day] ?? 0,
                    isToday: day == todayStart
                )
            }
    }

    /// Highest count in a series, used to scale the bars. Never negative.
    static func peak(of bars: [DayBar]) -> Int {
        max(bars.map(\.tapCount).max() ?? 0, 0)
    }

    // MARK: - Formatting

    /// A day count with its unit, pluralised — "1 day", "2 days".
    ///
    /// Interpolating the count and appending "days" reads as "1 days" on the
    /// single-day case, which is the case a new user sees first.
    static func dayCountText(_ days: Int) -> String {
        "\(days.formatted()) \(abs(days) == 1 ? "day" : "days")"
    }

    /// Daily average as a whole number, grouped like every other figure shown.
    ///
    /// `String(format: "%.0f")` skips the grouping separator, so the average was
    /// the one statistic rendered "2633" while its neighbours read "2,633".
    /// Non-finite input degrades to "0" rather than rendering "nan".
    static func averageText(_ average: Double) -> String {
        guard average.isFinite, average > 0 else { return "0" }
        return Int(average.rounded()).formatted()
    }
}

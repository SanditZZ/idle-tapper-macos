//
//  DayBoundary.swift
//  Idle Tapper — Calculations (pure)
//
//  Everything about "which day is it" lives here. No I/O, no state, no timers:
//  the daily reset is a consequence of asking which day `now` falls in, not of
//  a scheduled event. That is what makes it correct across sleep, wake, time
//  zone changes and daylight saving transitions.
//

import Foundation

/// Pure calendar arithmetic for local-day boundaries.
enum DayBoundary {

    /// Midnight of the local day containing `date`.
    ///
    /// Uses the supplied calendar — which defaults to the machine's current
    /// calendar and time zone — so the reset happens at the user's local
    /// midnight, as configured in System Settings.
    static func dayStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Whether two instants fall on the same local day.
    static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    /// The day-start `count` days before the day containing `date`.
    ///
    /// Uses calendar arithmetic rather than subtracting 86,400 seconds, so
    /// daylight saving transitions (23- and 25-hour days) resolve correctly.
    static func dayStart(
        daysAgo count: Int,
        from date: Date,
        calendar: Calendar = .current
    ) -> Date {
        let start = dayStart(for: date, calendar: calendar)
        guard let shifted = calendar.date(byAdding: .day, value: -count, to: start) else {
            // Calendar arithmetic only fails for absurd inputs. Degrading to the
            // current day keeps the UI showing something sane instead of crashing.
            AppLog.tap.error("[DayBoundary] Failed to shift \(count) days back from \(start, privacy: .public)")
            return start
        }
        return dayStart(for: shifted, calendar: calendar)
    }

    /// Ascending list of day-starts for the `count` most recent days, ending on
    /// the day containing `date` (inclusive).
    ///
    /// A `count` of 7 returns six days ago through today.
    static func recentDayStarts(
        count: Int,
        endingOn date: Date = Date(),
        calendar: Calendar = .current
    ) -> [Date] {
        guard count > 0 else { return [] }
        return (0..<count)
            .map { dayStart(daysAgo: $0, from: date, calendar: calendar) }
            .reversed()
    }

    /// Number of whole local days between two instants' day boundaries.
    /// Positive when `later` is after `earlier`.
    static func dayCount(
        from earlier: Date,
        to later: Date,
        calendar: Calendar = .current
    ) -> Int {
        let start = dayStart(for: earlier, calendar: calendar)
        let end = dayStart(for: later, calendar: calendar)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
}

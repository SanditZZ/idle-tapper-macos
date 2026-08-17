//
//  DaySnapshot.swift
//  Idle Tapper — Value types
//
//  Plain, `Sendable` value types that cross the boundary between persistence
//  and the pure calculation layer.
//

import Foundation

/// An immutable reading of one day's tap total.
struct DaySnapshot: Equatable, Hashable, Sendable, Codable, Identifiable {
    /// Midnight (local time) of the day.
    let dayStart: Date

    /// Taps recorded on that day.
    let tapCount: Int

    var id: Date { dayStart }

    init(dayStart: Date, tapCount: Int) {
        self.dayStart = dayStart
        self.tapCount = tapCount
    }
}

/// A single bar in the history sparkline.
///
/// Distinct from `DaySnapshot` because it also carries days that have *no*
/// record at all — those render as empty bars rather than being skipped, which
/// keeps the x-axis evenly spaced.
struct DayBar: Equatable, Hashable, Sendable, Identifiable {
    let dayStart: Date
    let tapCount: Int
    let isToday: Bool

    var id: Date { dayStart }

    /// Height of this bar relative to the tallest bar in the series, `0...1`.
    ///
    /// The floor keeps a real but tiny day from rounding away to nothing. It no
    /// longer applies to zero-tap days: those draw no bar at all and are carried
    /// by the chart's baseline instead — see `AppColors.chartBaseline`.
    func normalizedHeight(max maxCount: Int, floor: Double = 0.04) -> Double {
        guard maxCount > 0 else { return floor }
        let ratio = Double(tapCount) / Double(maxCount)
        return Swift.max(ratio, floor)
    }
}

/// Aggregate statistics derived from the full history.
struct TapStats: Equatable, Sendable {
    /// Taps so far today.
    let today: Int

    /// Taps so far in the calendar week containing "now".
    ///
    /// A calendar week, not a rolling seven days. Which day the week starts on
    /// is `Calendar.firstWeekday`, so this follows the user's region: on a
    /// Sunday it reads as the day's own total for anyone whose week starts on
    /// Sunday, and as a full week's total for anyone whose week starts on Monday.
    let thisWeek: Int

    /// Taps so far in the calendar month containing "now".
    let thisMonth: Int

    /// Taps across every recorded day.
    let allTime: Int

    /// Highest single-day total.
    let bestDay: Int

    /// The day on which `bestDay` was achieved, if any.
    let bestDayDate: Date?

    /// Consecutive days with at least one tap, counting backwards. Today is
    /// included once it has a tap; an untapped day still in progress does not
    /// break the streak.
    let currentStreak: Int

    /// Longest run of consecutive tapped days ever recorded.
    let longestStreak: Int

    /// Number of days that have at least one tap.
    let activeDays: Int

    /// Mean taps per active day. Zero when there are no active days.
    let averagePerActiveDay: Double

    /// The zero value, used before any data has loaded.
    static let empty = TapStats(
        today: 0,
        thisWeek: 0,
        thisMonth: 0,
        allTime: 0,
        bestDay: 0,
        bestDayDate: nil,
        currentStreak: 0,
        longestStreak: 0,
        activeDays: 0,
        averagePerActiveDay: 0
    )
}

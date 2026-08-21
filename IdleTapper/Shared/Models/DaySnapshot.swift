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

    /// The daily goal that was in effect on that day, or `nil` if none was.
    ///
    /// See `DayRecord.goalTarget` for why this is recorded per day rather than
    /// read from the live setting. Carried across the boundary because the
    /// streak calculation needs it, and encoded in the JSON export because it
    /// is user data: a history exported without it could not be read back
    /// without losing which days counted.
    let goalTarget: Int?

    var id: Date { dayStart }

    /// - Parameter goalTarget: Defaults to `nil` — "no goal was in effect" —
    ///   which is both the pre-goals history case and what the great majority
    ///   of test fixtures want.
    init(dayStart: Date, tapCount: Int, goalTarget: Int? = nil) {
        self.dayStart = dayStart
        self.tapCount = tapCount
        self.goalTarget = goalTarget
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

    /// Consecutive days that met their goal, counting backwards. Today is
    /// included once it has met its goal; a day still in progress that has not
    /// met it does not break the streak.
    ///
    /// "Met its goal" means the day reached the target recorded against it, or,
    /// for a day with no goal in effect, that it had any tap at all — see
    /// `GoalCalculator.metGoal(tapCount:goalTarget:)`. History recorded before
    /// goals existed therefore streaks exactly as it always did.
    let currentStreak: Int

    /// Longest run of consecutive days meeting their goal ever recorded.
    let longestStreak: Int

    /// Number of days that have at least one tap.
    let activeDays: Int

    /// Mean taps per active day. Zero when there are no active days.
    let averagePerActiveDay: Double

    /// The highest percentage of a day's own goal ever reached, across days
    /// that had a goal. Zero when no day has ever had one.
    ///
    /// A day of 250 taps against a goal of 100 reads 250. Days with no goal are
    /// skipped entirely rather than counted as zero, so switching the goal off
    /// cannot pull this figure down — it is a high-water mark, and an
    /// achievement built on one is never revoked.
    let bestGoalPercent: Int

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
        averagePerActiveDay: 0,
        bestGoalPercent: 0
    )
}

//
//  GoalCalculator.swift
//  Idle Tapper — Calculations (pure)
//
//  Everything the daily goal means, as arithmetic. Whether a day met its goal,
//  how far through today is, and whether a given tap was the one that crossed
//  the line.
//
//  Modelled on `MilestoneCalculator`: the crossing test takes the count before
//  and after so that a single tap — not a redraw, not a refresh — is what fires
//  the celebration.
//

import Foundation

enum GoalCalculator {

    // MARK: - Bounds

    /// What the goal is set to when the user first switches it on.
    ///
    /// Matches `MilestoneCalculator.defaultInterval`, so a new goal is reached
    /// at the same moment as the first milestone of the day rather than at some
    /// unrelated number.
    static let defaultGoal = 100

    /// The range a goal may be set to.
    ///
    /// The lower bound is 1 because zero is not a small goal, it is the off
    /// switch — see `normalized(_:)`. The upper bound only exists so a
    /// mistyped or corrupted preference cannot produce a progress ring that
    /// never visibly moves.
    static let bounds = 1...1_000_000

    /// Keep a goal inside `bounds`, mapping "off" to `nil`.
    ///
    /// Zero and anything negative mean the feature is switched off. Returning
    /// `nil` rather than zero puts that state in the type, so every caller has
    /// to decide what "no goal" does instead of accidentally dividing by it.
    static func normalized(_ goal: Int) -> Int? {
        guard goal > 0 else { return nil }
        return min(max(goal, bounds.lowerBound), bounds.upperBound)
    }

    // MARK: - Whether a Day Counts

    /// Whether a day met the goal that was in effect on it.
    ///
    /// **This is the streak rule, and it is deliberately the only copy of it.**
    /// A day with a goal has to reach it; a day with no goal in effect counts
    /// on any tap at all, exactly as every day did before goals existed. That
    /// fallback is what stops this feature from retroactively erasing the
    /// streaks of anyone upgrading, and what keeps the streak meaningful for
    /// someone who never sets a goal.
    static func metGoal(tapCount: Int, goalTarget: Int?) -> Bool {
        guard let target = normalized(goalTarget ?? 0) else { return tapCount > 0 }
        return tapCount >= target
    }

    /// Whether a recorded day met its own goal.
    static func metGoal(_ snapshot: DaySnapshot) -> Bool {
        metGoal(tapCount: snapshot.tapCount, goalTarget: snapshot.goalTarget)
    }

    // MARK: - Progress

    /// Taps still needed to reach `goalTarget`. Zero once it is met, and zero
    /// when there is no goal to be short of.
    static func remaining(tapCount: Int, goalTarget: Int?) -> Int {
        guard let target = normalized(goalTarget ?? 0) else { return 0 }
        return max(target - tapCount, 0)
    }

    /// Progress toward the goal, clamped to `0...1` for a progress ring.
    ///
    /// Clamped because the ring has nowhere to put a second lap; `percent`
    /// is the uncapped figure for anyone who wants to show the overshoot.
    static func fraction(tapCount: Int, goalTarget: Int?) -> Double {
        guard let target = normalized(goalTarget ?? 0), target > 0 else { return 0 }
        let raw = Double(max(tapCount, 0)) / Double(target)
        return min(max(raw, 0), 1)
    }

    /// Progress as a whole percentage, *not* capped at 100.
    ///
    /// Truncated rather than rounded, for the same reason
    /// `AchievementRequirement.averagePerActiveDay` truncates: 99.9% of a goal
    /// is not 100% of it, and a figure that reads "100%" beside a ring that is
    /// visibly short of the top is worse than an honest 99%.
    ///
    /// Integer arithmetic is done on `Double` to sidestep overflow: `count *
    /// 100` is unreachable in practice but cheap to make impossible.
    static func percent(tapCount: Int, goalTarget: Int?) -> Int {
        guard let target = normalized(goalTarget ?? 0), target > 0 else { return 0 }
        let raw = (Double(max(tapCount, 0)) / Double(target)) * 100
        guard raw.isFinite, raw < Double(Int.max) else { return 0 }
        return Int(raw)
    }

    // MARK: - Crossing

    /// Whether moving from `previousCount` to `newCount` is what met the goal.
    ///
    /// True exactly once per day, on the tap that lands on or past the target,
    /// so the celebration fires on the crossing rather than on every tap after
    /// it. Returns `false` when there is no goal, when the count did not move,
    /// and when the goal was already met before this jump.
    static func crossed(from previousCount: Int, to newCount: Int, goal: Int?) -> Bool {
        guard let target = normalized(goal ?? 0) else { return false }
        guard newCount > previousCount else { return false }
        return previousCount < target && newCount >= target
    }

    // MARK: - Reminder Hours

    /// Every hour a reminder may be set to, for the Settings picker.
    static let reminderHours = Array(0...23)

    /// A reminder hour as the user's locale writes it — "8:00 PM" or "20:00".
    ///
    /// Formatted from a real date rather than assembled by hand, because
    /// whether an hour is written with an AM/PM marker, and where that marker
    /// goes, is a locale's business and not ours.
    ///
    /// - Parameter reference: A date supplying the day the hour is placed in.
    ///   Which day barely matters, with one exception: on a spring-forward
    ///   morning one hour does not exist, and `date(bySettingHour:)` answers
    ///   with the next valid time. The label falls back to a plain 24-hour
    ///   spelling in that case rather than silently naming a different hour.
    static func reminderHourLabel(_ hour: Int, reference: Date, calendar: Calendar) -> String {
        let fallback = String(format: "%02d:00", hour)
        guard (0...23).contains(hour) else { return fallback }

        guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: reference),
              calendar.component(.hour, from: date) == hour
        else { return fallback }

        return date.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - History

    /// The highest percentage of its own goal any day ever reached.
    ///
    /// Days with no goal are skipped rather than counted as zero: they had no
    /// target to beat, and letting them contribute would mean switching the
    /// goal off could lower a high-water mark. See `TapStats.bestGoalPercent`.
    static func bestGoalPercent(from snapshots: [DaySnapshot]) -> Int {
        snapshots.reduce(0) { best, snapshot in
            guard snapshot.goalTarget != nil else { return best }
            return max(best, percent(tapCount: snapshot.tapCount, goalTarget: snapshot.goalTarget))
        }
    }
}

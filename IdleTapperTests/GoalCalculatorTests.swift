//
//  GoalCalculatorTests.swift
//  IdleTapperTests
//

import Testing
import Foundation
@testable import IdleTapper

@Suite("Goal calculator")
struct GoalCalculatorTests {

    // MARK: - Whether a Day Counts

    @Test("A day one tap short of its goal does not count")
    func shortOfGoalDoesNotCount() {
        #expect(!GoalCalculator.metGoal(tapCount: 99, goalTarget: 100))
    }

    @Test("A day exactly on its goal counts")
    func exactlyOnGoalCounts() {
        #expect(GoalCalculator.metGoal(tapCount: 100, goalTarget: 100))
    }

    /// The guarantee that this feature did not retroactively erase anybody's
    /// streak. Every day recorded before goals existed has no target, and has
    /// to keep counting on a single tap.
    @Test("A day with no goal counts on any tap at all")
    func noGoalCountsOnAnyTap() {
        #expect(GoalCalculator.metGoal(tapCount: 1, goalTarget: nil))
        #expect(!GoalCalculator.metGoal(tapCount: 0, goalTarget: nil))
    }

    @Test("A goal of zero is the off switch, not a goal every day meets")
    func zeroGoalIsOff() {
        // Were zero treated as a target, `0 >= 0` would make an untapped day
        // count and every streak would run unbroken forever.
        #expect(!GoalCalculator.metGoal(tapCount: 0, goalTarget: 0))
        #expect(GoalCalculator.metGoal(tapCount: 1, goalTarget: 0))
    }

    // MARK: - Crossing

    @Test("Crossing fires on the tap that reaches the goal and not after")
    func crossesOnce() {
        #expect(GoalCalculator.crossed(from: 99, to: 100, goal: 100))
        #expect(!GoalCalculator.crossed(from: 100, to: 101, goal: 100))
        #expect(!GoalCalculator.crossed(from: 98, to: 99, goal: 100))
    }

    @Test("A jump straight past the goal still crosses it")
    func crossesOnAJump() {
        #expect(GoalCalculator.crossed(from: 10, to: 500, goal: 100))
    }

    @Test("Nothing crosses when the goal is off")
    func noCrossingWithoutAGoal() {
        #expect(!GoalCalculator.crossed(from: 0, to: 1_000, goal: 0))
        #expect(!GoalCalculator.crossed(from: 0, to: 1_000, goal: nil))
    }

    // MARK: - Progress

    @Test("Percentage is truncated, never rounded up to a goal not reached")
    func percentageTruncates() {
        // 99.9% of the way there is not there. Rounding would show "100%"
        // beside a ring visibly short of the top.
        #expect(GoalCalculator.percent(tapCount: 999, goalTarget: 1_000) == 99)
        #expect(GoalCalculator.percent(tapCount: 1_000, goalTarget: 1_000) == 100)
    }

    @Test("Percentage keeps climbing past the goal but the ring does not")
    func overshoot() {
        #expect(GoalCalculator.percent(tapCount: 250, goalTarget: 100) == 250)
        #expect(GoalCalculator.fraction(tapCount: 250, goalTarget: 100) == 1)
    }

    @Test("Progress against no goal is zero rather than a division by it")
    func noGoalProgress() {
        #expect(GoalCalculator.percent(tapCount: 50, goalTarget: 0) == 0)
        #expect(GoalCalculator.fraction(tapCount: 50, goalTarget: 0) == 0)
        #expect(GoalCalculator.remaining(tapCount: 50, goalTarget: 0) == 0)
    }

    @Test("Remaining counts down to zero and stops there")
    func remaining() {
        #expect(GoalCalculator.remaining(tapCount: 40, goalTarget: 100) == 60)
        #expect(GoalCalculator.remaining(tapCount: 100, goalTarget: 100) == 0)
        #expect(GoalCalculator.remaining(tapCount: 500, goalTarget: 100) == 0)
    }

    // MARK: - History

    @Test("The best-goal high-water mark ignores days that had no goal")
    func bestGoalPercentSkipsGoallessDays() {
        let calendar = TestSupport.utcCalendar
        let day = TestSupport.date(2026, 3, 10, 12, 0, calendar: calendar)

        let history = [
            // A huge day with no target cannot contribute: there was nothing
            // to beat. Counting it as a ratio would mean switching the goal
            // off could raise — or later lower — a figure an achievement
            // depends on, and an achievement is never revoked.
            TestSupport.snapshot(on: day, count: 10_000, calendar: calendar),
            TestSupport.snapshot(
                on: TestSupport.date(2026, 3, 11, 12, 0, calendar: calendar),
                count: 150,
                calendar: calendar,
                goalTarget: 100
            ),
        ]

        #expect(GoalCalculator.bestGoalPercent(from: history) == 150)
    }

    @Test("No day with a goal means no high-water mark")
    func bestGoalPercentWithoutGoals() {
        let calendar = TestSupport.utcCalendar
        let history = [
            TestSupport.snapshot(
                on: TestSupport.date(2026, 3, 10, 12, 0, calendar: calendar),
                count: 5_000,
                calendar: calendar
            )
        ]

        #expect(GoalCalculator.bestGoalPercent(from: history) == 0)
    }
}

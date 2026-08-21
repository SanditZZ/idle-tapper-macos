//
//  GoalStreakTests.swift
//  IdleTapperTests
//
//  What a streak means once a goal exists. The day arithmetic itself is
//  `StatsCalculatorTests`' subject and is unchanged; what is under test here is
//  the predicate deciding which days are eligible to be counted.
//

import Testing
import Foundation
@testable import IdleTapper

@Suite("Goal streaks")
struct GoalStreakTests {

    private let calendar = TestSupport.utcCalendar

    private var now: Date {
        TestSupport.date(2026, 3, 10, 12, 0, calendar: calendar)
    }

    // MARK: - The Goal Decides

    @Test("A day that fell short of its goal breaks the streak")
    func shortDayBreaksTheStreak() {
        let history = [
            TestSupport.snapshot(daysAgo: 3, count: 100, from: now, calendar: calendar, goalTarget: 100),
            // Tapped, but not to target — under the old rule this day counted.
            TestSupport.snapshot(daysAgo: 2, count: 40, from: now, calendar: calendar, goalTarget: 100),
            TestSupport.snapshot(daysAgo: 1, count: 100, from: now, calendar: calendar, goalTarget: 100),
            TestSupport.snapshot(daysAgo: 0, count: 100, from: now, calendar: calendar, goalTarget: 100),
        ]

        #expect(StatsCalculator.currentStreak(from: history, now: now, calendar: calendar) == 2)
    }

    /// The upgrade guarantee. Nobody's existing streak moved when this shipped,
    /// because every day already in the database has no target recorded against
    /// it and keeps counting on a single tap.
    @Test("History recorded before goals existed streaks exactly as it did")
    func preGoalHistoryIsUnchanged() {
        let history = (0...4).map {
            TestSupport.snapshot(daysAgo: $0, count: 1, from: now, calendar: calendar)
        }

        #expect(StatsCalculator.currentStreak(from: history, now: now, calendar: calendar) == 5)
    }

    @Test("Old goalless days and new goal days run together as one streak")
    func mixedHistory() {
        let history = [
            TestSupport.snapshot(daysAgo: 3, count: 1, from: now, calendar: calendar),
            TestSupport.snapshot(daysAgo: 2, count: 1, from: now, calendar: calendar),
            TestSupport.snapshot(daysAgo: 1, count: 120, from: now, calendar: calendar, goalTarget: 100),
            TestSupport.snapshot(daysAgo: 0, count: 100, from: now, calendar: calendar, goalTarget: 100),
        ]

        #expect(StatsCalculator.currentStreak(from: history, now: now, calendar: calendar) == 4)
    }

    /// The grace day, which the streak-at-risk reminder depends on: today has
    /// not reached its target yet, and must not be counted as a break while it
    /// is still in progress. The figure the reminder warns about is this one.
    @Test("Today short of its goal does not break the run yet")
    func todayInProgressIsAGraceDay() {
        let history = [
            TestSupport.snapshot(daysAgo: 2, count: 100, from: now, calendar: calendar, goalTarget: 100),
            TestSupport.snapshot(daysAgo: 1, count: 100, from: now, calendar: calendar, goalTarget: 100),
            TestSupport.snapshot(daysAgo: 0, count: 10, from: now, calendar: calendar, goalTarget: 100),
        ]

        #expect(StatsCalculator.currentStreak(from: history, now: now, calendar: calendar) == 2)
    }

    @Test("Raising the goal does not reach back into days already recorded")
    func pastDaysKeepTheirOwnTarget() {
        // Days recorded against a goal of 100, all of which met it. The user
        // then raises their goal to 500. Because each day carries the target it
        // was recorded against, the run is untouched — which is the entire
        // reason `DayRecord.goalTarget` is stored per day rather than read from
        // the current setting.
        let history = (0...3).map {
            TestSupport.snapshot(daysAgo: $0, count: 120, from: now, calendar: calendar, goalTarget: 100)
        }

        #expect(StatsCalculator.currentStreak(from: history, now: now, calendar: calendar) == 4)
    }

    // MARK: - Longest

    @Test("The longest run counts only days that met their goal")
    func longestStreakUsesTheGoal() {
        let history = [
            TestSupport.snapshot(daysAgo: 6, count: 100, from: now, calendar: calendar, goalTarget: 100),
            TestSupport.snapshot(daysAgo: 5, count: 100, from: now, calendar: calendar, goalTarget: 100),
            TestSupport.snapshot(daysAgo: 4, count: 100, from: now, calendar: calendar, goalTarget: 100),
            // Falls short, splitting what would otherwise be a run of seven.
            TestSupport.snapshot(daysAgo: 3, count: 99, from: now, calendar: calendar, goalTarget: 100),
            TestSupport.snapshot(daysAgo: 2, count: 100, from: now, calendar: calendar, goalTarget: 100),
            TestSupport.snapshot(daysAgo: 1, count: 100, from: now, calendar: calendar, goalTarget: 100),
        ]

        #expect(StatsCalculator.longestStreak(from: history, calendar: calendar) == 3)
    }

    // MARK: - Daylight Saving

    /// New York springs forward on 8 March 2026, making that local day 23 hours
    /// long. A run of goal-meeting days across it must still read as
    /// consecutive.
    ///
    /// The fixture is deliberately gap-free across the transition: an
    /// implementation measuring the gap between days in *seconds* sees 82,800
    /// rather than 86,400 between the 7th and the 8th, fails to call them
    /// adjacent, and reports 2 instead of 4. A fixture that skipped the 8th
    /// would pass on both implementations and prove nothing — the trap
    /// `weekSpanningDaylightSaving` was strengthened to avoid.
    @Test("A goal streak spanning a daylight saving change stays unbroken")
    func streakSpanningDaylightSaving() {
        let newYork = TestSupport.newYorkCalendar
        let reference = TestSupport.date(2026, 3, 9, 12, 0, calendar: newYork)

        let history = [
            TestSupport.snapshot(on: TestSupport.date(2026, 3, 6, 12, 0, calendar: newYork),
                                 count: 100, calendar: newYork, goalTarget: 100),
            TestSupport.snapshot(on: TestSupport.date(2026, 3, 7, 12, 0, calendar: newYork),
                                 count: 100, calendar: newYork, goalTarget: 100),
            // The 23-hour day itself.
            TestSupport.snapshot(on: TestSupport.date(2026, 3, 8, 12, 0, calendar: newYork),
                                 count: 100, calendar: newYork, goalTarget: 100),
            TestSupport.snapshot(on: reference,
                                 count: 100, calendar: newYork, goalTarget: 100),
        ]

        #expect(StatsCalculator.currentStreak(from: history, now: reference, calendar: newYork) == 4)
        #expect(StatsCalculator.longestStreak(from: history, calendar: newYork) == 4)
    }

    // MARK: - Achievements

    /// The existing streak achievements become goal achievements for free once
    /// a goal is set, which is why the catalog has no separate "hit your goal
    /// seven days running" entry.
    @Test("A week of goal-meeting days unlocks the week streak achievement")
    func goalStreakFeedsTheExistingAchievement() {
        let history = (0...6).map {
            TestSupport.snapshot(daysAgo: $0, count: 100, from: now, calendar: calendar, goalTarget: 100)
        }
        let stats = StatsCalculator.stats(from: history, now: now, calendar: calendar)

        #expect(stats.longestStreak == 7)
        #expect(AchievementCalculator.unlocked(from: stats).contains(.weekStreak))
    }

    @Test("Doubling the goal unlocks Overachiever, and merely meeting it does not")
    func overachiever() {
        let met = StatsCalculator.stats(
            from: [TestSupport.snapshot(daysAgo: 0, count: 100, from: now, calendar: calendar, goalTarget: 100)],
            now: now,
            calendar: calendar
        )
        #expect(!AchievementCalculator.unlocked(from: met).contains(.overachiever))

        let doubled = StatsCalculator.stats(
            from: [TestSupport.snapshot(daysAgo: 0, count: 200, from: now, calendar: calendar, goalTarget: 100)],
            now: now,
            calendar: calendar
        )
        #expect(AchievementCalculator.unlocked(from: doubled).contains(.overachiever))
    }
}

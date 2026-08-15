//
//  StatsCalculatorTests.swift
//  IdleTapperTests
//

import Testing
import Foundation
@testable import IdleTapper

@Suite("Statistics")
struct StatsCalculatorTests {

    private let calendar = TestSupport.utcCalendar

    private var now: Date {
        TestSupport.date(2026, 3, 15, 10, 0, calendar: calendar)
    }

    // MARK: - Aggregates

    @Test("Empty history produces the zero summary rather than nil or a crash")
    func emptyHistory() {
        let stats = StatsCalculator.stats(from: [], now: now, calendar: calendar)
        #expect(stats == .empty)
    }

    @Test("Totals, best day and averages are derived correctly")
    func aggregates() {
        let history = [
            TestSupport.snapshot(daysAgo: 0, count: 10, from: now, calendar: calendar),
            TestSupport.snapshot(daysAgo: 1, count: 50, from: now, calendar: calendar),
            TestSupport.snapshot(daysAgo: 2, count: 30, from: now, calendar: calendar),
        ]

        let stats = StatsCalculator.stats(from: history, now: now, calendar: calendar)

        #expect(stats.today == 10)
        #expect(stats.allTime == 90)
        #expect(stats.bestDay == 50)
        #expect(stats.activeDays == 3)
        #expect(stats.averagePerActiveDay == 30)
    }

    @Test("Days recorded with zero taps do not count as active")
    func zeroDaysAreInactive() {
        let history = [
            TestSupport.snapshot(daysAgo: 0, count: 0, from: now, calendar: calendar),
            TestSupport.snapshot(daysAgo: 1, count: 20, from: now, calendar: calendar),
        ]

        let stats = StatsCalculator.stats(from: history, now: now, calendar: calendar)

        #expect(stats.activeDays == 1)
        #expect(stats.averagePerActiveDay == 20, "A zero day must not drag the average down")
    }

    // MARK: - Calendar periods

    // Every date below is stated outright and checked against a real calendar:
    // 15 March 2026 is a **Sunday**, 8 March a Sunday, 14 March a Saturday.
    // The suite's `now` therefore lands on the first day of its own week, which
    // is what makes the rolling-window and `firstWeekday` cases below sharp.

    @Test("This week is the calendar week, not the last seven days")
    func weekIsCalendarNotRolling() {
        // `now` is a Sunday and the fixture week starts on Sunday, so the week
        // under way is one day old. Yesterday is inside a rolling seven days
        // and outside this week — precisely the misreading this feature invites.
        let history = [
            TestSupport.snapshot(daysAgo: 0, count: 10, from: now, calendar: calendar),
            TestSupport.snapshot(daysAgo: 1, count: 500, from: now, calendar: calendar),
            TestSupport.snapshot(daysAgo: 2, count: 500, from: now, calendar: calendar),
        ]

        let stats = StatsCalculator.stats(from: history, now: now, calendar: calendar)

        #expect(stats.thisWeek == 10, "Saturday belongs to the week that has just ended")
        #expect(stats.thisMonth == 1010, "All three days are in March, so the month keeps them")
    }

    @Test("A week keeps its first and last day and drops the days either side")
    func weekBoundaries() {
        // The week of Sunday 8 March through Saturday 14 March.
        let midweek = TestSupport.date(2026, 3, 11, 10, 0, calendar: calendar)
        let history = [
            TestSupport.snapshot(on: TestSupport.date(2026, 3, 7, calendar: calendar), count: 100, calendar: calendar),
            TestSupport.snapshot(on: TestSupport.date(2026, 3, 8, calendar: calendar), count: 1, calendar: calendar),
            TestSupport.snapshot(on: TestSupport.date(2026, 3, 14, calendar: calendar), count: 2, calendar: calendar),
            TestSupport.snapshot(on: TestSupport.date(2026, 3, 15, calendar: calendar), count: 400, calendar: calendar),
        ]

        let stats = StatsCalculator.stats(from: history, now: midweek, calendar: calendar)

        #expect(stats.thisWeek == 3, "Sunday and Saturday are in; the Saturday before and Sunday after are not")
    }

    @Test("A month keeps its first and last day and drops the days either side")
    func monthBoundaries() {
        let midMarch = TestSupport.date(2026, 3, 11, 10, 0, calendar: calendar)
        let history = [
            TestSupport.snapshot(on: TestSupport.date(2026, 2, 28, calendar: calendar), count: 100, calendar: calendar),
            TestSupport.snapshot(on: TestSupport.date(2026, 3, 1, calendar: calendar), count: 1, calendar: calendar),
            TestSupport.snapshot(on: TestSupport.date(2026, 3, 31, calendar: calendar), count: 2, calendar: calendar),
            TestSupport.snapshot(on: TestSupport.date(2026, 4, 1, calendar: calendar), count: 400, calendar: calendar),
        ]

        let stats = StatsCalculator.stats(from: history, now: midMarch, calendar: calendar)

        #expect(stats.thisMonth == 3, "The 1st and the 31st are in; 28 February and 1 April are not")
    }

    @Test("The same day gives a different week total depending on firstWeekday")
    func weekStartRespectsFirstWeekday() {
        // Monday 9 March through Sunday 15 March, one tap each.
        let sunday = TestSupport.weekCalendar(startingOn: 1)
        let monday = TestSupport.weekCalendar(startingOn: 2)
        let history = (0..<7).map {
            TestSupport.snapshot(daysAgo: $0, count: 1, from: now, calendar: sunday)
        }

        let sundayWeek = StatsCalculator.stats(from: history, now: now, calendar: sunday)
        let mondayWeek = StatsCalculator.stats(from: history, now: now, calendar: monday)

        #expect(sundayWeek.thisWeek == 1, "A Sunday-based week has only just begun")
        #expect(
            mondayWeek.thisWeek == 7,
            "A Monday-based week ends on this Sunday, so it holds all seven days"
        )
        #expect(
            sundayWeek.thisMonth == mondayWeek.thisMonth,
            "firstWeekday moves week boundaries only — the month is the same either way"
        )
    }

    @Test("A week containing a daylight saving transition keeps exactly its own days")
    func weekSpanningDaylightSaving() {
        // US clocks go forward on Sunday 8 March 2026, so that week opens with a
        // 23-hour day. Counting in seconds rather than in calendar days would
        // pull Saturday the 14th out of the week, or push the 7th into it.
        let dstCalendar = TestSupport.newYorkCalendar
        let midweek = TestSupport.date(2026, 3, 10, 12, 0, calendar: dstCalendar)
        let history = [
            TestSupport.snapshot(on: TestSupport.date(2026, 3, 7, calendar: dstCalendar), count: 100, calendar: dstCalendar),
            TestSupport.snapshot(on: TestSupport.date(2026, 3, 8, calendar: dstCalendar), count: 1, calendar: dstCalendar),
            TestSupport.snapshot(on: TestSupport.date(2026, 3, 14, calendar: dstCalendar), count: 2, calendar: dstCalendar),
        ]

        let stats = StatsCalculator.stats(from: history, now: midweek, calendar: dstCalendar)

        #expect(stats.thisWeek == 3, "The short day is still one whole day")
    }

    @Test("Empty history totals zero rather than nil or a crash")
    func emptyPeriods() {
        #expect(StatsCalculator.total(from: [], in: .weekOfYear, containing: now, calendar: calendar) == 0)
        #expect(StatsCalculator.total(from: [], in: .month, containing: now, calendar: calendar) == 0)
        #expect(StatsCalculator.stats(from: [], now: now, calendar: calendar).thisWeek == 0)
        #expect(StatsCalculator.stats(from: [], now: now, calendar: calendar).thisMonth == 0)
    }

    // MARK: - Streaks

    @Test("An unbroken run counts every consecutive day including today")
    func currentStreakIncludesToday() {
        let history = (0..<4).map {
            TestSupport.snapshot(daysAgo: $0, count: 5, from: now, calendar: calendar)
        }

        #expect(StatsCalculator.currentStreak(from: history, now: now, calendar: calendar) == 4)
    }

    @Test("An untapped today does not break a streak that is still in progress")
    func todayIsAGraceDay() {
        // Tapped on each of the last three days, but nothing yet today.
        let history = (1...3).map {
            TestSupport.snapshot(daysAgo: $0, count: 5, from: now, calendar: calendar)
        }

        #expect(
            StatsCalculator.currentStreak(from: history, now: now, calendar: calendar) == 3,
            "The day is not over, so the streak should still stand"
        )
    }

    @Test("A missed day breaks the streak")
    func gapBreaksStreak() {
        let history = [
            TestSupport.snapshot(daysAgo: 0, count: 5, from: now, calendar: calendar),
            TestSupport.snapshot(daysAgo: 1, count: 5, from: now, calendar: calendar),
            // Day 2 missing.
            TestSupport.snapshot(daysAgo: 3, count: 5, from: now, calendar: calendar),
        ]

        #expect(StatsCalculator.currentStreak(from: history, now: now, calendar: calendar) == 2)
    }

    @Test("Longest streak finds the best historical run, not the current one")
    func longestStreak() {
        let history = [
            // A five-day run well in the past.
            TestSupport.snapshot(daysAgo: 10, count: 1, from: now, calendar: calendar),
            TestSupport.snapshot(daysAgo: 11, count: 1, from: now, calendar: calendar),
            TestSupport.snapshot(daysAgo: 12, count: 1, from: now, calendar: calendar),
            TestSupport.snapshot(daysAgo: 13, count: 1, from: now, calendar: calendar),
            TestSupport.snapshot(daysAgo: 14, count: 1, from: now, calendar: calendar),
            // A shorter current run.
            TestSupport.snapshot(daysAgo: 0, count: 1, from: now, calendar: calendar),
            TestSupport.snapshot(daysAgo: 1, count: 1, from: now, calendar: calendar),
        ]

        let stats = StatsCalculator.stats(from: history, now: now, calendar: calendar)

        #expect(stats.longestStreak == 5)
        #expect(stats.currentStreak == 2)
    }

    @Test("A history of only zero-count days yields no streak")
    func zeroCountsAreNotAStreak() {
        let history = (0..<5).map {
            TestSupport.snapshot(daysAgo: $0, count: 0, from: now, calendar: calendar)
        }

        #expect(StatsCalculator.currentStreak(from: history, now: now, calendar: calendar) == 0)
        #expect(StatsCalculator.longestStreak(from: history, calendar: calendar) == 0)
    }

    // MARK: - Series

    @Test("The series is a fixed length with missing days filled as zero")
    func seriesFillsGaps() {
        let history = [
            TestSupport.snapshot(daysAgo: 0, count: 10, from: now, calendar: calendar),
            TestSupport.snapshot(daysAgo: 3, count: 40, from: now, calendar: calendar),
        ]

        let bars = StatsCalculator.series(from: history, days: 7, endingOn: now, calendar: calendar)

        #expect(bars.count == 7, "Length must not depend on how many days have data")
        #expect(bars.map(\.dayStart) == bars.map(\.dayStart).sorted(), "Oldest first")
        #expect(bars.last?.tapCount == 10)
        #expect(bars.last?.isToday == true)
        #expect(bars.filter { $0.tapCount == 0 }.count == 5)
    }

    @Test("Exactly one bar is marked as today")
    func singleTodayBar() {
        let bars = StatsCalculator.series(from: [], days: 30, endingOn: now, calendar: calendar)
        #expect(bars.filter(\.isToday).count == 1)
    }

    @Test("Bar heights scale to the peak and empty days keep a visible floor")
    func normalizedHeights() {
        let peakBar = DayBar(dayStart: now, tapCount: 100, isToday: true)
        let halfBar = DayBar(dayStart: now, tapCount: 50, isToday: false)
        let emptyBar = DayBar(dayStart: now, tapCount: 0, isToday: false)

        #expect(peakBar.normalizedHeight(max: 100) == 1.0)
        #expect(halfBar.normalizedHeight(max: 100) == 0.5)
        #expect(emptyBar.normalizedHeight(max: 100) > 0, "Empty bars stay visible")
        #expect(peakBar.normalizedHeight(max: 0) > 0, "A zero peak must not divide by zero")
    }

    // MARK: - Formatting

    @Test("A one-day streak reads 'day', not 'days'")
    func dayCountPluralisation() {
        #expect(StatsCalculator.dayCountText(1) == "1 day", "The first case a new user sees")
        #expect(StatsCalculator.dayCountText(0) == "0 days")
        #expect(StatsCalculator.dayCountText(2) == "2 days")
    }

    @Test("The daily average is grouped like every other figure and survives bad input")
    func averageFormatting() {
        #expect(StatsCalculator.averageText(2633) == 2633.formatted(), "Grouped, not '2633'")
        #expect(StatsCalculator.averageText(0.4) == "0", "Rounds down to zero rather than '0.4'")
        #expect(StatsCalculator.averageText(0) == "0")
        #expect(StatsCalculator.averageText(-5) == "0", "A negative average is not displayable")
        #expect(StatsCalculator.averageText(.nan) == "0", "Never renders 'nan'")
        #expect(StatsCalculator.averageText(.infinity) == "0")
    }
}

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
}

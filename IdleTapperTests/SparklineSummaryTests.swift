//
//  SparklineSummaryTests.swift
//  Idle Tapper — Tests
//

import Foundation
import Testing
@testable import IdleTapper

@Suite("Sparkline summary")
struct SparklineSummaryTests {

    /// Days ending today, so `isToday` lands on the last bar the way the real
    /// series builds it. Time is pinned via `TestSupport.utcCalendar`.
    private static func bars(_ counts: [Int]) -> [DayBar] {
        let calendar = TestSupport.utcCalendar
        let today = calendar.startOfDay(for: Date())
        return counts.enumerated().map { index, count in
            let offset = index - (counts.count - 1)
            return DayBar(
                dayStart: calendar.date(byAdding: .day, value: offset, to: today)!,
                tapCount: count,
                isToday: offset == 0
            )
        }
    }

    @Test("Counts every day, but only tapped days as active")
    func countsDaysAndActiveDays() {
        let summary = SparklineSummary.make(from: Self.bars([5, 0, 0, 12, 0, 0, 3]))

        #expect(summary.dayCount == 7)
        #expect(summary.activeDayCount == 3)
        #expect(summary.total == 20)
        #expect(summary.peak == 12)
        #expect(summary.todayCount == 3)
    }

    /// The case that motivated the change: an almost-empty range must still
    /// summarise rather than reciting a run of zeros.
    @Test("A sparse range reports its shape, not its zeros")
    func sparseRange() {
        var counts = Array(repeating: 0, count: 30)
        counts[10] = 3_026
        let summary = SparklineSummary.make(from: Self.bars(counts))

        #expect(summary.dayCount == 30)
        #expect(summary.activeDayCount == 1)
        #expect(summary.peak == 3_026)
        #expect(summary.todayCount == 0)
        #expect(summary.announcement.contains("None today"))
    }

    @Test("No taps at all says so plainly")
    func noTapsAnywhere() {
        let summary = SparklineSummary.make(from: Self.bars(Array(repeating: 0, count: 7)))

        #expect(summary.total == 0)
        #expect(summary.announcement == "No taps in the last 7 days.")
    }

    @Test("No bars at all does not claim a range")
    func noBars() {
        let summary = SparklineSummary.make(from: [])

        #expect(summary.dayCount == 0)
        #expect(summary.announcement == "No history yet.")
    }

    /// "1 days" is the kind of thing that makes a spoken interface sound broken.
    @Test("A single day is singular")
    func singularDay() {
        let summary = SparklineSummary.make(from: Self.bars([9]))

        #expect(summary.announcement.contains("1 day,"))
        #expect(!summary.announcement.contains("1 days"))
    }

    /// A series that does not include today must not invent a value for it —
    /// the History window's longer ranges are built the same way but the popover
    /// and the chart can disagree about whether today is in view.
    @Test("A series without today reports no today")
    func seriesWithoutToday() {
        let calendar = TestSupport.utcCalendar
        let start = calendar.date(from: DateComponents(year: 2025, month: 3, day: 1))!
        let bars = (0..<3).map { offset in
            DayBar(
                dayStart: calendar.date(byAdding: .day, value: offset, to: start)!,
                tapCount: 4,
                isToday: false
            )
        }

        let summary = SparklineSummary.make(from: bars)

        #expect(summary.todayCount == nil)
        #expect(!summary.announcement.contains("today"))
    }
}

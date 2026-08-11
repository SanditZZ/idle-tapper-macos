//
//  DayBoundaryTests.swift
//  IdleTapperTests
//
//  The daily reset is entirely a consequence of these functions, so the edge
//  cases here are the ones that would silently corrupt a user's history.
//

import Testing
import Foundation
@testable import IdleTapper

@Suite("Day boundaries")
struct DayBoundaryTests {

    // MARK: - Day Start

    @Test("Day start is local midnight, not the current time")
    func dayStartIsMidnight() {
        let calendar = TestSupport.utcCalendar
        let afternoon = TestSupport.date(2026, 3, 15, 14, 37, calendar: calendar)

        let start = DayBoundary.dayStart(for: afternoon, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: start)

        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 15)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
    }

    @Test("One second before and after midnight fall on different days")
    func midnightSplitsDays() {
        let calendar = TestSupport.utcCalendar
        let justBefore = TestSupport.date(2026, 3, 15, 23, 59, calendar: calendar)
        let justAfter = TestSupport.date(2026, 3, 16, 0, 1, calendar: calendar)

        #expect(
            DayBoundary.dayStart(for: justBefore, calendar: calendar)
                != DayBoundary.dayStart(for: justAfter, calendar: calendar),
            "Crossing midnight must start a new day — this is what resets the counter"
        )
    }

    // MARK: - Daylight Saving

    @Test("Backwards day arithmetic survives a 23-hour spring-forward day")
    func springForwardDay() {
        // 8 March 2026 is a US spring-forward date: that local day is 23 hours.
        let calendar = TestSupport.newYorkCalendar
        let afterTransition = TestSupport.date(2026, 3, 9, 12, 0, calendar: calendar)

        let yesterday = DayBoundary.dayStart(daysAgo: 1, from: afterTransition, calendar: calendar)
        let components = calendar.dateComponents([.month, .day, .hour], from: yesterday)

        #expect(components.month == 3)
        #expect(components.day == 8, "Subtracting a day must land on the 8th, not slip to the 7th")
        #expect(components.hour == 0)
    }

    @Test("Backwards day arithmetic survives a 25-hour fall-back day")
    func fallBackDay() {
        // 1 November 2026 is a US fall-back date: that local day is 25 hours.
        let calendar = TestSupport.newYorkCalendar
        let afterTransition = TestSupport.date(2026, 11, 2, 12, 0, calendar: calendar)

        let yesterday = DayBoundary.dayStart(daysAgo: 1, from: afterTransition, calendar: calendar)
        let components = calendar.dateComponents([.month, .day, .hour], from: yesterday)

        #expect(components.month == 11)
        #expect(components.day == 1)
        #expect(components.hour == 0)
    }

    // MARK: - Recent Days

    @Test("Recent day starts are ascending, unique and inclusive of today")
    func recentDayStarts() {
        let calendar = TestSupport.utcCalendar
        let now = TestSupport.date(2026, 3, 15, 9, 0, calendar: calendar)

        let days = DayBoundary.recentDayStarts(count: 7, endingOn: now, calendar: calendar)

        #expect(days.count == 7)
        #expect(Set(days).count == 7, "No duplicate days")
        #expect(days == days.sorted(), "Oldest first")
        #expect(days.last == DayBoundary.dayStart(for: now, calendar: calendar), "Today is last")
    }

    @Test("A non-positive range yields no days rather than crashing")
    func emptyRange() {
        let calendar = TestSupport.utcCalendar
        let now = TestSupport.date(2026, 3, 15, calendar: calendar)

        #expect(DayBoundary.recentDayStarts(count: 0, endingOn: now, calendar: calendar).isEmpty)
        #expect(DayBoundary.recentDayStarts(count: -5, endingOn: now, calendar: calendar).isEmpty)
    }

    @Test("Day counting spans month and year boundaries")
    func dayCountAcrossBoundaries() {
        let calendar = TestSupport.utcCalendar
        let endOfYear = TestSupport.date(2025, 12, 30, 23, 0, calendar: calendar)
        let newYear = TestSupport.date(2026, 1, 2, 1, 0, calendar: calendar)

        #expect(DayBoundary.dayCount(from: endOfYear, to: newYear, calendar: calendar) == 3)
    }
}

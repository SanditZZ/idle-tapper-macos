//
//  TapRepositoryTests.swift
//  IdleTapperTests
//
//  Runs against a real SwiftData stack backed by an in-memory store, so the
//  model, the unique constraint and the save path are all genuinely exercised
//  without touching disk.
//

import Testing
import Foundation
import SwiftData
@testable import IdleTapper

@Suite("Tap repository")
@MainActor
struct TapRepositoryTests {

    private let calendar = TestSupport.utcCalendar

    private func makeRepository() throws -> SwiftDataTapRepository {
        let container = try ModelContainerFactory.makeInMemory()
        return SwiftDataTapRepository(
            container: container,
            calendar: calendar,
            // Effectively disable the debounce so tests drive saves explicitly.
            saveDebounce: .seconds(60)
        )
    }

    // MARK: - Counting

    @Test("A fresh day starts at zero")
    func freshDayIsZero() throws {
        let repository = try makeRepository()
        let today = TestSupport.date(2026, 3, 15, 10, 0, calendar: calendar)

        #expect(try repository.count(on: today) == 0)
    }

    @Test("Increments accumulate within the same day")
    func incrementsAccumulate() throws {
        let repository = try makeRepository()
        let today = TestSupport.date(2026, 3, 15, 10, 0, calendar: calendar)

        #expect(try repository.increment(by: 1, at: today) == 1)
        #expect(try repository.increment(by: 1, at: today) == 2)
        #expect(try repository.increment(by: 5, at: today) == 7)
        #expect(try repository.count(on: today) == 7)
    }

    @Test("Taps at different times of the same day share one record")
    func sameDaySharesRecord() throws {
        let repository = try makeRepository()
        let morning = TestSupport.date(2026, 3, 15, 0, 1, calendar: calendar)
        let night = TestSupport.date(2026, 3, 15, 23, 59, calendar: calendar)

        try repository.increment(by: 3, at: morning)
        try repository.increment(by: 4, at: night)

        #expect(try repository.count(on: morning) == 7)
        #expect(try repository.allDays().count == 1, "One row per day, not per tap")
    }

    // MARK: - Daily Reset

    @Test("Crossing midnight resets the visible count while preserving history")
    func dailyReset() throws {
        let repository = try makeRepository()
        let today = TestSupport.date(2026, 3, 15, 23, 59, calendar: calendar)
        let tomorrow = TestSupport.date(2026, 3, 16, 0, 1, calendar: calendar)

        try repository.increment(by: 42, at: today)

        #expect(try repository.count(on: tomorrow) == 0, "The new day starts fresh")
        #expect(try repository.count(on: today) == 42, "Yesterday's total is retained")

        try repository.increment(by: 1, at: tomorrow)

        let days = try repository.allDays()
        #expect(days.count == 2)
        #expect(days.map(\.tapCount) == [42, 1], "Ascending by date")
    }

    @Test("A gap of several days does not create records for the skipped days")
    func skippedDaysAreNotCreated() throws {
        let repository = try makeRepository()
        let first = TestSupport.date(2026, 3, 1, 12, 0, calendar: calendar)
        let muchLater = TestSupport.date(2026, 3, 20, 12, 0, calendar: calendar)

        try repository.increment(by: 5, at: first)
        try repository.increment(by: 5, at: muchLater)

        #expect(try repository.allDays().count == 2)
    }

    // MARK: - Ranges

    @Test("Recent days returns only days inside the window, today included")
    func recentDaysWindow() throws {
        let repository = try makeRepository()
        let now = TestSupport.date(2026, 3, 15, 12, 0, calendar: calendar)

        for offset in 0..<10 {
            let day = DayBoundary.dayStart(daysAgo: offset, from: now, calendar: calendar)
            try repository.increment(by: offset + 1, at: day)
        }

        let recent = try repository.recentDays(7, endingOn: now)

        #expect(recent.count == 7)
        #expect(recent.last?.dayStart == DayBoundary.dayStart(for: now, calendar: calendar))
        #expect(recent.map(\.dayStart) == recent.map(\.dayStart).sorted())
    }

    // MARK: - Writes

    @Test("Flushing persists to the store")
    func flushPersists() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataTapRepository(
            container: container,
            calendar: calendar,
            saveDebounce: .seconds(60)
        )
        let today = TestSupport.date(2026, 3, 15, 12, 0, calendar: calendar)

        try repository.increment(by: 9, at: today)
        try repository.flush()

        // A second repository over the same container reads through a fresh
        // context, so this only passes if the data actually reached the store.
        let reader = SwiftDataTapRepository(container: container, calendar: calendar)
        #expect(try reader.count(on: today) == 9)
    }

    @Test("Deleting all history empties the store")
    func deleteAll() throws {
        let repository = try makeRepository()
        let now = TestSupport.date(2026, 3, 15, 12, 0, calendar: calendar)

        for offset in 0..<3 {
            let day = DayBoundary.dayStart(daysAgo: offset, from: now, calendar: calendar)
            try repository.increment(by: 5, at: day)
        }
        #expect(try repository.allDays().count == 3)

        try repository.deleteAll()

        #expect(try repository.allDays().isEmpty)
        #expect(try repository.count(on: now) == 0, "The cached record must be dropped too")
    }

    @Test("A zero increment is a no-op that still reports the current total")
    func zeroIncrement() throws {
        let repository = try makeRepository()
        let today = TestSupport.date(2026, 3, 15, 12, 0, calendar: calendar)

        try repository.increment(by: 4, at: today)

        #expect(try repository.increment(by: 0, at: today) == 4)
        #expect(try repository.allDays().count == 1)
    }
}

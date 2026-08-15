//
//  TestSupport.swift
//  IdleTapperTests
//
//  Shared fixtures. Tests pin the calendar and the clock so results do not
//  depend on the machine's time zone or on when the suite happens to run.
//

import Foundation
import SwiftData
@testable import IdleTapper

enum TestSupport {

    /// A fixed calendar in UTC. Removes time-zone flakiness from day-boundary
    /// assertions; the DST tests opt into a real zone explicitly.
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// A calendar in a zone that observes daylight saving, for rollover tests.
    static var newYorkCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// Build a date from components in the given calendar.
    static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 12,
        _ minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute

        guard let date = calendar.date(from: components) else {
            fatalError("Invalid test date \(year)-\(month)-\(day) \(hour):\(minute)")
        }
        return date
    }

    /// Snapshot helper: a day offset from a reference date, with a count.
    static func snapshot(
        daysAgo: Int,
        count: Int,
        from reference: Date,
        calendar: Calendar
    ) -> DaySnapshot {
        DaySnapshot(
            dayStart: DayBoundary.dayStart(daysAgo: daysAgo, from: reference, calendar: calendar),
            tapCount: count
        )
    }

    // MARK: - Preferences

    /// A `UserDefaults` suite of its own, so a settings test cannot read or
    /// write the real app's preferences.
    ///
    /// This matters more than it looks: `AppSettings` defaults to
    /// `UserDefaults.standard`, and a test that took that default would edit the
    /// preferences of the copy of Idle Tapper installed on the machine running
    /// the suite — `resetToDefaults()` in particular would silently wipe them.
    ///
    /// The name is unique per call so tests cannot leak state into each other.
    static func scratchDefaults(
        function: StaticString = #function,
        line: UInt = #line
    ) -> UserDefaults {
        let name = "IdleTapperTests.\(function).\(line).\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            fatalError("Could not create a scratch defaults suite named \(name)")
        }
        return defaults
    }

    /// Discards a scratch suite. Paired with `scratchDefaults()` via `defer`.
    static func removeScratchDefaults(_ defaults: UserDefaults) {
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Clock

    /// A clock a test can move.
    ///
    /// `TapTracker` takes its time as `() -> Date`, so a plain pinned date can
    /// only ever describe one moment. This lets one tracker see two — a
    /// relaunch a week later, a day rollover — without rebuilding it, which
    /// would lose the very persistence the test is checking.
    ///
    /// A class rather than a struct on purpose: the closure has to observe
    /// later writes, which a captured value copy cannot.
    final class MutableClock {
        var now: Date

        init(_ start: Date) {
            self.now = start
        }

        /// Pass this to `makeTracker(now:)`.
        func read() -> Date { now }

        /// Move the clock forward. Negative intervals are allowed — the app
        /// has to survive a user setting their system clock backwards.
        func advance(days: Int, calendar: Calendar) {
            guard let moved = calendar.date(byAdding: .day, value: days, to: now) else { return }
            now = moved
        }
    }

    // MARK: - Tracker

    /// A `TapTracker` over a real, in-memory SwiftData stack, optionally
    /// pre-seeded with history.
    ///
    /// Seeds through the repository rather than through `tracker.tap()`: a tap
    /// only ever records *now*, and most cases need specific days.
    ///
    /// The calendar is overridable because a UTC one hides every time-zone bug
    /// by construction — see `ExportHistoryTests.usesTheRecordingZone`.
    ///
    /// `now` is what decides both what "today" is and the date an achievement
    /// unlocked at, so pin it in any test that asserts on either.
    @MainActor
    static func makeTracker(
        defaults: UserDefaults,
        seed: [(day: Date, count: Int)] = [],
        calendar: Calendar = TestSupport.utcCalendar,
        bannerDuration: Duration = .seconds(4),
        now: @escaping () -> Date = { Date() }
    ) throws -> TapTracker {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataTapRepository(
            container: container,
            calendar: calendar,
            // Effectively disable the debounce so tests drive saves explicitly.
            saveDebounce: .seconds(60)
        )
        for entry in seed {
            _ = try repository.increment(by: entry.count, at: entry.day)
        }
        try repository.flush()

        return TapTracker(
            repository: repository,
            settings: AppSettings(defaults: defaults),
            calendar: calendar,
            bannerDuration: bannerDuration,
            now: now
        )
    }
}

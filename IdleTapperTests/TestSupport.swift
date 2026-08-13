//
//  TestSupport.swift
//  IdleTapperTests
//
//  Shared fixtures. Tests pin the calendar and the clock so results do not
//  depend on the machine's time zone or on when the suite happens to run.
//

import Foundation
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
}

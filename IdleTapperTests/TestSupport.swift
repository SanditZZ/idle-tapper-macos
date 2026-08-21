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
    ///
    /// `firstWeekday` is set explicitly, and has to be: assigning `locale` does
    /// **not** update it, so a week-boundary assertion made against this
    /// calendar without it would be pinning whatever the machine's region says
    /// a week starts on — passing here and being wrong for a user in a Monday
    /// country. Use `weekCalendar(startingOn:)` to vary it deliberately.
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 1        // Sunday
        return calendar
    }

    /// The UTC calendar with a deliberate week start — 1 is Sunday, 2 Monday.
    ///
    /// Week totals are the one statistic whose boundaries move with the user's
    /// region rather than only with their time zone, so both settings are worth
    /// covering.
    ///
    /// Named apart from `utcCalendar` rather than overloading it: a property and
    /// a method sharing a base name is legal but reads as a typo at the call site.
    static func weekCalendar(startingOn firstWeekday: Int) -> Calendar {
        var calendar = utcCalendar
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    /// A calendar in a zone that observes daylight saving, for rollover tests.
    static var newYorkCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 1        // Sunday, as above
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
        calendar: Calendar,
        goalTarget: Int? = nil
    ) -> DaySnapshot {
        DaySnapshot(
            dayStart: DayBoundary.dayStart(daysAgo: daysAgo, from: reference, calendar: calendar),
            tapCount: count,
            goalTarget: goalTarget
        )
    }

    /// Snapshot for a named calendar day, for tests that state their dates
    /// outright rather than counting backwards from "now".
    ///
    /// Week and month boundaries are easier to read — and to check by eye
    /// against a calendar — as "7 March" than as "four days ago".
    ///
    /// `goalTarget` defaults to `nil`, meaning no goal was in effect that day —
    /// which is what every day recorded before goals shipped looks like, and
    /// therefore the case the existing streak fixtures are asserting.
    static func snapshot(
        on day: Date,
        count: Int,
        calendar: Calendar,
        goalTarget: Int? = nil
    ) -> DaySnapshot {
        DaySnapshot(
            dayStart: DayBoundary.dayStart(for: day, calendar: calendar),
            tapCount: count,
            goalTarget: goalTarget
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

    // MARK: - Notifications

    /// A `NotificationScheduling` that records what it was asked to do.
    ///
    /// Stands in for `UNUserNotificationCenter`, which a test must never reach:
    /// it is process-wide, backed by the real notification database, and gated
    /// behind a permission prompt that would be shown to whoever is running the
    /// suite. Everything `GoalTracker` decides is observable here instead.
    @MainActor
    final class FakeNotificationScheduler: NotificationScheduling {

        /// What `authorizationStatus()` reports. Set before exercising the
        /// tracker to cover the refused and not-yet-asked paths.
        var authorization: NotificationAuthorization = .authorized

        /// Identifiers already pending before this launch — a reminder left
        /// behind by a previous run, which the first reconciliation sweeps.
        var preexisting: Set<String> = []

        /// Requests currently scheduled, keyed by identifier.
        private(set) var scheduled: [String: PlannedNotification] = [:]

        /// Every request ever added, in order, including replacements.
        ///
        /// The count is the point: a thousand taps that do not change the plan
        /// must not produce a thousand of these.
        private(set) var added: [PlannedNotification] = []

        private(set) var removed: [String] = []
        private(set) var authorizationRequests = 0

        /// How many times the authorization state was read.
        ///
        /// A proxy for "how many times did the tracker actually go to the
        /// notification centre", which is the figure the hot-path guarantee is
        /// about. Counting `added` alone would not catch it: a refused app adds
        /// nothing however many times it tries.
        private(set) var statusChecks = 0

        /// When set, `add` throws it, for the scheduling-failure path.
        var addError: (any Error)?

        func authorizationStatus() async -> NotificationAuthorization {
            statusChecks += 1
            return authorization
        }

        func requestAuthorization() async -> NotificationAuthorization {
            authorizationRequests += 1
            if authorization == .notDetermined {
                authorization = .authorized
            }
            return authorization
        }

        func pendingIdentifiers(withPrefix prefix: String) async -> Set<String> {
            preexisting.union(scheduled.keys).filter { $0.hasPrefix(prefix) }
        }

        func add(_ notification: PlannedNotification) async throws {
            if let addError { throw addError }
            added.append(notification)
            scheduled[notification.identifier] = notification
        }

        func removeIdentifiers(_ identifiers: [String]) {
            removed.append(contentsOf: identifiers)
            for identifier in identifiers {
                scheduled.removeValue(forKey: identifier)
                preexisting.remove(identifier)
            }
        }

        /// Scheduled requests that fire later, ignoring immediate deliveries.
        var pendingReminders: [PlannedNotification] {
            scheduled.values.filter { !$0.isImmediate }
        }

        /// Requests delivered immediately — the goal-reached notifications.
        var delivered: [PlannedNotification] {
            added.filter(\.isImmediate)
        }
    }

    /// A `GoalTracker` over a fake scheduler.
    @MainActor
    static func makeGoalTracker(
        scheduler: FakeNotificationScheduler,
        settings: AppSettings,
        calendar: Calendar = TestSupport.utcCalendar,
        bannerDuration: Duration = .seconds(4)
    ) -> GoalTracker {
        GoalTracker(
            scheduler: scheduler,
            settings: settings,
            calendar: calendar,
            bannerDuration: bannerDuration
        )
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

//
//  SettingsActionsTests.swift
//  Idle Tapper — Tests
//
//  The three Settings controls that had no coverage at all: Export History,
//  Restore Defaults, and the message shown when launch at login cannot be
//  changed. Their views are thin — a save panel and a button — so the substance
//  is tested here rather than by driving the window.
//

import Foundation
import Testing
@testable import IdleTapper

@Suite("Export history")
@MainActor
struct ExportHistoryTests {

    private let calendar = TestSupport.utcCalendar

    /// Seeds through the repository rather than the tracker: `tap()` only ever
    /// records *now*, and these cases need specific days.
    private func makeTracker(
        defaults: UserDefaults,
        seed: [(day: Date, count: Int)] = []
    ) throws -> TapTracker {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataTapRepository(
            container: container,
            calendar: calendar,
            saveDebounce: .seconds(60)
        )
        for entry in seed {
            _ = try repository.increment(by: entry.count, at: entry.day)
        }
        try repository.flush()

        return TapTracker(
            repository: repository,
            settings: AppSettings(defaults: defaults),
            calendar: calendar
        )
    }

    /// The export is what a user keeps after deleting their history, so it has
    /// to survive a round trip rather than merely being written.
    @Test("Exported JSON decodes back to the same days and totals")
    func roundTrips() throws {
        let defaults = TestSupport.scratchDefaults()
        defer { TestSupport.removeScratchDefaults(defaults) }

        let day = TestSupport.date(2026, 3, 15, 10, 0, calendar: calendar)
        let tracker = try makeTracker(
            defaults: defaults,
            seed: [
                (day, 7),
                (calendar.date(byAdding: .day, value: -1, to: day)!, 5),
            ]
        )

        let data = try tracker.exportJSON()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([DaySnapshot].self, from: data)

        #expect(decoded.count == 2)
        #expect(decoded.map(\.tapCount).sorted() == [5, 7])
    }

    /// An empty export must be valid JSON, not an error or an empty file — this
    /// is what someone gets if they export straight after deleting everything.
    @Test("Exporting an empty history produces an empty array, not a failure")
    func emptyHistoryExports() throws {
        let defaults = TestSupport.scratchDefaults()
        defer { TestSupport.removeScratchDefaults(defaults) }
        let tracker = try makeTracker(defaults: defaults)

        let data = try tracker.exportJSON()
        let decoded = try JSONDecoder().decode([DaySnapshot].self, from: data)

        #expect(decoded.isEmpty)
    }

    /// ISO-8601 rather than a raw `Double`, so the file is readable by anything
    /// and does not silently depend on Apple's reference date.
    @Test("Dates are written as ISO-8601 text")
    func datesAreISO8601() throws {
        let defaults = TestSupport.scratchDefaults()
        defer { TestSupport.removeScratchDefaults(defaults) }

        let tracker = try makeTracker(
            defaults: defaults,
            seed: [(TestSupport.date(2026, 3, 15, 10, 0, calendar: calendar), 1)]
        )

        let text = String(decoding: try tracker.exportJSON(), as: UTF8.self)

        #expect(text.contains("2026-03-15"))
    }
}

@Suite("Restore defaults")
@MainActor
struct RestoreDefaultsTests {

    /// Every setting, not merely the ones the user is most likely to have
    /// changed — a "restore defaults" that leaves one behind is worse than none,
    /// because the state it leaves is one no fresh install ever has.
    @Test("Restores every setting, not just some of them")
    func restoresEverySetting() {
        let defaults = TestSupport.scratchDefaults()
        defer { TestSupport.removeScratchDefaults(defaults) }

        let settings = AppSettings(defaults: defaults)
        settings.menuBarDisplayStyle = .countOnly
        settings.historyRangeDays = 365
        settings.confirmBeforeReset = false
        settings.playTapSound = true
        settings.suppressHiddenIconNotice = true

        settings.resetToDefaults()

        #expect(settings.menuBarDisplayStyle == .iconAndCount)
        #expect(settings.historyRangeDays == AppSettings.defaultHistoryRangeDays)
        #expect(settings.confirmBeforeReset)
        #expect(!settings.playTapSound)
        #expect(!settings.suppressHiddenIconNotice)
    }

    /// The reset has to reach the store, or it survives only until relaunch.
    @Test("The restored values are persisted, not just held in memory")
    func restoredValuesPersist() {
        let defaults = TestSupport.scratchDefaults()
        defer { TestSupport.removeScratchDefaults(defaults) }

        let settings = AppSettings(defaults: defaults)
        settings.menuBarDisplayStyle = .iconOnly
        settings.playTapSound = true
        settings.resetToDefaults()

        let reloaded = AppSettings(defaults: defaults)

        #expect(reloaded.menuBarDisplayStyle == .iconAndCount)
        #expect(!reloaded.playTapSound)
    }

    /// A corrupt or out-of-range stored value must not produce an unusable
    /// chart; the clamp is the only thing standing between a bad default and a
    /// window that cannot render.
    @Test("An out-of-range stored range is clamped on load")
    func clampsStoredRange() {
        let defaults = TestSupport.scratchDefaults()
        defer { TestSupport.removeScratchDefaults(defaults) }

        defaults.set(99_999, forKey: "historyRangeDays")
        #expect(AppSettings(defaults: defaults).historyRangeDays
            == AppSettings.historyRangeBounds.upperBound)

        defaults.set(1, forKey: "historyRangeDays")
        #expect(AppSettings(defaults: defaults).historyRangeDays
            == AppSettings.historyRangeBounds.lowerBound)
    }
}

@Suite("Launch at login messages")
struct LaunchAtLoginMessageTests {

    private struct StubError: LocalizedError {
        var errorDescription: String? { "Operation not permitted" }
    }

    /// The failure nearly every developer and every curious user hits first:
    /// macOS refuses to register a login item for an app outside a normal
    /// install location. A raw ServiceManagement error says nothing about that,
    /// so the message has to.
    @Test("Failing to enable outside Applications explains why")
    func explainsTheApplicationsFolder() {
        let message = LaunchAtLoginService.describe(
            StubError(),
            whileEnabling: true,
            isInApplications: false
        )

        #expect(message.contains("Applications folder"))
    }

    /// Once the app *is* installed properly the Applications advice is wrong and
    /// actively misleading, so the underlying reason has to come through.
    @Test("Failing to enable from Applications reports the real error")
    func reportsTheRealErrorWhenInstalled() {
        let message = LaunchAtLoginService.describe(
            StubError(),
            whileEnabling: true,
            isInApplications: true
        )

        #expect(message.contains("Operation not permitted"))
        #expect(!message.contains("Applications folder"))
    }

    /// Turning it *off* never depends on where the app lives, so the location
    /// advice must not leak into that path.
    @Test("Failing to disable never blames the install location")
    func disablingIgnoresLocation() {
        let message = LaunchAtLoginService.describe(
            StubError(),
            whileEnabling: false,
            isInApplications: false
        )

        #expect(message.contains("disable"))
        #expect(!message.contains("Applications folder"))
    }
}

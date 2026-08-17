//
//  TapTrackerAchievementTests.swift
//  IdleTapperTests
//
//  The achievement behaviour that lives in the Actions layer and so cannot be
//  reached from `AchievementCalculatorTests`: when an unlock is announced,
//  when it is granted silently, and that an unlock outlives the history it was
//  earned from. Runs against a real SwiftData stack, in memory.
//

import Testing
import Foundation
@testable import IdleTapper

@Suite("Tap tracker achievements")
@MainActor
struct TapTrackerAchievementTests {

    private let calendar = TestSupport.utcCalendar

    private var launchDate: Date {
        TestSupport.date(2026, 3, 15, 10, 0, calendar: calendar)
    }

    private func progress(_ tracker: TapTracker, _ id: AchievementID) -> AchievementProgress? {
        tracker.achievementProgress.first { $0.id == id }
    }

    // MARK: - Silent retroactive grants

    /// The case a release that adds achievements creates for every existing
    /// user: history that already satisfies a brand-new entry.
    ///
    /// `TapTracker.init` evaluates before the user can have tapped, so
    /// anything satisfied at that moment was earned in the past. It must be
    /// persisted — the trophy is real — but announcing it would greet someone
    /// who has just updated with a banner for something they did months ago.
    @Test("An achievement already earned at launch is granted with no banner")
    func launchGrantsSilently() throws {
        let defaults = TestSupport.scratchDefaults()
        defer { TestSupport.removeScratchDefaults(defaults) }

        let clock = TestSupport.MutableClock(launchDate)
        let tracker = try TestSupport.makeTracker(
            defaults: defaults,
            seed: [(launchDate, 150)],
            calendar: calendar,
            now: clock.read
        )

        #expect(progress(tracker, .firstTap)?.isUnlocked == true)
        #expect(progress(tracker, .hundredClub)?.isUnlocked == true)
        #expect(tracker.latestUnlock == nil, "A pre-existing achievement must not raise a banner")
    }

    /// The trap the "capture the flag at the top" rule exists for. On a quiet
    /// launch nothing is newly satisfied, so `evaluateAchievements` returns
    /// early — and if the flag were set after that early return, the first
    /// *real* unlock of the session would be mistaken for the initial
    /// evaluation and silently swallowed.
    @Test("The first unlock after a quiet launch still raises a banner")
    func laterUnlockStillBanners() throws {
        let defaults = TestSupport.scratchDefaults()
        defer { TestSupport.removeScratchDefaults(defaults) }

        // No seed: at launch `allTime` is 0, so not even First Tap is met and
        // the initial evaluation finds nothing.
        let clock = TestSupport.MutableClock(launchDate)
        let tracker = try TestSupport.makeTracker(
            defaults: defaults,
            calendar: calendar,
            // Long enough that the banner cannot clear itself mid-test.
            bannerDuration: .seconds(600),
            now: clock.read
        )
        #expect(tracker.latestUnlock == nil)

        tracker.tap()
        // `tap()` only schedules a debounced refresh; drive it directly rather
        // than sleeping for the debounce.
        tracker.refresh()

        #expect(tracker.latestUnlock?.id == .firstTap)
    }

    // MARK: - Unlock dates

    @Test("An unlock records the date it happened and carries it into progress")
    func unlockDateReachesProgress() throws {
        let defaults = TestSupport.scratchDefaults()
        defer { TestSupport.removeScratchDefaults(defaults) }

        let clock = TestSupport.MutableClock(launchDate)
        let tracker = try TestSupport.makeTracker(
            defaults: defaults,
            seed: [(launchDate, 1)],
            calendar: calendar,
            now: clock.read
        )

        #expect(progress(tracker, .firstTap)?.unlockedAt == launchDate)
        #expect(progress(tracker, .hundredClub)?.unlockedAt == nil)
    }

    /// A second launch must read the original date back rather than restamping
    /// it — otherwise every unlock would show today's date forever.
    @Test("An unlock date survives a relaunch unchanged")
    func unlockDateSurvivesRelaunch() throws {
        let defaults = TestSupport.scratchDefaults()
        defer { TestSupport.removeScratchDefaults(defaults) }

        let clock = TestSupport.MutableClock(launchDate)
        let tracker = try TestSupport.makeTracker(
            defaults: defaults,
            seed: [(launchDate, 1)],
            calendar: calendar,
            now: clock.read
        )
        #expect(progress(tracker, .firstTap)?.unlockedAt == launchDate)

        // A refresh a week later stands in for the next launch: same store,
        // later clock. The date has to come back off the row rather than being
        // restamped as "now".
        clock.advance(days: 7, calendar: calendar)
        tracker.refresh()

        #expect(progress(tracker, .firstTap)?.unlockedAt == launchDate)
    }

    // MARK: - Achievements are never revoked

    /// Deleting history is the user throwing away their *counts*, not their
    /// trophies. The unlock set is read from persistence rather than
    /// recomputed from `stats`, and `deleteAll()` deliberately leaves the
    /// achievement rows alone — tiers must not have quietly changed that.
    @Test("An achievement stays unlocked after all history is deleted")
    func deletingHistoryKeepsAchievements() throws {
        let defaults = TestSupport.scratchDefaults()
        defer { TestSupport.removeScratchDefaults(defaults) }

        let clock = TestSupport.MutableClock(launchDate)
        let tracker = try TestSupport.makeTracker(
            defaults: defaults,
            seed: [(launchDate, 150)],
            calendar: calendar,
            now: clock.read
        )
        #expect(progress(tracker, .hundredClub)?.isUnlocked == true)

        tracker.deleteAllHistory()

        #expect(tracker.stats.allTime == 0)
        #expect(progress(tracker, .hundredClub)?.isUnlocked == true)
        #expect(progress(tracker, .hundredClub)?.unlockedAt == launchDate)
        #expect(progress(tracker, .hundredClub)?.fraction == 1)
    }
}

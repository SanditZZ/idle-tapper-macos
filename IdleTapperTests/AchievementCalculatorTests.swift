//
//  AchievementCalculatorTests.swift
//  IdleTapperTests
//

import Testing
import Foundation
@testable import IdleTapper

@Suite("Achievement calculator")
struct AchievementCalculatorTests {

    // MARK: - Fixtures

    private func stats(
        allTime: Int = 0,
        bestDay: Int = 0,
        longestStreak: Int = 0,
        activeDays: Int = 0,
        averagePerActiveDay: Double = 0,
        bestGoalPercent: Int = 0
    ) -> TapStats {
        TapStats(
            today: 0,
            thisWeek: 0,
            thisMonth: 0,
            allTime: allTime,
            bestDay: bestDay,
            bestDayDate: nil,
            currentStreak: 0,
            longestStreak: longestStreak,
            activeDays: activeDays,
            averagePerActiveDay: averagePerActiveDay,
            bestGoalPercent: bestGoalPercent
        )
    }

    private let unlockDate = TestSupport.date(2026, 3, 15, 10, 0, calendar: TestSupport.utcCalendar)

    // MARK: - Boundaries

    @Test("An achievement is locked one short of its threshold")
    func lockedBelowThreshold() {
        let unlocked = AchievementCalculator.unlocked(from: stats(allTime: 99))
        #expect(!unlocked.contains(.hundredClub))
    }

    @Test("An achievement unlocks exactly at its threshold")
    func unlockedAtThreshold() {
        let unlocked = AchievementCalculator.unlocked(from: stats(allTime: 100))
        #expect(unlocked.contains(.hundredClub))
    }

    @Test("An achievement stays unlocked past its threshold")
    func unlockedAboveThreshold() {
        let unlocked = AchievementCalculator.unlocked(from: stats(allTime: 250))
        #expect(unlocked.contains(.hundredClub))
    }

    @Test("Every catalog requirement kind reads the matching stat")
    func everyRequirementKindIsWired() {
        let unlocked = AchievementCalculator.unlocked(
            from: stats(
                allTime: 1,
                bestDay: 100,
                longestStreak: 7,
                activeDays: 30,
                averagePerActiveDay: 100
            )
        )
        #expect(unlocked == [.firstTap, .centuryDay, .weekStreak, .dedicated, .consistent])
    }

    // MARK: - The average requirement

    /// The one requirement reading a `Double`. Rounding rather than truncating
    /// would let an average of 99.5 satisfy a target of 100, which reads as a
    /// bug to anyone who can see their own average printed in the History
    /// window as 99.5.
    @Test("A fractional average is truncated, never rounded up")
    func averageTruncates() {
        let justUnder = AchievementCalculator.unlocked(from: stats(averagePerActiveDay: 99.9))
        #expect(!justUnder.contains(.consistent))

        let exactly = AchievementCalculator.unlocked(from: stats(averagePerActiveDay: 100.0))
        #expect(exactly.contains(.consistent))
    }

    /// `Int(_: Double)` traps on a non-finite value, and on anything at or
    /// beyond `Int.max` — either would take the app down from inside a
    /// refresh. All three read as zero, which errs toward locked; the opposite
    /// error is unfixable, since an achievement is never revoked.
    @Test("An unrepresentable average reads as zero rather than crashing")
    func averageSurvivesUnrepresentableValues() {
        let requirement = AchievementRequirement.averagePerActiveDay(100)

        #expect(requirement.current(in: stats(averagePerActiveDay: .nan)) == 0)
        #expect(requirement.current(in: stats(averagePerActiveDay: .infinity)) == 0)
        #expect(requirement.current(in: stats(averagePerActiveDay: .greatestFiniteMagnitude)) == 0)

        #expect(!AchievementCalculator.unlocked(from: stats(averagePerActiveDay: .nan)).contains(.consistent))
    }

    // MARK: - Diffing

    @Test("Nothing is newly unlocked when the sets are equal")
    func noDiffWhenEqual() {
        let newly = AchievementCalculator.newlyUnlocked(previously: [.firstTap], now: [.firstTap])
        #expect(newly.isEmpty)
    }

    @Test("Newly unlocked is exactly what now has that previously did not")
    func diffFindsNewOnes() {
        let newly = AchievementCalculator.newlyUnlocked(
            previously: [.firstTap],
            now: [.firstTap, .hundredClub, .thousandClub]
        )
        #expect(newly == [.hundredClub, .thousandClub])
    }

    // MARK: - Unlock dates

    @Test("Persisted unlocks reduce to one date per achievement")
    func unlockDatesKeyByID() {
        let later = unlockDate.addingTimeInterval(3600)
        let dates = AchievementCalculator.unlockDates(from: [
            AchievementSnapshot(id: .firstTap, unlockedAt: unlockDate),
            AchievementSnapshot(id: .hundredClub, unlockedAt: later),
        ])

        #expect(dates == [.firstTap: unlockDate, .hundredClub: later])
    }

    /// A duplicate id should be impossible — the column is unique — but the
    /// obvious `Dictionary(uniqueKeysWithValues:)` *traps* if one ever appears,
    /// and a corrupt row is not worth crashing a launch over.
    @Test("A duplicated unlock keeps the earliest date instead of trapping")
    func unlockDatesSurviveDuplicates() {
        let later = unlockDate.addingTimeInterval(3600)
        let dates = AchievementCalculator.unlockDates(from: [
            AchievementSnapshot(id: .firstTap, unlockedAt: later),
            AchievementSnapshot(id: .firstTap, unlockedAt: unlockDate),
        ])

        #expect(dates == [.firstTap: unlockDate])
    }

    // MARK: - Progress

    @Test("Progress reports every catalog entry, in catalog order")
    func progressCoversWholeCatalog() {
        let progress = AchievementCalculator.progress(stats: stats(), unlocked: [:])
        #expect(progress.map(\.id) == AchievementCatalog.all.map(\.id))
    }

    @Test("A locked entry reports its current figure against its target")
    func lockedProgressReportsCurrentAndTarget() {
        let progress = AchievementCalculator.progress(stats: stats(allTime: 40), unlocked: [:])
        let hundredClub = progress.first { $0.id == .hundredClub }

        #expect(hundredClub?.isUnlocked == false)
        #expect(hundredClub?.unlockedAt == nil)
        #expect(hundredClub?.current == 40)
        #expect(hundredClub?.target == 100)
        #expect(hundredClub?.fraction == 0.4)
    }

    @Test("An unlocked entry reports full progress even if current has since regressed")
    func unlockedProgressStaysFullEvenIfCurrentDrops() {
        // Simulates the state right after `deleteAll()`: the achievement is
        // still persisted as unlocked, but the stats it was computed from are
        // gone. The trophy must not look half-earned.
        let progress = AchievementCalculator.progress(
            stats: stats(allTime: 0),
            unlocked: [.hundredClub: unlockDate]
        )
        let hundredClub = progress.first { $0.id == .hundredClub }

        #expect(hundredClub?.isUnlocked == true)
        #expect(hundredClub?.fraction == 1)
    }

    /// The date is the whole point of the tiers release, and `isUnlocked` is
    /// derived from it rather than stored beside it, so a progress entry
    /// cannot claim to be unlocked with no date or the reverse.
    @Test("Progress carries the unlock date and the tier from the catalog")
    func progressCarriesDateAndTier() {
        let progress = AchievementCalculator.progress(
            stats: stats(allTime: 1),
            unlocked: [.firstTap: unlockDate]
        )
        let firstTap = progress.first { $0.id == .firstTap }

        #expect(firstTap?.unlockedAt == unlockDate)
        #expect(firstTap?.isUnlocked == true)
        #expect(firstTap?.tier == AchievementCatalog.byID[.firstTap]?.tier)
    }

    // MARK: - Tier grouping

    @Test("Grouping keeps every entry, in tier order then catalog order")
    func groupingPreservesOrderAndCount() {
        let progress = AchievementCalculator.progress(stats: stats(), unlocked: [:])
        let groups = AchievementCalculator.grouped(progress)

        #expect(groups.map(\.tier) == [.bronze, .silver, .gold])
        #expect(groups.flatMap(\.entries).count == progress.count)

        // Flattening the sections must give back the catalog's own order —
        // which is what keeps "the first newly unlocked in catalog order" the
        // same achievement the window shows first.
        #expect(groups.flatMap(\.entries).map(\.id) == progress.map(\.id))
    }

    @Test("A tier with no entries is dropped rather than rendered empty")
    func groupingDropsEmptyTiers() {
        let bronzeOnly = AchievementCalculator
            .progress(stats: stats(), unlocked: [:])
            .filter { $0.tier == .bronze }
        let groups = AchievementCalculator.grouped(bronzeOnly)

        #expect(groups.map(\.tier) == [.bronze])
    }

    @Test("A group counts only its own unlocked entries")
    func groupCountsItsOwnUnlocks() {
        let progress = AchievementCalculator.progress(
            stats: stats(allTime: 1),
            unlocked: [.firstTap: unlockDate, .tenThousandClub: unlockDate]
        )
        let groups = AchievementCalculator.grouped(progress)

        #expect(groups.first { $0.tier == .bronze }?.unlockedCount == 1)
        #expect(groups.first { $0.tier == .silver }?.unlockedCount == 0)
        #expect(groups.first { $0.tier == .gold }?.unlockedCount == 1)
    }
}

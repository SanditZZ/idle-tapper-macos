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
        activeDays: Int = 0
    ) -> TapStats {
        TapStats(
            today: 0,
            allTime: allTime,
            bestDay: bestDay,
            bestDayDate: nil,
            currentStreak: 0,
            longestStreak: longestStreak,
            activeDays: activeDays,
            averagePerActiveDay: 0
        )
    }

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
            from: stats(allTime: 1, bestDay: 100, longestStreak: 7, activeDays: 30)
        )
        #expect(unlocked == [.firstTap, .centuryDay, .weekStreak, .dedicated])
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

    // MARK: - Progress

    @Test("Progress reports every catalog entry, in catalog order")
    func progressCoversWholeCatalog() {
        let progress = AchievementCalculator.progress(stats: stats(), unlocked: [])
        #expect(progress.map(\.id) == AchievementCatalog.all.map(\.id))
    }

    @Test("A locked entry reports its current figure against its target")
    func lockedProgressReportsCurrentAndTarget() {
        let progress = AchievementCalculator.progress(stats: stats(allTime: 40), unlocked: [])
        let hundredClub = progress.first { $0.id == .hundredClub }

        #expect(hundredClub?.isUnlocked == false)
        #expect(hundredClub?.current == 40)
        #expect(hundredClub?.target == 100)
        #expect(hundredClub?.fraction == 0.4)
    }

    @Test("An unlocked entry reports full progress even if current has since regressed")
    func unlockedProgressStaysFullEvenIfCurrentDrops() {
        // Simulates the state right after `deleteAll()`: the achievement is
        // still persisted as unlocked, but the stats it was computed from are
        // gone. The trophy must not look half-earned.
        let progress = AchievementCalculator.progress(stats: stats(allTime: 0), unlocked: [.hundredClub])
        let hundredClub = progress.first { $0.id == .hundredClub }

        #expect(hundredClub?.isUnlocked == true)
        #expect(hundredClub?.fraction == 1)
    }
}

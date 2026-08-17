//
//  AchievementCalculator.swift
//  Idle Tapper — Calculations (pure)
//
//  Evaluates the achievement catalog against `TapStats`. Pure functions
//  only: same input, same output, no I/O and no SwiftData types.
//

import Foundation

enum AchievementCalculator {

    /// Every achievement whose requirement `stats` currently satisfies.
    static func unlocked(
        from stats: TapStats,
        catalog: [AchievementDefinition] = AchievementCatalog.all
    ) -> Set<AchievementID> {
        Set(
            catalog
                .filter { $0.requirement.current(in: stats) >= $0.requirement.target }
                .map(\.id)
        )
    }

    /// Achievements present in `now` but not in `previously` — what should be
    /// persisted and announced this refresh.
    static func newlyUnlocked(
        previously: Set<AchievementID>,
        now: Set<AchievementID>
    ) -> Set<AchievementID> {
        now.subtracting(previously)
    }

    /// Persisted unlocks reduced to the date each achievement was earned.
    ///
    /// `AchievementRecord.id` is unique, so a repeated id should be
    /// impossible — but `Dictionary(uniqueKeysWithValues:)` *traps* if one
    /// ever appears, which is not a price worth paying for reading a row back.
    /// The earliest date wins: an achievement is earned once, and the first
    /// time is the true one.
    static func unlockDates(from snapshots: [AchievementSnapshot]) -> [AchievementID: Date] {
        snapshots.reduce(into: [:]) { dates, snapshot in
            dates[snapshot.id] = min(dates[snapshot.id] ?? snapshot.unlockedAt, snapshot.unlockedAt)
        }
    }

    /// The full catalog, each entry paired with its unlock date (if any) and
    /// progress toward its target, in catalog order.
    static func progress(
        stats: TapStats,
        unlocked: [AchievementID: Date],
        catalog: [AchievementDefinition] = AchievementCatalog.all
    ) -> [AchievementProgress] {
        catalog.map { definition in
            AchievementProgress(
                id: definition.id,
                tier: definition.tier,
                unlockedAt: unlocked[definition.id],
                current: definition.requirement.current(in: stats),
                target: definition.requirement.target
            )
        }
    }

    /// `progress` split into tier sections, easiest tier first, each keeping
    /// the order its entries arrived in.
    ///
    /// Empty tiers are dropped rather than rendered as a heading with nothing
    /// under it — which only happens for a filtered subset, since the real
    /// catalog has every tier populated.
    static func grouped(_ progress: [AchievementProgress]) -> [AchievementTierGroup] {
        AchievementTier.allCases.compactMap { tier in
            let entries = progress.filter { $0.tier == tier }
            guard !entries.isEmpty else { return nil }
            return AchievementTierGroup(tier: tier, entries: entries)
        }
    }
}

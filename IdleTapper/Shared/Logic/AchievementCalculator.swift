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

    /// The full catalog, each entry paired with its locked/unlocked state and
    /// progress toward its target, in catalog order.
    static func progress(
        stats: TapStats,
        unlocked: Set<AchievementID>,
        catalog: [AchievementDefinition] = AchievementCatalog.all
    ) -> [AchievementProgress] {
        catalog.map { definition in
            AchievementProgress(
                id: definition.id,
                isUnlocked: unlocked.contains(definition.id),
                current: definition.requirement.current(in: stats),
                target: definition.requirement.target
            )
        }
    }
}

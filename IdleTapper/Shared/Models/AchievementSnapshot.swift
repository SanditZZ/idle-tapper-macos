//
//  AchievementSnapshot.swift
//  Idle Tapper — Value types
//
//  Plain, `Sendable` value types for achievements, crossing the boundary
//  between persistence and the pure calculation layer the same way
//  `DaySnapshot` does for daily totals.
//

import Foundation

/// An unlocked achievement, as read back from persistence.
struct AchievementSnapshot: Equatable, Hashable, Sendable, Codable, Identifiable {
    let id: AchievementID
    let unlockedAt: Date
}

/// One catalog entry combined with its current locked/unlocked state, for
/// display in the Achievements window.
struct AchievementProgress: Equatable, Sendable, Identifiable {
    let id: AchievementID

    /// Difficulty band, carried from the definition so the window can group
    /// by tier from this array alone, with no catalog lookup in the grouping.
    let tier: AchievementTier

    /// When this was unlocked, or `nil` while it is still locked.
    ///
    /// Deliberately the *only* record of unlocked-ness — `isUnlocked` is
    /// computed from it rather than stored beside it, so the two cannot
    /// disagree.
    let unlockedAt: Date?

    let current: Int
    let target: Int

    /// Whether this achievement has been earned.
    var isUnlocked: Bool { unlockedAt != nil }

    /// Progress toward `target`, `0...1`. Already-unlocked entries read 1
    /// even if `current` has since moved past `target`.
    var fraction: Double {
        guard target > 0 else { return isUnlocked ? 1 : 0 }
        return isUnlocked ? 1 : min(Double(current) / Double(target), 1)
    }
}

/// One tier's worth of achievements, in catalog order — a section of the
/// Achievements window.
struct AchievementTierGroup: Equatable, Sendable, Identifiable {
    let tier: AchievementTier
    let entries: [AchievementProgress]

    var id: AchievementTier { tier }

    /// How many entries in this tier are unlocked.
    var unlockedCount: Int {
        entries.filter(\.isUnlocked).count
    }
}

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
    let isUnlocked: Bool
    let current: Int
    let target: Int

    /// Progress toward `target`, `0...1`. Already-unlocked entries read 1
    /// even if `current` has since moved past `target`.
    var fraction: Double {
        guard target > 0 else { return isUnlocked ? 1 : 0 }
        return isUnlocked ? 1 : min(Double(current) / Double(target), 1)
    }
}

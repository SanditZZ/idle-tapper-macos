//
//  AchievementDefinition.swift
//  Idle Tapper — Data
//
//  The fixed catalog of achievements. Each entry names a requirement rather
//  than embedding logic — `AchievementCalculator` is what interprets a
//  requirement against `TapStats`, keeping this file pure data.
//

import Foundation

/// Stable identity for an achievement. The raw value is what persists in
/// `AchievementRecord`, so renaming a case would silently orphan existing
/// unlocks — add a new case instead of renaming one already shipped.
enum AchievementID: String, CaseIterable, Codable, Sendable {
    case firstTap
    case hundredClub
    case thousandClub
    case tenThousandClub
    case centuryDay
    case bigDay
    case weekStreak
    case monthStreak
    case dedicated
}

/// What a `TapStats` figure must reach for an achievement to unlock.
enum AchievementRequirement: Sendable {
    case allTimeTaps(Int)
    case bestDay(Int)
    case longestStreak(Int)
    case activeDays(Int)

    /// The figure this requirement reads from `TapStats`.
    func current(in stats: TapStats) -> Int {
        switch self {
        case .allTimeTaps: return stats.allTime
        case .bestDay: return stats.bestDay
        case .longestStreak: return stats.longestStreak
        case .activeDays: return stats.activeDays
        }
    }

    /// The value `current(in:)` must reach.
    var target: Int {
        switch self {
        case .allTimeTaps(let target),
             .bestDay(let target),
             .longestStreak(let target),
             .activeDays(let target):
            return target
        }
    }
}

/// One entry in the achievement catalog.
struct AchievementDefinition: Identifiable, Sendable {
    let id: AchievementID
    let title: String
    let detail: String
    let systemImage: String
    let requirement: AchievementRequirement
}

/// The full, fixed set of achievements. Ordered roughly by how soon a new
/// user reaches each one.
enum AchievementCatalog {
    static let all: [AchievementDefinition] = [
        AchievementDefinition(
            id: .firstTap,
            title: "First Tap",
            detail: "Record your first tap.",
            systemImage: "hand.tap.fill",
            requirement: .allTimeTaps(1)
        ),
        AchievementDefinition(
            id: .hundredClub,
            title: "Hundred Club",
            detail: "Reach 100 taps all-time.",
            systemImage: "100.circle.fill",
            requirement: .allTimeTaps(100)
        ),
        AchievementDefinition(
            id: .thousandClub,
            title: "Thousand Club",
            detail: "Reach 1,000 taps all-time.",
            systemImage: "sum",
            requirement: .allTimeTaps(1_000)
        ),
        AchievementDefinition(
            id: .tenThousandClub,
            title: "Ten Thousand Club",
            detail: "Reach 10,000 taps all-time.",
            systemImage: "sparkles",
            requirement: .allTimeTaps(10_000)
        ),
        AchievementDefinition(
            id: .centuryDay,
            title: "Century Day",
            detail: "Tap 100 times in a single day.",
            systemImage: "sun.max.fill",
            requirement: .bestDay(100)
        ),
        AchievementDefinition(
            id: .bigDay,
            title: "Big Day",
            detail: "Tap 1,000 times in a single day.",
            systemImage: "bolt.fill",
            requirement: .bestDay(1_000)
        ),
        AchievementDefinition(
            id: .weekStreak,
            title: "Week Streak",
            detail: "Tap on 7 consecutive days.",
            systemImage: "flame.fill",
            requirement: .longestStreak(7)
        ),
        AchievementDefinition(
            id: .monthStreak,
            title: "Month Streak",
            detail: "Tap on 30 consecutive days.",
            systemImage: "flame.fill",
            requirement: .longestStreak(30)
        ),
        AchievementDefinition(
            id: .dedicated,
            title: "Dedicated",
            detail: "Tap on 30 different days.",
            systemImage: "calendar",
            requirement: .activeDays(30)
        ),
    ]
}

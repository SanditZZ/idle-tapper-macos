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

    // Added in the tiers release. New cases go at the end; the order here is
    // not what the window renders — `AchievementCatalog.all` decides that.
    case consistent
    case fiftyThousandClub
    case marathonDay
    case hundredDayStreak
    case hundredActiveDays
    case relentless
}

/// Difficulty band an achievement sits in.
///
/// Ordered easiest first, which is the order tiers are shown in *and* the
/// order `AchievementCatalog.all` is written in — so the catalog's own
/// "soonest reached first" ordering, which decides which unlock gets the
/// banner, survives the grouping for free.
enum AchievementTier: String, CaseIterable, Comparable, Sendable {
    case bronze
    case silver
    case gold

    /// Section heading in the Achievements window.
    var title: String {
        switch self {
        case .bronze: "Bronze"
        case .silver: "Silver"
        case .gold: "Gold"
        }
    }

    /// Position in the easiest-first ordering.
    var rank: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// What a `TapStats` figure must reach for an achievement to unlock.
enum AchievementRequirement: Sendable {
    case allTimeTaps(Int)
    case bestDay(Int)
    case longestStreak(Int)
    case activeDays(Int)
    case averagePerActiveDay(Int)

    /// The figure this requirement reads from `TapStats`.
    func current(in stats: TapStats) -> Int {
        switch self {
        case .allTimeTaps: return stats.allTime
        case .bestDay: return stats.bestDay
        case .longestStreak: return stats.longestStreak
        case .activeDays: return stats.activeDays
        case .averagePerActiveDay:
            let average = stats.averagePerActiveDay
            // This is the only requirement reading a `Double`, and
            // `Int(_: Double)` traps on anything non-finite or beyond
            // `Int.max`. Neither is reachable from a real history — the
            // average is an Int/Int division already guarded against a zero
            // divisor — but a crash inside a refresh is not the way to find
            // out otherwise. Reading as zero errs toward *locked*, which is
            // the safe direction: an achievement is never revoked, so a
            // trophy granted on a garbage figure could not be taken back.
            guard average.isFinite, average < Double(Int.max) else { return 0 }
            // Truncated, never rounded: an average of 99.9 must not satisfy a
            // target of 100.
            return Int(average)
        }
    }

    /// The value `current(in:)` must reach.
    var target: Int {
        switch self {
        case .allTimeTaps(let target),
             .bestDay(let target),
             .longestStreak(let target),
             .activeDays(let target),
             .averagePerActiveDay(let target):
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
    let tier: AchievementTier
    let requirement: AchievementRequirement
}

/// The full, fixed set of achievements. Ordered by tier, easiest first, and
/// within a tier by how soon a new user reaches each one.
///
/// **`today` and `currentStreak` are deliberately absent**, although both are
/// `TapStats` fields with no achievement reading them. Neither can carry one:
/// `bestDay >= N` unlocks the instant `today >= N`, and
/// `longestStreak >= currentStreak` always holds, so either would only ever
/// fire alongside an existing entry — two trophies for one event. `bestDayDate`
/// is the wrong shape entirely: any requirement built on a date can stop being
/// true, and an achievement is never revoked.
enum AchievementCatalog {
    static let all: [AchievementDefinition] = [

        // MARK: Bronze

        AchievementDefinition(
            id: .firstTap,
            title: "First Tap",
            detail: "Record your first tap.",
            systemImage: "hand.tap.fill",
            tier: .bronze,
            requirement: .allTimeTaps(1)
        ),
        AchievementDefinition(
            id: .hundredClub,
            title: "Hundred Club",
            detail: "Reach 100 taps all-time.",
            // Not "100.circle.fill": SF Symbols' numbered circles stop at 50,
            // so that name resolves to nothing and the badge renders blank.
            // Anything chosen here must also exist on macOS 14, the deployment
            // target — which rules out newer glyphs like `medal.fill`.
            systemImage: "number.circle.fill",
            tier: .bronze,
            requirement: .allTimeTaps(100)
        ),
        AchievementDefinition(
            id: .centuryDay,
            title: "Century Day",
            detail: "Tap 100 times in a single day.",
            systemImage: "sun.max.fill",
            tier: .bronze,
            requirement: .bestDay(100)
        ),
        AchievementDefinition(
            id: .weekStreak,
            title: "Week Streak",
            detail: "Tap on 7 consecutive days.",
            systemImage: "flame.fill",
            tier: .bronze,
            requirement: .longestStreak(7)
        ),

        // MARK: Silver

        AchievementDefinition(
            id: .thousandClub,
            title: "Thousand Club",
            detail: "Reach 1,000 taps all-time.",
            systemImage: "sum",
            tier: .silver,
            requirement: .allTimeTaps(1_000)
        ),
        AchievementDefinition(
            id: .bigDay,
            title: "Big Day",
            detail: "Tap 1,000 times in a single day.",
            systemImage: "bolt.fill",
            tier: .silver,
            requirement: .bestDay(1_000)
        ),
        AchievementDefinition(
            id: .monthStreak,
            title: "Month Streak",
            detail: "Tap on 30 consecutive days.",
            systemImage: "flame.fill",
            tier: .silver,
            requirement: .longestStreak(30)
        ),
        AchievementDefinition(
            id: .dedicated,
            title: "Dedicated",
            detail: "Tap on 30 different days.",
            systemImage: "calendar",
            tier: .silver,
            requirement: .activeDays(30)
        ),
        AchievementDefinition(
            id: .consistent,
            title: "Consistent",
            detail: "Average 100 taps across every active day.",
            systemImage: "chart.line.uptrend.xyaxis",
            tier: .silver,
            requirement: .averagePerActiveDay(100)
        ),

        // MARK: Gold

        AchievementDefinition(
            id: .tenThousandClub,
            title: "Ten Thousand Club",
            detail: "Reach 10,000 taps all-time.",
            systemImage: "sparkles",
            tier: .gold,
            requirement: .allTimeTaps(10_000)
        ),
        AchievementDefinition(
            id: .marathonDay,
            title: "Marathon Day",
            detail: "Tap 5,000 times in a single day.",
            systemImage: "figure.run",
            tier: .gold,
            requirement: .bestDay(5_000)
        ),
        AchievementDefinition(
            id: .fiftyThousandClub,
            title: "Fifty Thousand Club",
            detail: "Reach 50,000 taps all-time.",
            systemImage: "crown.fill",
            tier: .gold,
            requirement: .allTimeTaps(50_000)
        ),
        AchievementDefinition(
            id: .hundredDayStreak,
            title: "Hundred Day Streak",
            detail: "Tap on 100 consecutive days.",
            systemImage: "flame.circle.fill",
            tier: .gold,
            requirement: .longestStreak(100)
        ),
        AchievementDefinition(
            id: .hundredActiveDays,
            title: "Hundred Days",
            detail: "Tap on 100 different days.",
            systemImage: "calendar.badge.clock",
            tier: .gold,
            requirement: .activeDays(100)
        ),
        AchievementDefinition(
            id: .relentless,
            title: "Relentless",
            detail: "Average 500 taps across every active day.",
            systemImage: "infinity",
            tier: .gold,
            requirement: .averagePerActiveDay(500)
        ),
    ]

    /// The catalog keyed by id, for the view's per-entry lookup.
    ///
    /// Grouping the window into tier sections broke the positional `zip` of
    /// catalog against progress that used to pair the two, so a lookup is what
    /// replaces it. Built once rather than searched linearly per card.
    static let byID: [AchievementID: AchievementDefinition] = Dictionary(
        Self.all.map { ($0.id, $0) },
        // Two entries sharing an id is a catalog bug, pinned by
        // `AchievementCatalogTests.idsAreUnique`. Keeping the first rather
        // than trapping means the bug shows as a missing card, not a crash.
        uniquingKeysWith: { first, _ in first }
    )
}

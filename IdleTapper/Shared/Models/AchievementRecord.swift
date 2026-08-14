//
//  AchievementRecord.swift
//  Idle Tapper — SwiftData model
//
//  One row per *unlocked* achievement. Locked achievements have no row at
//  all — they are derived from `TapStats` by `AchievementCalculator` — so
//  writes only ever happen on the rare event of a new unlock.
//

import Foundation
import SwiftData

@Model
final class AchievementRecord {

    /// Raw value of the `AchievementID` this row records. Stored as a string
    /// so a store opened by an older build with fewer cases still reads.
    @Attribute(.unique) var id: String

    /// When this achievement was unlocked.
    var unlockedAt: Date

    init(id: String, unlockedAt: Date) {
        self.id = id
        self.unlockedAt = unlockedAt
    }
}

extension AchievementRecord {
    /// Value-type projection used by the calculation layer.
    ///
    /// `nil` when `id` no longer matches a known `AchievementID` — for
    /// example a row left behind by a build that shipped a case this one
    /// removed. Dropping it silently is the right call: it is a stale unlock,
    /// not user data worth surfacing an error over.
    var snapshot: AchievementSnapshot? {
        guard let achievementID = AchievementID(rawValue: id) else { return nil }
        return AchievementSnapshot(id: achievementID, unlockedAt: unlockedAt)
    }
}

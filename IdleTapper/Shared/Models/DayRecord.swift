//
//  DayRecord.swift
//  Idle Tapper — SwiftData model
//
//  One row per calendar day. `dayStart` is the midnight boundary of the local
//  day and is the record's identity, which is what makes the daily reset work:
//  a new day simply has no row yet, so its count starts at zero.
//

import Foundation
import SwiftData

/// Persisted tap total for a single local calendar day.
@Model
final class DayRecord {

    /// Midnight (local time) of the day this record covers.
    ///
    /// Unique so a day can never be double-inserted — for example when two
    /// increments race across the midnight boundary.
    @Attribute(.unique) var dayStart: Date

    /// Number of taps recorded on this day.
    var tapCount: Int

    /// When this record was first created.
    var createdAt: Date

    /// When this record was last incremented.
    var updatedAt: Date

    /// The daily goal in effect on this day, or `nil` when none was set.
    ///
    /// Stamped from the user's current setting whenever this day is written to.
    /// A tap only ever lands on *today*, so a past day's target is frozen the
    /// moment that day ends — which is the whole point. The streak asks whether
    /// each day met its goal, and if that question were answered against the
    /// live setting instead, raising the goal in Settings would silently rewrite
    /// every day in history and collapse a long streak with one keystroke.
    ///
    /// Optional, and not merely defaulted to zero, for two reasons. It is what
    /// keeps this a *lightweight* SwiftData migration (see
    /// `ModelContainerFactory.schema`), and it is what distinguishes "recorded
    /// before goals existed, or with the goal switched off" from "had a goal".
    /// Those days fall back to counting any tap at all, so nobody's existing
    /// streak changed the day this shipped.
    var goalTarget: Int?

    init(
        dayStart: Date,
        tapCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        goalTarget: Int? = nil
    ) {
        self.dayStart = dayStart
        self.tapCount = tapCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.goalTarget = goalTarget
    }
}

extension DayRecord {
    /// Value-type projection used by the calculation layer.
    ///
    /// Calculations never touch `@Model` instances: those are bound to a
    /// `ModelContext` and to the main actor, which would make the pure logic
    /// untestable in isolation.
    var snapshot: DaySnapshot {
        DaySnapshot(dayStart: dayStart, tapCount: tapCount, goalTarget: goalTarget)
    }
}

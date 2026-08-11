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

    init(
        dayStart: Date,
        tapCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.dayStart = dayStart
        self.tapCount = tapCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension DayRecord {
    /// Value-type projection used by the calculation layer.
    ///
    /// Calculations never touch `@Model` instances: those are bound to a
    /// `ModelContext` and to the main actor, which would make the pure logic
    /// untestable in isolation.
    var snapshot: DaySnapshot {
        DaySnapshot(dayStart: dayStart, tapCount: tapCount)
    }
}

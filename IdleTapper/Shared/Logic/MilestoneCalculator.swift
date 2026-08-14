//
//  MilestoneCalculator.swift
//  Idle Tapper — Calculations (pure)
//
//  Detects a round-number crossing within today's count. Distinct from
//  achievements: milestones are per-day and not persisted, so the same
//  number can be reached again on a later day.
//

import Foundation

enum MilestoneCalculator {

    /// Default spacing between milestones, in taps.
    static let defaultInterval = 100

    /// The highest multiple of `interval` crossed by moving from
    /// `previousCount` to `newCount`, or `nil` if none was crossed.
    ///
    /// Only ever returns the highest multiple in the jump — a burst of taps
    /// that spans several intervals at once fires one milestone, not several.
    /// An `interval` of zero or less disables milestones entirely rather than
    /// dividing by zero.
    static func crossed(from previousCount: Int, to newCount: Int, interval: Int) -> Int? {
        guard interval > 0, newCount > previousCount else { return nil }

        let highestMultiple = (newCount / interval) * interval
        guard highestMultiple > 0, highestMultiple > previousCount else { return nil }

        return highestMultiple
    }
}

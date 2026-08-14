//
//  MilestoneCalculatorTests.swift
//  IdleTapperTests
//

import Testing
@testable import IdleTapper

@Suite("Milestone calculator")
struct MilestoneCalculatorTests {

    @Test("No milestone fires below the interval")
    func noFireBelowInterval() {
        #expect(MilestoneCalculator.crossed(from: 0, to: 99, interval: 100) == nil)
    }

    @Test("A milestone fires exactly at the interval")
    func firesExactlyAtInterval() {
        #expect(MilestoneCalculator.crossed(from: 99, to: 100, interval: 100) == 100)
    }

    @Test("A jump spanning several intervals fires the highest one only")
    func jumpFiresHighestOnly() {
        // A burst of taps (or a big backfill) moving straight from 150 to 350
        // must not fire both 200 and 300 — only the higher one.
        #expect(MilestoneCalculator.crossed(from: 150, to: 350, interval: 100) == 300)
    }

    @Test("Re-reaching the same milestone does not fire again")
    func sameMilestoneDoesNotRefire() {
        // Nothing has moved past the last multiple already reached.
        #expect(MilestoneCalculator.crossed(from: 100, to: 150, interval: 100) == nil)
    }

    @Test("Crossing back to zero and up again reaches a new milestone")
    func dailyResetAllowsTheSameMilestoneAgain() {
        // Simulates the day rolling over: `previousCount` is 0 for the new
        // day, so reaching 100 again is a fresh crossing, not a repeat.
        #expect(MilestoneCalculator.crossed(from: 0, to: 100, interval: 100) == 100)
    }

    @Test("An interval of zero never fires")
    func zeroIntervalDisablesMilestones() {
        #expect(MilestoneCalculator.crossed(from: 0, to: 500, interval: 0) == nil)
    }

    @Test("A negative interval never fires")
    func negativeIntervalDisablesMilestones() {
        #expect(MilestoneCalculator.crossed(from: 0, to: 500, interval: -100) == nil)
    }

    @Test("A decrease (or no change) never fires")
    func noIncreaseNeverFires() {
        #expect(MilestoneCalculator.crossed(from: 100, to: 100, interval: 100) == nil)
        #expect(MilestoneCalculator.crossed(from: 100, to: 50, interval: 100) == nil)
    }
}

//
//  PressAnimationTimingTests.swift
//  IdleTapperTests
//
//  A soft trackpad tap lasts a few milliseconds. Without a minimum hold the
//  press animation is set and cleared inside one frame and never appears, which
//  is what made the button look unresponsive to anything but a hard click.
//

import Testing
import Foundation
@testable import IdleTapper

@Suite("Press animation timing")
struct PressAnimationTimingTests {

    @Test("A soft tap is held long enough to be seen")
    func softTapIsHeld() {
        // Roughly what a trackpad tap-to-click delivers.
        let hold = PressAnimationTiming.remainingHold(pressedFor: .milliseconds(3))

        #expect(hold > .zero, "A 3ms press must be extended or the animation never renders")
        #expect(hold == PressAnimationTiming.minimumVisibleDuration - .milliseconds(3))
    }

    @Test("An instantaneous press still gets the full hold")
    func zeroLengthPress() {
        let hold = PressAnimationTiming.remainingHold(pressedFor: .zero)
        #expect(hold == PressAnimationTiming.minimumVisibleDuration)
    }

    @Test("A press already long enough is released immediately")
    func longPressIsNotDelayed() {
        #expect(PressAnimationTiming.remainingHold(pressedFor: .milliseconds(500)) == .zero)
        #expect(
            PressAnimationTiming.remainingHold(
                pressedFor: PressAnimationTiming.minimumVisibleDuration
            ) == .zero,
            "Exactly the minimum needs no extra hold"
        )
    }

    @Test("The hold never exceeds the minimum, however brief the press")
    func holdIsBounded() {
        for microseconds in [0, 1, 100, 1_000, 50_000] {
            let hold = PressAnimationTiming.remainingHold(
                pressedFor: .microseconds(microseconds)
            )
            #expect(hold <= PressAnimationTiming.minimumVisibleDuration)
        }
    }

    // MARK: - Date-based Overload

    @Test("Timestamps produce the same result as durations")
    func timestampOverload() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = start.addingTimeInterval(0.005)

        let hold = PressAnimationTiming.remainingHold(pressedAt: start, now: end)

        #expect(hold > .zero)
        #expect(hold < PressAnimationTiming.minimumVisibleDuration)
    }

    @Test("A clock that jumps backwards mid-press still animates")
    func clockGoingBackwards() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = start.addingTimeInterval(-60)

        let hold = PressAnimationTiming.remainingHold(pressedAt: start, now: end)

        #expect(
            hold == PressAnimationTiming.minimumVisibleDuration,
            "A negative interval must not be read as a long press and skip the animation"
        )
    }
}

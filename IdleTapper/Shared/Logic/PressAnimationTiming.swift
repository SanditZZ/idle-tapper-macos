//
//  PressAnimationTiming.swift
//  Idle Tapper — Calculations (pure)
//
//  Keeps the tap button's press animation visible regardless of how briefly the
//  physical press lasted.
//
//  ## Why this is needed
//
//  A trackpad "tap to click" — a soft touch, not a hard press — delivers mouse
//  down and mouse up only a few milliseconds apart. Driving the animation
//  directly from the gesture means the pressed state is set and cleared within
//  a single frame, so the button never visibly moves: the tap registers, but
//  there is no feedback at all. A hard physical click holds the button down for
//  long enough that the animation happens to be seen, which is why the problem
//  looks like "it only works when I press hard".
//
//  The fix is to decouple the *visual* press from the *physical* one. The press
//  is held for a minimum duration, so a 3 ms tap and a 300 ms press produce the
//  same feedback.
//

import Foundation

/// Timing rules for the tap button's press feedback.
enum PressAnimationTiming {

    /// How long the pressed state must remain visible.
    ///
    /// Long enough for the spring to travel far enough to notice, short enough
    /// not to lag behind sustained fast tapping.
    static let minimumVisibleDuration: Duration = .milliseconds(110)

    /// How much longer the pressed state should be held after the physical
    /// press ends.
    ///
    /// Returns `.zero` when the press already lasted long enough, in which case
    /// the caller releases immediately.
    static func remainingHold(
        pressedFor elapsed: Duration,
        minimum: Duration = minimumVisibleDuration
    ) -> Duration {
        guard elapsed < minimum else { return .zero }
        return minimum - elapsed
    }

    /// Convenience for callers holding timestamps rather than a duration.
    ///
    /// A clock that has gone backwards — a manual time change mid-press —
    /// yields a negative interval, which is treated as "no time elapsed" so the
    /// full hold still applies rather than the animation being skipped.
    static func remainingHold(
        pressedAt start: Date,
        now: Date,
        minimum: Duration = minimumVisibleDuration
    ) -> Duration {
        let seconds = max(now.timeIntervalSince(start), 0)
        return remainingHold(pressedFor: .seconds(seconds), minimum: minimum)
    }
}

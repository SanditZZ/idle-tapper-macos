//
//  TapTracker+Goal.swift
//  Idle Tapper — Actions layer
//
//  Where the tap path meets the daily goal. Split out of `TapTracker.swift` for
//  the same reason the export was: that file is at the size this project splits
//  at, and this is a feature of its own.
//
//  Thin by design. The decisions belong to `GoalNotificationPlan`, which is
//  pure, and the side effects to `GoalTracker`, which owns the notification
//  centre. What is left here is the wiring: handing the tracker the two figures
//  it cannot see for itself — today's count and the streak at risk.
//

import Foundation

extension TapTracker {

    /// Bring the streak reminder into line with the state as of `date`.
    ///
    /// Called from `tap()` and from `refresh()`, and therefore from all four of
    /// the observers `refresh()` already backs: wake, day change, clock change
    /// and time-zone change. Every one of them is the same call, because
    /// `GoalTracker.reconcile` applies a desired state rather than performing an
    /// operation — there is no ordering to get wrong, and no cancel to pair
    /// with a reschedule.
    ///
    /// Safe on the hot path: a tap that does not change the plan costs one
    /// comparison of two value types and no I/O at all.
    ///
    /// `stats.currentStreak` is recomputed on a debounce and so may lag a tap by
    /// a few hundred milliseconds. That does not matter here. The streak only
    /// changes when a day first meets its goal, and what removes the reminder in
    /// that moment is `todayCount` — which is updated synchronously — meeting
    /// the target, not the streak figure.
    func reconcileGoal(at date: Date) {
        goals?.reconcile(
            todayCount: todayCount,
            currentStreak: stats.currentStreak,
            now: date
        )
    }

    /// Record a change to the daily goal against today, and re-evaluate.
    ///
    /// The goal is stamped onto a day when it is tapped, so a goal edited
    /// mid-morning would otherwise not reach today's record until the next tap —
    /// leaving the popover's ring measuring against the new target while the
    /// streak still judged today by the old one. This closes that window.
    ///
    /// Only ever touches today, and only a day that already has taps: a goal
    /// changed on a day with nothing recorded needs no row, and creating one
    /// would leave an empty day in the history.
    ///
    /// Never throws. A goal that fails to write is a cosmetic problem until the
    /// next tap, which stamps it again — not a reason to interrupt the game.
    func applyGoalChange(to goal: Int) {
        let date = now()

        do {
            try repository.setGoalTarget(GoalCalculator.normalized(goal), on: date)
            AppLog.goal.info("[Goal] Today's target updated to \(goal, privacy: .public)")
        } catch {
            lastErrorMessage = error.localizedDescription
            AppLog.goal.error(
                "[Goal] Could not record today's target: \(error.localizedDescription, privacy: .public)"
            )
        }

        // Refreshes rather than only reconciling: changing the goal changes
        // which past days met theirs, so the streak — and every achievement
        // reading it — has to be recomputed, not just the reminder.
        refresh()
    }
}

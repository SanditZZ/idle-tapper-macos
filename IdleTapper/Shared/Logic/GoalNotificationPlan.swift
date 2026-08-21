//
//  GoalNotificationPlan.swift
//  Idle Tapper — Calculations (pure)
//
//  Decides which notifications the goal feature wants to exist right now.
//
//  ## Why a plan rather than cancel-and-reschedule
//
//  The streak reminder has to be reconsidered whenever a tap lands, and again
//  on wake, on day change, on a clock change and on a time-zone change — the
//  same five moments the rest of the app already reacts to. Written as five
//  imperative cancel/reschedule sites, that is five chances to get the order
//  wrong and no way to test any of it without `UserNotifications` present.
//
//  Written as a *plan* — a pure function from the current state to the complete
//  set of notifications that should be pending — every one of those sites
//  becomes the same single call, applying the plan is idempotent, and the whole
//  decision surface is directly unit-testable. `GoalTracker` does the applying;
//  nothing in this file has an effect.
//
//  No timer appears anywhere here, and none may. "Today" is whichever day
//  contains the `now` that is passed in, exactly as everywhere else in the app.
//

import Foundation

enum GoalNotificationPlan {

    // MARK: - Identifiers

    /// Prefix shared by every notification this feature owns.
    ///
    /// Reconciliation removes pending requests by this prefix, so it must not
    /// match anything scheduled by another part of the app.
    static let identifierPrefix = "com.kkpon3.IdleTapper.goal"

    /// Identifier for the streak reminder belonging to a given day.
    ///
    /// Keyed to the day rather than fixed, so yesterday's reminder cannot be
    /// mistaken for today's: on a rollover the planned identifier changes, the
    /// stale one is no longer in the plan, and reconciliation drops it.
    static func reminderIdentifier(for date: Date, calendar: Calendar) -> String {
        "\(identifierPrefix).streakAtRisk.\(dayKey(for: date, calendar: calendar))"
    }

    /// Identifier for the goal-reached notification belonging to a given day.
    static func reachedIdentifier(for date: Date, calendar: Calendar) -> String {
        "\(identifierPrefix).reached.\(dayKey(for: date, calendar: calendar))"
    }

    /// `yyyy-MM-dd` for the day containing `date`, built from calendar
    /// components rather than a `DateFormatter`.
    ///
    /// A formatter would drag a locale in — and a non-Gregorian one would
    /// produce a different key for the same day, which is exactly the kind of
    /// thing that works everywhere it is tested and breaks for one user.
    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    // MARK: - The Plan

    /// The streak reminder that should currently be pending, if any.
    ///
    /// It exists only when all of the following hold, and reconciliation drops
    /// it the moment any stops holding:
    ///
    /// - the user has reminders switched on;
    /// - there is a streak to lose — one or more days already run up. With no
    ///   streak there is nothing at risk, and nagging someone who has not
    ///   started is how an app gets its notifications turned off for good;
    /// - today has not met its goal yet. Meeting it is what cancels the
    ///   reminder, and that falls out of the plan rather than needing its own
    ///   call site;
    /// - the reminder hour is still ahead of us today.
    ///
    /// - Parameters:
    ///   - todayCount: Taps recorded today so far.
    ///   - todayGoal: The goal in effect today; `0` or less means none is.
    ///   - currentStreak: `TapStats.currentStreak` — which, on a day that has
    ///     not met its goal, is the run of days up to and including yesterday.
    ///     That is precisely the number at risk.
    ///   - reminderHour: Local hour, `0...23`, the user chose.
    ///   - now: The instant treated as "now".
    static func streakAtRiskReminder(
        todayCount: Int,
        todayGoal: Int,
        currentStreak: Int,
        remindersEnabled: Bool,
        reminderHour: Int,
        now: Date,
        calendar: Calendar
    ) -> PlannedNotification? {
        guard remindersEnabled else { return nil }
        guard currentStreak >= 1 else { return nil }
        guard !GoalCalculator.metGoal(tapCount: todayCount, goalTarget: todayGoal) else { return nil }
        guard let fireDate = reminderFireDate(hour: reminderHour, now: now, calendar: calendar) else {
            return nil
        }

        return PlannedNotification(
            identifier: reminderIdentifier(for: now, calendar: calendar),
            title: streakAtRiskTitle(currentStreak: currentStreak),
            body: streakAtRiskBody(todayGoal: todayGoal),
            fireDate: fireDate
        )
    }

    /// When today's reminder should fire, or `nil` if it cannot.
    ///
    /// Built with `Calendar`, never by adding seconds — the hour of a day is
    /// not a fixed offset from its midnight on the two days a year that are 23
    /// or 25 hours long.
    ///
    /// **The same-day check is what makes "already passed" work, and it is not
    /// redundant.** `date(bySettingHour:)` searches *forward*: asked for 20:00
    /// at 22:30, it does not answer with a time earlier today, it answers with
    /// 20:00 tomorrow. Scheduling that under today's identifier would post a
    /// reminder a full day late, and one that today's own rollover would never
    /// clear. Rejecting it leaves today without a reminder, which is correct —
    /// the next day change plans a fresh one.
    ///
    /// A daylight-saving morning is handled by the same call rather than
    /// specially: with no 02:00 in existence, the forward search lands on the
    /// nearest real time that day, and firing an hour late beats not firing.
    static func reminderFireDate(hour: Int, now: Date, calendar: Calendar) -> Date? {
        guard (0...23).contains(hour) else { return nil }

        guard let fireDate = calendar.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: now
        ) else { return nil }

        guard calendar.isDate(fireDate, inSameDayAs: now) else { return nil }
        guard fireDate > now else { return nil }

        return fireDate
    }

    /// The notification announcing that today's goal has been met.
    ///
    /// Immediate: it marks a moment rather than waiting for one. Whether it is
    /// actually delivered is a separate question — see `GoalTracker`, which
    /// suppresses it while the popover the user just tapped in is on screen.
    static func goalReached(
        goal: Int,
        todayCount: Int,
        now: Date,
        calendar: Calendar
    ) -> PlannedNotification {
        PlannedNotification(
            identifier: reachedIdentifier(for: now, calendar: calendar),
            title: "Daily goal reached",
            body: "\(formatted(todayCount)) taps today — you hit your goal of \(formatted(goal)).",
            fireDate: nil
        )
    }

    // MARK: - Copy

    private static func streakAtRiskTitle(currentStreak: Int) -> String {
        "Your \(dayCount(currentStreak)) streak is at risk"
    }

    /// **Deliberately says nothing about how far through today the user is.**
    ///
    /// Two reasons, and the first is correctness rather than economy. This text
    /// is written when the reminder is *scheduled* — often at breakfast — and
    /// read when it is *delivered*, eight hours and several hundred taps later.
    /// "60 taps to go" would be a number that was true this morning, and the
    /// notification cannot rewrite itself in the meantime. What is left is
    /// self-correcting: if the goal is met the whole reminder is withdrawn, so
    /// it can only ever be delivered while still true.
    ///
    /// The second reason follows from it. Everything here depends only on
    /// figures that hold steady for the rest of the day, so the plan is
    /// unchanged by an ordinary tap — which is what lets `GoalTracker` skip the
    /// notification centre entirely on the hot path instead of rescheduling
    /// hundreds of times an evening.
    private static func streakAtRiskBody(todayGoal: Int) -> String {
        guard let target = GoalCalculator.normalized(todayGoal) else {
            return "You have not tapped today. Tap once before midnight to keep it going."
        }

        return "Today's goal of \(formatted(target)) taps is still open. There is time before midnight."
    }

    /// "1 day" / "7 days". Hand-rolled, as `StatsCalculator.dayCountText`
    /// already is, and with the same caveat: this cannot be right for a
    /// language with more than two plural forms, and becomes a catalog plural
    /// variation when the app is localized.
    private static func dayCount(_ value: Int) -> String {
        value == 1 ? "1-day" : "\(formatted(value))-day"
    }

    /// Grouped for legibility — "1,250", not "1250". Spelled the same way as
    /// `StatsCalculator.dayCountText` and `SparklineSummary`, which already
    /// format their own copy in this layer.
    private static func formatted(_ value: Int) -> String {
        value.formatted()
    }
}

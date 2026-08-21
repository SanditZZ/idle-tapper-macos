//
//  GoalNotificationPlanTests.swift
//  IdleTapperTests
//
//  The scheduling decision, which is the whole of this feature. Every one of
//  these runs against a pinned clock and an explicit calendar: a reminder is a
//  statement about a local wall-clock hour, so a test that took the machine's
//  time zone would pass here and be wrong for whoever ran it next.
//

import Testing
import Foundation
@testable import IdleTapper

@Suite("Goal notification plan")
struct GoalNotificationPlanTests {

    private let calendar = TestSupport.utcCalendar

    /// Midday, so a reminder hour of 20:00 is still ahead.
    private var noon: Date {
        TestSupport.date(2026, 3, 10, 12, 0, calendar: calendar)
    }

    private func reminder(
        todayCount: Int = 0,
        todayGoal: Int = 100,
        currentStreak: Int = 5,
        remindersEnabled: Bool = true,
        reminderHour: Int = 20,
        now: Date? = nil,
        calendar: Calendar? = nil
    ) -> PlannedNotification? {
        GoalNotificationPlan.streakAtRiskReminder(
            todayCount: todayCount,
            todayGoal: todayGoal,
            currentStreak: currentStreak,
            remindersEnabled: remindersEnabled,
            reminderHour: reminderHour,
            now: now ?? noon,
            calendar: calendar ?? self.calendar
        )
    }

    // MARK: - When a Reminder Exists

    @Test("A streak at risk earns a reminder at the chosen hour")
    func remindsWhenAtRisk() throws {
        let plan = try #require(reminder())
        #expect(plan.fireDate == TestSupport.date(2026, 3, 10, 20, 0, calendar: calendar))
    }

    @Test("Meeting the goal is what cancels the reminder")
    func noReminderOnceMet() {
        #expect(reminder(todayCount: 100, todayGoal: 100) == nil)
    }

    @Test("One tap short of the goal is still at risk")
    func stillAtRiskOneShort() {
        #expect(reminder(todayCount: 99, todayGoal: 100) != nil)
    }

    /// With no goal set the streak still exists — any tap keeps it — so the
    /// reminder has to follow that same rule rather than the target.
    @Test("With the goal off, a single tap is enough to cancel the reminder")
    func goalOffFollowsTheAnyTapRule() {
        #expect(reminder(todayCount: 0, todayGoal: 0) != nil)
        #expect(reminder(todayCount: 1, todayGoal: 0) == nil)
    }

    @Test("Nothing is scheduled with reminders switched off")
    func respectsThePreference() {
        #expect(reminder(remindersEnabled: false) == nil)
    }

    /// Nagging someone who has not started is how an app gets its notifications
    /// switched off for good.
    @Test("No streak means nothing is at risk")
    func noReminderWithoutAStreak() {
        #expect(reminder(currentStreak: 0) == nil)
        #expect(reminder(currentStreak: 1) != nil)
    }

    // MARK: - The Hour

    /// The case a naive implementation gets wrong. `date(bySettingHour:)`
    /// searches *forward*, so asked for 20:00 at 22:30 it answers with 20:00
    /// **tomorrow** — which, scheduled under today's identifier, would fire a
    /// day late and never be cleared by today's rollover.
    @Test("An hour that has already passed schedules nothing, not tomorrow")
    func hourAlreadyPassed() {
        let evening = TestSupport.date(2026, 3, 10, 22, 30, calendar: calendar)
        #expect(reminder(reminderHour: 20, now: evening) == nil)
    }

    @Test("A reminder set for the current hour still counts as passed")
    func withinTheHour() {
        // 20:30 is inside hour 20, but 20:00 itself is behind us.
        let justAfter = TestSupport.date(2026, 3, 10, 20, 30, calendar: calendar)
        #expect(reminder(reminderHour: 20, now: justAfter) == nil)
    }

    @Test("An impossible hour schedules nothing")
    func invalidHour() {
        #expect(reminder(reminderHour: 24) == nil)
        #expect(reminder(reminderHour: -1) == nil)
    }

    /// A reminder is a wall-clock time, so it has to survive the two days a
    /// year that are not 24 hours long. On 8 March 2026 New York springs
    /// forward and 02:00 never happens; the evening hour is unaffected and must
    /// still land on that same local day.
    @Test("A daylight saving morning does not move the evening reminder")
    func daylightSavingDay() throws {
        let newYork = TestSupport.newYorkCalendar
        let springForward = TestSupport.date(2026, 3, 8, 9, 0, calendar: newYork)

        let plan = try #require(
            reminder(reminderHour: 20, now: springForward, calendar: newYork)
        )
        let fireDate = try #require(plan.fireDate)

        #expect(newYork.component(.hour, from: fireDate) == 20)
        #expect(newYork.isDate(fireDate, inSameDayAs: springForward))
    }

    // MARK: - Identifiers

    /// What makes reconciliation drop a stale reminder without having to
    /// remember it: yesterday's identifier simply is not in today's plan.
    @Test("The identifier changes when the day does")
    func identifierIsKeyedToTheDay() {
        let today = GoalNotificationPlan.reminderIdentifier(for: noon, calendar: calendar)
        let tomorrow = GoalNotificationPlan.reminderIdentifier(
            for: TestSupport.date(2026, 3, 11, 12, 0, calendar: calendar),
            calendar: calendar
        )

        #expect(today != tomorrow)
        #expect(today.hasPrefix(GoalNotificationPlan.identifierPrefix))
    }

    @Test("Two moments on the same day share an identifier")
    func identifierIsStableWithinADay() {
        let morning = TestSupport.date(2026, 3, 10, 7, 0, calendar: calendar)
        let evening = TestSupport.date(2026, 3, 10, 23, 0, calendar: calendar)

        #expect(
            GoalNotificationPlan.reminderIdentifier(for: morning, calendar: calendar)
                == GoalNotificationPlan.reminderIdentifier(for: evening, calendar: calendar)
        )
    }

    @Test("A day key is zero-padded so it sorts and compares as written")
    func dayKeyFormat() {
        let january = TestSupport.date(2026, 1, 5, 12, 0, calendar: calendar)
        #expect(GoalNotificationPlan.dayKey(for: january, calendar: calendar) == "2026-01-05")
    }

    @Test("The reminder and the goal-reached notification never collide")
    func distinctIdentifiers() {
        #expect(
            GoalNotificationPlan.reminderIdentifier(for: noon, calendar: calendar)
                != GoalNotificationPlan.reachedIdentifier(for: noon, calendar: calendar)
        )
    }

    // MARK: - Content

    @Test("The reminder names the streak at risk and the target")
    func contentNamesTheStakes() throws {
        let plan = try #require(reminder(todayCount: 40, todayGoal: 100))
        #expect(plan.title.contains("5"))
        #expect(plan.body.contains("100"))
    }

    /// The reminder is written hours before it is delivered, so its text may
    /// not depend on a number that moves in between. Two very different
    /// progress readings on the same day must produce the identical request —
    /// which is also what lets a tap skip the notification centre entirely.
    @Test("The reminder does not change as the day's count climbs")
    func contentIsStableAcrossTaps() throws {
        let early = try #require(reminder(todayCount: 1, todayGoal: 100))
        let late = try #require(reminder(todayCount: 99, todayGoal: 100))

        #expect(early == late)
    }

    @Test("The goal-reached notification is delivered rather than scheduled")
    func reachedIsImmediate() {
        let reached = GoalNotificationPlan.goalReached(
            goal: 100,
            todayCount: 100,
            now: noon,
            calendar: calendar
        )
        #expect(reached.isImmediate)
        #expect(reached.fireDate == nil)
    }
}

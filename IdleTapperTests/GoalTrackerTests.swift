//
//  GoalTrackerTests.swift
//  IdleTapperTests
//
//  The bookkeeping the issue called the whole feature: keeping exactly the
//  right reminder scheduled as taps land, days roll over and permission
//  changes — without the notification centre ever being touched needlessly.
//
//  All of it runs against `TestSupport.FakeNotificationScheduler`, so nothing
//  here reaches `UNUserNotificationCenter` or prompts whoever is running the
//  suite for permission.
//

import Testing
import Foundation
@testable import IdleTapper

@Suite("Goal tracker")
@MainActor
struct GoalTrackerTests {

    private let calendar = TestSupport.utcCalendar

    private var noon: Date {
        TestSupport.date(2026, 3, 10, 12, 0, calendar: calendar)
    }

    /// A tracker with the goal on, reminders on, and permission granted.
    private func makeTracker(
        goal: Int = 100,
        remindersEnabled: Bool = true,
        reminderHour: Int = 20,
        authorization: NotificationAuthorization = .authorized
    ) -> (GoalTracker, TestSupport.FakeNotificationScheduler, AppSettings, UserDefaults) {
        let defaults = TestSupport.scratchDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.dailyGoal = goal
        settings.goalRemindersEnabled = remindersEnabled
        settings.goalReminderHour = reminderHour

        let scheduler = TestSupport.FakeNotificationScheduler()
        scheduler.authorization = authorization

        let tracker = TestSupport.makeGoalTracker(
            scheduler: scheduler,
            settings: settings,
            calendar: calendar
        )

        return (tracker, scheduler, settings, defaults)
    }

    // MARK: - Scheduling

    @Test("A streak at risk gets exactly one reminder scheduled")
    func schedulesOneReminder() async {
        let (tracker, scheduler, _, defaults) = makeTracker()
        defer { TestSupport.removeScratchDefaults(defaults) }

        tracker.reconcile(todayCount: 0, currentStreak: 5, now: noon)
        await tracker.settle()

        #expect(scheduler.pendingReminders.count == 1)
    }

    /// The claim that reconciliation is safe on the hot path. Five hundred taps
    /// that do not change the plan must not produce five hundred round trips to
    /// the notification database — the whole reason the applied plan is
    /// remembered and compared before anything is applied.
    @Test("A burst of tapping touches the notification centre once")
    func tappingDoesNotRescheduleRepeatedly() async {
        let (tracker, scheduler, _, defaults) = makeTracker(goal: 100_000)
        defer { TestSupport.removeScratchDefaults(defaults) }

        for count in 1...500 {
            tracker.reconcile(todayCount: count, currentStreak: 5, now: noon)
        }
        await tracker.settle()

        #expect(scheduler.added.count == 1)
        #expect(scheduler.pendingReminders.count == 1)
        #expect(scheduler.statusChecks == 1)
    }

    @Test("Meeting the goal withdraws the reminder")
    func meetingTheGoalWithdrawsIt() async {
        let (tracker, scheduler, _, defaults) = makeTracker(goal: 100)
        defer { TestSupport.removeScratchDefaults(defaults) }

        tracker.reconcile(todayCount: 99, currentStreak: 5, now: noon)
        await tracker.settle()
        #expect(scheduler.pendingReminders.count == 1)

        tracker.reconcile(todayCount: 100, currentStreak: 6, now: noon)
        await tracker.settle()

        #expect(scheduler.pendingReminders.isEmpty)
    }

    @Test("Switching reminders off withdraws what was already scheduled")
    func switchingOffWithdrawsIt() async {
        let (tracker, scheduler, settings, defaults) = makeTracker()
        defer { TestSupport.removeScratchDefaults(defaults) }

        tracker.reconcile(todayCount: 0, currentStreak: 5, now: noon)
        await tracker.settle()
        #expect(scheduler.pendingReminders.count == 1)

        settings.goalRemindersEnabled = false
        tracker.reconcile(todayCount: 0, currentStreak: 5, now: noon)
        await tracker.settle()

        #expect(scheduler.pendingReminders.isEmpty)
    }

    /// A reminder scheduled yesterday is still pending when the app launches
    /// today, under an identifier today's plan will never mention. The first
    /// reconciliation of a launch sweeps by prefix for exactly this reason.
    @Test("A reminder left over from a previous launch is swept")
    func sweepsStaleRequestsOnFirstApply() async {
        let (tracker, scheduler, _, defaults) = makeTracker()
        defer { TestSupport.removeScratchDefaults(defaults) }

        let yesterday = GoalNotificationPlan.reminderIdentifier(
            for: TestSupport.date(2026, 3, 9, 12, 0, calendar: calendar),
            calendar: calendar
        )
        scheduler.preexisting = [yesterday]

        tracker.reconcile(todayCount: 0, currentStreak: 5, now: noon)
        await tracker.settle()

        #expect(scheduler.removed.contains(yesterday))
        #expect(!scheduler.scheduled.keys.contains(yesterday))
        #expect(scheduler.pendingReminders.count == 1)
    }

    /// The day rolled over while the app was running. The reminder for the old
    /// day has to go, and today's has to replace it — with no explicit cancel
    /// anywhere, because the old identifier simply is not in the new plan.
    @Test("A day rollover replaces the reminder rather than stacking one")
    func rolloverReplacesTheReminder() async throws {
        let (tracker, scheduler, _, defaults) = makeTracker()
        defer { TestSupport.removeScratchDefaults(defaults) }

        tracker.reconcile(todayCount: 0, currentStreak: 5, now: noon)
        await tracker.settle()
        let first = try #require(scheduler.pendingReminders.first).identifier

        let tomorrow = TestSupport.date(2026, 3, 11, 12, 0, calendar: calendar)
        tracker.reconcile(todayCount: 0, currentStreak: 5, now: tomorrow)
        await tracker.settle()

        #expect(scheduler.pendingReminders.count == 1)
        #expect(scheduler.pendingReminders.first?.identifier != first)
        #expect(scheduler.removed.contains(first))
    }

    // MARK: - Permission

    /// A refusal must cost the reminder and nothing else. The goal keeps
    /// working — this asserts the tracker does not throw, does not disable the
    /// preference, and simply schedules nothing.
    @Test("Refused permission schedules nothing and leaves the goal alone")
    func deniedAuthorization() async {
        let (tracker, scheduler, settings, defaults) = makeTracker(authorization: .denied)
        defer { TestSupport.removeScratchDefaults(defaults) }

        tracker.reconcile(todayCount: 0, currentStreak: 5, now: noon)
        await tracker.settle()

        #expect(scheduler.added.isEmpty)
        #expect(tracker.authorization == .denied)
        // The user's preference is untouched, so granting permission later in
        // System Settings needs no second visit to ours.
        #expect(settings.goalRemindersEnabled)
        #expect(settings.dailyGoal == 100)
    }

    @Test("An unauthorized app does not retry on every single tap")
    func deniedDoesNotRetryPerTap() async {
        let (tracker, scheduler, _, defaults) = makeTracker(
            goal: 100_000,
            authorization: .denied
        )
        defer { TestSupport.removeScratchDefaults(defaults) }

        for count in 1...200 {
            tracker.reconcile(todayCount: count, currentStreak: 5, now: noon)
        }
        await tracker.settle()

        #expect(scheduler.added.isEmpty)
        // The point of the test. `added` would be empty however many times a
        // refused app tried, so what is actually asserted is that it stopped
        // trying — the plan it decided on is remembered even though nothing
        // could be scheduled from it.
        #expect(scheduler.statusChecks == 1)
    }

    @Test("Permission is never requested without being asked for")
    func doesNotPromptOnItsOwn() async {
        let (tracker, scheduler, _, defaults) = makeTracker(authorization: .notDetermined)
        defer { TestSupport.removeScratchDefaults(defaults) }

        tracker.reconcile(todayCount: 0, currentStreak: 5, now: noon)
        await tracker.settle()

        // Reading the status is fine; prompting is not. A permission dialog
        // must only ever follow the user switching reminders on.
        #expect(scheduler.authorizationRequests == 0)
        #expect(scheduler.added.isEmpty)
    }

    // MARK: - Celebration

    @Test("Reaching the goal celebrates once, not on every tap after it")
    func celebratesOncePerDay() {
        let (tracker, _, _, defaults) = makeTracker(goal: 100)
        defer { TestSupport.removeScratchDefaults(defaults) }

        tracker.recordTap(previousCount: 99, newCount: 100, at: noon)
        #expect(tracker.activeCelebration == 100)

        tracker.recordTap(previousCount: 100, newCount: 101, at: noon)
        #expect(tracker.activeCelebration == 100)
    }

    /// Asserted through the delivered notifications rather than through
    /// `activeCelebration`, which still reads 100 from yesterday and would let
    /// this pass with the re-arm removed entirely. Two deliveries under two
    /// different day identifiers is the thing that can only happen if the
    /// once-per-day guard reset.
    @Test("A new day re-arms the celebration")
    func rearmsOnANewDay() async {
        let (tracker, scheduler, _, defaults) = makeTracker(goal: 100)
        defer { TestSupport.removeScratchDefaults(defaults) }

        tracker.recordTap(previousCount: 99, newCount: 100, at: noon)

        let tomorrow = TestSupport.date(2026, 3, 11, 12, 0, calendar: calendar)
        tracker.recordTap(previousCount: 99, newCount: 100, at: tomorrow)
        await tracker.settle()

        #expect(Set(scheduler.delivered.map(\.identifier)).count == 2)
    }

    /// The counterpart: within one day, the same crossing must not be
    /// celebrated twice even if the count somehow crosses again.
    @Test("Crossing the goal twice in one day delivers one notification")
    func oneNotificationPerDay() async {
        let (tracker, scheduler, _, defaults) = makeTracker(goal: 100)
        defer { TestSupport.removeScratchDefaults(defaults) }

        tracker.recordTap(previousCount: 99, newCount: 100, at: noon)
        tracker.recordTap(previousCount: 99, newCount: 100, at: noon)
        await tracker.settle()

        #expect(scheduler.delivered.count == 1)
    }

    @Test("Nothing is celebrated when the goal is off")
    func noCelebrationWithoutAGoal() {
        let (tracker, scheduler, _, defaults) = makeTracker(goal: 0)
        defer { TestSupport.removeScratchDefaults(defaults) }

        tracker.recordTap(previousCount: 999, newCount: 1_000, at: noon)

        #expect(tracker.activeCelebration == nil)
        #expect(scheduler.delivered.isEmpty)
    }

    /// The goal can only be reached by tapping, and the tap button lives in the
    /// popover — so with it open the notification would be announcing the very
    /// burst the user is watching.
    @Test("The goal-reached notification is suppressed while the popover is open")
    func suppressesTheNotificationBehindThePopover() async {
        let (tracker, scheduler, _, defaults) = makeTracker(goal: 100)
        defer { TestSupport.removeScratchDefaults(defaults) }

        tracker.setPopoverVisible(true)
        tracker.recordTap(previousCount: 99, newCount: 100, at: noon)
        await Task.yield()

        #expect(scheduler.delivered.isEmpty)
        // The in-app celebration is not suppressed — only the notification is.
        #expect(tracker.activeCelebration == 100)
    }

    @Test("With the popover closed the goal-reached notification is delivered")
    func deliversTheNotificationWhenUnseen() async {
        let (tracker, scheduler, _, defaults) = makeTracker(goal: 100)
        defer { TestSupport.removeScratchDefaults(defaults) }

        tracker.setPopoverVisible(false)
        tracker.recordTap(previousCount: 99, newCount: 100, at: noon)
        await tracker.settle()

        #expect(scheduler.delivered.count == 1)
        #expect(scheduler.delivered.first?.isImmediate == true)
    }

    @Test("A refused app posts no goal-reached notification but still celebrates")
    func deniedStillCelebrates() async {
        let (tracker, scheduler, _, defaults) = makeTracker(
            goal: 100,
            authorization: .denied
        )
        defer { TestSupport.removeScratchDefaults(defaults) }

        tracker.recordTap(previousCount: 99, newCount: 100, at: noon)
        await tracker.settle()

        #expect(scheduler.delivered.isEmpty)
        #expect(tracker.activeCelebration == 100)
    }
}

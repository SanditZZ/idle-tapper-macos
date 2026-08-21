//
//  GoalTracker.swift
//  Idle Tapper — Actions layer
//
//  Everything the daily goal *does*: celebrating the moment it is reached, and
//  keeping the streak reminder in step with reality.
//
//  Held apart from `TapTracker` rather than folded into it. `TapTracker` was
//  already at the size this project splits at, and the two have almost nothing
//  in common — the goal writes no history, reads no repository, and its whole
//  job is scheduling. `TapTracker` calls two methods here and knows nothing
//  else about it.
//
//  ## Reconciliation, not cancel-and-reschedule
//
//  `reconcile` is called from five places — a tap, and the four observers
//  `TapTracker` already registers for wake, day change, clock change and
//  time-zone change. It is safe to call at any of them, in any order, any
//  number of times, because it applies a *desired state* computed by
//  `GoalNotificationPlan` rather than performing an operation. That is the
//  whole design: there is no sequence to get wrong.
//
//  Nothing here uses a timer, and nothing may. The reminder is a
//  `UNCalendarNotificationTrigger`, and "today" is whichever day contains the
//  `now` it is handed.
//

import Foundation
import Observation

@MainActor
@Observable
final class GoalTracker {

    // MARK: - Published Data

    /// The goal just reached today, for a transient popover banner and burst.
    /// Clears itself after `bannerDuration`, exactly as a milestone does.
    private(set) var activeCelebration: Int?

    /// Whether the app may post notifications, as last read.
    ///
    /// Surfaced so Settings can explain a refused prompt rather than leaving a
    /// switch that appears to work and silently does nothing. **A refusal never
    /// disables the goal** — progress, the celebration and the streak rule are
    /// all in-app and unaffected.
    private(set) var authorization: NotificationAuthorization = .notDetermined

    /// Human-readable description of the last scheduling failure, or `nil`.
    private(set) var lastErrorMessage: String?

    // MARK: - Dependencies

    @ObservationIgnored private let scheduler: any NotificationScheduling
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let bannerDuration: Duration

    // MARK: - State

    /// The last plan this tracker acted on, and whether it has acted at all yet
    /// this launch.
    ///
    /// This pair is what keeps reconciliation off the hot path. A tap that does
    /// not change the plan — which is all but one tap a day — compares two
    /// value types and returns, touching no notification centre and awaiting
    /// nothing. Without it, a fast tapper would issue an async round trip to
    /// the notification database per tap.
    ///
    /// **Deliberately the plan that was decided, not the request that ended up
    /// scheduled.** The two differ whenever a plan cannot be carried out — a
    /// refused permission, most often — and remembering only what was scheduled
    /// would leave an unauthorized app comparing a live plan against `nil` and
    /// retrying the whole round trip on every single tap, which is exactly the
    /// cost this exists to avoid. Permission changing is what re-arms it, via
    /// `requestAuthorization` and `refreshAuthorization`.
    @ObservationIgnored private var lastPlan: PlannedNotification?
    @ObservationIgnored private var hasApplied = false

    /// The reminder actually pending, as far as this launch knows. Used only to
    /// work out what to withdraw when the plan moves on.
    @ObservationIgnored private var appliedReminder: PlannedNotification?

    /// Serialises applications so two reconciliations cannot interleave and
    /// leave the centre holding the older plan. Chained rather than cancelled:
    /// cancelling mid-apply is what would leave a half-applied state behind.
    @ObservationIgnored private var applyTask: Task<Void, Never>?

    /// The day whose goal has already been celebrated, so crossing the line
    /// fires once and a rollover re-arms it — the same shape as
    /// `TapTracker.lastMilestoneDay`.
    @ObservationIgnored private var lastCelebratedDay: Date?

    @ObservationIgnored private var pendingCelebrationClear: Task<Void, Never>?

    /// Whether the popover is on screen.
    ///
    /// The goal can only be reached by tapping, and the tap button lives in the
    /// popover — so the "goal reached" notification would otherwise fire while
    /// the user is looking at the burst that celebrates the same event. Set by
    /// `MenuBarController` as the popover opens and closes.
    @ObservationIgnored private var isPopoverVisible = false

    // MARK: - Lifecycle

    init(
        scheduler: any NotificationScheduling,
        settings: AppSettings,
        calendar: Calendar = .current,
        bannerDuration: Duration = .seconds(4)
    ) {
        self.scheduler = scheduler
        self.settings = settings
        self.calendar = calendar
        self.bannerDuration = bannerDuration
    }

    deinit {
        applyTask?.cancel()
        pendingCelebrationClear?.cancel()
    }

    // MARK: - Actions

    /// Tell the tracker the popover's visibility changed.
    func setPopoverVisible(_ visible: Bool) {
        isPopoverVisible = visible
    }

    /// Note a tap, and celebrate if it was the one that met the goal.
    ///
    /// - Parameters:
    ///   - previousCount: Today's count before the tap.
    ///   - newCount: Today's count after it.
    ///   - date: When the tap happened.
    func recordTap(previousCount: Int, newCount: Int, at date: Date) {
        let goal = GoalCalculator.normalized(settings.dailyGoal)
        guard let goal else { return }

        guard GoalCalculator.crossed(from: previousCount, to: newCount, goal: goal) else { return }

        let dayStart = DayBoundary.dayStart(for: date, calendar: calendar)
        guard lastCelebratedDay != dayStart else { return }
        lastCelebratedDay = dayStart

        celebrate(goal)
        deliverGoalReached(goal: goal, todayCount: newCount, at: date)

        AppLog.goal.info("[Goal] Daily goal of \(goal, privacy: .public) reached")
    }

    /// Bring the scheduled reminder into line with the current state.
    ///
    /// Cheap and safe to call from anywhere, including on every tap: when the
    /// plan has not changed this returns without any I/O at all.
    ///
    /// - Parameters:
    ///   - todayCount: Taps recorded today.
    ///   - currentStreak: `TapStats.currentStreak` — the run at risk.
    ///   - now: The instant treated as "now".
    func reconcile(todayCount: Int, currentStreak: Int, now: Date) {
        let plan = GoalNotificationPlan.streakAtRiskReminder(
            todayCount: todayCount,
            todayGoal: settings.dailyGoal,
            currentStreak: currentStreak,
            remindersEnabled: settings.goalRemindersEnabled,
            reminderHour: settings.goalReminderHour,
            now: now,
            calendar: calendar
        )

        guard !hasApplied || plan != lastPlan else { return }

        enqueue { tracker in
            await tracker.apply(plan)
        }
    }

    /// Run `work` after any scheduling already in flight.
    ///
    /// Every touch of the notification centre goes through here, so two of them
    /// cannot interleave and leave it holding the older plan. Chained rather
    /// than cancelled: cancelling mid-apply is what would leave a half-applied
    /// state behind.
    private func enqueue(_ work: @escaping @MainActor (GoalTracker) async -> Void) {
        let previous = applyTask
        applyTask = Task { @MainActor [weak self] in
            _ = await previous?.value
            guard let self else { return }
            await work(self)
        }
    }

    /// Read the authorization state without prompting, for Settings.
    func refreshAuthorization() {
        enqueue { tracker in
            let status = await tracker.scheduler.authorizationStatus()
            guard status != tracker.authorization else { return }

            tracker.authorization = status
            // Permission granted in System Settings while the app was running
            // is the one way the answer changes without us asking. Re-arm, so
            // the next reconciliation actually schedules rather than believing
            // the current plan was already dealt with.
            tracker.hasApplied = false
        }
    }

    /// Ask for permission, for the moment the user switches reminders on.
    ///
    /// A refusal is recorded and surfaced, and changes nothing else: the goal
    /// keeps working, and the preference stays as the user set it so that
    /// granting permission later in System Settings needs no second visit here.
    func requestAuthorization(todayCount: Int, currentStreak: Int, now: Date) {
        // A plain task, **not** `enqueue`. This ends by calling `reconcile`,
        // which enqueues — and an enqueued task that enqueues would chain onto
        // itself and await its own completion, which never arrives. The prompt
        // also has no business queueing behind scheduling work.
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorization = await self.scheduler.requestAuthorization()

            if self.authorization == .denied {
                AppLog.goal.info("[Goal] Notification permission refused — reminders will not be posted")
            }

            // Whatever the answer, the plan may now be schedulable (or not),
            // so re-apply rather than waiting for the next tap.
            self.hasApplied = false
            self.reconcile(todayCount: todayCount, currentStreak: currentStreak, now: now)
        }
    }

    /// Wait for any in-flight reconciliation to finish.
    ///
    /// Exists for tests. Reconciliation is fire-and-forget by design — a tap
    /// must never await the notification centre — which leaves a caller with
    /// nothing to join. Awaiting the latest application awaits all of them,
    /// because each one chains onto its predecessor. Nothing in the app calls
    /// this.
    func settle() async {
        await applyTask?.value
    }

    // MARK: - Applying

    /// Make the notification centre hold exactly `plan` and nothing else of
    /// ours.
    ///
    /// The first application of a launch sweeps every pending request carrying
    /// this feature's prefix, which is what clears a reminder left behind by a
    /// previous run — yesterday's, most often, since its identifier is keyed to
    /// a day that has passed. Later applications only have to undo what this
    /// launch itself scheduled.
    private func apply(_ plan: PlannedNotification?) async {
        let isFirstApply = !hasApplied
        let authorization = await scheduler.authorizationStatus()
        self.authorization = authorization

        var stale: [String] = []

        if isFirstApply {
            // Nothing is known about what a previous launch left behind, so
            // sweep by prefix. This is what clears yesterday's reminder, whose
            // identifier names a day that has passed.
            let pending = await scheduler.pendingIdentifiers(
                withPrefix: GoalNotificationPlan.identifierPrefix
            )
            stale = pending.filter { $0 != plan?.identifier }
        } else if let applied = appliedReminder, applied.identifier != plan?.identifier {
            stale = [applied.identifier]
        }

        scheduler.removeIdentifiers(stale)

        lastPlan = plan
        hasApplied = true

        // Nothing to schedule, or nowhere to schedule it.
        guard let plan, authorization == .authorized else {
            appliedReminder = nil
            return
        }

        do {
            try await scheduler.add(plan)
            appliedReminder = plan
            lastErrorMessage = nil
            AppLog.goal.debug("[Goal] Streak reminder scheduled")
        } catch {
            // Re-armed on purpose, so the next reconciliation retries rather
            // than believing a reminder is in place that is not.
            appliedReminder = nil
            hasApplied = false
            lastErrorMessage = error.localizedDescription
            AppLog.goal.error(
                "[Goal] Could not schedule the streak reminder: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Celebration

    private func celebrate(_ goal: Int) {
        activeCelebration = goal
        pendingCelebrationClear?.cancel()
        pendingCelebrationClear = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.bannerDuration)
            guard !Task.isCancelled else { return }
            self.activeCelebration = nil
        }
    }

    /// Post the "goal reached" notification, unless the user is already looking
    /// at the celebration.
    private func deliverGoalReached(goal: Int, todayCount: Int, at date: Date) {
        guard !isPopoverVisible else {
            AppLog.goal.debug("[Goal] Goal-reached notification suppressed — the popover is open")
            return
        }

        let notification = GoalNotificationPlan.goalReached(
            goal: goal,
            todayCount: todayCount,
            now: date,
            calendar: calendar
        )

        enqueue { tracker in
            guard await tracker.scheduler.authorizationStatus() == .authorized else { return }
            do {
                try await tracker.scheduler.add(notification)
            } catch {
                AppLog.goal.error(
                    "[Goal] Could not post the goal-reached notification: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}

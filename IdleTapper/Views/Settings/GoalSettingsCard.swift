//
//  GoalSettingsCard.swift
//  Idle Tapper — Settings ▸ General ▸ Daily goal
//
//  Its own file rather than another card inside `GeneralSettingsPage`: the goal
//  is four related controls that reveal one another, plus a permission state to
//  explain, which is more than a page of plain switches should carry inline.
//
//  Presentational, like every view here. The arithmetic is `GoalCalculator`'s
//  and the writing is `TapTracker`'s — this decides only what is on screen.
//

import SwiftUI
import AppKit

/// Sets the daily target and the streak reminder.
struct GoalSettingsCard: View {

    @Bindable var settings: AppSettings
    @Bindable var tracker: TapTracker

    /// The target being edited.
    ///
    /// Held apart from `settings.dailyGoal` because committing on every
    /// keystroke would mean a repository write and a full history refresh per
    /// character typed — and would fight the user, since "5" is a legal goal on
    /// the way to typing "500". Committed on submit and on each stepper press.
    @State private var draftGoal: Int = GoalCalculator.defaultGoal

    private var isGoalOn: Bool { settings.dailyGoal > 0 }

    var body: some View {
        SettingsCard(
            title: "Daily goal",
            footer: footer
        ) {
            SettingToggle(
                "Set a daily goal",
                description: "A target for today, shown as a ring around the counter. While a goal is set, a day counts toward your streak once it reaches the target.",
                isOn: Binding(get: { isGoalOn }, set: setGoalEnabled)
            )

            if isGoalOn {
                AppDivider()
                targetRow
                AppDivider()
                reminderControls
            }
        }
        // The user may have changed notification permission in System Settings
        // since this window was last open, so it is re-read rather than trusted.
        .task {
            draftGoal = max(settings.dailyGoal, GoalCalculator.bounds.lowerBound)
            tracker.goals?.refreshAuthorization()
        }
    }

    // MARK: - Rows

    private var targetRow: some View {
        SettingRow(
            "Taps per day",
            description: "Changing this affects today onwards. Days already recorded keep the goal they were set against, so your streak history does not move."
        ) {
            HStack(spacing: DesignTokens.Spacing.small) {
                TextField("", value: $draftGoal, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: DesignTokens.Layout.goalFieldWidth)
                    .onSubmit { commitDraft() }
                    .accessibilityLabel("Taps per day")

                Stepper(
                    "",
                    value: Binding(get: { draftGoal }, set: { draftGoal = $0; commitDraft() }),
                    in: GoalCalculator.bounds,
                    step: Self.stepperStep
                )
                .labelsHidden()
                .accessibilityLabel("Adjust the daily goal")
            }
        }
    }

    @ViewBuilder
    private var reminderControls: some View {
        SettingToggle(
            "Remind me if my streak is at risk",
            description: "A notification late in the day when today has not met its goal yet and a streak is on the line. Nothing is sent once you have reached it.",
            isOn: Binding(get: { settings.goalRemindersEnabled }, set: setRemindersEnabled)
        )

        if settings.goalRemindersEnabled {
            SettingRow("Remind me at") {
                Picker("", selection: $settings.goalReminderHour) {
                    ForEach(GoalCalculator.reminderHours, id: \.self) { hour in
                        Text(
                            GoalCalculator.reminderHourLabel(
                                hour,
                                reference: Date(),
                                calendar: .current
                            )
                        )
                        .tag(hour)
                    }
                }
                .labelsHidden()
                .frame(width: DesignTokens.Layout.goalHourPickerWidth)
                .accessibilityLabel("Reminder time")
            }

            if tracker.goals?.authorization == .denied {
                permissionNotice
            }
        }
    }

    /// Shown when notifications are refused.
    ///
    /// Deliberately a notice and not a disabled switch. The goal, the ring, the
    /// celebration and the streak all keep working without permission — only
    /// the reminder itself cannot be delivered — so turning the feature off
    /// here would take away more than the refusal did.
    private var permissionNotice: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Label(
                "Notifications are turned off for Idle Tapper, so no reminder can be delivered. Everything else about the goal still works.",
                systemImage: "bell.slash.fill"
            )
            .font(DesignTokens.Typography.caption)
            .foregroundStyle(AppColors.warning)
            .fixedSize(horizontal: false, vertical: true)

            Button("Open Notification Settings", action: openNotificationSettings)
                .buttonStyle(.settings)
        }
        .accessibilityElement(children: .contain)
    }

    private var footer: String {
        isGoalOn
            ? "With no goal set, a day counts toward your streak on any tap at all — which is how it worked before goals existed."
            : "Off by default. Turning it on changes what keeps a streak alive: a day has to reach the target, not just be tapped."
    }

    // MARK: - Actions

    private func setGoalEnabled(_ enabled: Bool) {
        let goal = enabled ? max(draftGoal, GoalCalculator.bounds.lowerBound) : 0
        settings.dailyGoal = goal
        tracker.applyGoalChange(to: goal)
    }

    private func commitDraft() {
        let clamped = AppSettings.clampDailyGoal(draftGoal)
        // A cleared or nonsensical field falls back to the last good value
        // rather than switching the goal off, which is not what editing a
        // number means.
        let goal = clamped > 0 ? clamped : max(settings.dailyGoal, GoalCalculator.defaultGoal)

        draftGoal = goal
        guard goal != settings.dailyGoal else { return }

        settings.dailyGoal = goal
        tracker.applyGoalChange(to: goal)
    }

    private func setRemindersEnabled(_ enabled: Bool) {
        settings.goalRemindersEnabled = enabled

        guard enabled else {
            // Reconciling drops the pending reminder: the plan no longer
            // contains one, so nothing has to be cancelled by hand.
            tracker.reconcileGoal(at: Date())
            return
        }

        // Asked for here and nowhere else. Prompting at launch, or on a tap,
        // would be a permission dialog the user did not ask for; prompting when
        // they switch a reminder on is the one moment it explains itself.
        tracker.goals?.requestAuthorization(
            todayCount: tracker.todayCount,
            currentStreak: tracker.stats.currentStreak,
            now: Date()
        )
    }

    private func openNotificationSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.notifications"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Constants

    /// Step for the stepper. Twenty-five rather than one: a goal is a round
    /// figure, and stepping to 500 one tap at a time is not a control.
    private static let stepperStep = 25
}

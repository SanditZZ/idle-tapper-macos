//
//  GeneralSettingsPage.swift
//  Idle Tapper — Settings ▸ General
//

import SwiftUI

/// Launch behaviour, tap feedback, what the menu bar item shows, and restoring
/// defaults.
///
/// The menu bar picker was its own "Appearance" page. See `SettingsSection` for
/// why it is here instead: one control is not a page, and this is the page a
/// user opens first.
struct GeneralSettingsPage: View {

    @Bindable var settings: AppSettings
    @Bindable var launchAtLogin: LaunchAtLoginService
    @Bindable var tracker: TapTracker

    var body: some View {
        SettingsPage(section: .general) {
            // One card, not one per setting. "Startup" and "Tapping" each held a
            // single switch, so the page read as three headings with one control
            // apiece — more card than content. Both are plain on/off behaviour,
            // which is exactly what a single group is for.
            SettingsCard(title: "Behaviour") {
                SettingToggle(
                    "Launch at login",
                    description: "Start Idle Tapper automatically when you log in.",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )

                if let message = launchAtLogin.lastErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppColors.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().opacity(0.3)

                SettingToggle(
                    "Play a click when tapping",
                    description: "A short click each time the counter goes up.",
                    isOn: $settings.playTapSound
                )

                Divider().opacity(0.3)

                SettingToggle(
                    "Celebrate milestones",
                    description: "A burst of colour every \(MilestoneCalculator.defaultInterval) taps. Turning this off keeps the milestone message.",
                    isOn: $settings.showVisualEffects
                )
            }

            SettingsCard(
                title: "Menu bar",
                subtitle: "Each option shows today's count as it would appear.",
                footer: "The item keeps a fixed width so it does not shove the icons beside it around as the count grows."
            ) {
                MenuBarStylePicker(
                    selection: $settings.menuBarDisplayStyle,
                    sampleCount: tracker.todayCount
                )
            }

            // Only offered once the user has dismissed the notice, so there is
            // a way back from "Don't show again" — and no dead control when
            // there is nothing to restore.
            if settings.suppressHiddenIconNotice {
                SettingsCard(
                    title: "Notices",
                    footer: "You chose not to be told again when the menu bar item is hidden behind the notch or another app's icons."
                ) {
                    Button("Show hidden-icon warnings again") {
                        settings.suppressHiddenIconNotice = false
                    }
                    .buttonStyle(.settings)
                }
            }

            SettingsCard(
                title: "Defaults",
                footer: "Restores every setting to how it shipped. Your tap history is not affected."
            ) {
                Button("Restore Defaults") { settings.resetToDefaults() }
                    .buttonStyle(.settings)
            }
        }
        // The user may have changed this in System Settings since launch, so
        // the switch has to be re-read rather than trusted from last time.
        .task { launchAtLogin.refresh() }
    }
}

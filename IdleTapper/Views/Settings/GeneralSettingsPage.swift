//
//  GeneralSettingsPage.swift
//  Idle Tapper — Settings ▸ General
//

import SwiftUI

/// Launch behaviour, tap feedback, and restoring defaults.
struct GeneralSettingsPage: View {

    @Bindable var settings: AppSettings
    @Bindable var launchAtLogin: LaunchAtLoginService

    var body: some View {
        SettingsPage(section: .general) {
            SettingsCard(title: "Startup") {
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
            }

            SettingsCard(title: "Tapping") {
                SettingToggle(
                    "Play a click when tapping",
                    description: "A short click each time the counter goes up.",
                    isOn: $settings.playTapSound
                )
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

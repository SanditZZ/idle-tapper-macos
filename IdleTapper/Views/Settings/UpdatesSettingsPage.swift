//
//  UpdatesSettingsPage.swift
//  Idle Tapper — Settings ▸ Updates
//

import SwiftUI

/// Automatic update checks and the manual one.
struct UpdatesSettingsPage: View {

    @Bindable var updates: UpdateService

    var body: some View {
        SettingsPage(section: .updates) {
            SettingsCard(
                title: "Automatic checks",
                footer: "Checks the project's release feed for a newer version. Nothing about you or your taps is sent."
            ) {
                SettingToggle(
                    "Check for updates automatically",
                    description: "Looks once a day while the app is running.",
                    isOn: $updates.automaticallyChecks
                )
            }

            SettingsCard(title: "Check now") {
                HStack(spacing: DesignTokens.Spacing.medium) {
                    Button("Check Now") { updates.checkForUpdates() }
                        .buttonStyle(.settingsPrimary)
                        .disabled(!updates.canCheck)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.lastCheckDescription(updates.lastCheckDate))
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(AppColors.textSecondary)

                        if let summary = updates.lastCheckSummary {
                            Text(summary)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// "Never checked" reads better than an empty space where a date should be.
    private static func lastCheckDescription(_ date: Date?) -> String {
        guard let date else { return "Never checked" }
        return "Last checked \(date.formatted(.relative(presentation: .named)))"
    }
}

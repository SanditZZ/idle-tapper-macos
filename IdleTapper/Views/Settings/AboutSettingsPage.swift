//
//  AboutSettingsPage.swift
//  Idle Tapper — Settings ▸ About
//

import SwiftUI

/// Version, and where the project lives.
struct AboutSettingsPage: View {

    /// Where "View on GitHub" goes. Kept here rather than in the button so the
    /// address is stated once and is visible next to the label that opens it.
    private static let repositoryURL = URL(string: "https://github.com/SanditZZ/idle-tapper-macos")!

    var body: some View {
        SettingsPage(section: .about) {
            SettingsCard {
                HStack(spacing: DesignTokens.Spacing.large) {
                    // The real app icon, so this page cannot show something the
                    // Dock and Finder disagree with.
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
                        Text(AppInfo.name)
                            .font(DesignTokens.Typography.pageTitle)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Version \(AppInfo.displayVersion)")
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(AppColors.textSecondary)
                            .monospacedDigit()

                        Text("A tap counter that lives in the menu bar.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    Spacer(minLength: 0)
                }
            }

            SettingsCard(
                title: "Project",
                footer: "Idle Tapper is open source. Issues and pull requests are welcome."
            ) {
                Button("View on GitHub") {
                    NSWorkspace.shared.open(Self.repositoryURL)
                }
                .buttonStyle(.settings)
            }
        }
    }
}

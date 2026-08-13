//
//  AppearanceSettingsPage.swift
//  Idle Tapper — Settings ▸ Appearance
//

import SwiftUI

/// What the status item shows, and recovering dismissed notices.
struct AppearanceSettingsPage: View {

    @Bindable var settings: AppSettings
    @Bindable var tracker: TapTracker

    var body: some View {
        SettingsPage(section: .appearance) {
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
        }
    }
}

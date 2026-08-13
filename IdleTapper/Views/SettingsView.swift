//
//  SettingsView.swift
//  Idle Tapper — Settings window
//
//  A sidebar and a detail pane. The window used to be one long scroll, which
//  worked while there were three sections and quietly clipped its own bottom
//  once there were five — the failure that hid the export-failure message.
//  Splitting the sections across pages means no page has to be tall.
//

import SwiftUI

struct SettingsView: View {

    @Bindable var tracker: TapTracker
    @Bindable var settings: AppSettings
    @Bindable var launchAtLogin: LaunchAtLoginService
    @Bindable var updates: UpdateService

    /// Which page is showing. Not persisted: Settings should open where the
    /// user expects it to, not wherever they happened to leave it weeks ago.
    @State private var selection: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selection)

            // An explicit hairline rather than `Divider()`. In dark mode the
            // sidebar material and the content pane sit close enough in
            // brightness that the edge between them was doing the whole job of
            // separating them, and the system divider is the fainter of the two.
            Rectangle()
                .fill(AppColors.separator)
                .frame(width: 1)

            VStack(spacing: 0) {
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // A failed tap write is the one error that matters wherever the
                // user happens to be, so it sits outside the pages rather than
                // on whichever one they might not be looking at.
                if let message = tracker.lastErrorMessage {
                    Divider()
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppColors.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignTokens.Spacing.large)
                        .padding(.vertical, DesignTokens.Spacing.small)
                }
            }
            .background(AppColors.windowSurface)
        }
        .frame(
            minWidth: DesignTokens.Layout.settingsWindowMinSize.width,
            idealWidth: DesignTokens.Layout.settingsWindowSize.width,
            minHeight: DesignTokens.Layout.settingsWindowMinSize.height,
            idealHeight: DesignTokens.Layout.settingsWindowSize.height
        )
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .general:
            GeneralSettingsPage(
                settings: settings,
                launchAtLogin: launchAtLogin,
                tracker: tracker
            )
        case .updates:
            UpdatesSettingsPage(updates: updates)
        case .data:
            DataSettingsPage(tracker: tracker, settings: settings)
        case .about:
            AboutSettingsPage()
        }
    }
}

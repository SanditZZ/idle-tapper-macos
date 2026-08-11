//
//  SettingsView.swift
//  Idle Tapper — Settings window
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {

    @Bindable var tracker: TapTracker
    @Bindable var settings: AppSettings
    @Bindable var launchAtLogin: LaunchAtLoginService

    @State private var isConfirmingReset = false
    @State private var exportMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.section) {
            header
            generalSection
            appearanceSection
            dataSection
            Spacer(minLength: 0)
            footer
        }
        // The user may have changed this in System Settings since launch.
        .task { launchAtLogin.refresh() }
        .padding(DesignTokens.Spacing.cardPadding)
        .frame(
            minWidth: DesignTokens.Layout.settingsWindowSize.width,
            minHeight: DesignTokens.Layout.settingsWindowSize.height
        )
        .confirmationDialog(
            "Delete all tap history?",
            isPresented: $isConfirmingReset
        ) {
            Button("Delete Everything", role: .destructive) {
                tracker.deleteAllHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every recorded day. It cannot be undone.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Settings")
                .font(DesignTokens.Typography.pageTitle)
            Text("Idle Tapper \(Self.appVersion)")
                .font(DesignTokens.Typography.pageSubtitle)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var generalSection: some View {
        section("General") {
            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )
            )
            .font(DesignTokens.Typography.body)

            if let message = launchAtLogin.lastErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppColors.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var appearanceSection: some View {
        section("Menu Bar") {
            Picker("Show in menu bar", selection: $settings.menuBarDisplayStyle) {
                ForEach(MenuBarDisplayStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.radioGroup)

            Toggle("Play a click when tapping", isOn: $settings.playTapSound)
                .font(DesignTokens.Typography.body)

            // Only offered once the user has dismissed the notice, so there is
            // a way back from "Don't show again".
            if settings.suppressHiddenIconNotice {
                Button("Show hidden-icon warnings again") {
                    settings.suppressHiddenIconNotice = false
                }
                .font(DesignTokens.Typography.caption)
            }
        }
    }

    private var dataSection: some View {
        section("Data") {
            LabeledContent("Stored days") {
                Text("\(tracker.stats.activeDays)")
                    .monospacedDigit()
            }
            .font(DesignTokens.Typography.body)

            Text("Taps are saved on this Mac only and reset at local midnight.")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppColors.textTertiary)

            HStack(spacing: DesignTokens.Spacing.small) {
                Button("Export History…") { exportHistory() }

                Button("Delete All History…", role: .destructive) {
                    if settings.confirmBeforeReset {
                        isConfirmingReset = true
                    } else {
                        tracker.deleteAllHistory()
                    }
                }
            }

            Toggle("Ask before deleting history", isOn: $settings.confirmBeforeReset)
                .font(DesignTokens.Typography.body)

            if let exportMessage {
                Text(exportMessage)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppColors.success)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Restore Defaults") {
                settings.resetToDefaults()
            }
            .font(DesignTokens.Typography.caption)

            Spacer()

            if let message = tracker.lastErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppColors.error)
            }
        }
    }

    // MARK: - Building Blocks

    private func section(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text(title.uppercased())
                .font(DesignTokens.Typography.statLabel)
                .foregroundStyle(AppColors.textTertiary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                content()
            }
            .appCard()
        }
    }

    // MARK: - Actions

    /// Export history as JSON via a save panel.
    ///
    /// JSON rather than the raw SQLite store: the store's schema belongs to
    /// SwiftData and is not a stable format to hand a user.
    private func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "idle-tapper-history.json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try tracker.exportJSON()
            try data.write(to: url, options: .atomic)
            exportMessage = "Exported to \(url.lastPathComponent)"
            AppLog.settings.info("[Settings] Exported history")
        } catch {
            exportMessage = nil
            AppLog.settings.error(
                "[Settings] Export failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Helpers

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}

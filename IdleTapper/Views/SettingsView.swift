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
    @Bindable var updates: UpdateService

    @State private var isConfirmingReset = false
    @State private var exportOutcome: ExportOutcome?

    /// The result of the last export.
    ///
    /// A failure used to clear the message and log, which left the user looking
    /// at a save panel that had closed with nothing to show for it. An export
    /// that fails has to say so on screen.
    private enum ExportOutcome {
        case succeeded(fileName: String)
        case failed(reason: String)

        var message: String {
            switch self {
            case .succeeded(let fileName): "Exported to \(fileName)"
            case .failed(let reason): "Export failed — \(reason)"
            }
        }

        var systemImage: String {
            switch self {
            case .succeeded: "checkmark.circle.fill"
            case .failed: "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .succeeded: AppColors.success
            case .failed: AppColors.error
            }
        }
    }

    var body: some View {
        // The sections scroll; the footer does not. Settings grows a section
        // every so often, and a fixed-height stack quietly clips the bottom of
        // itself when it does — which is exactly what happened when Updates
        // was added. Scrolling makes the window's height a comfort setting
        // rather than a limit on what can be reached.
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.section) {
                    header
                    generalSection
                    updatesSection
                    appearanceSection
                    dataSection
                }
                .padding(DesignTokens.Spacing.cardPadding)
                // Without this the stack hugs its content and the sections
                // centre themselves in a wide window instead of filling it.
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            footer
                .padding(.horizontal, DesignTokens.Spacing.cardPadding)
                .padding(.vertical, DesignTokens.Spacing.small)
        }
        // The user may have changed this in System Settings since launch.
        .task { launchAtLogin.refresh() }
        .frame(
            minWidth: DesignTokens.Layout.settingsWindowMinSize.width,
            idealWidth: DesignTokens.Layout.settingsWindowSize.width,
            minHeight: DesignTokens.Layout.settingsWindowMinSize.height,
            idealHeight: DesignTokens.Layout.settingsWindowSize.height
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

    private var updatesSection: some View {
        section("Updates") {
            Toggle("Check for updates automatically", isOn: $updates.automaticallyChecks)
                .font(DesignTokens.Typography.body)

            HStack(spacing: DesignTokens.Spacing.small) {
                Button("Check Now") { updates.checkForUpdates() }
                    .disabled(!updates.canCheck)

                Text(Self.lastCheckDescription(updates.lastCheckDate))
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }

            if let summary = updates.lastCheckSummary {
                Text(summary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }

            Text("Checks the project's release feed for a newer version. Nothing about you or your taps is sent.")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
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

            if let exportOutcome {
                Label(exportOutcome.message, systemImage: exportOutcome.systemImage)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(exportOutcome.tint)
                    .fixedSize(horizontal: false, vertical: true)
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

            // Fill the width before the card is applied. Without this each card
            // hugs its own content, so the four sections rendered at four
            // different widths — a ragged right edge that reads as unfinished
            // rather than as deliberate. The outer stack filling the window is
            // not enough; the card sizes to whatever it wraps.
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            exportOutcome = .succeeded(fileName: url.lastPathComponent)
            AppLog.settings.info("[Settings] Exported history")
        } catch {
            exportOutcome = .failed(reason: error.localizedDescription)
            AppLog.settings.error(
                "[Settings] Export failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Helpers

    /// "Never checked" reads better than an empty space where a date should be.
    private static func lastCheckDescription(_ date: Date?) -> String {
        guard let date else { return "Never checked" }
        return "Last checked \(date.formatted(.relative(presentation: .named)))"
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}

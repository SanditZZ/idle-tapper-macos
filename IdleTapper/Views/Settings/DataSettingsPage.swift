//
//  DataSettingsPage.swift
//  Idle Tapper — Settings ▸ Data
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Where history lives, exporting it, and deleting it.
struct DataSettingsPage: View {

    @Bindable var tracker: TapTracker
    @Bindable var settings: AppSettings

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
        SettingsPage(section: .data) {
            SettingsCard(
                title: "Stored history",
                footer: "Taps are saved on this Mac only and reset at local midnight."
            ) {
                SettingRow("Days recorded") {
                    Text("\(tracker.stats.activeDays)")
                        .font(DesignTokens.Typography.bodyMedium)
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textPrimary)
                }
            }

            SettingsCard(
                title: "Export",
                footer: "Saves a JSON file of every recorded day."
            ) {
                Button("Export History…") { exportHistory() }
                    .buttonStyle(.settings)

                if let exportOutcome {
                    Label(exportOutcome.message, systemImage: exportOutcome.systemImage)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(exportOutcome.tint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsCard(title: "Danger zone") {
                SettingToggle(
                    "Ask before deleting history",
                    description: "Show a confirmation first. Turning this off deletes immediately.",
                    isOn: $settings.confirmBeforeReset
                )

                Button("Delete All History…") {
                    if settings.confirmBeforeReset {
                        isConfirmingReset = true
                    } else {
                        tracker.deleteAllHistory()
                    }
                }
                .buttonStyle(.settingsDestructive)
            }
        }
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
}

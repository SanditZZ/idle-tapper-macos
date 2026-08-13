//
//  DataSettingsPage.swift
//  Idle Tapper — Settings ▸ Data
//

import SwiftUI

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
                footer: "Saves every recorded day. Choose JSON or CSV in the save panel — "
                    + "CSV opens in a spreadsheet, JSON keeps the exact data."
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

    /// Export history via a save panel, in whichever format the user picks.
    ///
    /// Either format rather than the raw SQLite store: the store's schema
    /// belongs to SwiftData and is not a stable thing to hand a user. The panel
    /// itself lives in `HistoryExportPanel` so this stays a view.
    private func exportHistory() {
        guard let choice = HistoryExportPanel.run() else { return }

        do {
            let data = switch choice.format {
            case .json: try tracker.exportJSON()
            case .csv: try tracker.exportCSV()
            }
            try data.write(to: choice.url, options: .atomic)
            exportOutcome = .succeeded(fileName: choice.url.lastPathComponent)
            AppLog.settings.info(
                "[Settings] Exported history as \(choice.format.fileExtension, privacy: .public)"
            )
        } catch {
            exportOutcome = .failed(reason: error.localizedDescription)
            AppLog.settings.error(
                "[Settings] Export failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

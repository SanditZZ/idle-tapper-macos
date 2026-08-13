//
//  HistoryExportPanel.swift
//  Idle Tapper — Actions layer
//
//  The save panel behind Settings ▸ Data ▸ Export. Owns the AppKit plumbing so
//  the view stays presentational.
//

import AppKit
import UniformTypeIdentifiers

/// Runs the export save panel and reports what the user chose.
///
/// **The format popup is ours, not AppKit's.** Handing `NSSavePanel` several
/// `allowedContentTypes` does *not* produce a File Format row — that popup is
/// built by `NSDocument`'s save machinery, which this app does not use. A bare
/// panel given two types simply accepts either extension if one is typed by
/// hand, and offers no way to discover the second. So the popup is supplied as
/// an accessory view, and keeping the file name's extension in step with it
/// becomes ours to do as well.
@MainActor
enum HistoryExportPanel {

    /// What the user settled on.
    struct Choice {
        let url: URL
        let format: HistoryExportFormat
    }

    /// Presents the panel modally.
    ///
    /// - Parameter defaultName: File name without an extension.
    /// - Returns: The chosen destination, or `nil` if the panel was cancelled.
    static func run(defaultName: String = HistoryExportFormat.defaultBaseName) -> Choice? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = HistoryExportFormat.default.renaming(defaultName)

        let picker = FormatPicker(panel: panel)
        panel.accessoryView = picker.view

        apply(HistoryExportFormat.default, to: panel)

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        // The extension is the authority rather than the popup's selection: the
        // name field is editable, so someone can type `.csv` over a JSON
        // selection and the file they asked for is the one they typed.
        let format = HistoryExportFormat.matching(fileExtension: url.pathExtension)
            ?? picker.selection

        return Choice(url: url, format: format)
    }

    /// Narrows the panel to one format and renames the field to match.
    ///
    /// One type at a time, not all of them: with several allowed, the panel
    /// accepts a stale extension left over from a previous selection, which is
    /// how a file ends up named `.json` holding CSV.
    fileprivate static func apply(_ format: HistoryExportFormat, to panel: NSSavePanel) {
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = format.renaming(panel.nameFieldStringValue)
    }

    /// Retains the popup and its target, which `NSSavePanel` does not.
    @MainActor
    private final class FormatPicker {

        let view: NSView
        private let popUp = NSPopUpButton()
        private weak var panel: NSSavePanel?

        var selection: HistoryExportFormat {
            HistoryExportFormat.allCases[popUp.indexOfSelectedItem]
        }

        init(panel: NSSavePanel) {
            self.panel = panel

            popUp.addItems(withTitles: HistoryExportFormat.allCases.map(\.displayName))
            popUp.selectItem(at: 0)

            let label = NSTextField(labelWithString: "Format:")
            let row = NSStackView(views: [label, popUp])
            row.orientation = .horizontal
            row.alignment = .firstBaseline
            row.spacing = DesignTokens.Spacing.small
            row.translatesAutoresizingMaskIntoConstraints = false

            // The panel sizes an accessory view to its own width, so the row is
            // inset rather than pinned edge to edge.
            let container = NSView()
            container.addSubview(row)
            NSLayoutConstraint.activate([
                row.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                row.topAnchor.constraint(
                    equalTo: container.topAnchor,
                    constant: DesignTokens.Spacing.small
                ),
                row.bottomAnchor.constraint(
                    equalTo: container.bottomAnchor,
                    constant: -DesignTokens.Spacing.small
                ),
            ])
            self.view = container

            popUp.target = self
            popUp.action = #selector(formatChanged)
        }

        @objc private func formatChanged() {
            guard let panel else { return }
            HistoryExportPanel.apply(selection, to: panel)
            AppLog.settings.debug(
                "[Settings] Export format set to \(self.selection.fileExtension, privacy: .public)"
            )
        }
    }
}

private extension HistoryExportFormat {
    var contentType: UTType {
        switch self {
        case .json: .json
        case .csv: .commaSeparatedText
        }
    }
}

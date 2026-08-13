//
//  HistoryExportFormat.swift
//  Idle Tapper — Calculations
//
//  The formats history can be exported in, and the pure file-name arithmetic
//  that goes with choosing one.
//

import Foundation

/// A format offered by the export save panel.
///
/// `json` is first because it is the one that reads back into the app; CSV is
/// the convenience.
enum HistoryExportFormat: String, CaseIterable, Sendable {
    case json
    case csv

    /// The format a save panel starts on.
    static let `default`: HistoryExportFormat = .json

    /// The file name offered before the user types one of their own.
    static let defaultBaseName = "idle-tapper-history"

    /// Extension without the dot.
    var fileExtension: String { rawValue }

    /// Shown in the panel's format popup.
    var displayName: String {
        switch self {
        case .json: "JSON"
        case .csv: "CSV (spreadsheet)"
        }
    }

    /// The format a file name implies, or `nil` if it names neither.
    ///
    /// Case-insensitive because the panel lets the name be typed by hand, and
    /// someone typing `.CSV` means CSV.
    static func matching(fileExtension: String) -> HistoryExportFormat? {
        allCases.first { $0.fileExtension.caseInsensitiveCompare(fileExtension) == .orderedSame }
    }

    /// The same file name carrying this format's extension.
    ///
    /// Only a *known* export extension is replaced. Someone who typed
    /// `march.2026.json` keeps the middle component, and someone whose name has
    /// no extension gains one rather than losing the last word after a dot.
    func renaming(_ fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        let existing = (fileName as NSString).pathExtension

        let stem = existing.isEmpty || matching(fileExtension: existing) != nil ? base : fileName
        // Reachable by clearing the name field and then switching format, which
        // would otherwise leave the panel showing a bare ".csv" — a hidden file,
        // and not what anyone meant to save.
        let safeStem = stem.isEmpty ? Self.defaultBaseName : stem

        return "\(safeStem).\(fileExtension)"
    }

    /// Instance-side spelling of the static lookup, for readability at call sites.
    private func matching(fileExtension: String) -> HistoryExportFormat? {
        Self.matching(fileExtension: fileExtension)
    }
}

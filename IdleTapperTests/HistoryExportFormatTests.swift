//
//  HistoryExportFormatTests.swift
//  IdleTapperTests
//
//  The file-name arithmetic behind the export panel's format popup. Worth
//  testing rather than trusting to `NSString.pathExtension`: the panel's name
//  field is editable, so the input is whatever a user typed.
//

import Foundation
import Testing
@testable import IdleTapper

@Suite("History export format")
struct HistoryExportFormatTests {

    /// The ordinary case: switching the popup rewrites the extension in place.
    @Test("Switching format replaces a known extension")
    func replacesAKnownExtension() {
        #expect(HistoryExportFormat.csv.renaming("idle-tapper-history.json")
            == "idle-tapper-history.csv")
        #expect(HistoryExportFormat.json.renaming("idle-tapper-history.csv")
            == "idle-tapper-history.json")
    }

    /// A name with no extension gains one rather than being left bare, which is
    /// the state the panel starts in if the default name is written without one.
    @Test("A name with no extension gains one")
    func addsAMissingExtension() {
        #expect(HistoryExportFormat.csv.renaming("taps") == "taps.csv")
    }

    /// The case that a naive `deletingPathExtension` gets wrong: everything
    /// after the last dot looks like an extension, so "march.2026" would be
    /// silently truncated to "march.csv" and the user would lose the year.
    @Test("A dot inside the name is not mistaken for an extension")
    func keepsAnUnknownFinalComponent() {
        #expect(HistoryExportFormat.csv.renaming("march.2026") == "march.2026.csv")
        #expect(HistoryExportFormat.json.renaming("v1.2") == "v1.2.json")
    }

    /// A middle component survives, because only the final known extension is
    /// the one being replaced.
    @Test("A known extension is replaced without disturbing the rest")
    func replacesOnlyTheFinalExtension() {
        #expect(HistoryExportFormat.csv.renaming("march.2026.json") == "march.2026.csv")
    }

    /// Reachable by clearing the name field and then switching the format,
    /// which would otherwise leave the panel showing a bare ".csv" — a hidden
    /// file, and not what anyone meant to save.
    @Test("An emptied name falls back to the default rather than a bare extension")
    func recoversFromAnEmptyName() {
        #expect(HistoryExportFormat.csv.renaming("") == "idle-tapper-history.csv")
    }

    /// The chosen `url`'s extension is what picks the encoder, and it comes from
    /// a field the user can type into — including in the wrong case.
    @Test("Matching an extension ignores case, and rejects anything unknown")
    func matchesExtensionsCaseInsensitively() {
        #expect(HistoryExportFormat.matching(fileExtension: "CSV") == .csv)
        #expect(HistoryExportFormat.matching(fileExtension: "Json") == .json)
        #expect(HistoryExportFormat.matching(fileExtension: "txt") == nil)
        #expect(HistoryExportFormat.matching(fileExtension: "") == nil)
    }

    /// The popup is built by mapping over `allCases` and the selection is read
    /// back by index, so the two would silently disagree if the order changed.
    @Test("JSON is first, so the panel opens on the round-trippable format")
    func defaultsToJSON() {
        #expect(HistoryExportFormat.allCases.first == .json)
        #expect(HistoryExportFormat.default == .json)
    }
}

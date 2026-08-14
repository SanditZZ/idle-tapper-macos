//
//  AchievementCatalogTests.swift
//  Idle Tapper — Tests
//

import AppKit
import Testing

@testable import IdleTapper

@Suite("Achievement catalog")
struct AchievementCatalogTests {

    /// Every catalog entry must name a real SF Symbol.
    ///
    /// `Image(systemName:)` fails silently — an unknown name renders as empty
    /// space, so a typo ships as a blank badge rather than as any kind of
    /// error. `Hundred Club` did exactly that with `100.circle.fill`: SF
    /// Symbols' numbered circles stop at 50, and the achievement most users
    /// unlock first had no icon at all.
    ///
    /// **This checks the symbol exists on whatever macOS runs the tests, which
    /// is not the same as existing on the deployment target.** A glyph added
    /// after macOS 14 passes here and still renders blank for a user on 14, so
    /// prefer long-standing symbols when adding to the catalog.
    @Test("Every achievement names a real SF Symbol")
    func everySymbolResolves() {
        for definition in AchievementCatalog.all {
            #expect(
                NSImage(systemSymbolName: definition.systemImage, accessibilityDescription: nil) != nil,
                "\(definition.title) uses '\(definition.systemImage)', which is not an SF Symbol"
            )
        }
    }

    /// Two entries sharing an id would make `unlocked` and the persisted
    /// records disagree about which one was earned.
    @Test("Achievement ids are unique")
    func idsAreUnique() {
        let ids = AchievementCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}

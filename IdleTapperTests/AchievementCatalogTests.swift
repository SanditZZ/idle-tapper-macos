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

    @Test("The lookup covers every catalog entry")
    func lookupCoversCatalog() {
        #expect(AchievementCatalog.byID.count == AchievementCatalog.all.count)
        for definition in AchievementCatalog.all {
            #expect(AchievementCatalog.byID[definition.id]?.title == definition.title)
        }
    }

    // MARK: - Tiers

    /// Catalog order is load-bearing twice over: `TapTracker` banners "the
    /// first newly unlocked in catalog order", and the window renders tier
    /// sections in tier order. Both agree only while the array is itself
    /// sorted by tier, so an entry inserted into the wrong block would show
    /// under one heading and be announced as though it belonged to another.
    @Test("Tiers never go backwards in catalog order")
    func tiersAreNonDecreasing() {
        let tiers = AchievementCatalog.all.map(\.tier)
        for (earlier, later) in zip(tiers, tiers.dropFirst()) {
            #expect(earlier <= later, "\(later.title) appears after \(earlier.title) in the catalog")
        }
    }

    /// A tier with nothing in it renders as a heading over empty space.
    @Test("Every tier has at least one achievement")
    func everyTierIsPopulated() {
        for tier in AchievementTier.allCases {
            #expect(
                AchievementCatalog.all.contains { $0.tier == tier },
                "No achievement is in the \(tier.title) tier"
            )
        }
    }

    /// The `Comparable` conformance is what `tiersAreNonDecreasing` and the
    /// window's section order both rest on, and it is derived from
    /// `allCases` rather than written out.
    @Test("Tiers order easiest first")
    func tiersOrderEasiestFirst() {
        #expect(AchievementTier.allCases == [.bronze, .silver, .gold])
        #expect(AchievementTier.bronze < AchievementTier.silver)
        #expect(AchievementTier.silver < AchievementTier.gold)
    }
}

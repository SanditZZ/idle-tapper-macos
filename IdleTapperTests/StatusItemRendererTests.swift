//
//  StatusItemRendererTests.swift
//  IdleTapperTests
//
//  The menu bar has very little room; an unabbreviated count would push other
//  status items off screen.
//

import Testing
@testable import IdleTapper

@Suite("Menu bar rendering")
struct StatusItemRendererTests {

    @Test("Counts below ten thousand are shown exactly", arguments: [0, 1, 999, 9_999])
    func exactBelowThreshold(count: Int) {
        #expect(StatusItemRenderer.abbreviated(count) == "\(count)")
    }

    @Test("Large counts are abbreviated")
    func abbreviations() {
        #expect(StatusItemRenderer.abbreviated(10_000) == "10K")
        #expect(StatusItemRenderer.abbreviated(10_500) == "10.5K")
        #expect(StatusItemRenderer.abbreviated(999_000) == "999K")
        #expect(StatusItemRenderer.abbreviated(1_000_000) == "1M")
        #expect(StatusItemRenderer.abbreviated(1_240_000) == "1.2M")
    }

    @Test("Display style controls what the status item shows")
    func displayStyles() {
        #expect(StatusItemRenderer.title(for: 42, style: .iconOnly).isEmpty)
        #expect(StatusItemRenderer.title(for: 42, style: .iconAndCount) == "42")
        #expect(StatusItemRenderer.title(for: 42, style: .countOnly) == "42")

        #expect(MenuBarDisplayStyle.iconOnly.showsIcon)
        #expect(!MenuBarDisplayStyle.iconOnly.showsCount)
        #expect(!MenuBarDisplayStyle.countOnly.showsIcon)
    }

    @Test("The tooltip always carries the exact count")
    func tooltipIsExact() {
        #expect(StatusItemRenderer.tooltip(for: 1_234_567).contains("1,234,567"))
    }
}

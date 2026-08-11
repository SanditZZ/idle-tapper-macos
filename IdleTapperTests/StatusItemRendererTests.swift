//
//  StatusItemRendererTests.swift
//  IdleTapperTests
//
//  The menu bar has very little room, and an item that resizes drags every
//  other status item along with it. The width tests below are the important
//  ones: they assert the property the user actually notices.
//

import Testing
import AppKit
@testable import IdleTapper

@Suite("Menu bar rendering")
struct StatusItemRendererTests {

    // MARK: - No Layout Shift

    @Test("Every title renders to exactly the same width, across four orders of magnitude")
    func renderedWidthIsConstant() {
        let counts = [0, 1, 7, 9, 10, 11, 88, 99, 100, 111, 888, 999,
                      1_000, 1_111, 8_888, 9_999,
                      10_000, 99_999, 999_999,
                      1_000_000, 999_999_999, 1_000_000_000,
                      1_000_000_000_000, Int.max]

        let widths = counts.map { count in
            StatusItemRenderer
                .attributedTitle(for: count, style: .iconAndCount)
                .size()
                .width
        }

        guard let first = widths.first else {
            Issue.record("No widths measured")
            return
        }

        for (count, width) in zip(counts, widths) {
            #expect(
                abs(width - first) < 0.01,
                "Count \(count) rendered \(width)pt wide, expected \(first)pt — the menu bar would shift"
            )
        }
    }

    @Test("Consecutive counts never change width, which is what fast tapping produces")
    func consecutiveCountsAreStable() {
        let widths = (0...200).map { count in
            StatusItemRenderer
                .attributedTitle(for: count, style: .iconAndCount)
                .size()
                .width
        }

        let distinct = Set(widths.map { ($0 * 100).rounded() })
        #expect(distinct.count == 1, "Width changed while counting 0 to 200")
    }

    @Test("The pinned item width does not depend on the count")
    func pinnedWidthIsStyleOnly() {
        // The width is a function of style alone — there is no count parameter,
        // which is the structural guarantee that it cannot vary as taps arrive.
        for style in MenuBarDisplayStyle.allCases {
            let width = StatusItemRenderer.statusItemLength(for: style)
            #expect(width > 0, "\(style.displayName) produced a zero-width item")
        }

        #expect(
            StatusItemRenderer.statusItemLength(for: .iconAndCount)
                > StatusItemRenderer.statusItemLength(for: .iconOnly),
            "Showing a count needs more room than the icon alone"
        )
    }

    @Test("The pinned width leaves room for the widest possible title")
    func pinnedWidthFitsWidestTitle() {
        let widest = StatusItemRenderer.attributedTitle(for: 8_888, style: .countOnly).size().width
        #expect(StatusItemRenderer.statusItemLength(for: .countOnly) >= widest)
    }

    @Test("The title font is fully monospaced, not merely monospaced-digit")
    func fontIsFullyMonospaced() {
        let font = StatusItemRenderer.titleFont
        let attributes: [NSAttributedString.Key: Any] = [.font: font]

        // A digit, a letter and a space must all advance identically, otherwise
        // padded titles containing "K" or "M" would not line up.
        let digit = NSAttributedString(string: "8", attributes: attributes).size().width
        let letter = NSAttributedString(string: "K", attributes: attributes).size().width
        let space = NSAttributedString(string: " ", attributes: attributes).size().width

        #expect(abs(digit - letter) < 0.01)
        #expect(abs(digit - space) < 0.01)
    }

    // MARK: - Padding

    @Test("Titles are padded to the reserved field width")
    func titlesArePadded() {
        #expect(StatusItemRenderer.title(for: 0, style: .iconAndCount) == "0   ")
        #expect(StatusItemRenderer.title(for: 42, style: .iconAndCount) == "42  ")
        #expect(StatusItemRenderer.title(for: 999, style: .iconAndCount) == "999 ")
        #expect(StatusItemRenderer.title(for: 9_999, style: .iconAndCount) == "9999")
    }

    @Test("Padding never truncates a value that overflows the field")
    func paddingDoesNotTruncate() {
        #expect(StatusItemRenderer.pad("12345") == "12345", "A wrong number is worse than a resize")
    }

    // MARK: - Abbreviation

    @Test("Counts below ten thousand are shown exactly", arguments: [0, 1, 999, 9_999])
    func exactBelowThreshold(count: Int) {
        #expect(StatusItemRenderer.abbreviated(count) == "\(count)")
    }

    @Test("Large counts abbreviate to whole units")
    func abbreviations() {
        #expect(StatusItemRenderer.abbreviated(10_000) == "10K")
        #expect(StatusItemRenderer.abbreviated(10_500) == "10K")
        #expect(StatusItemRenderer.abbreviated(999_000) == "999K")
        #expect(StatusItemRenderer.abbreviated(1_000_000) == "1M")
        #expect(StatusItemRenderer.abbreviated(1_240_000) == "1M")
        #expect(StatusItemRenderer.abbreviated(1_000_000_000) == "1B")
        #expect(StatusItemRenderer.abbreviated(2_000_000_000_000) == "2T")
    }

    @Test("Absurd totals saturate rather than overflowing the field")
    func saturation() {
        #expect(StatusItemRenderer.abbreviated(999_000_000_000_000) == "999T")
        #expect(StatusItemRenderer.abbreviated(1_000_000_000_000_000) == "999+")
        #expect(StatusItemRenderer.abbreviated(Int.max) == "999+")
    }

    @Test("A negative total is clamped rather than rendering a wider string")
    func negativeIsClamped() {
        #expect(StatusItemRenderer.abbreviated(-5_000) == "0")
    }

    @Test("No abbreviation ever exceeds the reserved field width")
    func abbreviationsFitTheField() {
        // Sample every order of magnitude plus the boundaries around each.
        let samples = (0...12).flatMap { power -> [Int] in
            let base = Int(pow(10.0, Double(power)))
            return [base - 1, base, base + 1, base * 9]
        }

        for count in samples where count >= 0 {
            let text = StatusItemRenderer.abbreviated(count)
            #expect(
                text.count <= StatusItemRenderer.reservedCharacters,
                "\(count) abbreviated to '\(text)', which overflows the reserved field"
            )
        }
    }

    // MARK: - Styles

    @Test("Display style controls what the status item shows")
    func displayStyles() {
        #expect(StatusItemRenderer.title(for: 42, style: .iconOnly).isEmpty)
        #expect(StatusItemRenderer.attributedTitle(for: 42, style: .iconOnly).length == 0)
        #expect(StatusItemRenderer.title(for: 42, style: .countOnly).trimmingCharacters(in: .whitespaces) == "42")

        #expect(MenuBarDisplayStyle.iconOnly.showsIcon)
        #expect(!MenuBarDisplayStyle.iconOnly.showsCount)
        #expect(!MenuBarDisplayStyle.countOnly.showsIcon)
    }

    @Test("The tooltip always carries the exact count, however it is abbreviated")
    func tooltipIsExact() {
        #expect(StatusItemRenderer.tooltip(for: 1_234_567).contains("1,234,567"))
        #expect(StatusItemRenderer.abbreviated(1_234_567) == "1M", "Precision is lost in the menu bar…")
    }
}

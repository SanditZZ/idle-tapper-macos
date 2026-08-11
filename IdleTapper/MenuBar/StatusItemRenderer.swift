//
//  StatusItemRenderer.swift
//  Idle Tapper — Menu bar presentation
//
//  Turns the current count and display style into the status item's title and
//  image. Pure formatting, kept out of the controller so it can be reasoned
//  about and tested on its own.
//

import AppKit

/// Formats the menu bar status item's contents.
enum StatusItemRenderer {

    /// SF Symbol used as the menu bar icon.
    static let symbolName = "hand.tap.fill"

    /// Accessibility description for the icon.
    static let symbolDescription = "Idle Tapper"

    /// The title text for a given count and style.
    ///
    /// Counts are abbreviated past four digits so a long session cannot push
    /// other menu bar items off screen.
    static func title(for count: Int, style: MenuBarDisplayStyle) -> String {
        guard style.showsCount else { return "" }
        return abbreviated(count)
    }

    /// The icon image, or `nil` when the style hides it.
    static func image(for style: MenuBarDisplayStyle) -> NSImage? {
        guard style.showsIcon else { return nil }

        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: symbolDescription
        )
        // Template rendering lets macOS invert the icon for light/dark menu bars
        // and for the "reduce transparency" appearance.
        image?.isTemplate = true
        return image
    }

    /// Compact numeric form: exact below 10,000, then abbreviated.
    ///
    /// 9999 → "9999", 10500 → "10.5K", 1_240_000 → "1.2M"
    static func abbreviated(_ count: Int) -> String {
        let magnitude = abs(count)

        switch magnitude {
        case ..<10_000:
            return "\(count)"
        case ..<1_000_000:
            return format(Double(count) / 1_000, suffix: "K")
        default:
            return format(Double(count) / 1_000_000, suffix: "M")
        }
    }

    /// Tooltip shown on hover — always the exact number, grouped for legibility.
    static func tooltip(for count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let exact = formatter.string(from: NSNumber(value: count)) ?? "\(count)"
        return "\(exact) taps today"
    }

    // MARK: - Helpers

    private static func format(_ value: Double, suffix: String) -> String {
        // Drop the decimal once the value is large enough that it adds no
        // information ("12K" rather than "12.0K").
        let rounded = (value * 10).rounded() / 10
        if rounded >= 100 || rounded == rounded.rounded() {
            return "\(Int(rounded))\(suffix)"
        }
        return String(format: "%.1f%@", rounded, suffix)
    }
}

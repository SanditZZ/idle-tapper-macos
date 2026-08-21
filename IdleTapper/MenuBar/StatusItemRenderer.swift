//
//  StatusItemRenderer.swift
//  Idle Tapper — Menu bar presentation
//
//  Turns the current count and display style into the status item's title and
//  image. Pure formatting, kept out of the controller so it can be reasoned
//  about and tested on its own.
//
//  ## Why the title is a fixed-width field
//
//  A status item sized to its content changes width as the count changes, and
//  every item to its left slides along with it. During fast tapping that is a
//  constant twitch in the menu bar. Two separate causes:
//
//  1. **Proportional digits.** In the system font a `1` is narrower than an
//     `8`, so even `11 → 12` changes width. Fixed by rendering in a monospaced
//     font.
//  2. **Digit count.** `9 → 10` genuinely needs more room. Fixed by reserving a
//     constant number of character cells and padding the rest.
//
//  Together these guarantee a constant rendered width: every title is exactly
//  `reservedCharacters` cells wide, and in a fully monospaced font every cell —
//  digit, letter or space — has the same advance. The item therefore never
//  resizes, whatever the count.
//
//  This is also why abbreviation is capped at `reservedCharacters`: allowing a
//  five-character form such as "10.5K" would break the guarantee at 10,000.
//

import AppKit

/// Formats the menu bar status item's contents.
enum StatusItemRenderer {

    /// SF Symbol used as the menu bar icon.
    static let symbolName = "hand.tap.fill"

    /// Accessibility description for the icon.
    static let symbolDescription = "Idle Tapper"

    /// Width of the reserved title field, in characters.
    ///
    /// Four cells hold every value `abbreviated(_:)` can produce, from "0"
    /// through "999B", so the item never has to resize. Raising this only adds
    /// empty space; lowering it would reintroduce shifting.
    static let reservedCharacters = 4

    // MARK: - Title

    /// The padded title for a given count, style and goal.
    ///
    /// Always exactly `reservedCharacters` long when the style shows a title,
    /// so the rendered width is constant. Empty when the style hides it.
    ///
    /// - Parameter goal: Today's target, or `0` when none is set. Only
    ///   `goalProgress` reads it, and with no goal that style falls back to the
    ///   count — a status item reading "0%" for a user who never set a target
    ///   looks broken rather than empty.
    static func title(for count: Int, style: MenuBarDisplayStyle, goal: Int = 0) -> String {
        guard style.showsCount else { return "" }

        if style.showsGoalProgress, let target = GoalCalculator.normalized(goal) {
            return pad(percentage(count, of: target))
        }

        return pad(abbreviated(count))
    }

    /// The title as an attributed string in a monospaced font.
    ///
    /// The font is the other half of the no-shift guarantee: padding alone is
    /// not enough, because in a proportional font four characters do not all
    /// occupy the same width. `monospacedDigitSystemFont` is not sufficient
    /// either — it equalises digits but leaves "K", "M" and spaces
    /// proportional.
    static func attributedTitle(
        for count: Int,
        style: MenuBarDisplayStyle,
        goal: Int = 0
    ) -> NSAttributedString {
        let text = title(for: count, style: style, goal: goal)
        guard !text.isEmpty else { return NSAttributedString(string: "") }

        return NSAttributedString(
            string: text,
            attributes: [
                .font: titleFont,
                // Matches the menu bar's own label colour in both appearances.
                .foregroundColor: NSColor.labelColor,
            ]
        )
    }

    /// Font used for the count. Fully monospaced, at the standard system size.
    static var titleFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    }

    // MARK: - Image

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

    // MARK: - Fixed Width

    /// Horizontal padding around the status item's content, matching what
    /// macOS applies to a self-sizing item.
    private static let horizontalInset: CGFloat = 6

    /// Gap between the icon and the count.
    private static let iconTextSpacing: CGFloat = 3

    /// The exact width to pin the status item to, for a given style.
    ///
    /// Padding the title is not quite enough on its own: it keeps the *string*
    /// a constant width, but relies on AppKit measuring trailing spaces rather
    /// than trimming them. Setting the item's length explicitly removes that
    /// assumption — the item occupies the same width no matter what, so nothing
    /// to either side of it can ever move.
    static func statusItemLength(for style: MenuBarDisplayStyle) -> CGFloat {
        var width = horizontalInset * 2

        if style.showsIcon {
            width += image(for: style)?.size.width ?? 18
        }

        if style.showsCount {
            if style.showsIcon { width += iconTextSpacing }
            // Measured against the widest glyph the field can hold. In a
            // monospaced font every character has this same advance.
            let sample = String(repeating: "8", count: reservedCharacters)
            width += NSAttributedString(
                string: sample,
                attributes: [.font: titleFont]
            ).size().width
        }

        return width.rounded(.up)
    }

    // MARK: - Number Formatting

    /// Compact numeric form, guaranteed never longer than `reservedCharacters`.
    ///
    /// Exact below 10,000, then whole-unit abbreviations:
    /// `9999` → "9999", `10500` → "10K", `1_240_000` → "1M", `2e12` → "2T".
    /// Beyond 999 trillion it saturates to "999+".
    ///
    /// The decimal is dropped deliberately. "10.5K" is five characters, which
    /// would force a wider reserved field and leave a visible gap at every
    /// ordinary count. The exact figure is always available in the tooltip and
    /// in the popover, so nothing is actually lost.
    static func abbreviated(_ count: Int) -> String {
        // A negative total is not reachable — taps only ever increment — but
        // clamping keeps the width guarantee true even if that ever changes.
        let value = max(count, 0)

        switch value {
        case ..<10_000:
            return "\(value)"
        case ..<1_000_000:
            return "\(value / 1_000)K"
        case ..<1_000_000_000:
            return "\(value / 1_000_000)M"
        case ..<1_000_000_000_000:
            return "\(value / 1_000_000_000)B"
        default:
            let trillions = value / 1_000_000_000_000
            // "1000T" would be five characters and break the fixed field, so
            // the display saturates. The tooltip still reports the real total.
            return trillions <= 999 ? "\(trillions)T" : "999+"
        }
    }

    /// Progress toward a goal, guaranteed never longer than
    /// `reservedCharacters`.
    ///
    /// "0%" through "999%" — four characters at the widest, which is exactly
    /// the reserved field, so this style needs no change to the width
    /// guarantee. Past 999% it saturates to "max" rather than growing a fifth
    /// character: someone who has done ten times their goal is not waiting on
    /// the precise figure, and the tooltip carries it anyway.
    ///
    /// Not capped at 100%. Overshoot is the interesting part of a goal, and a
    /// bar that sticks at "100%" for the rest of the day says less than one
    /// that keeps climbing.
    static func percentage(_ count: Int, of goal: Int) -> String {
        let percent = GoalCalculator.percent(tapCount: count, goalTarget: goal)
        return percent <= 999 ? "\(percent)%" : "max"
    }

    /// Tooltip shown on hover — always the exact number, grouped for legibility.
    ///
    /// - Parameter goal: Today's target, or `0` for none. When one is set the
    ///   tooltip is where the exact figures live, since the item itself only
    ///   has room for a rounded percentage.
    static func tooltip(for count: Int, goal: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let exact = formatter.string(from: NSNumber(value: count)) ?? "\(count)"

        guard let target = GoalCalculator.normalized(goal) else {
            return "\(exact) taps today"
        }

        let targetText = formatter.string(from: NSNumber(value: target)) ?? "\(target)"
        let percent = GoalCalculator.percent(tapCount: count, goalTarget: target)
        return "\(exact) of \(targetText) taps today — \(percent)%"
    }

    // MARK: - Helpers

    /// Pad to the reserved field width.
    ///
    /// Padding is trailing so the number stays tight against the icon; any
    /// slack sits on the outside where it reads as ordinary menu bar spacing.
    /// A value somehow longer than the field is returned unchanged rather than
    /// truncated — showing the wrong number would be worse than a one-off
    /// resize.
    static func pad(_ text: String) -> String {
        guard text.count < reservedCharacters else { return text }
        return text.padding(
            toLength: reservedCharacters,
            withPad: " ",
            startingAt: 0
        )
    }
}

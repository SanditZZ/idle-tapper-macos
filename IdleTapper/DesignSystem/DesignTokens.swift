//
//  DesignTokens.swift
//  Idle Tapper — Centralized Design System
//
//  Single source of truth for typography, spacing, radii and icon sizing.
//  Views must never hardcode these values; add a token here instead so the
//  whole app restyles from one place.
//

import SwiftUI

/// Centralized design tokens for all Idle Tapper UI.
enum DesignTokens {

    // MARK: - Typography

    enum Typography {
        /// Hero counter shown in the popover (44px, rounded, bold).
        static let counter = Font.system(size: 44, weight: .bold, design: .rounded)

        /// Secondary counter used in compact contexts (28px, rounded, semibold).
        static let counterCompact = Font.system(size: 28, weight: .semibold, design: .rounded)

        /// Main page / window title (18px, semibold).
        static let pageTitle = Font.system(size: 18, weight: .semibold)

        /// Page subtitle (13px, regular).
        static let pageSubtitle = Font.system(size: 13)

        /// Section header, e.g. "Last 7 days" (13px, medium).
        static let sectionTitle = Font.system(size: 13, weight: .medium)

        /// Section subtitle (12px, regular).
        static let sectionSubtitle = Font.system(size: 12)

        /// Body text (12px).
        static let body = Font.system(size: 12)

        /// Emphasised body text (13px, medium).
        static let bodyMedium = Font.system(size: 13, weight: .medium)

        /// Helper text and captions (11px).
        static let caption = Font.system(size: 11)

        /// Very small labels (10px).
        static let tiny = Font.system(size: 10)

        /// Tabular numerals for values that update in place without jitter.
        static let monospacedDigits = Font.system(size: 12, design: .monospaced)

        /// Small tabular numerals.
        static let monospacedDigitsSmall = Font.system(size: 11, design: .monospaced)

        /// Uppercase label above a statistic (10px, semibold).
        static let statLabel = Font.system(size: 10, weight: .semibold)
    }

    // MARK: - Spacing

    enum Spacing {
        /// Gap between major sections (24px).
        static let section: CGFloat = 24

        /// Padding inside a card (16px).
        static let cardPadding: CGFloat = 16

        /// Standard padding (12px).
        static let medium: CGFloat = 12

        /// Tight padding (8px).
        static let small: CGFloat = 8

        /// Hairline padding (4px).
        static let extraSmall: CGFloat = 4

        /// Gap between an icon and its label (10px).
        static let iconText: CGFloat = 10

        /// Fixed width reserved for a leading icon (20px).
        static let iconFrame: CGFloat = 20

        /// Outer padding of the popover (16px).
        static let popoverPadding: CGFloat = 16
    }

    // MARK: - Corner Radius

    enum Radius {
        /// The big tap button (28px) — generously rounded, per the game's core affordance.
        static let tapButton: CGFloat = 28

        /// Card radius (8px).
        static let card: CGFloat = 8

        /// Small radius (6px).
        static let small: CGFloat = 6

        /// Hairline radius (4px).
        static let tiny: CGFloat = 4
    }

    // MARK: - Icons

    enum Icons {
        /// Standard icon size (14px).
        static let standard: CGFloat = 14

        /// Small icon size (12px).
        static let small: CGFloat = 12

        /// Tiny icon size (10px).
        static let tiny: CGFloat = 10
    }

    // MARK: - Layout

    enum Layout {
        /// Popover content width. Kept narrow so the popover reads as a HUD.
        static let popoverWidth: CGFloat = 260

        /// Height of the big tap button.
        static let tapButtonHeight: CGFloat = 120

        /// Height of the 7-day sparkline.
        static let sparklineHeight: CGFloat = 36

        /// Size the History window opens at.
        static let historyWindowSize = CGSize(width: 520, height: 460)

        /// Smallest useful History window. The width matches the default: five
        /// stat tiles sit in one row, and narrowing it only truncates them.
        /// Below this height the chart and the day list fight over the same
        /// space and neither is readable.
        static let historyWindowMinSize = CGSize(width: 520, height: 400)

        /// Size the Settings window opens at.
        ///
        /// Tall enough to show every section without scrolling on a normal
        /// display. The content scrolls, so this is a comfort figure rather
        /// than a constraint — but a window that opens already clipped reads
        /// as broken even when scrolling works.
        static let settingsWindowSize = CGSize(width: 460, height: 620)

        /// Smallest Settings window. The content scrolls below this.
        static let settingsWindowMinSize = CGSize(width: 460, height: 380)
    }

    // MARK: - Animation

    enum Motion {
        /// Spring used for the tap button press/release. Snappy enough to keep up
        /// with fast tapping without feeling mushy.
        static let tapPress = Animation.spring(response: 0.18, dampingFraction: 0.55)

        /// Scale applied to the tap button while pressed.
        static let tapPressedScale: CGFloat = 0.94

        /// Transition for the counter when its value changes.
        static let counterChange = Animation.easeOut(duration: 0.12)
    }
}

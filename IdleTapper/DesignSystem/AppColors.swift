//
//  AppColors.swift
//  Idle Tapper — Semantic color palette
//
//  All colors are translucent or appearance-adaptive so they sit correctly on
//  the popover's vibrancy material in both light and dark mode.
//

import SwiftUI
import AppKit

/// Semantic colors used across the app. Views reference these names, never raw
/// literals, so a palette change lands in one place.
enum AppColors {

    // MARK: - Surfaces

    /// Surface sitting behind the popover's content.
    ///
    /// `NSPopover` supplies a fully translucent backdrop, which meant the
    /// contrast of every label on it was decided by whichever window happened to
    /// be underneath: the same caption measured 3.3:1 over a light desktop and
    /// 2.9:1 over a dark window. Colour alone cannot fix that, because there is
    /// no single colour that is legible against an unknown background.
    ///
    /// This bounds it. The popover keeps a little translucency — it should still
    /// read as a HUD floating over the desktop, not an opaque box — but the
    /// backdrop now contributes a small fraction of the result instead of all of
    /// it, so contrast is a property of the design rather than of what the user
    /// left open behind it.
    static let popoverSurface = Color.adaptivePopoverSurface

    /// Card background — translucent so vibrancy shows through.
    static let cardBackground = Color.primary.opacity(0.04)

    /// Card border — deliberately subtle.
    static let cardBorder = Color.primary.opacity(0.08)

    /// Background of a window's content pane, behind the cards.
    ///
    /// A real window background rather than a translucent one: cards are
    /// themselves translucent, and stacking translucency on translucency makes
    /// their edges disappear into whatever is behind the window.
    static let windowSurface = Color(nsColor: .windowBackgroundColor)

    /// Fill of the selected row in the settings sidebar.
    static let selectionFill = Color.accentColor.opacity(0.16)

    /// Fill of a sidebar row under the pointer.
    static let hoverFill = Color.primary.opacity(0.06)

    /// Hairline divider between regions.
    static let separator = Color.primary.opacity(0.10)

    /// Input field background.
    static let inputBackground = Color.primary.opacity(0.06)

    // MARK: - Interactive Fills

    /// Resting fill of a bordered control.
    static let controlFill = Color.primary.opacity(0.06)

    /// The same control under the pointer.
    static let controlFillHover = Color.primary.opacity(0.10)

    /// The same control while pressed. Deeper than hover, so a press inside a
    /// hover still reads as a state change rather than as nothing happening.
    static let controlFillPressed = Color.primary.opacity(0.16)

    /// Resting fill of a destructive control.
    static let destructiveFill = Color.red.opacity(0.12)

    /// Destructive control under the pointer.
    static let destructiveFillHover = Color.red.opacity(0.18)

    /// Destructive control while pressed.
    static let destructiveFillPressed = Color.red.opacity(0.26)

    /// Background of an inactive bar in the sparkline.
    static let trackBackground = Color.primary.opacity(0.08)

    // MARK: - Brand

    /// Primary action color, driven by the asset catalog accent color.
    ///
    /// Use for fills, bars and tints. For accent-coloured *text* use
    /// `accentOnText` instead — this one is too light to read in light mode.
    static let accent = Color.accentColor

    /// The accent, adjusted so it can be used as text.
    ///
    /// The brand accent is tuned to be legible as a large filled shape, which
    /// makes it too light to read as small text on a light background — the
    /// history window's "today" row measured 2.8:1 against it. This darkens the
    /// light appearance only; in dark mode the accent already reads well and is
    /// left alone.
    static let accentOnText = Color.adaptiveAccentText

    /// Fill of the big tap button.
    static let tapButtonFill = Color.accentColor

    /// Fill of the tap button while pressed — slightly deeper for tactile feedback.
    static let tapButtonPressedFill = Color.accentColor.opacity(0.82)

    /// Label rendered on top of the tap button.
    static let tapButtonLabel = Color.white

    // MARK: - Status

    /// Success / positive trend.
    static let success = Color.adaptiveGreen

    /// Error state.
    static let error = Color.red

    /// Warning state.
    static let warning = Color.orange

    /// Informational state.
    static let info = Color.blue

    // MARK: - Text

    /// Primary text.
    static let textPrimary = Color.primary

    /// Secondary / supporting text.
    ///
    /// Deliberately *not* `Color.secondary`, which measured only 3.0:1 in light
    /// mode against these surfaces.
    static let textSecondary = Color.adaptiveTextSecondary

    /// Tertiary text, e.g. axis labels and the small uppercase stat captions.
    ///
    /// The previous `Color.secondary.opacity(0.7)` measured **2.0:1** in light
    /// mode — an already-faint colour faded further — so every caption using it
    /// was effectively invisible on a light background.
    static let textTertiary = Color.adaptiveTextTertiary

    // MARK: - Data Visualisation

    /// Bar color for a past day in the sparkline.
    static let barPast = Color.accentColor.opacity(0.45)

    /// Bar color for today in the sparkline — the emphasised bar.
    static let barToday = Color.accentColor

    /// Bar color for a day with zero taps.
    ///
    /// At the previous 0.10 these measured 1.2:1 and were invisible rather than
    /// subtle, which defeats the point of drawing them — they exist so the
    /// timeline stays continuous and a gap reads as a gap. Still deliberately
    /// quiet: an empty day should never compete with a real one.
    static let barEmpty = Color.primary.opacity(0.28)

    // MARK: - Helpers

    /// A translucent tint of any color, for badge backgrounds and soft fills.
    static func tint(_ color: Color, opacity: Double = 0.12) -> Color {
        color.opacity(opacity)
    }
}

// MARK: - Adaptive Colors

extension Color {
    /// Green with good contrast in both appearances. The system green is too
    /// light to read against light translucent surfaces, so light mode uses a
    /// darker forest green.
    static let adaptiveGreen = Color(nsColor: .adaptiveGreen)

    /// See `AppColors.accentOnText`.
    static let adaptiveAccentText = Color(nsColor: .adaptiveAccentText)

    /// See `AppColors.textSecondary`.
    static let adaptiveTextSecondary = Color(nsColor: .adaptiveTextSecondary)

    /// See `AppColors.textTertiary`.
    static let adaptiveTextTertiary = Color(nsColor: .adaptiveTextTertiary)

    /// See `AppColors.popoverSurface`.
    static let adaptivePopoverSurface = Color(nsColor: .adaptivePopoverSurface)
}

extension NSColor {
    /// See `Color.adaptiveGreen`.
    static let adaptiveGreen = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 60 / 255, green: 199 / 255, blue: 95 / 255, alpha: 1.0)
            : NSColor(srgbRed: 27 / 255, green: 107 / 255, blue: 52 / 255, alpha: 1.0)
    }

    /// See `AppColors.accentOnText`. The dark value matches the asset catalog's
    /// dark accent, so accent text and accent fills stay the same colour there;
    /// only light mode is darkened, and only enough to clear 4.5:1.
    static let adaptiveAccentText = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 90 / 255, green: 150 / 255, blue: 255 / 255, alpha: 1.0)
            : NSColor(srgbRed: 24 / 255, green: 64 / 255, blue: 190 / 255, alpha: 1.0)
    }

    /// See `AppColors.textSecondary` and `AppColors.textTertiary`.
    ///
    /// The two appearances need different amounts, which is why a single
    /// `Color.primary.opacity(…)` cannot serve both. Fading white toward a dark
    /// background loses contrast far more slowly than fading black toward a
    /// light one, so a value that reads well in dark mode is still too faint in
    /// light. These were tuned against measured screenshots of the real windows
    /// rather than derived, because the popover's translucency puts the actual
    /// backdrop somewhere between the material and whatever sits behind it.
    static let adaptiveTextSecondary = NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 1.0, alpha: 0.78) : NSColor(white: 0.0, alpha: 0.88)
    }

    /// See `adaptiveTextSecondary`.
    static let adaptiveTextTertiary = NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 1.0, alpha: 0.62) : NSColor(white: 0.0, alpha: 0.72)
    }

    /// See `AppColors.popoverSurface`.
    ///
    /// The greys match what the popover's own material measures against a
    /// neutral backdrop, so this reads as the surface the design already had —
    /// only now it stays that colour. The alpha is the whole point: at 0.92 the
    /// window behind contributes 8% of the result rather than 100%, which turns
    /// a 60-level swing in background brightness into about 5.
    static let adaptivePopoverSurface = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(white: 0.137, alpha: 0.92)
            : NSColor(white: 0.925, alpha: 0.92)
    }
}

extension NSAppearance {
    /// Whether this appearance is one of the dark ones.
    ///
    /// `bestMatch` rather than comparing `name` directly, because the popover
    /// and the windows report different appearance names for the same
    /// appearance — vibrant dark is still dark.
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

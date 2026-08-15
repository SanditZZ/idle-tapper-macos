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

    /// Card border.
    ///
    /// The previous `Color.primary.opacity(0.08)` was not drawn in either
    /// appearance: measured against the real window, the content pane ran
    /// straight into the card fill with no border pixel at all — 236 → 229 in
    /// light and 50 → 58 in dark. A card that declares a stroke and renders
    /// none is worse than one that declares nothing, because the next person
    /// reads the code and believes it.
    ///
    /// See `separator` for where these numbers come from. System Settings puts
    /// its own card stroke 11 levels below its card in light and 37 above it in
    /// dark — far stronger than a separator, because this edge is what gives a
    /// card its shape.
    static let cardBorder = Color.adaptiveCardBorder

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

    /// Hairline between rows inside one surface — a card's settings, the day
    /// list, the popover's footer. Always drawn through `AppDivider`.
    ///
    /// Contrast *against the surface*, not a fixed tone: darker in light,
    /// lighter in dark, which is how `NSColor.separatorColor` behaves and how
    /// every rule inside a native window reads.
    ///
    /// The values are measured from System Settings rather than derived, the
    /// same way `adaptiveTextSecondary` was. On its card — 233.9 in light,
    /// 45.3 in dark — the system's row separator lands at 224.0 and 57.1.
    /// `separatorColor` itself is too strong for this job at 0.098: it would
    /// give 211.0 and 65.9, roughly twice the step in both directions.
    ///
    /// **Why this is not `Color.primary.opacity(0.10)` any more.** `primary`
    /// flips to white in dark mode, so that one token recessed a line in light
    /// and raised a *bright ridge* in dark. The Settings sidebar edge measured
    /// 62.9 between surfaces of 41.1 and 50.0 — a line lighter than both
    /// things it divides, which is the opposite of what a separator is for.
    static let separator = Color.adaptiveSeparator

    /// The seam where two panes meet — the Settings sidebar against the page
    /// beside it.
    ///
    /// Deliberately **not** `separator`, and the distinction is not cosmetic.
    /// A rule inside a surface takes its contrast from that surface and so
    /// flips with the appearance; a pane edge is a *recess* and stays dark in
    /// both. System Settings' own split divider measures 218.9 between panes of
    /// 231.2 and 237.9 in light, and drops to near black between panes of 74.9
    /// and 41.3 in dark.
    ///
    /// It also has to work when the two panes are close in tone. The sidebar is
    /// a vibrancy material and the page behind it is not, so their relationship
    /// depends on the desktop picture: the sidebar measured warm 42/41/39
    /// against a neutral 50/50/50 page, and a lighter wallpaper moves it the
    /// other way. A recess reads correctly whichever way that lands.
    static let paneSeam = Color.adaptivePaneSeam

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

    // MARK: - Achievement Tiers

    /// Bronze tier — the entry band.
    static let tierBronze = Color.adaptiveTierBronze

    /// Silver tier.
    static let tierSilver = Color.adaptiveTierSilver

    /// Gold tier — the hardest band.
    static let tierGold = Color.adaptiveTierGold

    /// The colour standing for a tier, used for its section heading and for
    /// the badge of an unlocked achievement in it.
    static func tier(_ tier: AchievementTier) -> Color {
        switch tier {
        case .bronze: tierBronze
        case .silver: tierSilver
        case .gold: tierGold
        }
    }

    // MARK: - Data Visualisation

    /// Bar color for a past day in the sparkline.
    static let barPast = Color.accentColor.opacity(0.45)

    /// Bar color for today in the sparkline — the emphasised bar.
    static let barToday = Color.accentColor

    /// The chart's baseline rule.
    ///
    /// This replaced a per-day "empty bar". A zero day used to be drawn as its
    /// own 2pt stub so the timeline stayed continuous, which reads fine for one
    /// gap and badly for many: over a 30-day range with taps on two days, the
    /// other 28 stubs lined up into what looked like a dashed axis rule drawn
    /// across the card. The emptier the history, the more the chart looked
    /// broken — worst exactly when a user is new.
    ///
    /// One continuous rule says "this is the baseline" deliberately, and a day
    /// with no taps simply contributes no bar. Quiet enough that it never
    /// competes with a real bar, but not so faint it vanishes in light mode.
    static let chartBaseline = Color.primary.opacity(0.14)

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

    /// See `AppColors.separator`.
    static let adaptiveSeparator = Color(nsColor: .adaptiveSeparator)

    /// See `AppColors.paneSeam`.
    static let adaptivePaneSeam = Color(nsColor: .adaptivePaneSeam)

    /// See `AppColors.cardBorder`.
    static let adaptiveCardBorder = Color(nsColor: .adaptiveCardBorder)

    /// See `AppColors.tierBronze`.
    static let adaptiveTierBronze = Color(nsColor: .adaptiveTierBronze)

    /// See `AppColors.tierSilver`.
    static let adaptiveTierSilver = Color(nsColor: .adaptiveTierSilver)

    /// See `AppColors.tierGold`.
    static let adaptiveTierGold = Color(nsColor: .adaptiveTierGold)
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

    /// See `AppColors.separator`.
    ///
    /// Alphas rather than tones, so one token holds its *relationship* to
    /// whatever surface it is drawn on. Solved from the measured targets: on a
    /// 233.9 card, black at 0.042 gives 224.0; on a 45.3 card, white at 0.056
    /// gives 57.1. Both land within a level of the system's own separator.
    static let adaptiveSeparator = NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 1.0, alpha: 0.056) : NSColor(white: 0.0, alpha: 0.042)
    }

    /// See `AppColors.paneSeam`.
    ///
    /// Black in both appearances — that is the whole point of the token. Light
    /// mode needs very little of it, because the panes it sits between are
    /// already near white; dark mode needs a great deal, because a faint black
    /// over a dark pane is indistinguishable from the pane.
    static let adaptivePaneSeam = NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 0.0, alpha: 0.72) : NSColor(white: 0.0, alpha: 0.08)
    }

    /// See `AppColors.cardBorder`.
    ///
    /// The asymmetry is real and is the same effect described on
    /// `adaptiveTextSecondary`: an equal alpha does not buy an equal step in
    /// both appearances. Solved from the measured native stroke — 11 levels
    /// below a 233.9 card in light, 37 above a 45.3 one in dark.
    static let adaptiveCardBorder = NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 1.0, alpha: 0.19) : NSColor(white: 0.0, alpha: 0.05)
    }

    /// See `AppColors.tierBronze`, `tierSilver` and `tierGold`.
    ///
    /// Metallics, not the system palette: bronze and gold are both oranges and
    /// silver is a grey, so the obvious `.brown` / `.gray` / `.yellow` would
    /// have put two nearly identical hues on adjacent sections and a third
    /// that is unreadable as small text in light mode.
    ///
    /// Each is given a light and a dark value for the reason set out on
    /// `adaptiveTextSecondary`: these are rendered as section headings as well
    /// as badge fills, so both ends have to clear 4.5:1 against the surface
    /// they sit on. The light values are darkened metallics — gold at its
    /// natural brightness measures under 3:1 on a light card — and the dark
    /// ones are lightened, which is also what makes them read as metal rather
    /// than as flat brown, grey and yellow.
    static let adaptiveTierBronze = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 214 / 255, green: 154 / 255, blue: 108 / 255, alpha: 1.0)
            : NSColor(srgbRed: 138 / 255, green: 74 / 255, blue: 26 / 255, alpha: 1.0)
    }

    /// See `adaptiveTierBronze`.
    static let adaptiveTierSilver = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 190 / 255, green: 198 / 255, blue: 208 / 255, alpha: 1.0)
            : NSColor(srgbRed: 92 / 255, green: 102 / 255, blue: 112 / 255, alpha: 1.0)
    }

    /// See `adaptiveTierBronze`.
    static let adaptiveTierGold = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 235 / 255, green: 186 / 255, blue: 74 / 255, alpha: 1.0)
            : NSColor(srgbRed: 138 / 255, green: 97 / 255, blue: 8 / 255, alpha: 1.0)
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

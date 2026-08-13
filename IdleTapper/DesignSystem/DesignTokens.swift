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

        /// Main page / window title (20px, semibold).
        ///
        /// 20 rather than 18: at 18 the title sat only a point above
        /// `bodyMedium`, so a page read as a list of similarly-sized lines with
        /// no clear top. The jump is what makes the hierarchy legible at a
        /// glance.
        static let pageTitle = Font.system(size: 20, weight: .semibold)

        /// Page subtitle (13px, regular).
        static let pageSubtitle = Font.system(size: 13)

        /// Title of a card grouping related controls (14px, semibold).
        static let cardTitle = Font.system(size: 14, weight: .semibold)

        /// Section header, e.g. "Last 7 days" (13px, medium).
        static let sectionTitle = Font.system(size: 13, weight: .medium)

        /// Section subtitle (12px, regular).
        static let sectionSubtitle = Font.system(size: 12)

        /// A row in the settings sidebar (13px, medium).
        static let sidebarItem = Font.system(size: 13, weight: .medium)

        /// Body text (13px).
        ///
        /// 13 is the macOS system size. The previous 12 was a point under every
        /// stock control the app puts beside it, so a label and its own toggle
        /// disagreed about how big text is.
        static let body = Font.system(size: 13)

        /// Small label, for control captions sitting under a body line (12px).
        static let label = Font.system(size: 12)

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
        ///
        /// Only ever rendered through `StatTile`, which uppercases it. For a
        /// sentence-case heading introducing a section, use `sectionLabel`.
        static let statLabel = Font.system(size: 10, weight: .semibold)

        /// Heading introducing a section of a panel, e.g. "Today" (11px, semibold).
        ///
        /// Deliberately not `statLabel`. The popover used that token for both
        /// "Today" and the `ALL TIME` / `BEST DAY` captions beside it, so one
        /// token produced small uppercase captions in one place and sentence
        /// case in another — the same name meaning two different treatments.
        /// A point larger, because these headings are read rather than scanned.
        static let sectionLabel = Font.system(size: 11, weight: .semibold)
    }

    // MARK: - Spacing

    /// Spacing on a 4px grid. Every value here is a multiple of 4, so anything
    /// placed against anything else lines up without one-off nudges.
    enum Spacing {

        // MARK: Grid

        /// 4px.
        static let extraSmall: CGFloat = 4

        /// 8px.
        static let small: CGFloat = 8

        /// 12px.
        static let medium: CGFloat = 12

        /// 16px.
        static let large: CGFloat = 16

        /// 20px.
        static let extraLarge: CGFloat = 20

        /// 24px.
        static let huge: CGFloat = 24

        // MARK: Semantic

        /// Gap between major sections (24px).
        static let section: CGFloat = 24

        /// Padding inside a card (20px).
        ///
        /// 16 read as cramped once cards carried a title as well as controls:
        /// the title sat almost against the card's own edge. The reference this
        /// design follows uses 20 for the same reason.
        static let cardPadding: CGFloat = 20

        /// Gap between stacked cards (16px).
        static let cardSpacing: CGFloat = 16

        /// Padding from a window's edge to its content (28px).
        static let contentPadding: CGFloat = 28

        /// Gap between a control and the caption explaining it (4px).
        static let controlCaption: CGFloat = 4

        /// Gap between an icon and its label (10px).
        static let iconText: CGFloat = 10

        /// Fixed width reserved for a leading icon (20px).
        static let iconFrame: CGFloat = 20

        /// Outer padding of the popover (16px).
        ///
        /// Deliberately tighter than `contentPadding`: the popover is a HUD at
        /// a fixed narrow width, and window-sized padding would eat it.
        static let popoverPadding: CGFloat = 16
    }

    // MARK: - Corner Radius

    enum Radius {
        /// The big tap button (28px) — generously rounded, per the game's core affordance.
        static let tapButton: CGFloat = 28

        /// Card radius (12px).
        ///
        /// The single most visible token in the restyle. At 8 the cards read as
        /// boxes; 12 is what makes the surface look current, and it matches the
        /// radius the tap button already implied.
        static let card: CGFloat = 12

        /// Radius for a control-sized surface: a button, a field, a sidebar row (8px).
        static let control: CGFloat = 8

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

        /// Height of the sparkline when it is the History window's main chart.
        static let historyChartHeight: CGFloat = 90

        /// Thickness of the chart's baseline rule.
        static let chartBaselineThickness: CGFloat = 1

        /// Shortest a bar may be drawn when the day it represents has taps.
        ///
        /// One tap against a peak of a few thousand rounds to a fraction of a
        /// point and would disappear entirely, so a real day would read as an
        /// empty one. This floor only ever applies to a day that has taps — a
        /// zero day draws no bar at all and is represented by the baseline.
        static let minimumBarHeight: CGFloat = 2

        /// Height of one row in the History window's day list, including the
        /// divider under it. Used to size the list to its content — see
        /// `HistoryLayout.listHeight(rowCount:rowHeight:)`.
        static let historyRowHeight: CGFloat = 33

        /// Height reserved for the History window's "no taps yet" placeholder.
        ///
        /// The list no longer stretches to fill the window, so the empty state
        /// needs a height of its own or it collapses to the height of its own
        /// text and the card round it shrinks to a strip.
        static let historyEmptyStateHeight: CGFloat = 150

        /// Size the History window opens at.
        ///
        /// 560 rather than 520: at 520 the five stat tiles each got about 82pt,
        /// which is narrower than the longest caption, so the window opened with
        /// "CURRENT ST…" and "LONGEST STR…" already truncated.
        ///
        /// Grown from 560x460 for the card layout: the content now sits inside
        /// a 28pt page margin and a 20pt card margin, so the five stat tiles
        /// have ~96pt less room than they used to at the same window width.
        static let historyWindowSize = CGSize(width: 660, height: 580)

        /// Smallest useful History window.
        ///
        /// Narrower than the default so the window can actually be resized, but
        /// not so narrow that the five stat tiles start truncating their
        /// captions. Below this height the chart and the day list fight over
        /// the same space and neither is readable.
        static let historyWindowMinSize = CGSize(width: 620, height: 480)

        /// Vertical room a window's content must leave clear at the top when it
        /// draws under the title bar, so nothing lands beneath the traffic
        /// lights. Standard title bar height is 28; this leaves a little air.
        static let titleBarInset: CGFloat = 38

        /// Width of the Settings sidebar.
        ///
        /// Sized to the longest item label plus its icon at `sidebarItem`, so
        /// no row truncates and the list does not float in dead space.
        static let settingsSidebarWidth: CGFloat = 190

        /// Size the Settings window opens at.
        ///
        /// Wider and shorter than the old single-column window: the sidebar
        /// takes 190 of the width, and splitting five sections across pages
        /// means no page needs the 700 height the stacked layout did.
        ///
        /// Each page still scrolls, so the height is a comfort figure rather
        /// than a limit — but a window that opens already clipped reads as
        /// broken even when scrolling works, which is why this is measured
        /// against the tallest page rather than guessed.
        ///
        /// 700 is that measurement, and **General** is what it is measured
        /// against. Data used to be the tallest page and set 620; folding the
        /// menu bar picker into General made General taller than Data, and at
        /// 620 it opened with "Restore Defaults" cut off by the window's own
        /// edge — the same failure Data had at 540, in a new place.
        ///
        /// So: whenever a card moves between pages, re-measure. The height is a
        /// property of the tallest page, not a number that stays true because it
        /// was true once.
        static let settingsWindowSize = CGSize(width: 720, height: 700)

        /// Smallest Settings window.
        ///
        /// Deliberately *not* equal to the default. When the two match, a
        /// window that fails to apply its size looks correct anyway — which is
        /// exactly how the `contentViewController` sizing bug survived from the
        /// first build until it was measured.
        static let settingsWindowMinSize = CGSize(width: 600, height: 420)

        /// Size the Achievements window opens at.
        ///
        /// Wide enough for a two-column card grid at `settingsSidebarWidth`-ish
        /// card widths without either column's progress bar looking cramped.
        static let achievementsWindowSize = CGSize(width: 560, height: 620)

        /// Smallest Achievements window. Below this the two-column grid starts
        /// squeezing a card's title and detail onto the same line as its icon.
        static let achievementsWindowMinSize = CGSize(width: 460, height: 420)
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

        /// The particle burst played when today's count crosses a milestone.
        ///
        /// These sit here rather than beside the maths in `ParticleBurst` so a
        /// tuning pass — fewer particles, a shorter burst, less gravity — is a
        /// design change in the design system, not an edit to a tested
        /// calculation. `ParticleBurst` reads them and stays pure.
        enum MilestoneBurst {

            /// Particles drawn per burst.
            ///
            /// Capped deliberately, and low. The burst fires at exactly the
            /// moment the user is tapping fastest, so it competes with the tap
            /// path for frames on whatever GPU the machine has — and in a
            /// 260pt popover, more than this reads as noise rather than as
            /// more celebration.
            static let particleCount = 28

            /// Total length of the burst.
            ///
            /// `ParticleBurst` guarantees every particle is fully transparent
            /// at this point, which is what lets the view stop its draw loop
            /// here instead of animating forever.
            static let duration: TimeInterval = 0.9

            /// Fraction of `duration` particles stay fully opaque for before
            /// they begin fading. Fading from the very first frame makes the
            /// burst look weak; holding then fading reads as a burst.
            static let fadeBegins: Double = 0.58

            /// Drawn radius range, in points.
            static let minimumRadius: CGFloat = 1.6
            static let maximumRadius: CGFloat = 3.4

            /// Initial speed range, in points per second.
            static let minimumSpeed: Double = 95
            static let maximumSpeed: Double = 285

            /// Downward acceleration, in points per second squared.
            static let gravity: Double = 420

            /// Linear drag coefficient. Without it every particle travels in a
            /// clean parabola and the burst looks like a fountain; with it they
            /// shoot out and settle, which is what a burst does.
            static let drag: Double = 1.8

            /// Angular spread, in radians, centred on straight up.
            ///
            /// Just under a full circle, so the burst radiates the way a burst
            /// does — the narrow wedge left out is the one pointing straight
            /// down, which is the only direction that would read as the button
            /// leaking rather than celebrating.
            static let spread: Double = .pi * 1.9

            /// How far the emission point is scattered around the origin, so
            /// the particles do not all appear from a single pixel.
            static let originJitter = CGSize(width: 60, height: 30)

            /// Maximum spin, in radians per second, applied to the
            /// non-circular particles.
            static let maximumSpin: Double = 6
        }
    }
}

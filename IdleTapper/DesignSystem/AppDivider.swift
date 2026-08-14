//
//  AppDivider.swift
//  Idle Tapper — The one separator
//
//  Every rule in the app is drawn by this view. It exists because the app had
//  five treatments of the same idea — a bare `Divider()`, `Divider()` at 0.5,
//  `Divider()` at 0.3 in two places, and a hand-rolled 1pt `Rectangle` — so
//  "the line between two things" looked different in every window, and no view
//  could tell which one it was supposed to be copying.
//
//  A plain `Divider()` cannot be used instead: it cannot be recoloured (an
//  `.overlay` tint composites *on top of* the system line rather than replacing
//  it, so a translucent token would compound with it), and the sidebar seam
//  needs a colour the system divider does not offer.
//

import SwiftUI

/// A hairline rule, one device pixel thick.
struct AppDivider: View {

    /// What the rule is separating. This decides its colour, and the two are
    /// genuinely different jobs — see `AppColors.paneSeam`.
    enum Role {
        /// A rule between rows inside one surface: a card's settings, the day
        /// list, the popover's footer.
        case content
        /// The seam where two panes meet — the Settings sidebar against the
        /// page beside it.
        case paneSeam
    }

    enum Axis {
        case horizontal
        case vertical
    }

    var role: Role = .content
    var axis: Axis = .horizontal

    /// Points-to-pixels ratio of the display this view is on, so the rule is a
    /// true hairline on Retina rather than a doubled 2px line.
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(
                width: axis == .vertical ? thickness : nil,
                height: axis == .horizontal ? thickness : nil
            )
            // A rule carries no information VoiceOver can use, and left visible
            // to it each one becomes its own stop between the rows it divides.
            .accessibilityHidden(true)
    }

    private var thickness: CGFloat {
        HairlineMetrics.thickness(displayScale: displayScale)
    }

    private var color: Color {
        switch role {
        case .content: AppColors.separator
        case .paneSeam: AppColors.paneSeam
        }
    }
}

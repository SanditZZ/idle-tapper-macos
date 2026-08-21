//
//  MenuBarDisplayStyle.swift
//  Idle Tapper — Models
//

import Foundation

/// How the status item presents itself in the menu bar.
enum MenuBarDisplayStyle: String, CaseIterable, Identifiable, Sendable {
    /// Icon only — the most compact, for crowded menu bars.
    case iconOnly
    /// Icon plus today's running total.
    case iconAndCount
    /// Today's total only.
    case countOnly
    /// Icon plus progress toward today's goal, as a percentage.
    ///
    /// Falls back to the count when no goal is set — see
    /// `StatusItemRenderer.title(for:style:goal:)`. A style that renders "0%"
    /// forever because the user never set a target would look broken.
    case goalProgress

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iconOnly: return "Icon only"
        case .iconAndCount: return "Icon and count"
        case .countOnly: return "Count only"
        case .goalProgress: return "Goal progress"
        }
    }

    var showsIcon: Bool {
        self != .countOnly
    }

    /// Whether the status item renders a title at all.
    ///
    /// True for `goalProgress`, whose title is a percentage rather than a
    /// count. What the title actually says is `StatusItemRenderer`'s decision,
    /// not this one.
    var showsCount: Bool {
        self != .iconOnly
    }

    /// Whether the title is progress toward the goal rather than a raw total.
    var showsGoalProgress: Bool {
        self == .goalProgress
    }
}

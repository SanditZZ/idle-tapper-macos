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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iconOnly: return "Icon only"
        case .iconAndCount: return "Icon and count"
        case .countOnly: return "Count only"
        }
    }

    var showsIcon: Bool {
        self != .countOnly
    }

    var showsCount: Bool {
        self != .iconOnly
    }
}

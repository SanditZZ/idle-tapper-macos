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

    /// Card background — translucent so vibrancy shows through.
    static let cardBackground = Color.primary.opacity(0.04)

    /// Card border — deliberately subtle.
    static let cardBorder = Color.primary.opacity(0.08)

    /// Input field background.
    static let inputBackground = Color.primary.opacity(0.06)

    /// Background of an inactive bar in the sparkline.
    static let trackBackground = Color.primary.opacity(0.08)

    // MARK: - Brand

    /// Primary action color, driven by the asset catalog accent color.
    static let accent = Color.accentColor

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
    static let textSecondary = Color.secondary

    /// Tertiary text, e.g. axis labels.
    static let textTertiary = Color.secondary.opacity(0.7)

    // MARK: - Data Visualisation

    /// Bar color for a past day in the sparkline.
    static let barPast = Color.accentColor.opacity(0.45)

    /// Bar color for today in the sparkline — the emphasised bar.
    static let barToday = Color.accentColor

    /// Bar color for a day with zero taps.
    static let barEmpty = Color.primary.opacity(0.10)

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
}

extension NSColor {
    /// See `Color.adaptiveGreen`.
    static let adaptiveGreen = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: 60 / 255, green: 199 / 255, blue: 95 / 255, alpha: 1.0)
        } else {
            return NSColor(red: 27 / 255, green: 107 / 255, blue: 52 / 255, alpha: 1.0)
        }
    }
}

//
//  HairlineMetrics.swift
//  Idle Tapper — How thick a hairline is
//
//  A separator is one *device* pixel, not one point. On a Retina display those
//  are not the same thing: a 1pt line is two device pixels, which is twice the
//  weight macOS draws its own separators at, and the difference is only visible
//  on hardware the developer may not have.
//

import CoreGraphics

/// Thickness of a hairline rule.
enum HairlineMetrics {

    /// One device pixel, expressed in points.
    ///
    /// - Parameter displayScale: Points-to-pixels ratio of the display the view
    ///   is on — 1 on a non-Retina display, 2 on a Retina one.
    ///
    /// A scale of zero or less cannot be honoured and would divide by zero or
    /// return a negative thickness, so it falls back to a 1pt line: visible and
    /// slightly heavy is a far better failure than an invisible separator or a
    /// crash. SwiftUI supplies a sane `displayScale`, but this reads from the
    /// environment and a default-constructed environment is not guaranteed to.
    static func thickness(displayScale: CGFloat) -> CGFloat {
        guard displayScale > 0 else { return 1 }
        return 1 / displayScale
    }
}

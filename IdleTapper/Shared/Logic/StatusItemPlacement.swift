//
//  StatusItemPlacement.swift
//  Idle Tapper — Calculations (pure)
//
//  Works out whether the menu bar status item ended up somewhere the user can
//  actually see it.
//
//  On a Mac with a notch, a full menu bar leaves no room to the right of the
//  camera housing, and macOS positions the overflow status item *behind* it.
//  The item reports itself as visible, is correctly sized and correctly
//  titled — it is simply covered by hardware. From the user's point of view
//  the app appears not to have launched at all.
//

import Foundation

/// Where the status item landed, and whether that is a problem.
enum StatusItemPlacement {

    /// The outcome of a placement check.
    enum Result: Equatable {
        /// The item is somewhere the user can see it.
        case visible
        /// The item is behind the display notch and cannot be seen.
        case behindNotch
        /// The item has no frame yet, or sits outside the screen entirely.
        case offScreen
    }

    /// Classify a status item's placement.
    ///
    /// - Parameters:
    ///   - itemFrame: Frame of the status item's window, in screen coordinates.
    ///   - leftArea: The usable menu bar region left of the notch
    ///     (`NSScreen.auxiliaryTopLeftArea`). `nil` on a screen with no notch.
    ///   - rightArea: The usable region right of the notch
    ///     (`NSScreen.auxiliaryTopRightArea`). `nil` on a screen with no notch.
    ///   - screenFrame: Full frame of the screen.
    static func classify(
        itemFrame: CGRect,
        leftArea: CGRect?,
        rightArea: CGRect?,
        screenFrame: CGRect
    ) -> Result {
        // A zero-width item has not been laid out yet; treat it as unknown
        // rather than reporting a false problem.
        guard itemFrame.width > 0 else { return .offScreen }

        guard itemFrame.minX >= screenFrame.minX, itemFrame.maxX <= screenFrame.maxX else {
            return .offScreen
        }

        // No notch means no way to be hidden by one.
        guard let leftArea, let rightArea else { return .visible }

        // The notch occupies the gap between the two usable areas. An item
        // overlapping that gap is behind the camera housing.
        let notchStart = leftArea.maxX
        let notchEnd = rightArea.minX
        guard notchEnd > notchStart else { return .visible }

        let overlapsNotch = itemFrame.maxX > notchStart && itemFrame.minX < notchEnd
        return overlapsNotch ? .behindNotch : .visible
    }
}

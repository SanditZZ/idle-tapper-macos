//
//  StatusItemPlacementTests.swift
//  IdleTapperTests
//
//  The numbers below are taken from a real 16-inch MacBook Pro on which the
//  status item was placed behind the notch: screen 1728 points wide, notch
//  centred on 864, item at x=858 width=46.
//

import Testing
import Foundation
@testable import IdleTapper

@Suite("Status item placement")
struct StatusItemPlacementTests {

    /// A notched display: 1728 points wide with a roughly 190-point notch.
    private enum NotchedScreen {
        static let frame = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        static let left = CGRect(x: 0, y: 1085, width: 769, height: 32)
        static let right = CGRect(x: 959, y: 1085, width: 769, height: 32)
    }

    @Test("An item straddling the notch is reported as hidden")
    func itemBehindNotch() {
        let result = StatusItemPlacement.classify(
            itemFrame: CGRect(x: 858, y: 1085, width: 46, height: 32),
            leftArea: NotchedScreen.left,
            rightArea: NotchedScreen.right,
            screenFrame: NotchedScreen.frame
        )

        #expect(result == .behindNotch)
    }

    @Test("An item to the right of the notch is visible")
    func itemRightOfNotch() {
        let result = StatusItemPlacement.classify(
            itemFrame: CGRect(x: 1043, y: 1085, width: 46, height: 32),
            leftArea: NotchedScreen.left,
            rightArea: NotchedScreen.right,
            screenFrame: NotchedScreen.frame
        )

        #expect(result == .visible)
    }

    @Test("An item ending exactly where the notch begins is visible")
    func itemTouchingNotchEdge() {
        let result = StatusItemPlacement.classify(
            itemFrame: CGRect(x: 723, y: 1085, width: 46, height: 32),
            leftArea: NotchedScreen.left,
            rightArea: NotchedScreen.right,
            screenFrame: NotchedScreen.frame
        )

        #expect(result == .visible, "Boundaries are exclusive — a flush fit is not obscured")
    }

    @Test("A screen with no notch never reports a hidden item")
    func screenWithoutNotch() {
        let result = StatusItemPlacement.classify(
            itemFrame: CGRect(x: 858, y: 1085, width: 46, height: 32),
            leftArea: nil,
            rightArea: nil,
            screenFrame: NotchedScreen.frame
        )

        #expect(result == .visible)
    }

    @Test("An unlaid-out item is not mistaken for a hidden one")
    func zeroWidthItem() {
        let result = StatusItemPlacement.classify(
            itemFrame: CGRect(x: 0, y: 0, width: 0, height: 0),
            leftArea: NotchedScreen.left,
            rightArea: NotchedScreen.right,
            screenFrame: NotchedScreen.frame
        )

        #expect(result == .offScreen, "A zero-width frame means layout has not settled yet")
    }

    @Test("An item beyond the screen edge is reported as off screen")
    func itemOffScreen() {
        let result = StatusItemPlacement.classify(
            itemFrame: CGRect(x: 1700, y: 1085, width: 46, height: 32),
            leftArea: NotchedScreen.left,
            rightArea: NotchedScreen.right,
            screenFrame: NotchedScreen.frame
        )

        #expect(result == .offScreen)
    }
}

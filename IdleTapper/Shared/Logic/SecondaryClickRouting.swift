//
//  SecondaryClickRouting.swift
//  Idle Tapper — Calculations (pure)
//
//  Decides whether a right-click the app has seen belongs to the tap button.
//
//  ## Why this exists as a calculation
//
//  The tap button counts on press-down via a `DragGesture`, and a `DragGesture`
//  never receives right-clicks — SwiftUI has no gesture that does. Seeing one at
//  all means an AppKit event monitor, and a monitor sees *every* right-click the
//  app receives, including the one on the menu bar status item that opens
//  History, Settings and Quit.
//
//  So the safety of the whole feature rests on one predicate: claim the click
//  only when it is in the button's own window and inside the button's own
//  bounds. Wrong in the permissive direction and the status item's context menu
//  stops working — an accessory app's only route to its other windows, and a far
//  worse outcome than the feature simply not working. That is why the rule lives
//  here, with tests, rather than inline in the view.
//

import AppKit

/// Whether a right-click belongs to the tap button.
enum SecondaryClickRouting {

    /// Whether the observed event should register a tap and be consumed.
    ///
    /// All three conditions are required, and each rules out a specific way of
    /// getting this wrong:
    ///
    /// - the press rather than the release, so one click counts once — matching
    ///   the left-click path, which counts on the way down;
    /// - the button's own window, so a right-click on the status item still
    ///   reaches the context menu;
    /// - the button's own bounds, so a right-click elsewhere in the popover is
    ///   left alone.
    ///
    /// - Parameters:
    ///   - eventType: Type of the observed event, or `nil` if there is none.
    ///   - isInOwningWindow: Whether the event was sent to the window the button
    ///     is currently in.
    ///   - isWithinButton: Whether the event's location falls inside the
    ///     button's bounds.
    static func registersTap(
        eventType: NSEvent.EventType?,
        isInOwningWindow: Bool,
        isWithinButton: Bool
    ) -> Bool {
        guard eventType == .rightMouseDown else { return false }
        return isInOwningWindow && isWithinButton
    }
}

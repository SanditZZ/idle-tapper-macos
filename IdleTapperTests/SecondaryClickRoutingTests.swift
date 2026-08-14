//
//  SecondaryClickRoutingTests.swift
//  IdleTapperTests
//
//  Right-clicking the tap button is delivered by an event monitor, and a monitor
//  sees every right-click the app receives — including the one on the status
//  item that opens History, Settings and Quit. Claiming one click too many takes
//  away an accessory app's only route to its other windows, which is worse than
//  the feature not existing. This is the predicate that prevents it.
//

import Testing
import AppKit
@testable import IdleTapper

@Suite("Secondary click routing")
struct SecondaryClickRoutingTests {

    // MARK: - Claiming

    @Test("A right-click on the button counts a tap")
    func rightClickOnButtonCounts() {
        #expect(
            SecondaryClickRouting.registersTap(
                eventType: .rightMouseDown,
                isInOwningWindow: true,
                isWithinButton: true
            )
        )
    }

    // MARK: - Leaving the Status Item Alone

    @Test("A right-click in another window is never claimed")
    func otherWindowIsLeftAlone() {
        // This is the one that matters. The status item's context menu is
        // raised by a right-click in a different window, and consuming it would
        // remove History, Settings and Quit with no other way to reach them.
        #expect(
            SecondaryClickRouting.registersTap(
                eventType: .rightMouseDown,
                isInOwningWindow: false,
                isWithinButton: false
            ) == false
        )
    }

    @Test("Another window is not claimed even if the point would fall inside")
    func otherWindowWinsOverPosition() {
        // The two windows have independent coordinate spaces, so a point inside
        // the status item can land inside the button's bounds when compared
        // naively. The window check has to be what decides.
        #expect(
            SecondaryClickRouting.registersTap(
                eventType: .rightMouseDown,
                isInOwningWindow: false,
                isWithinButton: true
            ) == false
        )
    }

    @Test("A right-click elsewhere in the popover is not claimed")
    func elsewhereInPopoverIsLeftAlone() {
        // The stats card, the sparkline and the footer are in the same window.
        // Only the button itself counts.
        #expect(
            SecondaryClickRouting.registersTap(
                eventType: .rightMouseDown,
                isInOwningWindow: true,
                isWithinButton: false
            ) == false
        )
    }

    // MARK: - Event Type

    @Test("Only the press counts, so one click counts once")
    func onlyPressCounts() {
        // Matching the left-click path, which counts on the way down so fast
        // tapping feels immediate. Counting the release as well would register
        // two taps for one click.
        for type in [NSEvent.EventType.rightMouseUp, .rightMouseDragged] {
            #expect(
                SecondaryClickRouting.registersTap(
                    eventType: type,
                    isInOwningWindow: true,
                    isWithinButton: true
                ) == false,
                "\(type) must not count a second tap"
            )
        }
    }

    @Test("A left-click is never claimed")
    func leftClickIsNeverClaimed() {
        // The SwiftUI gesture already counts the left-click. Claiming it here
        // would either double every tap or, if consumed, stop the button
        // counting at all.
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp, .leftMouseDragged] {
            #expect(
                SecondaryClickRouting.registersTap(
                    eventType: type,
                    isInOwningWindow: true,
                    isWithinButton: true
                ) == false,
                "\(type) belongs to the SwiftUI gesture, not the monitor"
            )
        }
    }

    @Test("Unrelated events are not claimed")
    func unrelatedEventsAreNotClaimed() {
        let ignored: [NSEvent.EventType] = [
            .otherMouseDown, .scrollWheel, .mouseMoved, .keyDown, .flagsChanged,
        ]

        for type in ignored {
            #expect(
                SecondaryClickRouting.registersTap(
                    eventType: type,
                    isInOwningWindow: true,
                    isWithinButton: true
                ) == false,
                "\(type) must not count a tap"
            )
        }
    }

    @Test("No event at all is not claimed")
    func noEventIsNotClaimed() {
        #expect(
            SecondaryClickRouting.registersTap(
                eventType: nil,
                isInOwningWindow: true,
                isWithinButton: true
            ) == false
        )
    }
}

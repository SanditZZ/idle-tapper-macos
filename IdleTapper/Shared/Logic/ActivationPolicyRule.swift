//
//  ActivationPolicyRule.swift
//  Idle Tapper — Calculations (pure)
//
//  Decides whether the app should behave as an accessory or as an ordinary
//  application, given how many of its real windows are open.
//
//  Idle Tapper launches as an accessory (`LSUIElement`), which keeps it out of
//  the Dock and out of the application switcher. That is right for a menu bar
//  utility and wrong the moment it owns a window: an accessory app's window
//  cannot be reached with ⌘-Tab, so clicking away from Settings strands it
//  behind whatever came forward, with the menu bar item as the only way back.
//
//  Switching to `.regular` while a window is open puts the app in the switcher.
//  It also puts it in the Dock and gives it a menu bar, which is not separable
//  from the switcher entry — one policy governs all three.
//

import AppKit

/// Pure mapping from "how many windows are open" to an activation policy.
enum ActivationPolicyRule {

    /// The policy the app should be in while `openWindowCount` windows are open.
    ///
    /// The popover is deliberately not a window for this purpose. It is not
    /// something ⌘-Tab can return to, and it dismisses as soon as the user
    /// clicks away, so counting it would flicker the Dock icon on every glance
    /// at the tap button.
    ///
    /// - Parameter openWindowCount: Real windows currently on screen. A
    ///   negative count is treated as none, so a bookkeeping slip degrades to
    ///   the app's normal accessory state rather than pinning a Dock icon that
    ///   nothing can remove.
    static func policy(openWindowCount: Int) -> NSApplication.ActivationPolicy {
        openWindowCount > 0 ? .regular : .accessory
    }

    /// Whether the app should appear in the Dock and the switcher.
    ///
    /// The same question as `policy(openWindowCount:)`, phrased for a caller
    /// that wants to log or assert the intent rather than apply it.
    static func appearsInSwitcher(openWindowCount: Int) -> Bool {
        policy(openWindowCount: openWindowCount) == .regular
    }
}

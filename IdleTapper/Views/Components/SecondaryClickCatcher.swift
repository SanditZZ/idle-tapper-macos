//
//  SecondaryClickCatcher.swift
//  Idle Tapper — Components
//
//  Reports right-clicks landing on the view it is attached to.
//
//  ## Why it works this way
//
//  SwiftUI has no gesture that sees a right-click on macOS, so this has to reach
//  into AppKit. Two more obvious routes were tried against a running build and
//  both failed, which is why the third looks indirect:
//
//  1. **A hit-testing overlay.** An `NSView` over the button, declining the hit
//     test for anything but the right button. SwiftUI runs its own hit test
//     *before* AppKit dispatch reaches the view, and treats an
//     `NSViewRepresentable` as opaque — so the overlay won the left-click press
//     outright and the button silently stopped counting taps.
//  2. **The same view behind the button.** That restored the left-click, but
//     right-clicks never arrived either: the gate read `NSApp.currentEvent`
//     inside `hitTest`, and at hit-test time that is not the click being
//     dispatched. `rightMouseDown` was never called on the view at all.
//
//  So the view here receives no events whatsoever — `hitTest` always declines,
//  and it exists purely to answer *where the button is and which window it is
//  in*. Delivery is a **local** `NSEvent` monitor, which sees the event before
//  any window dispatch and does not depend on hit testing.
//
//  ## Why a local monitor is safe here
//
//  A monitor is the blunt instrument the project's rule on scoping shortcuts
//  warns about, so it is scoped three ways: it exists only while the view is in
//  a window — that is, only while the popover is open; it ignores any event
//  whose window is not the button's own, which is what leaves the status item's
//  context menu alone; and it ignores anything outside the button's bounds.
//  `SecondaryClickRouting` holds that predicate, under test.
//
//  It is a *local* monitor, not a global one: global monitors observe only
//  events destined for other applications and could never see this click.
//

import AppKit
import SwiftUI

/// Calls `onSecondaryClick` when the covered area is right-clicked.
///
/// Every other event, including the left-click that normally counts a tap, is
/// left entirely alone.
struct SecondaryClickCatcher: NSViewRepresentable {

    /// Called once per right-click press, on the way down.
    let onSecondaryClick: () -> Void

    func makeNSView(context: Context) -> SecondaryClickView {
        let view = SecondaryClickView()
        view.onSecondaryClick = onSecondaryClick
        return view
    }

    func updateNSView(_ nsView: SecondaryClickView, context: Context) {
        // Rebound on every update: the closure captures the enclosing view's
        // current state, so a stale one would act on stale values.
        nsView.onSecondaryClick = onSecondaryClick
    }

    static func dismantleNSView(_ nsView: SecondaryClickView, coordinator: ()) {
        nsView.stopMonitoring()
    }
}

/// An invisible, event-transparent anchor that watches for right-clicks over
/// itself.
///
/// Not private, because `NSViewRepresentable` names it in its signature.
final class SecondaryClickView: NSView {

    var onSecondaryClick: () -> Void = {}

    private var monitor: Any?

    deinit {
        // Removing the monitor here rather than through `stopMonitoring`, which
        // is main-actor isolated and cannot be called from `deinit`.
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    /// Never take part in hit testing.
    ///
    /// The view is a position anchor, not a control. Claiming a hit here is
    /// precisely what broke the left-click press in the first attempt at this.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Keep the anchor out of the accessibility tree.
    ///
    /// The tap button presents itself as a single element with its own label,
    /// value and action; an unlabelled group inside it would be a second stop
    /// that reads as nothing. VoiceOver activates the button through that
    /// element's `.accessibilityAction`, never through this view.
    override func isAccessibilityElement() -> Bool { false }

    // MARK: - Monitoring

    /// Watch only while in a window — that is, only while the popover is open.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window == nil {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    private func startMonitoring() {
        guard monitor == nil else { return }

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    /// Stop watching. Safe to call when not running.
    func stopMonitoring() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    /// Consume the event if it is a right-click on the button, otherwise hand it
    /// back untouched so normal dispatch continues.
    private func handle(_ event: NSEvent) -> NSEvent? {
        guard let window else { return event }

        // `locationInWindow` is meaningless for an event belonging to a
        // different window, so the window has to be established first.
        let isInOwningWindow = event.window === window
        let isWithinButton = isInOwningWindow
            && bounds.contains(convert(event.locationInWindow, from: nil))

        guard SecondaryClickRouting.registersTap(
            eventType: event.type,
            isInOwningWindow: isInOwningWindow,
            isWithinButton: isWithinButton
        ) else {
            return event
        }

        onSecondaryClick()

        // Returning nil consumes the click, so nothing downstream treats it as
        // a context-menu request.
        return nil
    }
}

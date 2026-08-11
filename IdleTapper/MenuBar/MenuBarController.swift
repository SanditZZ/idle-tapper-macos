//
//  MenuBarController.swift
//  Idle Tapper — Menu bar presentation
//
//  Owns the `NSStatusItem` and the popover that hosts the SwiftUI interface.
//  AppKit rather than `MenuBarExtra` because the popover needs precise control
//  over dismissal and over how an accessory app takes focus.
//

import AppKit
import SwiftUI
import Observation

@MainActor
final class MenuBarController {

    // MARK: - Data

    private let tracker: TapTracker
    private let settings: AppSettings
    private let windowCoordinator: WindowCoordinator

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    /// Monitors clicks outside the popover so it dismisses like a menu.
    private lazy var outsideClickMonitor = EventMonitor(
        mask: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] _ in
        MainActor.assumeIsolated {
            self?.closePopover()
        }
    }

    /// Timestamp of the last popover close.
    ///
    /// Clicking the status item while the popover is open both dismisses it and
    /// fires `togglePopover`, which would immediately reopen it. Ignoring a
    /// toggle that lands within a few milliseconds of a close fixes that.
    private var lastCloseDate: Date = .distantPast

    // MARK: - Lifecycle

    init(tracker: TapTracker, settings: AppSettings, launchAtLogin: LaunchAtLoginService) {
        self.tracker = tracker
        self.settings = settings
        self.windowCoordinator = WindowCoordinator(
            tracker: tracker,
            settings: settings,
            launchAtLogin: launchAtLogin
        )
    }

    /// Create the status item and begin reflecting the tracker's state.
    func install() {
        // Length is set explicitly in `updateStatusItem()` rather than left
        // variable, so the item never resizes with the count.
        let item = NSStatusBar.system.statusItem(
            withLength: StatusItemRenderer.statusItemLength(for: settings.menuBarDisplayStyle)
        )

        guard let button = item.button else {
            AppLog.menuBar.error("[MenuBar] Status item has no button — cannot install")
            return
        }

        button.target = self
        button.action = #selector(statusItemClicked)
        button.imagePosition = .imageLeading
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        statusItem = item
        updateStatusItem()
        observeState()

        AppLog.menuBar.info("[MenuBar] Status item installed")

        checkPlacement()
    }

    // MARK: - Actions

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        // Right-click (or Control-click) opens the context menu instead.
        let isSecondaryClick = event.type == .rightMouseUp
            || event.modifierFlags.contains(.control)

        if isSecondaryClick {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover, popover.isShown {
            closePopover()
            return
        }

        // Swallow the click that just dismissed the popover.
        guard Date().timeIntervalSince(lastCloseDate) > 0.2 else { return }

        showPopover(from: button)
    }

    private func showPopover(from button: NSStatusBarButton) {
        // Reflect anything that changed while the popover was closed —
        // in particular a day rollover.
        tracker.refresh()

        let popover = popover ?? makePopover()
        self.popover = popover

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // An accessory app is not frontmost by default; without this the
        // popover renders inactive and text fields cannot take focus.
        NSApp.activate(ignoringOtherApps: true)

        startMonitoringOutsideClicks()
        AppLog.menuBar.debug("[MenuBar] Popover shown")
    }

    private func closePopover() {
        popover?.performClose(nil)
        lastCloseDate = Date()
        stopMonitoringOutsideClicks()

        // Taps are debounced; make sure the session reaches disk once the user
        // is done interacting.
        tracker.flush()

        AppLog.menuBar.debug("[MenuBar] Popover closed")
    }

    private func showContextMenu() {
        guard let statusItem else { return }

        let menu = NSMenu()

        menu.addItem(
            withTitle: "History…",
            action: #selector(openHistory),
            keyEquivalent: ""
        ).target = self

        menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ).target = self

        menu.addItem(.separator())

        menu.addItem(
            withTitle: "Quit Idle Tapper",
            action: #selector(quit),
            keyEquivalent: "q"
        ).target = self

        // Attaching the menu makes the status item present it, then detaching
        // restores normal click-to-toggle behaviour.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openHistory() {
        windowCoordinator.showHistory()
    }

    @objc private func openSettings() {
        windowCoordinator.showSettings()
    }

    @objc private func quit() {
        tracker.flush()
        NSApp.terminate(nil)
    }

    // MARK: - Rendering

    private func makePopover() -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let content = PopoverContentView(
            tracker: tracker,
            onOpenHistory: { [weak self] in
                self?.closePopover()
                self?.windowCoordinator.showHistory()
            },
            onOpenSettings: { [weak self] in
                self?.closePopover()
                self?.windowCoordinator.showSettings()
            },
            onQuit: { [weak self] in
                self?.quit()
            }
        )

        let hosting = NSHostingController(rootView: content)
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting

        return popover
    }

    private func updateStatusItem() {
        guard let item = statusItem, let button = item.button else { return }

        let style = settings.menuBarDisplayStyle
        let count = tracker.todayCount

        // Pin the width so the item cannot resize as the count grows. Without
        // this the whole menu bar shifts on every extra digit.
        item.length = StatusItemRenderer.statusItemLength(for: style)

        button.image = StatusItemRenderer.image(for: style)
        button.toolTip = StatusItemRenderer.tooltip(for: count)

        // Attributed rather than plain, so the count renders in a monospaced
        // font. Combined with the renderer's fixed-width padding, this is what
        // stops the item resizing — and the menu bar shifting — on every tap.
        button.attributedTitle = StatusItemRenderer.attributedTitle(for: count, style: style)

        // Keep the number tight against the icon rather than letting the pair
        // spread across the reserved width.
        button.imageHugsTitle = style.showsIcon && style.showsCount
    }

    // MARK: - Placement Diagnostics

    /// Report where macOS actually placed the status item.
    ///
    /// On a Mac with a notch, a full menu bar leaves no room to the right of
    /// the camera housing, and macOS positions overflow status items *behind*
    /// it — on screen, correctly sized, and completely invisible. That looks
    /// identical to a failed install, so it is worth naming explicitly in the
    /// log rather than leaving the user to guess.
    ///
    /// Placement settles a moment after the item is created, hence the delay.
    private func checkPlacement() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))

            guard
                let self,
                let item = self.statusItem,
                let frame = item.button?.window?.frame,
                let screen = NSScreen.main
            else { return }

            AppLog.menuBar.debug(
                "[MenuBar] Placed at x=\(frame.origin.x, privacy: .public) width=\(frame.width, privacy: .public)"
            )

            let placement = StatusItemPlacement.classify(
                itemFrame: frame,
                leftArea: screen.auxiliaryTopLeftArea,
                rightArea: screen.auxiliaryTopRightArea,
                screenFrame: screen.frame
            )

            guard placement == .behindNotch else { return }

            AppLog.menuBar.warning(
                """
                [MenuBar] The status item was placed behind the display notch and \
                cannot be seen. The menu bar has no room left.
                """
            )

            // The log alone is not enough: an accessory app with an invisible
            // icon has no other way to tell the user anything at all.
            self.presentHiddenIconNoticeIfNeeded()
        }
    }

    /// Explain the hidden icon once, unless the user has asked not to be told
    /// again. Deliberately not shown on every launch.
    private func presentHiddenIconNoticeIfNeeded() {
        guard !settings.suppressHiddenIconNotice else {
            AppLog.menuBar.debug("[MenuBar] Hidden-icon notice suppressed by the user")
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Idle Tapper is hidden behind the notch"
        alert.informativeText = """
            Idle Tapper is running, but your menu bar is full, so macOS placed its \
            icon behind the camera housing where it cannot be clicked.

            To reach it, quit or hide one of your other menu bar items. Choosing \
            “Icon only” below also makes Idle Tapper take up less space.
            """

        alert.addButton(withTitle: "Use Icon Only")
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Don’t Show Again")

        NSApp.activate(ignoringOtherApps: true)

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            settings.menuBarDisplayStyle = .iconOnly
            AppLog.menuBar.info("[MenuBar] Switched to icon-only from the hidden-icon notice")
        case .alertThirdButtonReturn:
            settings.suppressHiddenIconNotice = true
            AppLog.menuBar.info("[MenuBar] User suppressed the hidden-icon notice")
        default:
            break
        }
    }

    // MARK: - Observation

    /// Re-render whenever the count or the display style changes.
    ///
    /// `withObservationTracking` fires once per change, so the tracking is
    /// re-armed inside the change handler.
    private func observeState() {
        withObservationTracking {
            _ = tracker.todayCount
            _ = settings.menuBarDisplayStyle
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.updateStatusItem()
                self.observeState()
            }
        }
    }

    // MARK: - Outside Clicks

    private func startMonitoringOutsideClicks() {
        outsideClickMonitor.start()
    }

    private func stopMonitoringOutsideClicks() {
        outsideClickMonitor.stop()
    }
}

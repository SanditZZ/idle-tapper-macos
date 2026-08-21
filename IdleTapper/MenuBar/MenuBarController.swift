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
    /// Not `private`: `MenuBarController+Placement.swift` reads both, and
    /// Swift's `private` is file-scoped.
    let settings: AppSettings
    private let windowCoordinator: WindowCoordinator

    var statusItem: NSStatusItem?
    private var popover: NSPopover?

    /// Retains the notification-activation observer.
    private let observers = ObserverBag()

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

    /// - Parameter windowCoordinator: Injected rather than built here, because
    ///   the ⌘, command opens the same windows from outside the menu bar. Two
    ///   coordinators would mean two Settings windows.
    init(
        tracker: TapTracker,
        settings: AppSettings,
        windowCoordinator: WindowCoordinator
    ) {
        self.tracker = tracker
        self.settings = settings
        self.windowCoordinator = windowCoordinator
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
        observeNotificationActivation()

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

        // The goal can only be reached by tapping, and the tap button is in
        // here — so while this is up, the goal-reached notification would be
        // telling the user something the burst in front of them already has.
        tracker.goals?.setPopoverVisible(true)

        AppLog.menuBar.debug("[MenuBar] Popover shown")
    }

    private func closePopover() {
        popover?.performClose(nil)
        lastCloseDate = Date()
        stopMonitoringOutsideClicks()
        tracker.goals?.setPopoverVisible(false)

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

        menu.addItem(
            withTitle: "Achievements…",
            action: #selector(openAchievements),
            keyEquivalent: ""
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

    @objc private func openAchievements() {
        windowCoordinator.showAchievements()
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
            settings: settings,
            onOpenHistory: { [weak self] in
                self?.closePopover()
                self?.windowCoordinator.showHistory()
            },
            onOpenSettings: { [weak self] in
                self?.closePopover()
                self?.windowCoordinator.showSettings()
            },
            onOpenAchievements: { [weak self] in
                self?.closePopover()
                self?.windowCoordinator.showAchievements()
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

        let goal = settings.dailyGoal

        button.image = StatusItemRenderer.image(for: style)
        button.toolTip = StatusItemRenderer.tooltip(for: count, goal: goal)

        // Attributed rather than plain, so the count renders in a monospaced
        // font. Combined with the renderer's fixed-width padding, this is what
        // stops the item resizing — and the menu bar shifting — on every tap.
        button.attributedTitle = StatusItemRenderer.attributedTitle(
            for: count,
            style: style,
            goal: goal
        )

        // Keep the number tight against the icon rather than letting the pair
        // spread across the reserved width.
        button.imageHugsTitle = style.showsIcon && style.showsCount
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
            // The goal is read by `goalProgress` and by every style's tooltip,
            // so editing it in Settings has to redraw the item immediately.
            _ = settings.dailyGoal
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.updateStatusItem()
                self.observeState()
            }
        }
    }

    // MARK: - Notification Activation

    /// Open the popover when the user clicks one of our notifications.
    ///
    /// The reminder exists to get someone back to the counter, so dropping them
    /// at a menu bar icon they still have to find and click would be half a
    /// job. `showPopover` refreshes first, which matters here more than
    /// anywhere: the notification may have been sitting in Notification Centre
    /// since before a day rollover.
    private func observeNotificationActivation() {
        observers.observe(.idleTapperNotificationActivated) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let button = self.statusItem?.button else { return }
                guard self.popover?.isShown != true else { return }
                self.showPopover(from: button)
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

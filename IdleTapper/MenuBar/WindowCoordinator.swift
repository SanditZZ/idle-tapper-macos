//
//  WindowCoordinator.swift
//  Idle Tapper — Window management
//
//  Creates and reuses the auxiliary windows. An accessory app has to activate
//  itself explicitly, otherwise its windows open behind whatever the user was
//  using.
//

import AppKit
import SwiftUI

@MainActor
final class WindowCoordinator {

    private let tracker: TapTracker
    private let settings: AppSettings
    private let launchAtLogin: LaunchAtLoginService
    private let updates: UpdateService

    private var historyWindow: NSWindow?
    private var settingsWindow: NSWindow?

    init(
        tracker: TapTracker,
        settings: AppSettings,
        launchAtLogin: LaunchAtLoginService,
        updates: UpdateService
    ) {
        self.tracker = tracker
        self.settings = settings
        self.launchAtLogin = launchAtLogin
        self.updates = updates
    }

    // MARK: - Actions

    /// Show the history window, reusing it if already open.
    func showHistory() {
        tracker.refresh()

        if let historyWindow {
            present(historyWindow)
            return
        }

        let window = makeWindow(
            title: "Tap History",
            size: DesignTokens.Layout.historyWindowSize,
            minSize: DesignTokens.Layout.historyWindowMinSize,
            content: HistoryView(tracker: tracker, settings: settings)
        )
        historyWindow = window
        present(window)

        AppLog.app.info("[App] Opened history window")
    }

    /// Show the settings window, reusing it if already open.
    func showSettings() {
        if let settingsWindow {
            present(settingsWindow)
            return
        }

        let window = makeWindow(
            title: "Idle Tapper Settings",
            size: DesignTokens.Layout.settingsWindowSize,
            minSize: DesignTokens.Layout.settingsWindowMinSize,
            content: SettingsView(
                tracker: tracker,
                settings: settings,
                launchAtLogin: launchAtLogin,
                updates: updates
            )
        )
        settingsWindow = window
        present(window)

        AppLog.app.info("[App] Opened settings window")
    }

    // MARK: - Helpers

    private func makeWindow(
        title: String,
        size: CGSize,
        minSize: CGSize,
        content: some View
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentViewController = NSHostingController(rootView: content)
        window.isReleasedWhenClosed = false

        // Set the floor *before* the autosaved frame is restored, so a frame
        // saved by an older build — one whose window was sized for less
        // content — is clamped up instead of reopening clipped. Restoring a
        // stale, too-small frame is how a window that grew a section starts
        // hiding the bottom of itself on every launch afterwards.
        window.contentMinSize = minSize

        // Size and position the window *here*, not through the `contentRect`
        // passed to `init`. Assigning `contentViewController` collapses the
        // frame to about {1, 28} — the hosting controller has not laid the
        // SwiftUI view out yet — so the size given to `init` never survives.
        // That left `contentMinSize` above as the only thing setting a size,
        // and every window therefore opened at its *minimum* while the size
        // it was designed around was dead code. Settings asked for 700pt of
        // height, opened at 380, and hid the Data section below the fold.
        //
        // Centring has to follow for the same reason: centring a 1x28 frame
        // places the window by a size it is about to stop having.
        window.setContentSize(size)
        window.center()

        // The trailing number discards previously saved frames. Bump it when a
        // window's content grows enough that the old remembered size is no
        // longer a sensible place to reopen at — clamping to the minimum would
        // technically work, but it reopens the window scrolled and cramped
        // rather than at the size the layout was designed around.
        //
        // Bumped to .3 because every frame saved under .2 was recorded at the
        // minimum size by the bug described above, and a saved frame beats the
        // default — so without this the fix would never reach anyone who had
        // already opened either window once.
        window.setFrameAutosaveName("IdleTapper.\(title).3")

        return window
    }

    private func present(_ window: NSWindow) {
        // Accessory apps are never frontmost until they ask to be.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

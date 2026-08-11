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

    private var historyWindow: NSWindow?
    private var settingsWindow: NSWindow?

    init(tracker: TapTracker, settings: AppSettings, launchAtLogin: LaunchAtLoginService) {
        self.tracker = tracker
        self.settings = settings
        self.launchAtLogin = launchAtLogin
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
            content: SettingsView(
                tracker: tracker,
                settings: settings,
                launchAtLogin: launchAtLogin
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
        window.center()
        window.setFrameAutosaveName("IdleTapper.\(title)")
        return window
    }

    private func present(_ window: NSWindow) {
        // Accessory apps are never frontmost until they ask to be.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

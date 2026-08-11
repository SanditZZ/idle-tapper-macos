//
//  AppDelegate.swift
//  Idle Tapper
//
//  Owns the menu bar controller and makes sure pending taps reach disk before
//  the process goes away.
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var menuBarController: MenuBarController?
    private let observers = ObserverBag()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.app.info("[App] Launching")

        // Accessory app: no Dock icon, no app switcher entry.
        NSApp.setActivationPolicy(.accessory)

        let environment = AppEnvironment.shared
        menuBarController = MenuBarController(
            tracker: environment.tracker,
            settings: environment.settings,
            launchAtLogin: environment.launchAtLogin
        )
        menuBarController?.install()

        observeSleep()

        AppLog.app.info("[App] Ready")
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLog.app.info("[App] Terminating — flushing pending taps")
        AppEnvironment.shared.tracker.flush()
    }

    /// Nothing to restore when the app is re-activated with no windows open.
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: - Durability

    /// Flush before the machine sleeps. Sleep is the most common way for taps
    /// to sit in the debounce window indefinitely.
    private func observeSleep() {
        observers.observe(
            NSWorkspace.willSleepNotification,
            on: NSWorkspace.shared.notificationCenter
        ) { _ in
            MainActor.assumeIsolated {
                AppLog.app.debug("[App] Sleeping — flushing pending taps")
                AppEnvironment.shared.tracker.flush()
            }
        }

        observers.observe(
            NSWorkspace.sessionDidResignActiveNotification,
            on: NSWorkspace.shared.notificationCenter
        ) { _ in
            MainActor.assumeIsolated {
                AppEnvironment.shared.tracker.flush()
            }
        }
    }
}

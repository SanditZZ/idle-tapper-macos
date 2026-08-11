//
//  IdleTapperApp.swift
//  Idle Tapper
//
//  Menu bar only: the app is an accessory (`LSUIElement`) with no Dock icon and
//  no default window. All presentation is driven from `AppDelegate`.
//

import SwiftUI

@main
struct IdleTapperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Provides the standard ⌘, Settings window. Every other surface is
        // managed by WindowCoordinator so an accessory app can control its own
        // activation behaviour.
        Settings {
            SettingsView(
                tracker: AppEnvironment.shared.tracker,
                settings: AppEnvironment.shared.settings,
                launchAtLogin: AppEnvironment.shared.launchAtLogin
            )
        }
    }
}

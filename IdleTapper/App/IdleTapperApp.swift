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
        // An `App` must declare at least one scene, and `Settings` is the only
        // kind that does not put a window on screen at launch — which is what an
        // accessory app wants. Its *content* is deliberately empty: this scene
        // exists to satisfy the protocol and to carry the commands below, not to
        // present anything.
        //
        // It used to host `SettingsView`, and that was the bug. Opening Settings
        // from the popover or the status item goes through `WindowCoordinator`,
        // which builds the window the redesign was done against — full-size
        // content view, transparent title bar, a minimum size and a saved frame.
        // ⌘, opened *this* scene's window instead, so the app had two Settings
        // windows, showing the same settings in different chrome, either or both
        // of which could be open at once.
        Settings {
            EmptyView()
        }
        .commands {
            // Replace the standard Settings item rather than adding another, so
            // there is exactly one and its ⌘, lands on the same window every
            // other route opens.
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    AppEnvironment.shared.windows.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

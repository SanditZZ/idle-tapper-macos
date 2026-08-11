//
//  LaunchAtLoginService.swift
//  Idle Tapper — Launch at login
//
//  Wraps `SMAppService.mainApp`.
//
//  The enabled state is deliberately *not* stored in `UserDefaults`. macOS owns
//  it — the user can turn it off in System Settings → General → Login Items
//  without the app ever knowing — so a cached boolean would drift out of sync
//  and show the wrong thing. The system is always the source of truth here.
//

import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class LaunchAtLoginService {

    /// Whether the app is currently registered to launch at login.
    private(set) var isEnabled: Bool

    /// Set when the last change failed, for display in Settings.
    private(set) var lastErrorMessage: String?

    /// True when registration cannot work in this context — most commonly an
    /// app being run from a build folder rather than from /Applications.
    private(set) var isUnavailable: Bool = false

    init() {
        self.isEnabled = Self.currentStatus == .enabled
        refresh()
    }

    // MARK: - Actions

    /// Re-read the real state from the system.
    ///
    /// Call when Settings appears: the user may have changed the setting in
    /// System Settings since the app launched.
    func refresh() {
        let status = Self.currentStatus
        isEnabled = status == .enabled

        // `.requiresApproval` means macOS registered the item but the user has
        // it switched off in System Settings. Saying so is far more useful than
        // a toggle that silently springs back.
        if status == .requiresApproval {
            lastErrorMessage = "Allow Idle Tapper in System Settings › General › Login Items."
        }

        AppLog.settings.debug(
            "[Settings] Launch at login status: \(String(describing: status), privacy: .public)"
        )
    }

    /// Register or unregister the app as a login item.
    ///
    /// Never throws: a failure leaves the toggle reflecting reality and puts a
    /// message on screen rather than interrupting the user.
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                AppLog.settings.info("[Settings] Registered for launch at login")
            } else {
                try SMAppService.mainApp.unregister()
                AppLog.settings.info("[Settings] Unregistered from launch at login")
            }
            lastErrorMessage = nil
            isUnavailable = false
        } catch {
            lastErrorMessage = Self.describe(error, whileEnabling: enabled)
            isUnavailable = true
            AppLog.settings.error(
                "[Settings] Launch at login change failed: \(error.localizedDescription, privacy: .public)"
            )
        }

        // Reflect whatever the system actually ended up doing, not what was asked.
        refresh()
    }

    // MARK: - Helpers

    private static var currentStatus: SMAppService.Status {
        SMAppService.mainApp.status
    }

    /// Turn an opaque ServiceManagement failure into something actionable.
    ///
    /// The overwhelmingly common cause is running a development build from
    /// DerivedData: macOS will not register a login item for an app outside a
    /// normal install location.
    private static func describe(_ error: any Error, whileEnabling enabling: Bool) -> String {
        let action = enabling ? "enable" : "disable"
        let isInApplications = Bundle.main.bundlePath.hasPrefix("/Applications")

        if enabling, !isInApplications {
            return "Could not \(action) launch at login. Move Idle Tapper to your Applications folder and try again."
        }

        return "Could not \(action) launch at login: \(error.localizedDescription)"
    }
}

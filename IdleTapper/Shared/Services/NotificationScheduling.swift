//
//  NotificationScheduling.swift
//  Idle Tapper — Actions layer
//
//  The boundary around `UserNotifications`, and the only file in the app that
//  imports it.
//
//  It exists for the same reason `TapRepository` does. `UNUserNotificationCenter`
//  is a process-wide singleton wired to the real notification database and to a
//  TCC permission prompt; a test that touched it would be asking the machine
//  running the suite for permission to send notifications. Behind this protocol
//  the whole of `GoalTracker` — which requests are scheduled, which are dropped,
//  how many times the centre is touched during a burst of tapping — is
//  ordinary, offline, assertable code.
//

import Foundation

// `@preconcurrency` because `UserNotifications` is not Sendable-audited:
// `UNNotificationSettings` and `[UNNotificationRequest]` come back from
// `await`ed calls on a nonisolated singleton and are flagged as non-sendable
// results, which `SWIFT_TREAT_WARNINGS_AS_ERRORS` turns into a build failure.
//
// This is the compiler's own suggested fix and it weakens nothing of ours: it
// says the framework has not been annotated yet, not that our checking is off.
// Both values are read and discarded on the main actor inside this file and
// never escape it. Remove the attribute once the SDK annotates the module.
@preconcurrency import UserNotifications

/// Whether the app may post notifications.
///
/// Deliberately three states and not a `Bool`. "Not yet asked" and "asked and
/// refused" have to be told apart: the first is worth a prompt at the moment
/// the user switches reminders on, and the second must never prompt again.
enum NotificationAuthorization: Equatable, Sendable {
    /// The user has not been asked yet.
    case notDetermined
    /// Notifications may be posted.
    case authorized
    /// The user refused, or notifications are disabled for the app.
    case denied
}

/// Schedules and withdraws the app's notifications.
@MainActor
protocol NotificationScheduling: AnyObject {

    /// The current authorization state, without prompting.
    func authorizationStatus() async -> NotificationAuthorization

    /// Prompt for permission if it has not been asked for, and report the
    /// resulting state. Never prompts twice — macOS answers a second request
    /// with the existing decision.
    func requestAuthorization() async -> NotificationAuthorization

    /// Identifiers of pending requests beginning with `prefix`.
    ///
    /// Scoped by prefix so reconciliation can never withdraw a notification
    /// belonging to some other part of the app.
    func pendingIdentifiers(withPrefix prefix: String) async -> Set<String>

    /// Schedule or deliver `notification`.
    ///
    /// A notification with no `fireDate` is delivered immediately. Adding one
    /// whose identifier already exists replaces it, which is what makes
    /// applying the same plan repeatedly a no-op.
    func add(_ notification: PlannedNotification) async throws

    /// Withdraw pending requests by identifier. Unknown identifiers are ignored.
    func removeIdentifiers(_ identifiers: [String])
}

/// Posted when the user activates one of the app's notifications.
///
/// A `NotificationCenter` name rather than a callback on the delegate, so the
/// menu bar can react through the `ObserverBag` it already owns and nothing has
/// to thread a closure — or a reference to `MenuBarController` — down through
/// the composition root into a delegate object.
extension Notification.Name {
    static let idleTapperNotificationActivated = Notification.Name(
        "com.kkpon3.IdleTapper.notificationActivated"
    )
}

/// The app's `UNUserNotificationCenter` delegate.
///
/// Two jobs, both small. It asks for a banner even when Idle Tapper is
/// frontmost — without a delegate macOS suppresses that, and an accessory app
/// *is* frontmost whenever one of its windows is open, so the evening reminder
/// would silently not appear for anyone with History open. And it announces an
/// activation so the popover can be brought up.
///
/// Stateless on purpose: it holds nothing, so it is safely `Sendable` and needs
/// no isolation of its own. The delegate callbacks arrive off the main actor
/// and both hop to it explicitly.
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            NotificationCenter.default.post(name: .idleTapperNotificationActivated, object: nil)
        }
    }
}

/// `NotificationScheduling` backed by the real notification centre.
@MainActor
final class UserNotificationScheduler: NotificationScheduling {

    private let center: UNUserNotificationCenter

    /// Retained because `UNUserNotificationCenter.delegate` is a weak reference:
    /// without this the delegate would be released immediately and neither
    /// foreground banners nor activation would work.
    private let delegate = NotificationDelegate()

    /// Calendar used to turn a fire date into trigger components.
    ///
    /// Read fresh from `Calendar.current` on each use rather than captured, so
    /// a time-zone change between scheduling and rescheduling is picked up. The
    /// app already refreshes on `NSSystemTimeZoneDidChange`, which is what
    /// drives the reschedule.
    private var calendar: Calendar { Calendar.current }

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        center.delegate = delegate
    }

    func authorizationStatus() async -> NotificationAuthorization {
        let settings = await center.notificationSettings()
        return Self.authorization(from: settings.authorizationStatus)
    }

    func requestAuthorization() async -> NotificationAuthorization {
        do {
            // The result is ignored in favour of re-reading the settings: a
            // `false` here means "not authorized", which could be either a
            // refusal or a policy restriction, and the settings say which.
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            AppLog.goal.error(
                "[Goal] Notification authorization request failed: \(error.localizedDescription, privacy: .public)"
            )
        }
        return await authorizationStatus()
    }

    func pendingIdentifiers(withPrefix prefix: String) async -> Set<String> {
        let pending = await center.pendingNotificationRequests()
        return Set(pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
    }

    func add(_ notification: PlannedNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        try await center.add(
            UNNotificationRequest(
                identifier: notification.identifier,
                content: content,
                trigger: trigger(for: notification)
            )
        )
    }

    func removeIdentifiers(_ identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Helpers

    /// A calendar trigger for a scheduled notification, or `nil` to deliver now.
    ///
    /// `UNCalendarNotificationTrigger` rather than a time-interval one, and
    /// certainly rather than an in-app timer. "Eight in the evening" is a
    /// wall-clock time: an interval computed now would fire an hour out if the
    /// clock or the zone moved in between, and would drift across a daylight
    /// saving boundary. The components are what the system re-resolves.
    private func trigger(for notification: PlannedNotification) -> UNNotificationTrigger? {
        guard let fireDate = notification.fireDate else { return nil }

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    private static func authorization(
        from status: UNAuthorizationStatus
    ) -> NotificationAuthorization {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized, .provisional:
            return .authorized
        case .denied:
            return .denied
        @unknown default:
            // A status this build does not know about is treated as refused.
            // Erring toward *not* posting is the safe direction: the goal works
            // fully without notifications, and silently posting under an
            // unrecognised policy would not.
            return .denied
        }
    }
}

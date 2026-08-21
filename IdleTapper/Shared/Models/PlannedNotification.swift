//
//  PlannedNotification.swift
//  Idle Tapper — Value types
//
//  A notification the app intends to exist, described as plain data.
//
//  Deliberately not a `UNNotificationRequest`: that type is built by the action
//  layer, at the boundary, from one of these. Keeping the intention as a value
//  type is what lets `GoalNotificationPlan` be a pure function and the whole
//  scheduling decision be unit-tested without `UserNotifications` in the room.
//

import Foundation

/// One notification the app wants scheduled or delivered.
struct PlannedNotification: Equatable, Hashable, Sendable, Identifiable {

    /// Stable identity, and the reason reconciliation is idempotent.
    ///
    /// Adding a request whose identifier already exists *replaces* it rather
    /// than producing a second notification, so re-applying the same plan is a
    /// no-op however many times it happens.
    let identifier: String

    /// Notification title.
    let title: String

    /// Notification body.
    let body: String

    /// When it should fire, or `nil` to deliver it immediately.
    ///
    /// A `Date` rather than `DateComponents` so a test can assert on the exact
    /// instant; the action layer converts it when it builds the trigger.
    let fireDate: Date?

    var id: String { identifier }

    /// True when this is delivered now rather than scheduled for later.
    var isImmediate: Bool { fireDate == nil }
}

//
//  TapRepository.swift
//  Idle Tapper — Persistence boundary
//
//  The rest of the app talks to this protocol and never to SwiftData directly.
//  That keeps views and game logic free of `ModelContext`, makes the store
//  swappable, and lets tests run against an in-memory double.
//

import Foundation

/// Errors surfaced by a repository. Callers are expected to degrade gracefully
/// rather than crash — a dropped tap is preferable to losing the session.
enum TapRepositoryError: LocalizedError {
    case fetchFailed(underlying: any Error)
    case saveFailed(underlying: any Error)
    case containerUnavailable

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let underlying):
            return "Could not read tap history: \(underlying.localizedDescription)"
        case .saveFailed(let underlying):
            return "Could not save tap history: \(underlying.localizedDescription)"
        case .containerUnavailable:
            return "The tap history database is unavailable."
        }
    }
}

/// Reads and writes daily tap totals.
///
/// Main-actor bound because the backing `ModelContext` is the container's main
/// context; the tap path is inherently UI-driven so this costs nothing.
@MainActor
protocol TapRepository: AnyObject {

    /// Add `amount` taps to the day containing `date` and return the new total
    /// for that day.
    ///
    /// Creates the day's record on first use, which is how the daily reset
    /// happens: a fresh day simply has no record yet.
    @discardableResult
    func increment(by amount: Int, at date: Date) throws -> Int

    /// Tap total for the day containing `date`. Zero when nothing is recorded.
    func count(on date: Date) throws -> Int

    /// Every recorded day, ascending by date.
    func allDays() throws -> [DaySnapshot]

    /// The `days` most recent days ending on the day containing `date`,
    /// ascending. Days with no record are omitted; the calculation layer fills
    /// the gaps.
    func recentDays(_ days: Int, endingOn date: Date) throws -> [DaySnapshot]

    /// Delete all history. Irreversible.
    func deleteAll() throws

    /// Write any pending changes to disk immediately.
    ///
    /// Writes are normally debounced; call this before the app terminates or
    /// resigns active so nothing in flight is lost.
    func flush() throws

    /// Every achievement unlocked so far, in no particular order.
    func unlockedAchievements() throws -> [AchievementSnapshot]

    /// Record `id` as unlocked at `date`.
    ///
    /// Idempotent: a no-op if `id` is already recorded, so re-evaluating the
    /// same achievement twice never duplicates a row or throws.
    func unlockAchievement(_ id: AchievementID, at date: Date) throws
}

extension TapRepository {
    /// Convenience: record a single tap now.
    @discardableResult
    func recordTap(at date: Date = Date()) throws -> Int {
        try increment(by: 1, at: date)
    }

    /// Convenience: today's total.
    func todayCount(now: Date = Date()) throws -> Int {
        try count(on: now)
    }
}

//
//  SwiftDataTapRepository.swift
//  Idle Tapper — Persistence implementation
//
//  SwiftData-backed `TapRepository`.
//
//  Two performance decisions matter here, because a tapper generates writes far
//  faster than a normal app:
//
//  1. Autosave is disabled and saves are debounced. The in-memory object graph
//     updates on every tap, so reads are always correct immediately, but SQLite
//     is only touched once the user pauses. Without this, a fast tapper would
//     issue a disk write per tap.
//  2. Today's record is cached. Fetching it per tap would run a predicate query
//     on every click; instead it is resolved once per day and reused, and the
//     cache self-invalidates when the day rolls over.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataTapRepository: TapRepository {

    // MARK: - Data

    private let context: ModelContext
    private let calendar: Calendar

    /// How long to wait after the last change before writing to disk.
    private let saveDebounce: Duration

    /// Today's record, cached to avoid a fetch per tap. Held together with the
    /// day it belongs to so a rollover invalidates it automatically.
    private var cachedRecord: (dayStart: Date, record: DayRecord)?

    /// In-flight debounced save, cancelled and rescheduled on each change.
    private var pendingSave: Task<Void, Never>?

    /// True when the context holds changes that are not yet on disk.
    private var hasUnsavedChanges = false

    // MARK: - Lifecycle

    /// - Parameters:
    ///   - container: The SwiftData container to read and write through.
    ///   - calendar: Calendar used for day boundaries. Injectable for tests.
    ///   - saveDebounce: Quiet period before a save. Defaults to one second,
    ///     which keeps sustained tapping off the disk while bounding how much
    ///     work an abrupt termination could lose.
    init(
        container: ModelContainer,
        calendar: Calendar = .current,
        saveDebounce: Duration = .seconds(1)
    ) {
        self.context = ModelContext(container)
        self.calendar = calendar
        self.saveDebounce = saveDebounce

        // Saves are managed explicitly — see the note at the top of this file.
        self.context.autosaveEnabled = false

        AppLog.persistence.debug("[Persistence] Repository ready")
    }

    deinit {
        pendingSave?.cancel()
    }

    // MARK: - Actions: Writes

    @discardableResult
    func increment(by amount: Int, at date: Date, goalTarget: Int?) throws -> Int {
        guard amount != 0 else { return try count(on: date) }

        let record = try recordForToday(containing: date, createIfMissing: true)

        // `createIfMissing: true` always returns a record; this is belt and braces.
        guard let record else {
            throw TapRepositoryError.containerUnavailable
        }

        record.tapCount += amount
        record.updatedAt = date
        // Written on every increment rather than only at creation, so a goal
        // changed part-way through the day takes effect on the next tap. Only
        // ever today's record: `recordForToday` resolves the day containing
        // `date`, and a tap is always now.
        record.goalTarget = goalTarget
        hasUnsavedChanges = true
        scheduleSave()

        return record.tapCount
    }

    func setGoalTarget(_ goal: Int?, on date: Date) throws {
        // Deliberately does not create the record — see the protocol.
        guard let record = try recordForToday(containing: date, createIfMissing: false) else {
            return
        }
        guard record.goalTarget != goal else { return }

        record.goalTarget = goal
        record.updatedAt = date
        hasUnsavedChanges = true
        scheduleSave()
    }

    func deleteAll() throws {
        // Deleted per object rather than with the bulk `delete(model:)` overload:
        // the bulk form leaves objects already registered in this context, so a
        // subsequent fetch through the same context still returns them.
        //
        // Achievement records are deliberately not touched here: an unlock is a
        // trophy for a milestone already reached, not a live reflection of
        // current history, so clearing the day-by-day log does not take it back.
        let records = try fetchAllRecords()

        do {
            for record in records {
                context.delete(record)
            }
            cachedRecord = nil
            hasUnsavedChanges = true
            try performSave()
            AppLog.persistence.info("[Persistence] Deleted all tap history (\(records.count) days)")
        } catch {
            AppLog.persistence.error(
                "[Persistence] Delete-all failed: \(error.localizedDescription, privacy: .public)"
            )
            throw TapRepositoryError.saveFailed(underlying: error)
        }
    }

    func flush() throws {
        pendingSave?.cancel()
        pendingSave = nil
        try performSave()
    }

    func unlockAchievement(_ id: AchievementID, at date: Date) throws {
        let existing = try fetchAllAchievementRecords()
        guard !existing.contains(where: { $0.id == id.rawValue }) else { return }

        context.insert(AchievementRecord(id: id.rawValue, unlockedAt: date))
        hasUnsavedChanges = true
        scheduleSave()
        AppLog.persistence.info("[Persistence] Unlocked achievement \(id.rawValue, privacy: .public)")
    }

    // MARK: - Actions: Reads

    func count(on date: Date) throws -> Int {
        try recordForToday(containing: date, createIfMissing: false)?.tapCount ?? 0
    }

    func allDays() throws -> [DaySnapshot] {
        try fetchAllRecords()
            .map(\.snapshot)
            .sorted { $0.dayStart < $1.dayStart }
    }

    func recentDays(_ days: Int, endingOn date: Date) throws -> [DaySnapshot] {
        guard days > 0 else { return [] }

        let cutoff = DayBoundary.dayStart(daysAgo: days - 1, from: date, calendar: calendar)
        let upperBound = DayBoundary.dayStart(daysAgo: -1, from: date, calendar: calendar)

        return try allDays().filter { $0.dayStart >= cutoff && $0.dayStart < upperBound }
    }

    func unlockedAchievements() throws -> [AchievementSnapshot] {
        try fetchAllAchievementRecords().compactMap(\.snapshot)
    }

    // MARK: - Calculations / Helpers

    /// Resolve the record for the day containing `date`, optionally creating it.
    ///
    /// Returns the cached record when the day has not changed, so the hot tap
    /// path avoids a query entirely.
    private func recordForToday(
        containing date: Date,
        createIfMissing: Bool
    ) throws -> DayRecord? {
        let dayStart = DayBoundary.dayStart(for: date, calendar: calendar)

        if let cached = cachedRecord, cached.dayStart == dayStart {
            return cached.record
        }

        // Day changed (or first access): drop the stale cache before refetching.
        if cachedRecord != nil {
            AppLog.tap.info("[Persistence] Day rolled over — counter resets to 0")
        }
        cachedRecord = nil

        let existing = try fetchAllRecords().first { $0.dayStart == dayStart }

        if let existing {
            cachedRecord = (dayStart, existing)
            return existing
        }

        guard createIfMissing else { return nil }

        let created = DayRecord(dayStart: dayStart, tapCount: 0, createdAt: date, updatedAt: date)
        context.insert(created)
        cachedRecord = (dayStart, created)
        AppLog.persistence.info("[Persistence] Created record for a new day")
        return created
    }

    /// Fetch every record, unsorted and unfiltered.
    ///
    /// Sorting and filtering happen in Swift rather than through
    /// `#Predicate` / `SortDescriptor`. The table holds one row per day — a
    /// decade of daily use is a few thousand rows — so pushing the work into
    /// SQLite buys nothing measurable, while the macro-generated predicates
    /// drag in key paths that are not yet `Sendable` and therefore trip strict
    /// concurrency checking.
    ///
    /// Revisit if the schema ever grows finer-grained rows (per session, per
    /// hour), at which point real predicates start to earn their keep.
    private func fetchAllRecords() throws -> [DayRecord] {
        do {
            return try context.fetch(FetchDescriptor<DayRecord>())
        } catch {
            AppLog.persistence.error(
                "[Persistence] Fetch failed: \(error.localizedDescription, privacy: .public)"
            )
            throw TapRepositoryError.fetchFailed(underlying: error)
        }
    }

    /// Fetch every unlocked-achievement row. The table holds at most one row
    /// per `AchievementID` — a handful — so, as with `fetchAllRecords()`,
    /// there is nothing for a `#Predicate` to buy here.
    private func fetchAllAchievementRecords() throws -> [AchievementRecord] {
        do {
            return try context.fetch(FetchDescriptor<AchievementRecord>())
        } catch {
            AppLog.persistence.error(
                "[Persistence] Achievement fetch failed: \(error.localizedDescription, privacy: .public)"
            )
            throw TapRepositoryError.fetchFailed(underlying: error)
        }
    }

    // MARK: - Debounced Saving

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.saveDebounce)
            guard !Task.isCancelled else { return }

            do {
                try self.performSave()
            } catch {
                // Already logged in performSave. The in-memory count is still
                // correct, and the next tap reschedules another attempt.
                AppLog.persistence.error("[Persistence] Debounced save failed; will retry on next change")
            }
        }
    }

    private func performSave() throws {
        guard hasUnsavedChanges, context.hasChanges else {
            hasUnsavedChanges = false
            return
        }

        do {
            try context.save()
            hasUnsavedChanges = false
            AppLog.persistence.debug("[Persistence] Saved")
        } catch {
            AppLog.persistence.error(
                "[Persistence] Save failed: \(error.localizedDescription, privacy: .public)"
            )
            throw TapRepositoryError.saveFailed(underlying: error)
        }
    }
}

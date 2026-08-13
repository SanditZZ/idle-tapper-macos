//
//  ExportDateFormat.swift
//  Idle Tapper — Calculations
//
//  How an exported day is written down. Pure: a date and a zone in, text out.
//

import Foundation

/// The two ways a `DaySnapshot.dayStart` is rendered in an export file.
///
/// Both live here so the JSON and CSV exports cannot drift apart about which
/// day a row belongs to — the thing they most obviously must agree on.
///
/// **The zone is not incidental.** `dayStart` is *local* midnight, so the
/// instant it stores is only meaningful alongside the zone that produced it.
/// Rendering it in UTC moves the date across the boundary for everyone east or
/// west of Greenwich: local midnight on 15 March in Bangkok is
/// `2026-03-14T17:00:00Z`, which reads as the wrong day. The JSON export did
/// exactly that until this type existed, and no test caught it because the
/// suite pins a UTC calendar, in which the bug is invisible by construction.
enum ExportDateFormat {

    /// `2026-03-15` — the day as the user lived it.
    ///
    /// Used by the CSV export, where the date lands in a spreadsheet column:
    /// Excel and Numbers both parse this as a date without being asked, while a
    /// full timestamp imports as text and has to be cleaned up by hand.
    static func calendarDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        makeCalendarDateFormatter(timeZone: timeZone).string(from: date)
    }

    /// `2026-03-15T00:00:00+07:00` — the same instant, carrying its offset.
    ///
    /// Used by the JSON export. The offset rather than a `Z` is what makes the
    /// date part readable, and it stays valid ISO-8601 either way, so anything
    /// already parsing these files — including `JSONDecoder`'s `.iso8601`
    /// strategy — keeps working unchanged.
    static func iso8601(_ date: Date, timeZone: TimeZone = .current) -> String {
        makeISO8601Formatter(timeZone: timeZone).string(from: date)
    }

    // MARK: - Formatters

    /// Exposed so a caller writing many rows can build one formatter rather than
    /// one per row; `DateFormatter` is expensive to create and a year of history
    /// is 365 of them.
    static func makeCalendarDateFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        // POSIX, so a device set to a non-Gregorian calendar cannot turn
        // 2026 into 2569 BE in a file meant to be machine-readable.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    static func makeISO8601Formatter(timeZone: TimeZone) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = timeZone
        return formatter
    }
}

//
//  HistoryCSV.swift
//  Idle Tapper — Calculations
//
//  The CSV form of a tap history. Pure: days in, text out.
//

import Foundation

/// Renders recorded days as comma-separated text, for the Settings export.
///
/// The sibling of the JSON export rather than a replacement for it: JSON is what
/// survives a round trip back into the app, CSV is what opens in a spreadsheet.
/// They share `ExportDateFormat` so the two can never disagree about which day a
/// row describes.
///
/// **No quoting or escaping, deliberately.** The fields are a `yyyy-MM-dd` date
/// and an integer, neither of which can contain a comma, a quote or a newline,
/// so escaping machinery here would be code that can never run — untested by
/// construction and misleading to read. A field that *could* contain one would
/// need it; adding such a field means adding it then, not now.
enum HistoryCSV {

    /// The header row, without its line break.
    static let header = "date,taps"

    /// Renders every day as one row, oldest first, under a header row.
    ///
    /// Sorted here rather than trusting the caller: the output of a calculation
    /// should not depend on the order it happened to be handed.
    ///
    /// - Parameters:
    ///   - days: The recorded days. May be empty.
    ///   - timeZone: The zone `dayStart` was recorded in. Defaults to the
    ///     current one, which is the zone the app records days in.
    /// - Returns: The file's full contents, ending in a newline. An empty
    ///   history yields the header alone — a file with a header and no rows says
    ///   "you have no history", whereas an empty file is indistinguishable from
    ///   an export that failed halfway.
    static func make(from days: [DaySnapshot], timeZone: TimeZone = .current) -> String {
        let formatter = ExportDateFormat.makeCalendarDateFormatter(timeZone: timeZone)

        let rows = days
            .sorted { $0.dayStart < $1.dayStart }
            .map { "\(formatter.string(from: $0.dayStart)),\($0.tapCount)" }

        return ([header] + rows).joined(separator: "\n") + "\n"
    }
}

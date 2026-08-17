//
//  TapTracker+Export.swift
//  Idle Tapper — Actions layer
//
//  The two Settings export actions. Split out of `TapTracker.swift` when that
//  file reached the size at which this project splits: export is a whole
//  feature of its own, reads the repository and writes nothing, and shares no
//  state with the tap path.
//
//  Both stay thin, as an action should — the date and CSV formatting they need
//  is in `ExportDateFormat` and `HistoryCSV`, which are pure and tested.
//

import Foundation

extension TapTracker {

    /// Export the full history as JSON, for the Settings export action.
    ///
    /// Deliberately not the raw SQLite store: that schema is SwiftData's
    /// private implementation detail, whereas this is a stable, portable format.
    ///
    /// Dates carry the recording zone's offset rather than being converted to
    /// UTC. `JSONEncoder`'s stock `.iso8601` strategy does convert, and since
    /// `dayStart` is *local* midnight that pushed the date part onto the
    /// neighbouring day for every user not on UTC — see `ExportDateFormat`.
    func exportJSON() throws -> Data {
        let history = try repository.allDays()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let timeZone = calendar.timeZone
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ExportDateFormat.iso8601(date, timeZone: timeZone))
        }

        return try encoder.encode(history)
    }

    /// Export the full history as CSV, for the Settings export action.
    ///
    /// The spreadsheet-shaped sibling of `exportJSON()`. Not a round-trippable
    /// format — it drops nothing today, but JSON is the one to re-import.
    func exportCSV() throws -> Data {
        let history = try repository.allDays()
        let text = HistoryCSV.make(from: history, timeZone: calendar.timeZone)
        return Data(text.utf8)
    }
}

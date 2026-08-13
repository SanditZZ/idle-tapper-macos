//
//  HistoryCSVTests.swift
//  IdleTapperTests
//
//  The CSV export. Date rendering itself is covered by `ExportDateFormatTests`;
//  what matters here is the file a spreadsheet actually receives.
//

import Foundation
import Testing
@testable import IdleTapper

@Suite("History CSV")
struct HistoryCSVTests {

    private let calendar = TestSupport.utcCalendar
    private let utc = TimeZone(identifier: "UTC")!

    private func snapshot(_ year: Int, _ month: Int, _ day: Int, count: Int) -> DaySnapshot {
        DaySnapshot(
            dayStart: TestSupport.date(year, month, day, 0, 0, calendar: calendar),
            tapCount: count
        )
    }

    /// What someone gets if they export straight after deleting everything. A
    /// header with no rows reads as "no history"; an empty file is
    /// indistinguishable from an export that failed halfway through.
    @Test("An empty history produces the header alone, not an empty file")
    func emptyHistoryKeepsTheHeader() {
        let csv = HistoryCSV.make(from: [], timeZone: utc)

        #expect(csv == "date,taps\n")
    }

    /// Pinned in full rather than by property, because the whole value of a CSV
    /// is that another program can read it — a change to the separator, the
    /// column order or the header would otherwise break that silently.
    @Test("A known history produces exactly the expected text")
    func rendersKnownDays() {
        let csv = HistoryCSV.make(
            from: [
                snapshot(2026, 3, 14, count: 5),
                snapshot(2026, 3, 15, count: 7),
                snapshot(2026, 3, 16, count: 0),
            ],
            timeZone: utc
        )

        #expect(csv == """
            date,taps
            2026-03-14,5
            2026-03-15,7
            2026-03-16,0

            """)
    }

    /// A calculation's output must not depend on the order it was handed its
    /// input, even though the repository already sorts.
    @Test("Rows are oldest first regardless of the order given")
    func sortsIndependentlyOfInput() {
        let csv = HistoryCSV.make(
            from: [
                snapshot(2026, 3, 16, count: 3),
                snapshot(2026, 3, 14, count: 1),
                snapshot(2026, 3, 15, count: 2),
            ],
            timeZone: utc
        )

        #expect(csv.contains("2026-03-14,1\n2026-03-15,2\n2026-03-16,3"))
    }

    /// `dayStart` here is midnight *in Bangkok*; rendered in UTC that instant is
    /// 17:00 the previous afternoon, so a converting formatter would date the
    /// row 14 March. The user tapped on the 15th and the file has to say so.
    @Test("A local midnight is dated by its own zone, not converted to UTC")
    func usesTheRecordingZone() {
        var bangkok = Calendar(identifier: .gregorian)
        bangkok.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        bangkok.locale = Locale(identifier: "en_US_POSIX")

        let midnight = TestSupport.date(2026, 3, 15, 0, 0, calendar: bangkok)
        let csv = HistoryCSV.make(
            from: [DaySnapshot(dayStart: midnight, tapCount: 4)],
            timeZone: bangkok.timeZone
        )

        #expect(csv.contains("2026-03-15,4"))
        #expect(!csv.contains("2026-03-14"))
    }

    /// The two exports must not disagree about which day a row belongs to,
    /// which stays true only while both read their date from the same place.
    @Test("The CSV date is the date part of the JSON date")
    func agreesWithTheJSONDate() {
        let newYork = TestSupport.newYorkCalendar
        let midnight = TestSupport.date(2026, 3, 15, 0, 0, calendar: newYork)

        let csvDate = ExportDateFormat.calendarDate(midnight, timeZone: newYork.timeZone)
        let jsonDate = ExportDateFormat.iso8601(midnight, timeZone: newYork.timeZone)

        #expect(jsonDate.hasPrefix(csvDate))
    }
}

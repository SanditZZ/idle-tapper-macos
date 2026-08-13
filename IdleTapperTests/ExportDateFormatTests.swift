//
//  ExportDateFormatTests.swift
//  IdleTapperTests
//
//  How an exported day is written down. The zone cases are the point: the rest
//  of the suite pins a UTC calendar, in which local midnight and UTC midnight
//  are the same instant and every time-zone bug is invisible by construction.
//

import Foundation
import Testing
@testable import IdleTapper

@Suite("Export date format")
struct ExportDateFormatTests {

    private var bangkok: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// The offset is what makes the date part readable. A `Z` here would mean
    /// the value had been converted to UTC, which is the bug this type exists
    /// to prevent: local midnight on the 15th becomes 17:00 on the 14th.
    @Test("An ISO-8601 date carries its own offset rather than converting")
    func iso8601KeepsTheOffset() {
        let midnight = TestSupport.date(2026, 3, 15, 0, 0, calendar: bangkok)

        #expect(ExportDateFormat.iso8601(midnight, timeZone: bangkok.timeZone)
            == "2026-03-15T00:00:00+07:00")
    }

    /// Anything already parsing an exported file has to keep working, so the
    /// output must still satisfy `JSONDecoder`'s stock ISO-8601 strategy — and
    /// decode back to the very same instant, not merely to something valid.
    @Test("An offset date still decodes through the stock ISO-8601 strategy")
    func iso8601RoundTrips() throws {
        let midnight = TestSupport.date(2026, 3, 15, 0, 0, calendar: bangkok)
        let text = ExportDateFormat.iso8601(midnight, timeZone: bangkok.timeZone)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Date.self, from: Data("\"\(text)\"".utf8))

        #expect(decoded == midnight)
    }

    /// A zone behind UTC errs the other way — a converted value would date the
    /// row a day that had not happened yet.
    @Test("A zone behind UTC is dated by its own zone too")
    func handlesZonesBehindUTC() {
        let newYork = TestSupport.newYorkCalendar
        let midnight = TestSupport.date(2026, 3, 15, 0, 0, calendar: newYork)

        #expect(ExportDateFormat.calendarDate(midnight, timeZone: newYork.timeZone)
            == "2026-03-15")
    }

    /// A device set to a non-Gregorian calendar must not turn 2026 into 2569 BE
    /// in a file meant to be read by another program.
    @Test("A non-Gregorian device calendar does not reach the file")
    func ignoresTheDeviceCalendar() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "Asia/Bangkok")!

        let midnight = TestSupport.date(2569, 3, 15, 0, 0, calendar: buddhist)

        #expect(ExportDateFormat.calendarDate(midnight, timeZone: buddhist.timeZone)
            == "2026-03-15")
    }
}

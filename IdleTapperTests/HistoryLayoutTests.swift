//
//  HistoryLayoutTests.swift
//  Idle Tapper — Tests
//

import Testing
@testable import IdleTapper

@Suite("History layout")
struct HistoryLayoutTests {

    @Test("A list of rows asks for room proportional to the row count")
    func heightScalesWithRowCount() {
        #expect(HistoryLayout.listHeight(rowCount: 1, rowHeight: 30) == 30)
        #expect(HistoryLayout.listHeight(rowCount: 4, rowHeight: 30) == 120)
    }

    /// The case the change was made for: an empty list must not reserve space,
    /// or the card renders as a strip of padding around nothing.
    @Test("No rows asks for no height")
    func emptyListAsksForNothing() {
        #expect(HistoryLayout.listHeight(rowCount: 0, rowHeight: 30) == 0)
    }

    /// Guards against a negative frame, which SwiftUI treats as a layout error
    /// rather than clamping.
    @Test("Nonsense input yields zero rather than a negative height")
    func nonsenseInputIsSafe() {
        #expect(HistoryLayout.listHeight(rowCount: -3, rowHeight: 30) == 0)
        #expect(HistoryLayout.listHeight(rowCount: 5, rowHeight: 0) == 0)
        #expect(HistoryLayout.listHeight(rowCount: 5, rowHeight: -10) == 0)
    }

    @Test("The default row height comes from the design tokens")
    func defaultsToTheToken() {
        #expect(
            HistoryLayout.listHeight(rowCount: 3)
                == DesignTokens.Layout.historyRowHeight * 3
        )
    }
}

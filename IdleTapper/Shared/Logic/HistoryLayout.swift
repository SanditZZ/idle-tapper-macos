//
//  HistoryLayout.swift
//  Idle Tapper — Calculations
//
//  Sizing for the History window's day list. Pure: rows in, points out.
//

import CoreGraphics

/// Layout arithmetic for the History window.
enum HistoryLayout {

    /// Columns in the summary tile grid.
    ///
    /// The summary carries seven statistics. In one row, at the window's 620pt
    /// minimum, each tile gets about 65pt — narrower than "LONGEST STREAK" can
    /// be drawn even with `StatTile`'s `minimumScaleFactor(0.8)`, so the labels
    /// stop saying what they are just as the window gets hard to read. Four
    /// columns give roughly 119pt at that same width, and the seven tiles fall
    /// as four then three with nothing having to shrink.
    static let summaryColumnCount = 4

    /// Height the day list wants for `rowCount` rows.
    ///
    /// Applied as a *maximum*, not a fixed height, which is what makes it work
    /// at both ends. The list used to be pinned to `maxHeight: .infinity`, so
    /// two days of history rendered as two rows followed by a large empty area
    /// inside the card — the card claimed space it had nothing to put in.
    /// Capping it at what the rows actually need lets the card hug its content
    /// when history is short, while a long history still exceeds the space the
    /// window can offer and scrolls exactly as before.
    ///
    /// - Parameters:
    ///   - rowCount: Number of rows the list will render.
    ///   - rowHeight: Height of one row including its divider.
    /// - Returns: The list's preferred height, never negative.
    static func listHeight(
        rowCount: Int,
        rowHeight: CGFloat = DesignTokens.Layout.historyRowHeight
    ) -> CGFloat {
        guard rowCount > 0, rowHeight > 0 else { return 0 }
        return CGFloat(rowCount) * rowHeight
    }
}

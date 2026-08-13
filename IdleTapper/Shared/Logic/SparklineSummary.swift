//
//  SparklineSummary.swift
//  Idle Tapper — Calculations
//
//  What the history chart says when it cannot be seen. Pure: bars in, sentence
//  out.
//

import Foundation

/// A spoken summary of a run of daily totals.
///
/// The chart used to announce every bar in order — "13 Aug: 771, 12 Aug: 0,
/// 11 Aug: 3,026, …". At the popover's seven days that is merely tedious; at the
/// History window's ranges it is 30, 90 or **365** fragments read one after
/// another, with no way to skip and nothing that answers the question someone
/// actually asked, which is "how am I doing".
///
/// So this reports the shape of the data rather than its contents: how much, over
/// how long, how many days were active, the best day, and where today sits. A
/// listener gets the same impression in one sentence that a sighted user gets
/// from one glance.
///
/// Deliberately carries **no dates**. Spelling out which day was busiest reads
/// well in English and badly once a locale renders it "Tuesday, 11 August 2569
/// BE" — long, and the year is noise when every bar is inside the last month.
/// The day list underneath already gives exact dates to anyone who wants them.
struct SparklineSummary: Equatable {

    /// Days covered by the chart, including days with no taps.
    let dayCount: Int

    /// Days that have at least one tap.
    let activeDayCount: Int

    /// Taps across every day shown.
    let total: Int

    /// The highest single-day total shown.
    let peak: Int

    /// Today's total, when today is one of the days shown.
    let todayCount: Int?

    /// Derives the summary from the bars the chart is drawing, so the two can
    /// never disagree about what is on screen.
    static func make(from bars: [DayBar]) -> SparklineSummary {
        SparklineSummary(
            dayCount: bars.count,
            activeDayCount: bars.count { $0.tapCount > 0 },
            total: bars.reduce(0) { $0 + $1.tapCount },
            peak: bars.map(\.tapCount).max() ?? 0,
            todayCount: bars.first(where: \.isToday)?.tapCount
        )
    }

    /// The sentence VoiceOver reads.
    var announcement: String {
        guard dayCount > 0 else { return "No history yet." }
        guard total > 0 else { return "No taps in the last \(Self.days(dayCount))." }

        var sentences = [
            // "on 2 of them", not "on 2 days of them" — the unit is already
            // established by the clause before it, and repeating it reads as a
            // stutter when spoken aloud.
            "\(total.formatted()) taps over \(Self.days(dayCount)), "
                + "on \(activeDayCount.formatted()) of them.",
            "Best day \(peak.formatted()).",
        ]

        // Today is what the listener is most likely to be checking, so it goes
        // last, where it is easiest to catch without replaying the whole line.
        if let todayCount {
            sentences.append(todayCount > 0 ? "\(todayCount.formatted()) today." : "None today.")
        }

        return sentences.joined(separator: " ")
    }

    /// "1 day" / "6 days" — a bare count reads as "1 days" often enough to be
    /// worth the two lines.
    private static func days(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count.formatted()) days"
    }
}

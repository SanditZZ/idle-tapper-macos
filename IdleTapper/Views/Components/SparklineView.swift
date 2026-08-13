//
//  SparklineView.swift
//  Idle Tapper — Components
//
//  Compact bar chart of recent daily totals. Deliberately hand-drawn with
//  shapes rather than Swift Charts: at this size axes and legends are noise,
//  and it keeps the popover cheap to render during fast tapping.
//

import SwiftUI

/// A small bar chart of daily tap totals, oldest bar first.
struct SparklineView: View {

    let bars: [DayBar]

    var height: CGFloat = DesignTokens.Layout.sparklineHeight

    /// Whether to label each bar with its weekday initial.
    var showsWeekdayLabels: Bool = true

    /// Whether to caption the tallest bar with its value.
    ///
    /// Off in the popover, where the numbers that matter are already spelled out
    /// above the chart. On in the History window, where the chart is the main
    /// content and was otherwise unreadable: the bars carried no reference of
    /// any kind, so the tallest one could only be valued by cross-checking the
    /// list underneath it.
    var showsPeakLabel: Bool = false

    private var peak: Int { StatsCalculator.peak(of: bars) }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
            if showsPeakLabel && peak > 0 {
                peakCaption
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(bars) { bar in
                    barShape(for: bar)
                }
            }
            .frame(height: height)
            // Behind the bars, so it reads as the line they stand on rather
            // than as another mark competing with them.
            .background(alignment: .bottom) {
                Rectangle()
                    .fill(AppColors.chartBaseline)
                    .frame(height: DesignTokens.Layout.chartBaselineThickness)
            }

            if showsWeekdayLabels {
                HStack(spacing: 4) {
                    ForEach(bars) { bar in
                        Text(Self.weekdayInitial(for: bar.dayStart))
                            .font(DesignTokens.Typography.tiny)
                            .foregroundStyle(AppColors.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recent daily taps")
        .accessibilityValue(accessibilitySummary)
    }

    /// Sits in its own row above the bars rather than floating over them: the
    /// tallest bar reaches the full height by definition, so anything drawn
    /// inside the plot area would land on top of the very bar it labels.
    private var peakCaption: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Text("Peak \(peak.formatted())")
                .font(DesignTokens.Typography.caption)
                .monospacedDigit()
                .foregroundStyle(AppColors.textTertiary)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Bars

    private func barShape(for bar: DayBar) -> some View {
        GeometryReader { geometry in
            let fraction = bar.normalizedHeight(max: peak)
            // A day with no taps draws nothing — the baseline already shows
            // where it would have stood. See `AppColors.chartBaseline`.
            let barHeight = bar.tapCount == 0
                ? 0
                : max(geometry.size.height * fraction, DesignTokens.Layout.minimumBarHeight)

            RoundedRectangle(cornerRadius: DesignTokens.Radius.tiny, style: .continuous)
                .fill(bar.isToday ? AppColors.barToday : AppColors.barPast)
                .frame(height: barHeight)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity)
        .help(Self.tooltip(for: bar))
    }

    // MARK: - Formatting

    private var accessibilitySummary: String {
        bars
            .map { "\(Self.mediumDate(for: $0.dayStart)): \($0.tapCount)" }
            .joined(separator: ", ")
    }

    private static func tooltip(for bar: DayBar) -> String {
        "\(mediumDate(for: bar.dayStart)) — \(bar.tapCount) taps"
    }

    private static func weekdayInitial(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter.string(from: date)
    }

    private static func mediumDate(for date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

#Preview {
    SparklineView(
        bars: (0..<7).map { offset in
            DayBar(
                dayStart: Calendar.current.date(byAdding: .day, value: -6 + offset, to: Date())!,
                tapCount: [12, 48, 0, 91, 33, 64, 20][offset],
                isToday: offset == 6
            )
        }
    )
    .padding()
    .frame(width: DesignTokens.Layout.popoverWidth)
}

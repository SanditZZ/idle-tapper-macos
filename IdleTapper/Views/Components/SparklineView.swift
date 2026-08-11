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

    private var peak: Int { StatsCalculator.peak(of: bars) }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.extraSmall) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(bars) { bar in
                    barShape(for: bar)
                }
            }
            .frame(height: height)

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

    // MARK: - Bars

    private func barShape(for bar: DayBar) -> some View {
        GeometryReader { geometry in
            let fraction = bar.normalizedHeight(max: peak)
            let barHeight = max(geometry.size.height * fraction, 2)

            RoundedRectangle(cornerRadius: DesignTokens.Radius.tiny, style: .continuous)
                .fill(fill(for: bar))
                .frame(height: barHeight)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity)
        .help(Self.tooltip(for: bar))
    }

    private func fill(for bar: DayBar) -> Color {
        if bar.tapCount == 0 { return AppColors.barEmpty }
        return bar.isToday ? AppColors.barToday : AppColors.barPast
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

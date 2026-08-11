//
//  HistoryView.swift
//  Idle Tapper — History window
//
//  Daily totals over the configured range, as a chart plus a list.
//

import SwiftUI

struct HistoryView: View {

    @Bindable var tracker: TapTracker
    @Bindable var settings: AppSettings

    /// Bars for the selected range. Recomputed when the range changes or the
    /// window reappears rather than on every tap.
    @State private var bars: [DayBar] = []

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            header
            summary
            chart
            Divider().opacity(0.5)
            list
        }
        .padding(DesignTokens.Spacing.cardPadding)
        // The day list scrolls on its own, so the window only needs a floor
        // that keeps the chart and the list both usable — not a floor equal to
        // the size it opens at, which is what stopped it being resized at all.
        .frame(
            minWidth: DesignTokens.Layout.historyWindowMinSize.width,
            idealWidth: DesignTokens.Layout.historyWindowSize.width,
            minHeight: DesignTokens.Layout.historyWindowMinSize.height,
            idealHeight: DesignTokens.Layout.historyWindowSize.height
        )
        .task { reload() }
        .onChange(of: settings.historyRangeDays) { _, _ in reload() }
        .onChange(of: tracker.todayCount) { _, _ in reload() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tap History")
                    .font(DesignTokens.Typography.pageTitle)
                Text("Daily totals, reset at local midnight")
                    .font(DesignTokens.Typography.pageSubtitle)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Picker("Range", selection: $settings.historyRangeDays) {
                Text("7 days").tag(7)
                Text("30 days").tag(30)
                Text("90 days").tag(90)
                Text("1 year").tag(365)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 110)
        }
    }

    private var summary: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            StatTile(
                label: "All time",
                value: tracker.stats.allTime.formatted(),
                systemImage: "sum"
            )
            StatTile(
                label: "Best day",
                value: tracker.stats.bestDay.formatted(),
                systemImage: "trophy.fill",
                tint: AppColors.warning
            )
            StatTile(
                label: "Current streak",
                value: "\(tracker.stats.currentStreak) days",
                systemImage: "flame.fill",
                tint: AppColors.error
            )
            StatTile(
                label: "Longest streak",
                value: "\(tracker.stats.longestStreak) days",
                systemImage: "crown.fill",
                tint: AppColors.warning
            )
            StatTile(
                label: "Daily average",
                value: averageText,
                systemImage: "chart.line.uptrend.xyaxis"
            )
        }
        .appCard()
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text("Last \(settings.historyRangeDays) days")
                .font(DesignTokens.Typography.sectionTitle)
                .foregroundStyle(AppColors.textSecondary)

            // Weekday initials become unreadable past a couple of weeks.
            SparklineView(
                bars: bars,
                height: 90,
                showsWeekdayLabels: settings.historyRangeDays <= 14
            )
        }
    }

    private var list: some View {
        Group {
            if activeBars.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(activeBars.reversed()) { bar in
                            row(for: bar)
                            Divider().opacity(0.3)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func row(for bar: DayBar) -> some View {
        HStack {
            Text(bar.dayStart.formatted(date: .complete, time: .omitted))
                .font(DesignTokens.Typography.body)
                .foregroundStyle(bar.isToday ? AppColors.accent : AppColors.textPrimary)

            if bar.isToday {
                Text("TODAY")
                    .font(DesignTokens.Typography.tiny)
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(AppColors.tint(AppColors.accent))
                    )
            }

            Spacer()

            Text(bar.tapCount.formatted())
                .font(DesignTokens.Typography.bodyMedium)
                .monospacedDigit()
        }
        .padding(.vertical, DesignTokens.Spacing.small)
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.small) {
            Image(systemName: "hand.tap")
                .font(.system(size: 28))
                .foregroundStyle(AppColors.textTertiary)
            Text("No taps recorded yet")
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundStyle(AppColors.textSecondary)
            Text("Open the menu bar popover and start tapping.")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Calculations

    /// Only days that actually have taps appear in the list; the chart still
    /// shows the empty days so the timeline stays continuous.
    private var activeBars: [DayBar] {
        bars.filter { $0.tapCount > 0 }
    }

    private var averageText: String {
        let average = tracker.stats.averagePerActiveDay
        return average > 0 ? String(format: "%.0f", average) : "0"
    }

    private func reload() {
        bars = tracker.historyBars()
    }
}

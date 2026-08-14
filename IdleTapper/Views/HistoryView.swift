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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.cardSpacing) {
            header
            summary
            chart
            list

            // Absorbs whatever the cards do not need. Without it the list card
            // takes the slack and renders its rows above a void.
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.Spacing.contentPadding)
        .padding(.bottom, DesignTokens.Spacing.contentPadding)
        // The window draws under its title bar so the background runs the full
        // height; the header has to start below the traffic lights.
        .padding(.top, DesignTokens.Layout.titleBarInset)
        .background(AppColors.windowSurface)
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
        HStack(alignment: .center, spacing: DesignTokens.Spacing.medium) {
            SettingsPageHeader(
                title: "Tap History",
                subtitle: "Daily totals, reset at local midnight",
                systemImage: "chart.bar.fill"
            )

            Picker("Range", selection: $settings.historyRangeDays) {
                Text("7 days").tag(7)
                Text("30 days").tag(30)
                Text("90 days").tag(90)
                Text("1 year").tag(365)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            // No `accessibilityLabel` here on purpose. `labelsHidden()` only
            // hides the label visually — the "Range" title is still exposed to
            // VoiceOver, and adding one appends rather than replaces: the
            // control announced itself as "Range, History range".
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
                value: StatsCalculator.dayCountText(tracker.stats.currentStreak),
                systemImage: "flame.fill",
                tint: AppColors.error
            )
            StatTile(
                label: "Longest streak",
                value: StatsCalculator.dayCountText(tracker.stats.longestStreak),
                systemImage: "crown.fill",
                tint: AppColors.warning
            )
            // "Daily average" was wrong for what this shows: the figure is
            // `averagePerActiveDay`, so it divides by the days that have taps,
            // not by the days in the range. With taps on 2 of 30 days it read
            // "Daily average 1,899" beside a chart that was empty nearly
            // everywhere — a number that looked broken because the label
            // claimed something the maths never did.
            StatTile(
                label: "Avg. active day",
                value: averageText,
                systemImage: "chart.line.uptrend.xyaxis"
            )
        }
        .appCard()
    }

    private var chart: some View {
        SettingsCard(title: "Last \(settings.historyRangeDays) days") {
            // Weekday initials become unreadable past a couple of weeks.
            SparklineView(
                bars: bars,
                height: DesignTokens.Layout.historyChartHeight,
                showsWeekdayLabels: settings.historyRangeDays <= 14,
                showsPeakLabel: true
            )
        }
    }

    private var list: some View {
        SettingsCard(title: "Days with taps") {
            if activeBars.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(activeBars.reversed()) { bar in
                            row(for: bar)
                            AppDivider()
                        }
                    }
                }
                // A maximum, not a fixed height: a short history lets the card
                // hug its rows, while a long one still exceeds the window and
                // scrolls. See `HistoryLayout.listHeight(rowCount:rowHeight:)`.
                .frame(maxHeight: HistoryLayout.listHeight(rowCount: activeBars.count))
            }
        }
    }

    private func row(for bar: DayBar) -> some View {
        HStack {
            Text(bar.dayStart.formatted(date: .complete, time: .omitted))
                .font(DesignTokens.Typography.body)
                .foregroundStyle(bar.isToday ? AppColors.accentOnText : AppColors.textPrimary)

            if bar.isToday {
                Text("TODAY")
                    .font(DesignTokens.Typography.tiny)
                    .foregroundStyle(AppColors.accentOnText)
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
        // A row is one fact — a date and its total. Left uncombined it is three
        // stops (date, the "TODAY" badge, the number), and the number arrives
        // detached from the day it belongs to.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            bar.isToday
                ? "Today, \(bar.dayStart.formatted(date: .complete, time: .omitted))"
                : bar.dayStart.formatted(date: .complete, time: .omitted)
        )
        .accessibilityValue("\(bar.tapCount.formatted()) taps")
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
        .frame(
            maxWidth: .infinity,
            minHeight: DesignTokens.Layout.historyEmptyStateHeight
        )
    }

    // MARK: - Calculations

    /// Only days that actually have taps appear in the list; the chart still
    /// shows the empty days so the timeline stays continuous.
    private var activeBars: [DayBar] {
        bars.filter { $0.tapCount > 0 }
    }

    private var averageText: String {
        StatsCalculator.averageText(tracker.stats.averagePerActiveDay)
    }

    private func reload() {
        bars = tracker.historyBars()
    }
}

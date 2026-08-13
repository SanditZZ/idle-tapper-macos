//
//  PopoverContentView.swift
//  Idle Tapper — Popover
//
//  The main interface: today's count, the tap button, a week of history and the
//  entry points to the other windows.
//

import SwiftUI

struct PopoverContentView: View {

    @Bindable var tracker: TapTracker

    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            header
            counter
            TapButton(action: tracker.tap)
            statsRow
            sparklineSection

            if let message = tracker.lastErrorMessage {
                errorBanner(message)
            }

            if tracker.isEphemeral {
                ephemeralBanner
            }

            Divider().opacity(0.5)
            footer
        }
        .padding(DesignTokens.Spacing.popoverPadding)
        .frame(width: DesignTokens.Layout.popoverWidth)
        // Applied after the frame so it covers the whole popover body rather
        // than just the stack. See `AppColors.popoverSurface` for why the
        // popover cannot rely on its own backdrop alone.
        .background(AppColors.popoverSurface)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("Today")
                .font(DesignTokens.Typography.sectionLabel)
                .foregroundStyle(AppColors.textSecondary)

            Spacer()

            Text(Date().formatted(date: .abbreviated, time: .omitted))
                .font(DesignTokens.Typography.tiny)
                .foregroundStyle(AppColors.textTertiary)
        }
    }

    private var counter: some View {
        Text(tracker.todayCount, format: .number)
            .font(DesignTokens.Typography.counter)
            .monospacedDigit()
            .foregroundStyle(AppColors.textPrimary)
            .contentTransition(.numericText())
            .animation(DesignTokens.Motion.counterChange, value: tracker.todayCount)
            .accessibilityLabel("Taps today")
            .accessibilityValue("\(tracker.todayCount)")
    }

    private var statsRow: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            StatTile(
                label: "All time",
                value: tracker.stats.allTime.formatted(),
                systemImage: "sum",
                alignment: .center
            )
            StatTile(
                label: "Best day",
                value: tracker.stats.bestDay.formatted(),
                systemImage: "trophy.fill",
                tint: AppColors.warning,
                alignment: .center
            )
            StatTile(
                label: "Streak",
                value: "\(tracker.stats.currentStreak)d",
                systemImage: "flame.fill",
                tint: AppColors.error,
                alignment: .center
            )
        }
        .appCard(padding: DesignTokens.Spacing.small)
    }

    private var sparklineSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text("Last \(TapTracker.sparklineDayCount) days")
                .font(DesignTokens.Typography.sectionLabel)
                .foregroundStyle(AppColors.textSecondary)

            SparklineView(bars: tracker.recentBars)
        }
    }

    private var footer: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            footerButton("History", systemImage: "chart.bar.fill", action: onOpenHistory)
            footerButton("Settings", systemImage: "gearshape.fill", action: onOpenSettings)

            Spacer()

            Button(action: onQuit) {
                Image(systemName: "power")
                    .font(.system(size: DesignTokens.Icons.small))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.textSecondary)
            .help("Quit Idle Tapper")
            .accessibilityLabel("Quit Idle Tapper")
        }
    }

    private func footerButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(DesignTokens.Typography.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppColors.textSecondary)
    }

    // MARK: - Banners

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(DesignTokens.Typography.caption)
            .foregroundStyle(AppColors.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .fill(AppColors.tint(AppColors.error))
            )
    }

    private var ephemeralBanner: some View {
        Label(
            "History is not being saved — the database could not be opened.",
            systemImage: "externaldrive.badge.exclamationmark"
        )
        .font(DesignTokens.Typography.caption)
        .foregroundStyle(AppColors.warning)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                .fill(AppColors.tint(AppColors.warning))
        )
    }
}

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
    @Bindable var settings: AppSettings

    /// Mirrors `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.
    ///
    /// Read through the environment rather than from `NSWorkspace` directly:
    /// it is the same system setting, but SwiftUI already observes it, so a
    /// change in System Settings reaches an open popover without this view
    /// owning a notification observer that would have to be torn down.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void
    let onOpenAchievements: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            header
            counter
            TapButton(
                action: tracker.tap,
                todayCount: tracker.todayCount,
                rightClickCounts: settings.rightClickTaps
            )
                .overlay { MilestoneBurstView(milestone: celebratedMilestone) }
                // The burst's field is far larger than the button it is
                // centred on, so it overlaps the rows below. Without an
                // explicit z-index those rows would draw over it — the
                // particles would slide *behind* the stats card on the way
                // down, which reads as a glitch rather than as depth.
                .zIndex(1)

            statsRow
            sparklineSection

            if let unlock = tracker.latestUnlock {
                achievementBanner(unlock)
            }

            if let milestone = tracker.activeMilestone {
                milestoneBanner(milestone)
            }

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
        // The milestone burst is drawn in a field taller than the popover, so
        // that particles are not sliced off mid-flight. This is what keeps the
        // ones that would have escaped inside the window.
        .clipped()
    }

    /// The milestone to celebrate with a burst, if any.
    ///
    /// Two independent suppressions, and either is enough. Reduce Motion means
    /// moving things are a problem in themselves; `showVisualEffects` means the
    /// user finds this particular one distracting. Neither implies the other,
    /// so neither is derived from the other.
    ///
    /// Only the *burst* is gated. `tracker.activeMilestone` still raises the
    /// banner below, because that is what says which number was reached and is
    /// the only part of the celebration a screen reader ever hears.
    private var celebratedMilestone: Int? {
        guard settings.showVisualEffects, !reduceMotion else { return nil }
        return tracker.activeMilestone
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
        // "Today" and the date are one fact, and two stops that each read half
        // of it is how a two-word header becomes confusing.
        .accessibilityElement(children: .combine)
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
                // Lets rotor navigation jump between the popover's sections
                // instead of stepping through every element to reach the chart.
                .accessibilityAddTraits(.isHeader)

            SparklineView(bars: tracker.recentBars)
        }
    }

    private var footer: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            footerButton("History", systemImage: "chart.bar.fill", action: onOpenHistory)
            footerButton("Settings", systemImage: "gearshape.fill", action: onOpenSettings)

            Spacer()

            // Icon-only, unlike History/Settings: the popover is 260pt wide, and
            // a third labelled button starts crowding it. Trophy carries enough
            // meaning on its own beside Quit's power glyph.
            Button(action: onOpenAchievements) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: DesignTokens.Icons.small))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.textSecondary)
            .help("Achievements")
            .accessibilityLabel("Achievements")

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

    private func achievementBanner(_ definition: AchievementDefinition) -> some View {
        Label("Achievement unlocked: \(definition.title)", systemImage: "trophy.fill")
            .font(DesignTokens.Typography.caption)
            .foregroundStyle(AppColors.warning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .fill(AppColors.tint(AppColors.warning))
            )
            .accessibilityElement(children: .combine)
    }

    private func milestoneBanner(_ milestone: Int) -> some View {
        Label("Milestone: \(milestone.formatted()) taps today", systemImage: "star.fill")
            .font(DesignTokens.Typography.caption)
            .foregroundStyle(AppColors.accentOnText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .fill(AppColors.tint(AppColors.accent))
            )
            .accessibilityElement(children: .combine)
    }

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

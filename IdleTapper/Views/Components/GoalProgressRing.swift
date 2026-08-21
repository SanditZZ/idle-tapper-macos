//
//  GoalProgressRing.swift
//  Idle Tapper — Components
//
//  Progress toward today's goal, drawn as a ring around the counter.
//
//  Purely presentational, like everything in this folder: the arithmetic is
//  `GoalCalculator`'s and is passed in already computed. Nothing here decides
//  what "met the goal" means.
//

import SwiftUI

/// A ring showing how far through today's goal the user is.
struct GoalProgressRing<Content: View>: View {

    /// Taps recorded today.
    let todayCount: Int

    /// Today's target. Zero or less means no goal is set, and the ring is not
    /// drawn at all — the counter renders alone, exactly as before goals
    /// existed.
    let goal: Int

    /// Whether the goal has been met, drawn in the success colour rather than
    /// the accent.
    ///
    /// Passed in rather than derived from `todayCount >= goal` here, so the
    /// view cannot drift from `GoalCalculator.metGoal(tapCount:goalTarget:)` —
    /// which is the same rule the streak uses, and must stay the only copy.
    let isMet: Bool

    /// The counter this ring is drawn around.
    let content: () -> Content

    /// Spelled out rather than left to the memberwise synthesis, as
    /// `SettingsCard` does, so the trailing closure is unambiguously a view
    /// builder at every call site.
    init(
        todayCount: Int,
        goal: Int,
        isMet: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.todayCount = todayCount
        self.goal = goal
        self.isMet = isMet
        self.content = content
    }

    private var fraction: Double {
        GoalCalculator.fraction(tapCount: todayCount, goalTarget: goal)
    }

    private var percent: Int {
        GoalCalculator.percent(tapCount: todayCount, goalTarget: goal)
    }

    private var remaining: Int {
        GoalCalculator.remaining(tapCount: todayCount, goalTarget: goal)
    }

    private var tint: Color {
        isMet ? AppColors.success : AppColors.accent
    }

    var body: some View {
        if GoalCalculator.normalized(goal) == nil {
            content()
        } else {
            ring
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(
                    AppColors.tint(tint),
                    lineWidth: DesignTokens.Layout.goalRingThickness
                )

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    tint,
                    style: StrokeStyle(
                        lineWidth: DesignTokens.Layout.goalRingThickness,
                        lineCap: .round
                    )
                )
                // Starts at the top and runs clockwise. `trim` begins at three
                // o'clock, which reads as an arbitrary starting point on a
                // progress ring.
                .rotationEffect(.degrees(-90))
                .animation(DesignTokens.Motion.counterChange, value: fraction)

            content()
                .padding(DesignTokens.Layout.goalRingInset)
        }
        .frame(
            width: DesignTokens.Layout.goalRingDiameter,
            height: DesignTokens.Layout.goalRingDiameter
        )
        // One element, not a ring plus a number that each read half the fact.
        // The counter's own label is replaced here rather than added to,
        // because "1,234. Taps today. 62% of your goal" is three stops for one
        // glanceable thing.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Taps today")
        .accessibilityValue(accessibilityValue)
    }

    /// What VoiceOver reads. The percentage alone would be the one part of this
    /// a sighted user does *not* rely on — the ring shows that — so the spoken
    /// version leads with the numbers and says how many are left.
    private var accessibilityValue: String {
        let base = "\(todayCount.formatted()) of \(goal.formatted()), \(percent) percent"

        guard !isMet else {
            return "\(base). Goal reached."
        }

        return "\(base). \(remaining.formatted()) to go."
    }
}

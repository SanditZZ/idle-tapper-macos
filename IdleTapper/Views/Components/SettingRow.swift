//
//  SettingRow.swift
//  Idle Tapper — A labelled control inside a settings card
//
//  Pairs a label, and the sentence explaining it, with whatever control
//  operates it. Every row in Settings is built from this, so the gap between a
//  label and its control is decided once instead of per section.
//

import SwiftUI

/// A control with its label and explanation on the leading side.
struct SettingRow<Control: View>: View {

    let title: String
    let description: String?
    @ViewBuilder let control: Control

    init(
        _ title: String,
        description: String? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.description = description
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.large) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.controlCaption) {
                Text(title)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(AppColors.textPrimary)

                if let description {
                    Text(description)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // A minimum keeps the control off the label when the label wraps to
            // the full width of a narrow window.
            Spacer(minLength: DesignTokens.Spacing.medium)

            control
        }
    }
}

/// A switch with its label and explanation, the most common row in Settings.
struct SettingToggle: View {

    let title: String
    let description: String?
    @Binding var isOn: Bool

    init(_ title: String, description: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.description = description
        self._isOn = isOn
    }

    var body: some View {
        SettingRow(title, description: description) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        // Without combining, VoiceOver reads the label and the switch as two
        // unrelated elements and the switch announces itself as unlabelled.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(description.map { "\(title). \($0)" } ?? title)
    }
}

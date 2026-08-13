//
//  SettingsSection.swift
//  Idle Tapper — The pages Settings is divided into
//
//  One case per sidebar item. Adding a section here puts it in the sidebar and
//  gives it a title, an icon and a subtitle; only the page's own content has to
//  be written separately.
//

import Foundation

/// A page of the Settings window.
enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case updates
    case data
    case about

    var id: String { rawValue }

    /// Sidebar label and page title.
    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .updates: "Updates"
        case .data: "Data"
        case .about: "About"
        }
    }

    /// SF Symbol shown in the sidebar and in the page header. Never emoji.
    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "menubar.rectangle"
        case .updates: "arrow.triangle.2.circlepath"
        case .data: "internaldrive"
        case .about: "info.circle"
        }
    }

    /// One line under the page title saying what the page is for.
    var subtitle: String {
        switch self {
        case .general: "How Idle Tapper starts and behaves"
        case .appearance: "What the menu bar item shows"
        case .updates: "How new versions are found"
        case .data: "Your tap history, on this Mac"
        case .about: "Version and project links"
        }
    }
}

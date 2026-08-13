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
///
/// There is no `appearance` case. It existed, holding only the menu bar style
/// picker, and the whole app has about eleven settings in it — split five ways
/// that left Appearance's page 43% empty, and buried the most interesting
/// control the app has on a page there was little reason to open. Its content
/// moved to `general`. Prefer folding a thin page into a neighbour over adding
/// one; the sidebar is worth having for four full pages, not for eight thin ones.
enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case updates
    case data
    case about

    var id: String { rawValue }

    /// Sidebar label and page title.
    var title: String {
        switch self {
        case .general: "General"
        case .updates: "Updates"
        case .data: "Data"
        case .about: "About"
        }
    }

    /// SF Symbol shown in the sidebar and in the page header. Never emoji.
    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .updates: "arrow.triangle.2.circlepath"
        case .data: "internaldrive"
        case .about: "info.circle"
        }
    }

    /// One line under the page title saying what the page is for.
    var subtitle: String {
        switch self {
        case .general: "How Idle Tapper starts, behaves and appears"
        case .updates: "How new versions are found"
        case .data: "Your tap history, on this Mac"
        case .about: "Version and project links"
        }
    }
}

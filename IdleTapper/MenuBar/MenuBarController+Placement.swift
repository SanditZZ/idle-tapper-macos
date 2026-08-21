//
//  MenuBarController+Placement.swift
//  Idle Tapper — Menu bar presentation
//
//  Working out where macOS actually put the status item, and telling the user
//  when the answer is "somewhere you cannot click".
//
//  Split out of `MenuBarController.swift` when the daily goal pushed that file
//  past the size this project splits at. It is the natural seam: nothing here
//  runs during normal operation — it fires once, a second after install — and
//  it shares no state with the popover or the rendering beyond the status item
//  it is measuring.
//

import AppKit

extension MenuBarController {

    /// Report where macOS actually placed the status item.
    ///
    /// On a Mac with a notch, a full menu bar leaves no room to the right of
    /// the camera housing, and macOS positions overflow status items *behind*
    /// it — on screen, correctly sized, and completely invisible. That looks
    /// identical to a failed install, so it is worth naming explicitly in the
    /// log rather than leaving the user to guess.
    ///
    /// Placement settles a moment after the item is created, hence the delay.
    func checkPlacement() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))

            guard
                let self,
                let item = self.statusItem,
                let frame = item.button?.window?.frame,
                let screen = NSScreen.main
            else { return }

            AppLog.menuBar.debug(
                "[MenuBar] Placed at x=\(frame.origin.x, privacy: .public) width=\(frame.width, privacy: .public)"
            )

            let placement = StatusItemPlacement.classify(
                itemFrame: frame,
                leftArea: screen.auxiliaryTopLeftArea,
                rightArea: screen.auxiliaryTopRightArea,
                screenFrame: screen.frame
            )

            guard placement == .behindNotch else { return }

            AppLog.menuBar.warning(
                """
                [MenuBar] The status item was placed behind the display notch and \
                cannot be seen. The menu bar has no room left.
                """
            )

            // The log alone is not enough: an accessory app with an invisible
            // icon has no other way to tell the user anything at all.
            self.presentHiddenIconNoticeIfNeeded()
        }
    }

    /// Explain the hidden icon once, unless the user has asked not to be told
    /// again. Deliberately not shown on every launch.
    func presentHiddenIconNoticeIfNeeded() {
        guard !settings.suppressHiddenIconNotice else {
            AppLog.menuBar.debug("[MenuBar] Hidden-icon notice suppressed by the user")
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Idle Tapper is hidden behind the notch"
        alert.informativeText = """
            Idle Tapper is running, but your menu bar is full, so macOS placed its \
            icon behind the camera housing where it cannot be clicked.

            To reach it, quit or hide one of your other menu bar items. Choosing \
            “Icon only” below also makes Idle Tapper take up less space.
            """

        alert.addButton(withTitle: "Use Icon Only")
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Don’t Show Again")

        NSApp.activate(ignoringOtherApps: true)

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            settings.menuBarDisplayStyle = .iconOnly
            AppLog.menuBar.info("[MenuBar] Switched to icon-only from the hidden-icon notice")
        case .alertThirdButtonReturn:
            settings.suppressHiddenIconNotice = true
            AppLog.menuBar.info("[MenuBar] User suppressed the hidden-icon notice")
        default:
            break
        }
    }
}

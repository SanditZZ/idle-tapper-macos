//
//  VisualEffectView.swift
//  Idle Tapper — AppKit vibrancy in SwiftUI
//
//  SwiftUI's `.background(.ultraThinMaterial)` is not the same thing as the
//  sidebar material the system uses: it does not pick up the window's active
//  state, so a sidebar rendered with it stays fully saturated when the window
//  loses focus while every other app's dims. `NSVisualEffectView` is the only
//  way to get the real behaviour.
//

import SwiftUI
import AppKit

/// Wraps `NSVisualEffectView` so a SwiftUI view can sit on a system material.
struct VisualEffectView: NSViewRepresentable {

    /// Which material to draw. `.sidebar` for the settings sidebar,
    /// `.underWindowBackground` for a window's content pane.
    var material: NSVisualEffectView.Material = .sidebar

    /// `.followsWindowActiveState` is what makes the material dim with the
    /// window. `.active` would keep it lit even when another app is in front.
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}

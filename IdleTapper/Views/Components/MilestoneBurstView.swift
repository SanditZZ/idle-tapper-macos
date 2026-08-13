//
//  MilestoneBurstView.swift
//  Idle Tapper — Components
//
//  The celebration played when today's count crosses a milestone: a short
//  burst of particles thrown out of the tap button.
//
//  The view is purely presentational, in the strict sense — it holds no
//  particle state at all. `ParticleBurst` answers "where is everything at
//  `elapsed` seconds", and this draws the answer. The only state here is *when
//  the burst started*, which is genuinely a property of this view's lifetime
//  rather than of the effect.
//
//  ## Why `Canvas` rather than `CAEmitterLayer`
//
//  An emitter layer is purpose-built for this and would be less code. It also
//  keeps its particles inside CoreAnimation, where no test can see them — the
//  motion would stop being something the project can make assertions about.
//  Drawing `ParticleBurst`'s output into a `Canvas` keeps the interesting part
//  in the calculation layer, and avoids bridging an `NSView` into a popover
//  that can be dismissed out from under it.
//

import SwiftUI

/// The colours a burst is drawn in, indexed by `BurstParticle.colorIndex`.
///
/// Reuses the palette the app already has rather than introducing colours that
/// exist only for the effect. All three are appearance-adaptive, so the burst
/// stays legible on both the light and the dark popover.
private enum BurstPalette {
    static let colors: [Color] = [AppColors.accent, AppColors.warning, AppColors.success]
}

/// A short particle burst celebrating a milestone.
struct MilestoneBurstView: View {

    /// The milestone being celebrated, or `nil` when nothing is.
    ///
    /// Deliberately the number rather than a `Bool`: it both starts the burst
    /// and seeds it, so crossing 100 and crossing 1,200 do not produce a
    /// pixel-identical animation. Changing it mid-flight restarts the burst
    /// rather than stacking a second one on top of the first.
    let milestone: Int?

    /// When the current burst began, or `nil` if none is playing.
    ///
    /// This is also the off switch. No start date means no `TimelineView` in
    /// the hierarchy, which means no draw loop and no frames — an idle popover
    /// costs nothing, which matters because this sits directly over the control
    /// the user is hammering.
    @State private var startedAt: Date?

    private typealias Burst = DesignTokens.Motion.MilestoneBurst

    var body: some View {
        Group {
            if let startedAt {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        draw(
                            into: &context,
                            size: size,
                            elapsed: timeline.date.timeIntervalSince(startedAt)
                        )
                    }
                }
            }
        }
        .frame(width: Burst.fieldWidth, height: Burst.fieldHeight)
        // The burst sits on top of the tap button. Without this it would eat
        // every tap for the duration of the celebration — the one moment the
        // user is most likely to be mid-streak.
        .allowsHitTesting(false)
        // Decorative. The milestone banner is what announces the number, and it
        // stays on screen whether or not this plays.
        .accessibilityHidden(true)
        // `task(id:)` earns its place three times over: it restarts cleanly when
        // a second milestone arrives, it cancels itself when the popover is
        // dismissed mid-burst, and it needs no timer to tear down.
        .task(id: milestone) { await runBurst() }
    }

    // MARK: - Actions

    private func runBurst() async {
        guard milestone != nil else {
            startedAt = nil
            return
        }

        startedAt = .now
        try? await Task.sleep(for: .seconds(Burst.duration))

        // A replacement milestone cancels this task and immediately starts its
        // own. Without this check, the cancelled task would resume here and
        // clear the burst the replacement has just begun — the new celebration
        // would vanish a frame after starting.
        guard !Task.isCancelled else { return }

        startedAt = nil
    }

    // MARK: - Drawing

    private func draw(into context: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        // Particles come out of the middle of the field, and the field is
        // centred on the tap button by the caller.
        let origin = CGPoint(x: size.width / 2, y: size.height / 2)
        let seed = UInt64(max(milestone ?? 0, 0))

        for particle in ParticleBurst.particles(at: elapsed, seed: seed) {
            let center = CGPoint(
                x: origin.x + particle.offset.x,
                y: origin.y + particle.offset.y
            )
            // Modulo rather than a plain subscript: `ParticleBurst` promises the
            // index is inside its own `paletteSize`, and a palette that fell out
            // of step with that constant should dull the effect, not crash the
            // popover mid-celebration.
            let color = BurstPalette.colors[particle.colorIndex % BurstPalette.colors.count]

            context.opacity = particle.opacity

            if particle.isRound {
                context.fill(circle(at: center, radius: particle.radius), with: .color(color))
            } else {
                context.drawLayer { layer in
                    layer.translateBy(x: center.x, y: center.y)
                    layer.rotate(by: .radians(particle.rotation))
                    layer.fill(chip(radius: particle.radius), with: .color(color))
                }
            }
        }
    }

    private func circle(at center: CGPoint, radius: CGFloat) -> Path {
        Path(
            ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
    }

    /// A small oblong, drawn around its own centre so the layer's rotation
    /// spins it in place rather than swinging it around a corner.
    private func chip(radius: CGFloat) -> Path {
        Path(
            CGRect(
                x: -radius,
                y: -radius * 0.55,
                width: radius * 2,
                height: radius * 1.1
            )
        )
    }
}

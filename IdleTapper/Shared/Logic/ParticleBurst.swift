//
//  ParticleBurst.swift
//  Idle Tapper — Calculations (pure)
//
//  The milestone celebration's motion, expressed as a function of elapsed time.
//
//  ## Why a closed form rather than a step-by-step simulation
//
//  The obvious way to move particles is to advance them every frame:
//  `position += velocity * delta`. That makes the particle array *mutable state
//  owned by the view*, which cannot be unit-tested and is not even
//  deterministic — a dropped frame changes a longer `delta`, and the particles
//  end up somewhere else.
//
//  Everything here is solved analytically for a given `elapsed` instead, so
//  `particles(at: 0.5, seed: 7)` returns the same thing whether it is reached
//  in one frame or in thirty. That is what makes this a calculation rather than
//  an animation: the view stores no particle state at all — it asks where the
//  particles are *now* and draws them.
//
//  Positions are offsets from the burst's origin, not absolute points. The
//  calculation has no idea where on screen the tap button is, and should not.
//

import CoreGraphics
import Foundation

/// One particle's fully resolved state at a single moment of a burst.
struct BurstParticle: Equatable, Sendable {

    /// Offset from the burst's origin, in points. Positive `y` is downward, to
    /// match the coordinate space SwiftUI's `Canvas` draws in.
    let offset: CGPoint

    /// Drawn radius, in points.
    let radius: CGFloat

    /// `0` (invisible) to `1` (fully opaque).
    let opacity: Double

    /// Current rotation, in radians. Ignored for round particles.
    let rotation: Double

    /// Which of the burst's colors to draw this particle in. Always in
    /// `0..<paletteSize`; the view owns what those colors actually are.
    let colorIndex: Int

    /// Round particles are drawn as circles, the rest as small rectangles.
    /// Mixing the two stops the burst reading as a single repeated sprite.
    let isRound: Bool
}

enum ParticleBurst {

    /// How many distinct colors a burst is drawn with. The view supplies them;
    /// this only promises `colorIndex` stays inside the range.
    static let paletteSize = 3

    private typealias Burst = DesignTokens.Motion.MilestoneBurst

    /// Every particle of a burst, `elapsed` seconds after it started.
    ///
    /// Returns an empty array once the burst is over, which is the signal the
    /// view uses to stop drawing — there is no separate "is finished" flag to
    /// keep in step with this.
    ///
    /// - Parameters:
    ///   - elapsed: Seconds since the burst began. Negative values and values
    ///     at or past `duration` yield no particles.
    ///   - seed: Chooses the burst's shape. The same seed always produces the
    ///     same burst, so a test can assert on one and successive milestones
    ///     can look different by passing a different one.
    static func particles(at elapsed: TimeInterval, seed: UInt64) -> [BurstParticle] {
        guard Burst.duration > 0, elapsed >= 0, elapsed < Burst.duration else { return [] }

        let opacity = fade(at: elapsed)
        guard opacity > 0 else { return [] }

        var random = SplitMix64(seed: seed)

        // Drawn from the generator in a fixed order, so a given seed lays out
        // the same burst every time.
        return (0..<Burst.particleCount).map { _ in
            let angle = -Double.pi / 2 + (random.unit() - 0.5) * Burst.spread
            let speed = lerp(Burst.minimumSpeed, Burst.maximumSpeed, random.unit())
            let jitterX = (random.unit() - 0.5) * Double(Burst.originJitter.width)
            let jitterY = (random.unit() - 0.5) * Double(Burst.originJitter.height)
            let radius = lerp(
                Double(Burst.minimumRadius),
                Double(Burst.maximumRadius),
                random.unit()
            )
            let spin = (random.unit() - 0.5) * 2 * Burst.maximumSpin
            let colorIndex = min(Int(random.unit() * Double(paletteSize)), paletteSize - 1)
            let isRound = random.unit() > 0.45

            let moved = displacement(speed: speed, angle: angle, elapsed: elapsed)

            return BurstParticle(
                offset: CGPoint(
                    x: CGFloat(jitterX + moved.x),
                    y: CGFloat(jitterY + moved.y)
                ),
                radius: CGFloat(radius),
                opacity: opacity,
                rotation: spin * elapsed,
                colorIndex: colorIndex,
                isRound: isRound
            )
        }
    }

    /// Opacity shared by every particle in the burst at `elapsed`.
    ///
    /// Held at full for `fadeBegins` of the duration, then falling linearly to
    /// exactly zero at `duration` — the guarantee the draw loop relies on to
    /// know it can stop.
    static func fade(at elapsed: TimeInterval) -> Double {
        guard Burst.duration > 0 else { return 0 }

        let progress = elapsed / Burst.duration
        guard progress > Burst.fadeBegins else { return progress < 0 ? 0 : 1 }
        guard progress < 1 else { return 0 }

        return (1 - progress) / (1 - Burst.fadeBegins)
    }

    // MARK: - Physics

    /// Displacement from the emission point after `elapsed` seconds, for a
    /// particle launched at `speed` along `angle`.
    ///
    /// Closed-form solutions of constant gravity plus linear drag: a particle
    /// under drag `k` travelling at `v` covers `(v / k) * (1 - e^(-k t))`, which
    /// approaches a finite distance rather than continuing forever. Gravity is
    /// applied undamped on top, so particles still fall out of the popover
    /// instead of hanging where the drag left them.
    private static func displacement(
        speed: Double,
        angle: Double,
        elapsed: TimeInterval
    ) -> (x: Double, y: Double) {
        let travel = (1 - exp(-Burst.drag * elapsed)) / Burst.drag
        let fall = 0.5 * Burst.gravity * elapsed * elapsed

        return (
            x: cos(angle) * speed * travel,
            y: sin(angle) * speed * travel + fall
        )
    }

    private static func lerp(_ lower: Double, _ upper: Double, _ unit: Double) -> Double {
        lower + (upper - lower) * unit
    }
}

// MARK: - Seeded Randomness

/// A small, deterministic generator, so a burst is reproducible.
///
/// Deliberately not `SystemRandomNumberGenerator`: a burst that cannot be
/// reproduced cannot be asserted on, and every test below depends on the same
/// seed giving the same particles.
///
/// SplitMix64 specifically, rather than the shorter xorshift, because xorshift
/// has one catastrophic seed — seeded with zero it emits zeros forever, which
/// would produce a completely invisible burst for the one seed a caller is most
/// likely to reach for by accident. SplitMix64 has no bad seed.
private struct SplitMix64 {

    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in `0..<1`.
    ///
    /// Takes the top 53 bits, which is exactly the precision a `Double` has —
    /// using the low bits instead would waste most of them and, for some
    /// generators, use the least random ones.
    mutating func unit() -> Double {
        Double(next() >> 11) * 0x1p-53
    }
}

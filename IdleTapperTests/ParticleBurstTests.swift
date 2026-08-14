//
//  ParticleBurstTests.swift
//  IdleTapperTests
//

import CoreGraphics
import Foundation
import Testing
@testable import IdleTapper

@Suite("Particle burst")
struct ParticleBurstTests {

    private typealias Burst = DesignTokens.Motion.MilestoneBurst

    // MARK: - Determinism

    @Test("The same seed always produces the same burst")
    func sameSeedIsReproducible() {
        // The whole reason the burst is a calculation rather than a simulation.
        // If this fails, nothing else in this suite can be asserted on.
        let first = ParticleBurst.particles(at: 0.3, seed: 42)
        let second = ParticleBurst.particles(at: 0.3, seed: 42)

        #expect(first == second)
    }

    @Test("Different seeds produce different bursts")
    func differentSeedsDiffer() {
        // Guards the seed actually reaching the generator. A burst that ignored
        // it would still be deterministic, and the test above would still pass.
        let first = ParticleBurst.particles(at: 0.3, seed: 1)
        let second = ParticleBurst.particles(at: 0.3, seed: 2)

        #expect(first != second)
    }

    @Test("A seed of zero still produces a visible burst")
    func zeroSeedIsNotDegenerate() {
        // The specific trap `SplitMix64` was chosen to avoid: an xorshift
        // seeded with zero emits zeros forever, which would silently render an
        // invisible burst for the one seed most likely to be reached for by
        // accident.
        let particles = ParticleBurst.particles(at: 0.3, seed: 0)

        #expect(particles.count == Burst.particleCount)
        #expect(particles.contains { $0.offset != .zero })
        #expect(particles.contains { $0.radius > 0 })
    }

    // MARK: - The contract the draw loop depends on

    @Test("Nothing is drawn once the burst is over")
    func burstEndsAtDuration() {
        // The view stops its draw loop on an empty result, so "finished" has to
        // mean exactly this rather than a separate flag that could drift.
        #expect(ParticleBurst.particles(at: Burst.duration, seed: 7).isEmpty)
        #expect(ParticleBurst.particles(at: Burst.duration + 5, seed: 7).isEmpty)
    }

    @Test("Nothing is drawn before the burst starts")
    func negativeElapsedDrawsNothing() {
        // A clock change or a view appearing mid-frame can hand back a negative
        // elapsed; it must not produce a frame of particles frozen at the origin.
        #expect(ParticleBurst.particles(at: -0.5, seed: 7).isEmpty)
    }

    @Test("The burst is fully opaque, then fades to exactly zero")
    func fadeHoldsThenReachesZero() {
        #expect(ParticleBurst.fade(at: 0) == 1)
        // Comfortably inside the hold rather than exactly on `fadeBegins`, so
        // the assertion is about the behaviour and not about whether
        // `duration * fadeBegins / duration` round-trips exactly.
        #expect(ParticleBurst.fade(at: Burst.duration * Burst.fadeBegins * 0.9) == 1)
        #expect(ParticleBurst.fade(at: Burst.duration) == 0)

        // Strictly decreasing across the fade, not stepping to nothing.
        let early = ParticleBurst.fade(at: Burst.duration * 0.7)
        let late = ParticleBurst.fade(at: Burst.duration * 0.9)
        #expect(early > late)
        #expect(late > 0)
    }

    // MARK: - Bounds

    @Test("The particle count is capped at the token")
    func particleCountIsCapped() {
        // The cap is the only thing keeping the burst off an integrated GPU's
        // back at the exact moment the user is tapping fastest.
        #expect(ParticleBurst.particles(at: 0.1, seed: 3).count == Burst.particleCount)
    }

    @Test("Every colour index is inside the palette")
    func colorIndicesStayInRange() {
        // `colorIndex` is derived by truncating a unit value; a unit of exactly
        // 1.0 would index one past the end and trap in the view.
        for seed in UInt64(0)..<40 {
            for particle in ParticleBurst.particles(at: 0.2, seed: seed) {
                #expect(particle.colorIndex >= 0)
                #expect(particle.colorIndex < ParticleBurst.paletteSize)
            }
        }
    }

    @Test("No particle is ever positioned at a non-finite point")
    func geometryStaysFinite() {
        // The drag term divides by a coefficient and feeds `exp`; a NaN here
        // would not throw, it would silently draw nothing or corrupt the frame.
        for step in 0...30 {
            let elapsed = Burst.duration * Double(step) / 30
            for particle in ParticleBurst.particles(at: elapsed, seed: 99) {
                #expect(particle.offset.x.isFinite)
                #expect(particle.offset.y.isFinite)
                #expect(particle.radius.isFinite)
                #expect(particle.rotation.isFinite)
                #expect(particle.opacity.isFinite)
            }
        }
    }

    // MARK: - Motion

    @Test("Particles move outward and are pulled down over time")
    func particlesTravelAndFall() {
        let start = ParticleBurst.particles(at: 0, seed: 11)
        let later = ParticleBurst.particles(at: 0.6, seed: 11)

        // Same seed, so the two arrays describe the same particles at two
        // moments and can be compared pairwise.
        #expect(start.count == later.count)
        #expect(zip(start, later).contains { $0.0.offset != $0.1.offset })

        // Gravity is applied undamped, so the burst as a whole ends up lower
        // than it started even though individual particles were thrown upward.
        let startMeanY = start.map(\.offset.y).reduce(0, +) / CGFloat(start.count)
        let laterMeanY = later.map(\.offset.y).reduce(0, +) / CGFloat(later.count)
        #expect(laterMeanY > startMeanY)
    }

    @Test("The burst radiates rather than firing in one direction")
    func burstRadiatesOutward() {
        // A burst that only ever threw particles one way would still pass every
        // other test here — it would be deterministic, finite and correctly
        // faded, just wrong. Negative y is upward.
        let early = ParticleBurst.particles(at: 0.15, seed: 5)

        #expect(early.contains { $0.offset.x < 0 })
        #expect(early.contains { $0.offset.x > 0 })
        #expect(early.contains { $0.offset.y < 0 })
    }
}

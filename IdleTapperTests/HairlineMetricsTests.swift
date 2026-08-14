//
//  HairlineMetricsTests.swift
//  Idle Tapper
//

import Testing
import CoreGraphics
@testable import IdleTapper

@Suite("Hairline metrics")
struct HairlineMetricsTests {

    @Test("A hairline is one device pixel, whatever the display scale")
    func oneDevicePixel() {
        // The point of the type: the same rule is 1pt on a non-Retina display
        // and half that on Retina, so both draw a single pixel rather than one
        // drawing two.
        #expect(HairlineMetrics.thickness(displayScale: 1) == 1)
        #expect(HairlineMetrics.thickness(displayScale: 2) == 0.5)
        #expect(HairlineMetrics.thickness(displayScale: 3) == 1.0 / 3.0)
    }

    @Test("A nonsensical scale falls back to a visible line rather than dividing by zero")
    func degenerateScale() {
        // Zero would divide by zero and a negative would invert the rule out of
        // existence. A separator that is too heavy is a cosmetic problem; one
        // that is absent or NaN is a broken window.
        #expect(HairlineMetrics.thickness(displayScale: 0) == 1)
        #expect(HairlineMetrics.thickness(displayScale: -2) == 1)
    }
}

//
//  MomentFitZeroScaleTests.swift
//  BusinessMath
//
//  The Johnson shape parameter `delta` is a divisor in the transform and in the closed-form
//  raw moments. Every caller reaches them with a positive `delta`; these pin that the
//  functions say so themselves rather than relying on it.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Moment fit: a zero scale shape is refused")
struct MomentFitZeroScaleTests {

    @Test("Transform_PositiveDelta_Unchanged") func transformPositiveDeltaUnchanged() {
        let w = DistributionMomentFit.transform(family: .lognormal, z: 1.0, gamma: 0.5, delta: 2.0)
        #expect(abs(w - Foundation.exp(0.25)) < 1e-12)
    }

    /// `(z − γ)/0` is an infinity, and `exp` of `−inf` is a clean, plausible zero.
    @Test("Transform_ZeroDelta_IsNaN", arguments: [JohnsonFamily.unbounded, .lognormal, .bounded])
    func transformZeroDeltaIsNaN(family: JohnsonFamily) {
        let w = DistributionMomentFit.transform(family: family, z: -1.0, gamma: 0.5, delta: 0.0)
        #expect(w.isNaN)
    }

    @Test("ExponentialRawMoments_PositiveDelta_Unchanged") func rawMomentsPositiveDeltaUnchanged() {
        let raw = DistributionMomentFit.exponentialRawMoments(family: .lognormal, gamma: 0, delta: 2.0)
        // E[e^{tZ/2}] = e^{t²/8}
        #expect(abs(raw[0] - 1) < 1e-12)
        #expect(abs(raw[1] - Foundation.exp(0.125)) < 1e-12)
        #expect(abs(raw[2] - Foundation.exp(0.5)) < 1e-12)
    }

    /// With `gamma` zero the first division is `-0/0`; with it non-zero the moments are
    /// infinite. Neither is a moment.
    @Test("ExponentialRawMoments_ZeroDelta_IsNaN", arguments: [JohnsonFamily.unbounded, .lognormal])
    func rawMomentsZeroDeltaIsNaN(family: JohnsonFamily) {
        let raw = DistributionMomentFit.exponentialRawMoments(family: family, gamma: 1.0, delta: 0.0)
        #expect(raw.count == 5)
        #expect(raw.allSatisfy { $0.isNaN })
    }
}

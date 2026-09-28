//
//  ContaminatedCurveTests.swift
//  BusinessMathTests
//
//  From the fanned-out triage of `Sources/BusinessMath/Valuation/`.
//
//  `DiscountCurve.init` validates nothing, so a contaminated discount factor — from a bad
//  bootstrap, or from `shifted(by:)` with a NaN shift — reaches the accessors. Measured:
//
//      discountFactor(at: 5) = nan     <- correct
//      zeroRate(at: 5)       = 0.0
//      forwardRate(2 -> 5)   = 0.0
//
//  One curve, two accessors disagreeing about the same point. A zero rate is not a refusal:
//  0% is an entirely plausible rate, and in a market with negative rates it is mid-range, so
//  it sorts, thresholds and prices like a real quote.
//
//  The bootstrap is worse, and is the source of the contaminated factors above.
//
//      guard lastKnownDF > 0 else { continue }
//
//  `solveTerminalDiscountFactor` floors its result at `1e-10`, so this guard can only fail on
//  a NaN. When it does, `continue` skips the tenor **without advancing `prevParYear`** — so the
//  next quote re-reads the same bad anchor and is dropped too, and so on. Measured on five
//  quotes with the 3y contaminated:
//
//      tenors returned = [1.0, 2.0, 3.0]        (clean: [1.0 ... 10.0])
//
//  The 5y and 10y vanish. A ten-year curve silently becomes a three-year one, and a caller
//  asking for the 10y gets an extrapolated answer from a curve that no longer contains it.
//
//  And `Int(entry.tenor)` traps outright for a non-finite *tenor* — the second hard crash this
//  sweep has found, after `spearmansRho`.
//

import Testing
import Foundation
@testable import BusinessMath

/// Elementwise comparison for a numeric sequence; `==` on `[Double]` is refused by the gate,
/// because it hides three different claims.
private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
    lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) }
}

@Suite("Discount curves built from contaminated quotes")
struct ContaminatedCurveTests {

    private let asOf = Date(timeIntervalSince1970: 1_700_000_000)

    private var contaminatedCurve: DiscountCurve {
        DiscountCurve(asOfDate: asOf, tenors: [1.0, 2.0, 5.0], discountFactors: [0.97, 0.94, .nan])
    }

    /// The accessors must agree with each other about the same point.
    @Test("ZeroRate_OnAContaminatedCurve_IsUndefined")
    func zeroRateOnAContaminatedCurveIsUndefined() {
        let curve = contaminatedCurve
        #expect(curve.discountFactor(at: 5.0).isNaN, "the factor was already correct")
        #expect(curve.zeroRate(at: 5.0).isNaN, "got \(curve.zeroRate(at: 5.0))")
    }

    @Test("ForwardRate_OnAContaminatedCurve_IsUndefined")
    func forwardRateOnAContaminatedCurveIsUndefined() {
        let rate = contaminatedCurve.forwardRate(from: 2.0, to: 5.0)
        #expect(rate.isNaN, "got \(rate)")
    }

    /// The bootstrap must not silently shorten the curve it was asked to build.
    @Test("Bootstrap_DoesNotDropTenorsAfterABadQuote")
    func bootstrapDoesNotDropTenorsAfterABadQuote() {
        let curve = DiscountCurve.bootstrap(
            parRates: [(tenor: 1.0, rate: 0.04), (tenor: 2.0, rate: 0.045),
                       (tenor: 3.0, rate: .nan), (tenor: 5.0, rate: 0.05),
                       (tenor: 10.0, rate: 0.055)],
            asOfDate: asOf)
        #expect(curve.tenors.contains(10.0),
                "the 10y quote vanished; tenors were \(curve.tenors)")
        #expect(curve.tenors.contains(5.0), "and so did the 5y")
    }

    /// A non-finite tenor must not take the process down.
    @Test("Bootstrap_DoesNotTrapOnANonFiniteTenor")
    func bootstrapDoesNotTrapOnANonFiniteTenor() {
        let curve = DiscountCurve.bootstrap(
            parRates: [(tenor: 1.0, rate: 0.04), (tenor: Double.nan, rate: 0.045)],
            asOfDate: asOf)
        #expect(curve.tenors.count >= 0, "reaching this line at all is the assertion")
    }

    /// A hazard-rate curve with one unusable rate must not price protection as free.
    @Test("CDSSpread_OnAContaminatedHazardCurve_IsUndefined")
    func cdsSpreadOnAContaminatedHazardCurveIsUndefined() {
        let periods: [Period] = [.year(2024), .year(2025), .year(2026)]
        let curve = HazardRateCurve(
            hazardRates: TimeSeries(periods: periods, values: [0.02, Double.nan, 0.03]))
        let spread = curve.cdsSpread(maturity: 5.0)
        #expect(spread.isNaN, "reported \(spread) — protection priced as free")
        #expect(curve.defaultProbability(time: 5.0).isNaN,
                "the accessor that was already correct")
    }

    // MARK: - Controls

    /// A clean bootstrap is untouched, at the measured shape.
    @Test("CleanBootstrap_Unchanged")
    func cleanBootstrapUnchanged() {
        let curve = DiscountCurve.bootstrap(
            parRates: [(tenor: 1.0, rate: 0.04), (tenor: 2.0, rate: 0.045),
                       (tenor: 3.0, rate: 0.047), (tenor: 5.0, rate: 0.05),
                       (tenor: 10.0, rate: 0.055)],
            asOfDate: asOf)
        #expect(agree(curve.tenors, [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]),
                "got \(curve.tenors)")
        #expect(curve.discountFactors.allSatisfy { $0 > 0 && $0 <= 1 })
    }

    /// A clean curve's accessors are unchanged.
    @Test("CleanCurve_AccessorsUnchanged")
    func cleanCurveAccessorsUnchanged() {
        let curve = DiscountCurve(asOfDate: asOf, tenors: [1.0, 2.0, 5.0],
                                  discountFactors: [0.97, 0.94, 0.85])
        let zero = curve.zeroRate(at: 5.0)
        let expected = -log(0.85) / 5.0
        #expect(abs(zero - expected) < 1e-12, "got \(zero)")
        #expect(curve.forwardRate(from: 2.0, to: 5.0).isFinite)
    }
}

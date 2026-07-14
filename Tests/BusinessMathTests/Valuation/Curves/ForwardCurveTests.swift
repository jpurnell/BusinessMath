//
//  ForwardCurveTests.swift
//  BusinessMathTests
//
//  Tests for ForwardCurve and MultiCurveEnvironment.
//
//  Created by Justin Purnell on 2026-04-15.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Forward Curve Tests")
struct ForwardCurveTests {

    /// Tolerance comparison (auditor forbids `==` on floating-point literals); handles optionals.
    func isClose(_ a: Double?, _ b: Double, tol: Double = 1e-9) -> Bool {
        guard let a else { return false }
        return abs(a - b) < tol
    }

    private let asOf = Date()

    // MARK: - Helpers

    /// A flat discount curve where DF(t) = exp(-r * t) for a constant rate r.
    private func flatCurve(rate: Double) -> DiscountCurve {
        let tenors = [0.5, 1.0, 2.0, 5.0, 10.0]
        let dfs = tenors.map { exp(-rate * $0) }
        return DiscountCurve(asOfDate: asOf, tenors: tenors, discountFactors: dfs)
    }

    /// An upward-sloping curve where zero rate increases with tenor.
    private func upwardSlopingCurve() -> DiscountCurve {
        let tenors = [0.5, 1.0, 2.0, 5.0, 10.0]
        // Zero rates: 2%, 3%, 4%, 5%, 6%
        let rates = [0.02, 0.03, 0.04, 0.05, 0.06]
        let dfs = zip(tenors, rates).map { exp(-$1 * $0) }
        return DiscountCurve(asOfDate: asOf, tenors: tenors, discountFactors: dfs)
    }

    // MARK: - Test 1: Flat curve produces constant forward rates

    @Test func forwardRateFromFlatCurveIsConstant() {
        let rate = 0.05
        let curve = flatCurve(rate: rate)
        let fwd = ForwardCurve(indexName: "FLAT_3M", tenor: 0.25, referenceCurve: curve)

        let r1 = fwd.forwardRate(at: 0.5)
        let r2 = fwd.forwardRate(at: 1.0)
        let r3 = fwd.forwardRate(at: 3.0)

        #expect(abs((r1) - (rate)) <= (1e-10), "Forward rate from flat curve should equal the flat rate")
        #expect(abs((r2) - (rate)) <= (1e-10))
        #expect(abs((r3) - (rate)) <= (1e-10))
    }

    // MARK: - Test 2: Upward-sloping curve produces increasing forward rates

    @Test func forwardRateFromUpwardSlopingCurveIsIncreasing() {
        let curve = upwardSlopingCurve()
        let fwd = ForwardCurve(indexName: "SLOPE_6M", tenor: 0.5, referenceCurve: curve)

        let r0 = fwd.forwardRate(at: 0.5)
        let r1 = fwd.forwardRate(at: 1.0)
        let r2 = fwd.forwardRate(at: 2.0)

        #expect(r1 > r0, "Forward rates should increase for upward-sloping curve")
        #expect(r2 > r1, "Forward rates should increase for upward-sloping curve")
    }

    // MARK: - Test 3: Fixings schedule generates correct count

    @Test func fixingsScheduleGeneratesCorrectCount() {
        let curve = flatCurve(rate: 0.04)
        let fwd = ForwardCurve(indexName: "TEST_3M", tenor: 0.25, referenceCurve: curve)

        let schedule = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
        let fixings = fwd.fixings(at: schedule)

        #expect(fixings.count == schedule.count, "Fixings count should match schedule count")
    }

    // MARK: - Test 4: DF consistency: DF(t+tenor) = DF(t) * exp(-f * tenor)

    @Test func forwardRateConsistencyWithDiscountFactors() {
        let curve = upwardSlopingCurve()
        let tenor = 0.25
        let fwd = ForwardCurve(indexName: "CHECK_3M", tenor: tenor, referenceCurve: curve)

        let startTenors = [0.5, 1.0, 2.0, 5.0]
        for t in startTenors {
            let f = fwd.forwardRate(at: t)
            let dfT = curve.discountFactor(at: t)
            let dfTend = curve.discountFactor(at: t + tenor)

            // DF(t+tenor) should equal DF(t) * exp(-f * tenor)
            let expected = dfT * exp(-f * tenor)
            #expect(abs((dfTend) - (expected)) <= (1e-10),
                    "DF(t+tenor) must equal DF(t) * exp(-f * tenor) at t=\(t)")
        }
    }

    // MARK: - Test 5: MultiCurveEnvironment lookup existing index

    @Test func multiCurveEnvironmentLookupExistingIndex() {
        let curve = flatCurve(rate: 0.03)
        let sofr = ForwardCurve(indexName: "SOFR_3M", tenor: 0.25, referenceCurve: curve)
        let env = MultiCurveEnvironment(discountCurve: curve, forwardCurves: ["SOFR_3M": sofr])

        let result = env.forwardCurve(for: "SOFR_3M")

        #expect(result?.indexName == "SOFR_3M")
        #expect(isClose(result?.tenor, 0.25))
    }

    // MARK: - Test 6: MultiCurveEnvironment lookup missing index returns nil

    @Test func multiCurveEnvironmentLookupMissingIndexReturnsNil() {
        let curve = flatCurve(rate: 0.03)
        let sofr = ForwardCurve(indexName: "SOFR_3M", tenor: 0.25, referenceCurve: curve)
        let env = MultiCurveEnvironment(discountCurve: curve, forwardCurves: ["SOFR_3M": sofr])

        let result = env.forwardCurve(for: "EURIBOR_6M")

        #expect((result) == nil, "Lookup of missing index should return nil")
    }

    // MARK: - Test 7: MultiCurveEnvironment discount factor delegates to OIS curve

    @Test func multiCurveEnvironmentDiscountFactorDelegatesToOIS() {
        let ois = flatCurve(rate: 0.04)
        let env = MultiCurveEnvironment(discountCurve: ois, forwardCurves: [:])

        let tenor = 2.0
        let envDF = env.discountFactor(at: tenor)
        let oisDF = ois.discountFactor(at: tenor)

        #expect(abs((envDF) - (oisDF)) <= (1e-15),
                "MultiCurveEnvironment discount factor should match OIS curve exactly")
    }

    // MARK: - Test 8: OIS discount != projection rate (multi-curve reality)

    @Test func oISDiscountDiffersFromProjectionRate() {
        // OIS curve at 3%
        let ois = flatCurve(rate: 0.03)
        // Projection curve at 3.5% (term credit/liquidity spread)
        let projectionCurve = flatCurve(rate: 0.035)
        let sofr3M = ForwardCurve(indexName: "SOFR_3M", tenor: 0.25, referenceCurve: projectionCurve)
        let env = MultiCurveEnvironment(discountCurve: ois, forwardCurves: ["SOFR_3M": sofr3M])

        let oisZero = ois.zeroRate(at: 1.0)
        let projRate = env.forwardCurve(for: "SOFR_3M")?.forwardRate(at: 1.0) ?? 0.0

        #expect(abs((oisZero) - (projRate)) > (1e-6),
                "OIS discount rate should differ from projection forward rate")
        #expect(projRate > oisZero,
                "Projection rate should exceed OIS rate due to term spread")
    }

    // MARK: - Test 9: Single-point curve works

    @Test func singlePointCurveWorks() {
        let curve = DiscountCurve(
            asOfDate: asOf,
            tenors: [1.0],
            discountFactors: [0.95]
        )
        let fwd = ForwardCurve(indexName: "SINGLE", tenor: 0.5, referenceCurve: curve)

        let rate = fwd.forwardRate(at: 0.5)

        #expect(!(rate.isNaN), "Forward rate from single-point curve should not be NaN")
        #expect(!(rate.isInfinite), "Forward rate from single-point curve should not be infinite")
        #expect(rate > 0.0, "Forward rate should be positive for DF < 1")
    }

    // MARK: - Test 10: Zero tenor handled gracefully

    @Test func zeroTenorHandledGracefully() {
        let curve = flatCurve(rate: 0.05)
        let fwd = ForwardCurve(indexName: "ZERO_TENOR", tenor: 0.0, referenceCurve: curve)

        let rate = fwd.forwardRate(at: 1.0)

        #expect(!(rate.isNaN), "Zero tenor should not produce NaN")
        #expect(!(rate.isInfinite), "Zero tenor should not produce infinity")
        // With zero tenor, we fall back to the zero rate at that point
        let expectedZeroRate = curve.zeroRate(at: 1.0)
        #expect(abs((rate) - (expectedZeroRate)) <= (1e-10),
                "Zero tenor should return the zero rate as a fallback")
    }
}

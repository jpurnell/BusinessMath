//
//  DiscountCurveTests.swift
//  BusinessMath
//
//  Tests for DiscountCurve: construction, interpolation, forward rates,
//  bootstrapping, shifting, and edge cases.
//
//  Created by Justin Purnell on 2026-04-15.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("DiscountCurve")
struct DiscountCurveTests {

    // MARK: - Test Data

    /// A simple curve with known discount factors (approx 5% flat zero rate).
    private static let referenceDate = Date()
    private static let flatRate = 0.05
    private static let tenorPoints: [Double] = [1.0, 2.0, 3.0, 5.0, 10.0]
    private static let flatDFs: [Double] = tenorPoints.map { exp(-flatRate * $0) }

    private static var flatCurve: DiscountCurve {
        DiscountCurve(
            asOfDate: referenceDate,
            tenors: tenorPoints,
            discountFactors: flatDFs
        )
    }

    // MARK: - Construction Tests

    @Test("DF at t=0 is 1.0")
    func dfAtZeroIsOne() {
        let curve = Self.flatCurve
        #expect(abs(curve.discountFactor(at: 0.0) - 1.0) < 1e-12)
    }

    @Test("DF at known tenor matches input")
    func dfAtKnownTenorMatchesInput() {
        let curve = Self.flatCurve
        for (tenor, expectedDF) in zip(Self.tenorPoints, Self.flatDFs) {
            #expect(abs(curve.discountFactor(at: tenor) - expectedDF) < 1e-10,
                    "DF at tenor \(tenor) should match input")
        }
    }

    @Test("DF is monotonically decreasing for positive rates")
    func dfMonotonicallyDecreasing() {
        let curve = Self.flatCurve
        let sampleTenors = stride(from: 0.0, through: 12.0, by: 0.5).map { $0 }
        for i in 1..<sampleTenors.count {
            let dfPrev = curve.discountFactor(at: sampleTenors[i - 1])
            let dfCurr = curve.discountFactor(at: sampleTenors[i])
            #expect(dfCurr <= dfPrev + 1e-12,
                    "DF should be non-increasing; DF(\(sampleTenors[i])) > DF(\(sampleTenors[i-1]))")
        }
    }

    @Test("Zero rate: r(1) = -ln(DF(1))")
    func zeroRateAtOneYear() {
        let curve = Self.flatCurve
        let df1 = curve.discountFactor(at: 1.0)
        let expectedRate = -log(df1)
        let computedRate = curve.zeroRate(at: 1.0)
        #expect(abs(computedRate - expectedRate) < 1e-12)
    }

    // MARK: - Interpolation Tests

    @Test("Log-linear interpolation between two knots")
    func logLinearInterpolation() {
        let curve = Self.flatCurve
        // At 1.5Y, log-linear between 1Y and 2Y
        let df1 = curve.discountFactor(at: 1.0)
        let df2 = curve.discountFactor(at: 2.0)
        let expectedLnDF = (log(df1) + log(df2)) / 2.0
        let expectedDF = exp(expectedLnDF)
        let actualDF = curve.discountFactor(at: 1.5)
        #expect(abs(actualDF - expectedDF) < 1e-10,
                "Mid-point log-linear interpolation failed")
    }

    @Test("Flat extrapolation beyond last tenor")
    func flatExtrapolationBeyondLastTenor() {
        let curve = Self.flatCurve
        // Zero rate at 10Y
        let r10 = curve.zeroRate(at: 10.0)
        // DF at 15Y should use the same zero rate
        let df15 = curve.discountFactor(at: 15.0)
        let expected15 = exp(-r10 * 15.0)
        #expect(abs(df15 - expected15) < 1e-10,
                "Flat extrapolation should extend the last zero rate")
    }

    @Test("Single-knot curve works")
    func singleKnotCurve() {
        let curve = DiscountCurve(
            asOfDate: Self.referenceDate,
            tenors: [2.0],
            discountFactors: [exp(-0.05 * 2.0)]
        )
        // Should extend the single zero rate everywhere
        let df1 = curve.discountFactor(at: 1.0)
        let expected1 = exp(-0.05 * 1.0)
        #expect(abs(df1 - expected1) < 1e-10)

        let df5 = curve.discountFactor(at: 5.0)
        let expected5 = exp(-0.05 * 5.0)
        #expect(abs(df5 - expected5) < 1e-10)
    }

    // MARK: - Forward Rate Tests

    @Test("Forward rate consistency: DF(t2) = DF(t1) * exp(-f*(t2-t1))")
    func forwardRateConsistency() {
        let curve = Self.flatCurve
        let t1 = 2.0
        let t2 = 5.0
        let fwd = curve.forwardRate(from: t1, to: t2)
        let df1 = curve.discountFactor(at: t1)
        let df2 = curve.discountFactor(at: t2)
        let df2Implied = df1 * exp(-fwd * (t2 - t1))
        #expect(abs(df2 - df2Implied) < 1e-10,
                "Forward rate should be consistent with discount factors")
    }

    @Test("Forward rate t1 == t2 returns zero rate")
    func forwardRateEqualTenors() {
        let curve = Self.flatCurve
        let fwd = curve.forwardRate(from: 3.0, to: 3.0)
        let zr = curve.zeroRate(at: 3.0)
        #expect(abs(fwd - zr) < 1e-10,
                "Forward rate with equal tenors should return the zero rate")
    }

    // MARK: - Bootstrap Tests

    @Test("Bootstrap from par rates: NPV of par swap = 0 within 0.1bp")
    func bootstrapRepricesParSwap() {
        let parRates: [(tenor: Double, rate: Double)] = [
            (1.0, 0.04),
            (2.0, 0.045),
            (3.0, 0.048),
            (5.0, 0.05)
        ]

        let curve = DiscountCurve.bootstrap(parRates: parRates, asOfDate: Self.referenceDate)

        // For each par swap, NPV of fixed leg = NPV of floating leg
        // Par swap condition: c * sum(DF(Ti)) + DF(Tn) = 1
        for entry in parRates {
            let c = entry.rate
            let n = Int(entry.tenor)
            var sumDF = 0.0
            for i in 1...n {
                sumDF += curve.discountFactor(at: Double(i))
            }
            let npv = c * sumDF + curve.discountFactor(at: entry.tenor) - 1.0
            #expect(abs(npv) < 1e-5, // 0.1bp = 0.00001
                    "Par swap at tenor \(entry.tenor) should reprice to 0; got NPV=\(npv)")
        }
    }

    @Test("Bootstrap from flat curve: all DFs consistent")
    func bootstrapFlatCurve() {
        let flatRate = 0.05
        let parRates: [(tenor: Double, rate: Double)] = [
            (1.0, flatRate),
            (2.0, flatRate),
            (3.0, flatRate),
            (5.0, flatRate)
        ]

        let curve = DiscountCurve.bootstrap(parRates: parRates, asOfDate: Self.referenceDate)

        // For a flat par curve, zero rates won't be exactly flat, but all DFs must reprice
        for entry in parRates {
            let c = entry.rate
            let n = Int(entry.tenor)
            var sumDF = 0.0
            for i in 1...n {
                sumDF += curve.discountFactor(at: Double(i))
            }
            let npv = c * sumDF + curve.discountFactor(at: entry.tenor) - 1.0
            #expect(abs(npv) < 1e-10,
                    "Flat par rate should reprice exactly; got NPV=\(npv)")
        }
    }

    @Test("Bootstrap from upward-sloping curve")
    func bootstrapUpwardSloping() {
        let parRates: [(tenor: Double, rate: Double)] = [
            (1.0, 0.02),
            (2.0, 0.03),
            (3.0, 0.035),
            (5.0, 0.04)
        ]

        let curve = DiscountCurve.bootstrap(parRates: parRates, asOfDate: Self.referenceDate)

        // All DFs should be positive and decreasing
        var prevDF = 1.0
        for i in 0..<curve.tenors.count {
            let df = curve.discountFactors[i]
            #expect(df > 0, "DF must be positive at tenor \(curve.tenors[i])")
            #expect(df < prevDF, "DF must be decreasing at tenor \(curve.tenors[i])")
            prevDF = df
        }

        // Repricing check
        for entry in parRates {
            let c = entry.rate
            let n = Int(entry.tenor)
            var sumDF = 0.0
            for i in 1...n {
                sumDF += curve.discountFactor(at: Double(i))
            }
            let npv = c * sumDF + curve.discountFactor(at: entry.tenor) - 1.0
            #expect(abs(npv) < 1e-5,
                    "Upward-sloping par swap should reprice at tenor \(entry.tenor); NPV=\(npv)")
        }
    }

    // MARK: - Shifted Curve Tests

    @Test("Shifted curve has higher rates everywhere")
    func shiftedCurveHigherRates() {
        let curve = Self.flatCurve
        let shift = 0.01  // +100bp
        let shifted = curve.shifted(by: shift)

        for tenor in [0.5, 1.0, 2.0, 5.0, 10.0] {
            let rOrig = curve.zeroRate(at: tenor)
            let rShifted = shifted.zeroRate(at: tenor)
            #expect(rShifted > rOrig,
                    "Shifted rate at \(tenor) should be higher")
            #expect(abs(rShifted - rOrig - shift) < 1e-10,
                    "Shift should be exactly \(shift); got \(rShifted - rOrig)")
        }
    }

    // MARK: - Edge Case Tests

    @Test("Division safety: zeroRate at tenor=0")
    func zeroRateAtTenorZero() {
        let curve = Self.flatCurve
        // Should not crash, should return the short rate
        let rate = curve.zeroRate(at: 0.0)
        #expect(rate.isFinite, "Zero rate at t=0 should be finite")
        #expect(abs(rate - Self.flatRate) < 1e-10,
                "Zero rate at t=0 should approximate the short rate")
    }

    @Test("Empty tenors curve returns DF=1 everywhere")
    func emptyCurve() {
        let curve = DiscountCurve(
            asOfDate: Self.referenceDate,
            tenors: [],
            discountFactors: []
        )
        #expect(abs(curve.discountFactor(at: 0.0) - 1.0) < 1e-12)
        #expect(abs(curve.discountFactor(at: 5.0) - 1.0) < 1e-12)
        #expect(curve.zeroRate(at: 5.0) == 0.0)
        #expect(curve.forwardRate(from: 1.0, to: 2.0) == 0.0)
    }

    // MARK: - Additional Tests

    @Test("Linear interpolation mode produces valid results")
    func linearInterpolation() {
        let curve = DiscountCurve(
            asOfDate: Self.referenceDate,
            tenors: Self.tenorPoints,
            discountFactors: Self.flatDFs,
            interpolation: .linear
        )
        // For a flat-rate curve, linear on zero rates should give the same result
        let df1_5 = curve.discountFactor(at: 1.5)
        let expected = exp(-Self.flatRate * 1.5)
        #expect(abs(df1_5 - expected) < 1e-8,
                "Linear interpolation on flat curve should be exact")
    }

    @Test("Bootstrap with empty par rates returns empty curve")
    func bootstrapEmpty() {
        let curve = DiscountCurve.bootstrap(
            parRates: [],
            asOfDate: Self.referenceDate
        )
        #expect(curve.tenors.isEmpty)
        #expect(curve.discountFactors.isEmpty)
    }
}

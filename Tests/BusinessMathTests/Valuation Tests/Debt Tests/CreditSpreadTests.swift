//
//  CreditSpreadTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Credit Spread Model Tests")
struct CreditSpreadModelTests {

    @Test("Default probability from Z-Score - investment grade")
    func defaultProbabilityInvestmentGrade() {
        let model = CreditSpreadModel<Double>()

        // Z-Score > 2.99: Safe zone → Low default probability
        let zScore = 3.5
        let pd = model.defaultProbability(zScore: zScore)

        // Investment grade: PD should be very low (< 1%)
        #expect(pd < 0.01)
        #expect(pd > 0.0)
    }

    @Test("Default probability from Z-Score - grey zone")
    func defaultProbabilityGreyZone() {
        let model = CreditSpreadModel<Double>()

        // Z-Score between 1.8 and 2.99: Grey zone → Moderate default risk
        let zScore = 2.0
        let pd = model.defaultProbability(zScore: zScore)

        // Grey zone: PD should be moderate (1-10%)
        #expect(pd >= 0.01)
        #expect(pd <= 0.15)
    }

    @Test("Default probability from Z-Score - distress zone")
    func defaultProbabilityDistressZone() {
        let model = CreditSpreadModel<Double>()

        // Z-Score < 1.8: Distress zone → High default probability
        let zScore = 1.0
        let pd = model.defaultProbability(zScore: zScore)

        // Distress zone: PD should be elevated (> 10%)
        #expect(pd > 0.10)
        #expect(pd < 1.0)
    }

    @Test("Default probability increases as Z-Score decreases")
    func defaultProbabilityMonotonic() {
        let model = CreditSpreadModel<Double>()

        let pdHigh = model.defaultProbability(zScore: 3.0)
        let pdMid = model.defaultProbability(zScore: 2.0)
        let pdLow = model.defaultProbability(zScore: 1.0)

        // Default probability should increase as Z-Score decreases
        #expect(pdLow > pdMid)
        #expect(pdMid > pdHigh)
    }

    @Test("Credit spread from default probability")
    func creditSpreadCalculation() {
        let model = CreditSpreadModel<Double>()

        // 2% annual default probability, 40% recovery rate, 5-year maturity
        let spread = model.creditSpread(
            defaultProbability: 0.02,
            recoveryRate: 0.40,
            maturity: 5.0
        )

        // Spread should be positive and reasonable (50-300 bps)
        #expect(spread > 0.005)  // > 50 bps
        #expect(spread < 0.03)   // < 300 bps
    }

    @Test("Credit spread increases with default probability")
    func creditSpreadVsDefaultProbability() {
        let model = CreditSpreadModel<Double>()

        let spreadLowPD = model.creditSpread(
            defaultProbability: 0.01,
            recoveryRate: 0.40,
            maturity: 5.0
        )

        let spreadHighPD = model.creditSpread(
            defaultProbability: 0.05,
            recoveryRate: 0.40,
            maturity: 5.0
        )

        // Higher default probability → Higher spread
        #expect(spreadHighPD > spreadLowPD)
    }

    @Test("Credit spread decreases with recovery rate")
    func creditSpreadVsRecoveryRate() {
        let model = CreditSpreadModel<Double>()

        let spreadLowRecovery = model.creditSpread(
            defaultProbability: 0.02,
            recoveryRate: 0.20,
            maturity: 5.0
        )

        let spreadHighRecovery = model.creditSpread(
            defaultProbability: 0.02,
            recoveryRate: 0.60,
            maturity: 5.0
        )

        // Higher recovery rate → Lower spread
        #expect(spreadHighRecovery < spreadLowRecovery)
    }

    @Test("Corporate bond yield calculation")
    func corporateBondYield() {
        let model = CreditSpreadModel<Double>()

        let riskFreeRate = 0.03  // 3%
        let creditSpread = 0.015  // 150 bps
        let corporateYield = model.corporateBondYield(
            riskFreeRate: riskFreeRate,
            creditSpread: creditSpread
        )

        // Corporate yield = risk-free + spread
        let expected = riskFreeRate + creditSpread
        #expect(abs(corporateYield - expected) < 0.0001)
    }

    @Test("Round-trip: Z-Score → PD → Spread")
    func roundTripZScoreToSpread() {
        let model = CreditSpreadModel<Double>()

        // Start with a Z-Score
        let zScore = 2.5
        let pd = model.defaultProbability(zScore: zScore)
        let spread = model.creditSpread(
            defaultProbability: pd,
            recoveryRate: 0.40,
            maturity: 5.0
        )

        // Spread should be reasonable for this risk level
        #expect(spread > 0.0)
        #expect(spread < 0.05)  // Less than 500 bps for non-distressed
    }

    @Test("Credit spread with zero recovery rate")
    func creditSpreadZeroRecovery() {
        let model = CreditSpreadModel<Double>()

        let spreadZeroRecovery = model.creditSpread(
            defaultProbability: 0.02,
            recoveryRate: 0.0,
            maturity: 5.0
        )

        let spreadWithRecovery = model.creditSpread(
            defaultProbability: 0.02,
            recoveryRate: 0.40,
            maturity: 5.0
        )

        // Zero recovery → Maximum spread for given PD
        #expect(spreadZeroRecovery > spreadWithRecovery)
    }
}

@Suite("Credit Curve Tests")
struct CreditCurveTests {

    @Test("Credit curve construction")
    func creditCurveConstruction() {
        let periods = [
            Period.year(1),
            Period.year(3),
            Period.year(5),
            Period.year(10)
        ]

        let spreads = TimeSeries(
            periods: periods,
            values: [0.005, 0.010, 0.015, 0.020]  // 50, 100, 150, 200 bps
        )

        let curve = CreditCurve(
            spreads: spreads,
            recoveryRate: 0.40
        )

        #expect(curve.recoveryRate == 0.40)
        #expect(curve.spreads.count == 4)
    }

    @Test("Spread interpolation - exact maturity")
    func spreadInterpolationExact() {
        let periods = [
            Period.year(1),
            Period.year(3),
            Period.year(5)
        ]

        let spreads = TimeSeries(
            periods: periods,
            values: [0.005, 0.010, 0.015]
        )

        let curve = CreditCurve(
            spreads: spreads,
            recoveryRate: 0.40
        )

        // Should return exact spread for maturity = 3
        let spread = curve.spread(maturity: 3.0)
        #expect(abs(spread - 0.010) < 0.0001)
    }

    @Test("Spread interpolation - between maturities")
    func spreadInterpolationBetween() {
        let periods = [
            Period.year(1),
            Period.year(5)
        ]

        let spreads = TimeSeries(
            periods: periods,
            values: [0.005, 0.015]  // 50 bps at 1y, 150 bps at 5y
        )

        let curve = CreditCurve(
            spreads: spreads,
            recoveryRate: 0.40
        )

        // At maturity = 3 (midpoint), spread should be interpolated
        let spread = curve.spread(maturity: 3.0)

        // Linear interpolation: 50 + (150-50) * (3-1)/(5-1) = 100 bps
        #expect(spread > 0.008)
        #expect(spread < 0.012)
    }

    @Test("Spread curve is upward sloping")
    func spreadCurveUpwardSloping() {
        let periods = [
            Period.year(1),
            Period.year(3),
            Period.year(5),
            Period.year(10)
        ]

        let spreads = TimeSeries(
            periods: periods,
            values: [0.005, 0.010, 0.015, 0.020]
        )

        let curve = CreditCurve(
            spreads: spreads,
            recoveryRate: 0.40
        )

        let spread1y = curve.spread(maturity: 1.0)
        let spread5y = curve.spread(maturity: 5.0)
        let spread10y = curve.spread(maturity: 10.0)

        // Longer maturities → Higher spreads (typically)
        #expect(spread5y >= spread1y)
        #expect(spread10y >= spread5y)
    }

    @Test("Cumulative default probability calculation")
    func cumulativeDefaultProbability() {
        let periods = [
            Period.year(1),
            Period.year(5)
        ]

        let spreads = TimeSeries(
            periods: periods,
            values: [0.010, 0.020]  // 100 bps, 200 bps
        )

        let curve = CreditCurve(
            spreads: spreads,
            recoveryRate: 0.40
        )

        let cdp5y = curve.cumulativeDefaultProbability(maturity: 5.0)

        // CDF should be between 0 and 1
        #expect(cdp5y > 0.0)
        #expect(cdp5y < 1.0)
    }

    @Test("Cumulative default probability increases with maturity")
    func cumulativeDefaultProbabilityMonotonic() {
        let periods = [
            Period.year(1),
            Period.year(5),
            Period.year(10)
        ]

        let spreads = TimeSeries(
            periods: periods,
            values: [0.010, 0.015, 0.020]
        )

        let curve = CreditCurve(
            spreads: spreads,
            recoveryRate: 0.40
        )

        let cdp1y = curve.cumulativeDefaultProbability(maturity: 1.0)
        let cdp5y = curve.cumulativeDefaultProbability(maturity: 5.0)
        let cdp10y = curve.cumulativeDefaultProbability(maturity: 10.0)

        // CDF should increase with maturity
        #expect(cdp5y > cdp1y)
        #expect(cdp10y > cdp5y)
    }

    @Test("Hazard rate calculation")
    func hazardRateCalculation() {
        let periods = [
            Period.year(1),
            Period.year(5)
        ]

        let spreads = TimeSeries(
            periods: periods,
            values: [0.010, 0.020]
        )

        let curve = CreditCurve(
            spreads: spreads,
            recoveryRate: 0.40
        )

        let hazard = curve.hazardRate(maturity: 3.0)

        // Hazard rate should be positive
        #expect(hazard > 0.0)
        #expect(hazard < 1.0)
    }

    @Test("Hazard rate from spread relationship")
    func hazardRateSpreadRelationship() {
        let periods = [
            Period.year(1),
            Period.year(5)
        ]

        let spreadsLow = TimeSeries(
            periods: periods,
            values: [0.005, 0.010]  // Low spreads
        )

        let spreadsHigh = TimeSeries(
            periods: periods,
            values: [0.020, 0.030]  // High spreads
        )

        let curveLow = CreditCurve(spreads: spreadsLow, recoveryRate: 0.40)
        let curveHigh = CreditCurve(spreads: spreadsHigh, recoveryRate: 0.40)

        let hazardLow = curveLow.hazardRate(maturity: 3.0)
        let hazardHigh = curveHigh.hazardRate(maturity: 3.0)

        // Higher spreads → Higher hazard rate
        #expect(hazardHigh > hazardLow)
    }

    @Test("Survival probability from credit curve")
    func survivalProbability() {
        let periods = [
            Period.year(1),
            Period.year(5)
        ]

        let spreads = TimeSeries(
            periods: periods,
            values: [0.010, 0.020]
        )

        let curve = CreditCurve(
            spreads: spreads,
            recoveryRate: 0.40
        )

        let cdp = curve.cumulativeDefaultProbability(maturity: 5.0)
        let survivalProb = 1.0 - cdp

        // Survival probability = 1 - CDF
        #expect(survivalProb > 0.0)
        #expect(survivalProb < 1.0)
    }

    @Test("Credit curve with generic Float type")
    func creditCurveFloat() {
        let periods = [
            Period.year(1),
            Period.year(5)
        ]

        let spreads = TimeSeries(
            periods: periods,
            values: [Float(0.010), Float(0.020)]
        )

        let curve = CreditCurve(
            spreads: spreads,
            recoveryRate: Float(0.40)
        )

        let spread = curve.spread(maturity: 3.0)
        #expect(spread > Float(0.0))
    }
}

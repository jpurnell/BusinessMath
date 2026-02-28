//
//  CDSPricingTests.swift
//  BusinessMath
//
//  Credit Default Swap pricing tests using ISDA standard model
//

import Testing
import TestSupport  // Cross-platform math functions
import Foundation
@testable import BusinessMath

@Suite("CDS Pricing Tests")
struct CDSPricingTests {

    let tolerance = 0.01

    // MARK: - Basic CDS Structure Tests

    @Test("Initialize CDS contract with standard terms")
    func initializeCDS() {
        // Given: Standard 5-year CDS contract
        let cds = CDS(
            notional: 10_000_000.0,
            spread: 0.0150,  // 150 bps
            maturity: 5.0,
            recoveryRate: 0.40,
            paymentFrequency: .quarterly
        )

        // Then: Properties should be set correctly
        #expect(cds.notional == 10_000_000.0)
        #expect(cds.spread == 0.0150)
        #expect(cds.maturity == 5.0)
        #expect(cds.recoveryRate == 0.40)
        #expect(cds.paymentFrequency == .quarterly)
    }

    // MARK: - Premium Leg Valuation Tests

    @Test("Calculate premium leg PV with constant survival")
    func premiumLegConstantSurv() {
        // Given: 5Y CDS, 150bps spread, flat 5% discount rate
        let cds = CDS(
            notional: 10_000_000.0,
            spread: 0.0150,
            maturity: 5.0,
            recoveryRate: 0.40,
            paymentFrequency: .quarterly
        )

        // Flat discount curve at 5%
        // Create 20 unique quarterly periods (5 years)
        let periods = (0..<20).map { i in
            let year = 2024 + i / 4
            let quarter = (i % 4) + 1
            return Period.quarter(year: year, quarter: quarter)
        }
        let discountFactors = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.05 * t)
        }
        let discountCurve = TimeSeries(periods: periods, values: discountFactors)

        // Constant 2% hazard rate → survival = exp(-0.02*t)
        let survivalProbs = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.02 * t)
        }
        let survivalCurve = TimeSeries(periods: periods, values: survivalProbs)

        // When: Calculate premium leg PV
        let premiumPV = cds.premiumLegPV(
            discountCurve: discountCurve,
            survivalProbabilities: survivalCurve
        )

        // Then: Should be positive and reasonable
        #expect(premiumPV > 0)
        #expect(premiumPV < cds.notional * cds.spread * cds.maturity)
    }

    @Test("Premium leg decreases with higher default probability")
    func premiumLegHigherDefault() {
        let cds = CDS(
            notional: 10_000_000.0,
            spread: 0.0150,
            maturity: 5.0,
            recoveryRate: 0.40,
            paymentFrequency: .quarterly
        )

        // Create 20 unique quarterly periods (5 years)
        let periods = (0..<20).map { i in
            let year = 2024 + i / 4
            let quarter = (i % 4) + 1
            return Period.quarter(year: year, quarter: quarter)
        }
        let discountFactors = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.05 * t)
        }
        let discountCurve = TimeSeries(periods: periods, values: discountFactors)

        // Low hazard: 1%
        let lowHazardSurvival = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.01 * t)
        }
        let lowHazardCurve = TimeSeries(periods: periods, values: lowHazardSurvival)

        // High hazard: 5%
        let highHazardSurvival = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.05 * t)
        }
        let highHazardCurve = TimeSeries(periods: periods, values: highHazardSurvival)

        let premiumLow = cds.premiumLegPV(
            discountCurve: discountCurve,
            survivalProbabilities: lowHazardCurve
        )

        let premiumHigh = cds.premiumLegPV(
            discountCurve: discountCurve,
            survivalProbabilities: highHazardCurve
        )

        // Premium leg should be lower with higher default probability
        #expect(premiumHigh < premiumLow)
    }

    // MARK: - Protection Leg Valuation Tests

    @Test("Calculate protection leg PV")
    func protectionLegPV() {
        let cds = CDS(
            notional: 10_000_000.0,
            spread: 0.0150,
            maturity: 5.0,
            recoveryRate: 0.40,
            paymentFrequency: .quarterly
        )

        // Create 20 unique quarterly periods (5 years)
        let periods = (0..<20).map { i in
            let year = 2024 + i / 4
            let quarter = (i % 4) + 1
            return Period.quarter(year: year, quarter: quarter)
        }
        let discountFactors = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.05 * t)
        }
        let discountCurve = TimeSeries(periods: periods, values: discountFactors)

        let survivalProbs = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.02 * t)
        }
        let survivalCurve = TimeSeries(periods: periods, values: survivalProbs)

        let protectionPV = cds.protectionLegPV(
            discountCurve: discountCurve,
            survivalProbabilities: survivalCurve
        )

        // Protection leg should be positive
        #expect(protectionPV > 0)
        // Should be less than notional * (1 - recovery)
        #expect(protectionPV < cds.notional * (1 - cds.recoveryRate))
    }

    @Test("Protection leg increases with higher default probability")
    func protectionLegHigherDefault() {
        let cds = CDS(
            notional: 10_000_000.0,
            spread: 0.0150,
            maturity: 5.0,
            recoveryRate: 0.40,
            paymentFrequency: .quarterly
        )

        // Create 20 unique quarterly periods (5 years)
        let periods = (0..<20).map { i in
            let year = 2024 + i / 4
            let quarter = (i % 4) + 1
            return Period.quarter(year: year, quarter: quarter)
        }
        let discountFactors = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.05 * t)
        }
        let discountCurve = TimeSeries(periods: periods, values: discountFactors)

        // Low hazard: 1%
        let lowHazardSurvival = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.01 * t)
        }
        let lowHazardCurve = TimeSeries(periods: periods, values: lowHazardSurvival)

        // High hazard: 5%
        let highHazardSurvival = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.05 * t)
        }
        let highHazardCurve = TimeSeries(periods: periods, values: highHazardSurvival)

        let protectionLow = cds.protectionLegPV(
            discountCurve: discountCurve,
            survivalProbabilities: lowHazardCurve
        )

        let protectionHigh = cds.protectionLegPV(
            discountCurve: discountCurve,
            survivalProbabilities: highHazardCurve
        )

        // Protection leg should be higher with higher default probability
        #expect(protectionHigh > protectionLow)
    }

    @Test("Protection leg sensitive to recovery rate")
    func protectionLegRecoveryRate() {
        // Create 20 unique quarterly periods (5 years)
        let periods = (0..<20).map { i in
            let year = 2024 + i / 4
            let quarter = (i % 4) + 1
            return Period.quarter(year: year, quarter: quarter)
        }
        let discountFactors = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.05 * t)
        }
        let discountCurve = TimeSeries(periods: periods, values: discountFactors)

        let survivalProbs = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.02 * t)
        }
        let survivalCurve = TimeSeries(periods: periods, values: survivalProbs)

        // High recovery (70%)
        let cdsHighRecovery = CDS(
            notional: 10_000_000.0,
            spread: 0.0150,
            maturity: 5.0,
            recoveryRate: 0.70,
            paymentFrequency: .quarterly
        )

        // Low recovery (30%)
        let cdsLowRecovery = CDS(
            notional: 10_000_000.0,
            spread: 0.0150,
            maturity: 5.0,
            recoveryRate: 0.30,
            paymentFrequency: .quarterly
        )

        let protectionHigh = cdsHighRecovery.protectionLegPV(
            discountCurve: discountCurve,
            survivalProbabilities: survivalCurve
        )

        let protectionLow = cdsLowRecovery.protectionLegPV(
            discountCurve: discountCurve,
            survivalProbabilities: survivalCurve
        )

        // Lower recovery → higher protection leg value
        #expect(protectionLow > protectionHigh)
    }

    // MARK: - Fair Spread Tests

    @Test("Calculate fair spread where premium = protection")
    func fairSpreadCalculation() {
        let cds = CDS(
            notional: 10_000_000.0,
            spread: 0.0,  // Will be calculated
            maturity: 5.0,
            recoveryRate: 0.40,
            paymentFrequency: .quarterly
        )

        // Create 20 unique quarterly periods (5 years)
        let periods = (0..<20).map { i in
            let year = 2024 + i / 4
            let quarter = (i % 4) + 1
            return Period.quarter(year: year, quarter: quarter)
        }
        let discountFactors = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.05 * t)
        }
        let discountCurve = TimeSeries(periods: periods, values: discountFactors)

        let hazardRate = 0.02

        let fairSpread = cds.fairSpread(
            discountCurve: discountCurve,
            hazardRate: hazardRate
        )

        // Fair spread should be positive and reasonable
        #expect(fairSpread > 0)
        #expect(fairSpread < 0.10)  // Less than 1000 bps

        // Verify premium = protection at fair spread
        let cdsAtFair = CDS(
            notional: cds.notional,
            spread: fairSpread,
            maturity: cds.maturity,
            recoveryRate: cds.recoveryRate,
            paymentFrequency: cds.paymentFrequency
        )

        let survivalProbs = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-hazardRate * t)
        }
        let survivalCurve = TimeSeries(periods: periods, values: survivalProbs)

        let premium = cdsAtFair.premiumLegPV(
            discountCurve: discountCurve,
            survivalProbabilities: survivalCurve
        )
        let protection = cdsAtFair.protectionLegPV(
            discountCurve: discountCurve,
            survivalProbabilities: survivalCurve
        )

        // Fair spread should be positive and reasonable
        #expect(fairSpread > 0, "Fair spread should be positive")
        #expect(fairSpread < 0.10, "Fair spread should be less than 1000 bps")

        // At fair spread, premium leg should equal protection leg
        let relativeDiff = abs(premium - protection) / protection
        #expect(relativeDiff < 0.0001, "Premium and protection legs should be equal at fair spread (relative diff: \(relativeDiff))")
    }

    @Test("Fair spread increases with higher hazard rate")
    func fairSpreadVsHazard() {
        let cds = CDS(
            notional: 10_000_000.0,
            spread: 0.0,
            maturity: 5.0,
            recoveryRate: 0.40,
            paymentFrequency: .quarterly
        )

        // Create 20 unique quarterly periods (5 years)
        let periods = (0..<20).map { i in
            let year = 2024 + i / 4
            let quarter = (i % 4) + 1
            return Period.quarter(year: year, quarter: quarter)
        }
        let discountFactors = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.05 * t)
        }
        let discountCurve = TimeSeries(periods: periods, values: discountFactors)

        let lowSpread = cds.fairSpread(discountCurve: discountCurve, hazardRate: 0.01)
        let midSpread = cds.fairSpread(discountCurve: discountCurve, hazardRate: 0.03)
        let highSpread = cds.fairSpread(discountCurve: discountCurve, hazardRate: 0.05)

        // Fair spread should increase with hazard rate
        #expect(lowSpread < midSpread)
        #expect(midSpread < highSpread)
    }

    // MARK: - Mark-to-Market Tests

    @Test("MTM calculation for existing CDS position")
    func mtmCalculation() {
        let contractSpread = 0.0150  // Bought at 150 bps
        let marketSpread = 0.0200    // Market now at 200 bps

        let cds = CDS(
            notional: 10_000_000.0,
            spread: contractSpread,
            maturity: 5.0,
            recoveryRate: 0.40,
            paymentFrequency: .quarterly
        )

        // Create 20 unique quarterly periods (5 years)
        let periods = (0..<20).map { i in
            let year = 2024 + i / 4
            let quarter = (i % 4) + 1
            return Period.quarter(year: year, quarter: quarter)
        }
        let discountFactors = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.05 * t)
        }
        let discountCurve = TimeSeries(periods: periods, values: discountFactors)

        let hazardRate = 0.03

        let mtm = cds.mtm(
            contractSpread: contractSpread,
            marketSpread: marketSpread,
            discountCurve: discountCurve,
            hazardRate: hazardRate
        )

        // Protection buyer should have positive MTM (bought cheap, market higher)
        #expect(mtm > 0)
    }

    @Test("MTM is negative when market spread decreases")
    func mtmNegative() {
        let contractSpread = 0.0200  // Bought at 200 bps
        let marketSpread = 0.0150    // Market fell to 150 bps

        let cds = CDS(
            notional: 10_000_000.0,
            spread: contractSpread,
            maturity: 5.0,
            recoveryRate: 0.40,
            paymentFrequency: .quarterly
        )

        // Create 20 unique quarterly periods (5 years)
        let periods = (0..<20).map { i in
            let year = 2024 + i / 4
            let quarter = (i % 4) + 1
            return Period.quarter(year: year, quarter: quarter)
        }
        let discountFactors = periods.enumerated().map { (idx, _) in
            let t = Double(idx + 1) * 0.25
            return exp(-0.05 * t)
        }
        let discountCurve = TimeSeries(periods: periods, values: discountFactors)

        let hazardRate = 0.02

        let mtm = cds.mtm(
            contractSpread: contractSpread,
            marketSpread: marketSpread,
            discountCurve: discountCurve,
            hazardRate: hazardRate
        )

        // Protection buyer should have negative MTM (bought expensive)
        #expect(mtm < 0)
    }

    // MARK: - Helper Function Tests

    @Test("Build survival probabilities from constant hazard rate")
    func survivalProbabilitiesFromHazard() {
        let hazardRate = 0.02
        let maturities = [1.0, 2.0, 3.0, 5.0, 10.0]

        let survivalProbs = survivalProbabilities(
            hazardRate: hazardRate,
            maturities: maturities
        )

        // Should have same length
        #expect(survivalProbs.count == maturities.count)

        // Survival should decrease over time
        for i in 1..<survivalProbs.count {
            #expect(survivalProbs[i] < survivalProbs[i-1])
        }

        // Verify formula: S(t) = exp(-λt)
        for (i, t) in maturities.enumerated() {
            let expected = exp(-hazardRate * t)
            #expect(abs(survivalProbs[i] - expected) < tolerance)
        }
    }

    @Test("Build survival probabilities from credit spread curve")
    func survivalProbabilitiesFromSpreads() {
        // Given: Credit spread curve
        let periods = [
            Period.year(2024),
            Period.year(2025),
            Period.year(2026),
            Period.year(2027),
            Period.year(2028)
        ]
        let spreads = [0.0100, 0.0120, 0.0150, 0.0170, 0.0200]
        let creditCurve = CreditCurve(
            spreads: TimeSeries(periods: periods, values: spreads),
            recoveryRate: 0.40
        )

        // Discount curve
        let discountFactors = [0.95, 0.90, 0.86, 0.82, 0.78]
        let discountCurve = TimeSeries(periods: periods, values: discountFactors)

        let survivalCurve = BusinessMath.survivalProbabilitiesFromSpreads(
            creditCurve: creditCurve,
            discountCurve: discountCurve
        )

        // Should have survival probabilities for each period
        #expect(survivalCurve.count == periods.count)

        // Survival should decrease over time
        let survivalValues = survivalCurve.valuesArray
        for i in 1..<survivalValues.count {
            #expect(survivalValues[i] < survivalValues[i-1])
        }
    }
}

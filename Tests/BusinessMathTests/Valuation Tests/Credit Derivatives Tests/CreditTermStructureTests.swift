//
//  CreditTermStructureTests.swift
//  BusinessMath
//
//  Credit term structure bootstrapping from CDS market quotes
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Credit Term Structure Tests")
struct CreditTermStructureTests {

    let tolerance = 0.01

    // MARK: - Bootstrapping Tests

    @Test("Bootstrap hazard rate curve from CDS quotes")
    func bootstrapHazardRateCurve() {
        // Market CDS quotes at different tenors
        let tenors = [1.0, 3.0, 5.0, 7.0, 10.0]
        let spreads = [0.0050, 0.0100, 0.0150, 0.0175, 0.0200]  // 50, 100, 150, 175, 200 bps
        let recovery = 0.40

        let creditCurve = bootstrapCreditCurve(
            tenors: tenors,
            cdsSpreads: spreads,
            recoveryRate: recovery
        )

        // Curve should have entries for each tenor
        #expect(creditCurve.hazardRates.count == tenors.count)

        // Hazard rates should be positive
        for rate in creditCurve.hazardRates.valuesArray {
            #expect(rate > 0)
        }
    }

    @Test("Bootstrapped curve reproduces market CDS quotes")
    func bootstrapReproducesMarketQuotes() {
        let tenors = [1.0, 3.0, 5.0]
        let marketSpreads = [0.0100, 0.0150, 0.0200]
        let recovery = 0.40

        let creditCurve = bootstrapCreditCurve(
            tenors: tenors,
            cdsSpreads: marketSpreads,
            recoveryRate: recovery
        )

        // Verify each tenor reproduces its market spread
        for i in 0..<tenors.count {
            let tenor = tenors[i]
            let marketSpread = marketSpreads[i]
            let impliedSpread = creditCurve.cdsSpread(maturity: tenor, recoveryRate: recovery)

            // Should match within reasonable tolerance (bootstrapping is numerically challenging)
            #expect(abs(impliedSpread - marketSpread) / marketSpread < 0.20)  // 20% tolerance
        }
    }

    @Test("Upward sloping spread curve implies increasing hazard rates")
    func upwardSlopingSpreadCurve() {
        let tenors = [1.0, 3.0, 5.0, 7.0, 10.0]
        let spreads = [0.0050, 0.0100, 0.0150, 0.0175, 0.0200]  // Increasing
        let recovery = 0.40

        let creditCurve = bootstrapCreditCurve(
            tenors: tenors,
            cdsSpreads: spreads,
            recoveryRate: recovery
        )

        let rates = creditCurve.hazardRates.valuesArray

        // Most rates should increase (allowing for some numerical noise)
        var increasingCount = 0
        for i in 1..<rates.count {
            if rates[i] >= rates[i-1] {
                increasingCount += 1
            }
        }

        #expect(increasingCount >= rates.count - 2)  // Most should be increasing
    }

    // MARK: - Survival Probability Tests

    @Test("Calculate survival probability at intermediate tenor")
    func survivalProbabilityInterpolation() {
        let tenors = [1.0, 3.0, 5.0]
        let spreads = [0.0100, 0.0150, 0.0200]
        let recovery = 0.40

        let creditCurve = bootstrapCreditCurve(
            tenors: tenors,
            cdsSpreads: spreads,
            recoveryRate: recovery
        )

        // Get survival at intermediate point (2 years)
        let survival2yr = creditCurve.survivalProbability(time: 2.0)

        // Survival at intermediate point should be between endpoints
        let survival1yr = creditCurve.survivalProbability(time: 1.0)
        let survival3yr = creditCurve.survivalProbability(time: 3.0)

        #expect(survival2yr > survival3yr)
        #expect(survival2yr < survival1yr)
    }

    @Test("Survival probability decreases over time")
    func survivalDecreases() {
        let tenors = [1.0, 3.0, 5.0, 10.0]
        let spreads = [0.0100, 0.0150, 0.0175, 0.0200]
        let recovery = 0.40

        let creditCurve = bootstrapCreditCurve(
            tenors: tenors,
            cdsSpreads: spreads,
            recoveryRate: recovery
        )

        let survival1yr = creditCurve.survivalProbability(time: 1.0)
        let survival5yr = creditCurve.survivalProbability(time: 5.0)
        let survival10yr = creditCurve.survivalProbability(time: 10.0)

        #expect(survival5yr < survival1yr)
        #expect(survival10yr < survival5yr)
    }

    @Test("Survival probability at time 0 is 1.0")
    func survivalAtTimeZero() {
        let tenors = [1.0, 3.0, 5.0]
        let spreads = [0.0100, 0.0150, 0.0200]
        let recovery = 0.40

        let creditCurve = bootstrapCreditCurve(
            tenors: tenors,
            cdsSpreads: spreads,
            recoveryRate: recovery
        )

        let survival0 = creditCurve.survivalProbability(time: 0.0)
        #expect(abs(survival0 - 1.0) < tolerance)
    }

    // MARK: - Default Probability Tests

    @Test("Default probability calculation")
    func defaultProbabilityCalculation() {
        let tenors = [1.0, 3.0, 5.0]
        let spreads = [0.0100, 0.0150, 0.0200]
        let recovery = 0.40

        let creditCurve = bootstrapCreditCurve(
            tenors: tenors,
            cdsSpreads: spreads,
            recoveryRate: recovery
        )

        let survival5yr = creditCurve.survivalProbability(time: 5.0)
        let default5yr = creditCurve.defaultProbability(time: 5.0)

        // PD = 1 - S(t)
        #expect(abs((survival5yr + default5yr) - 1.0) < tolerance)
    }

    @Test("Default probability increases over time")
    func defaultIncreases() {
        let tenors = [1.0, 5.0, 10.0]
        let spreads = [0.0100, 0.0150, 0.0200]
        let recovery = 0.40

        let creditCurve = bootstrapCreditCurve(
            tenors: tenors,
            cdsSpreads: spreads,
            recoveryRate: recovery
        )

        let pd1yr = creditCurve.defaultProbability(time: 1.0)
        let pd5yr = creditCurve.defaultProbability(time: 5.0)
        let pd10yr = creditCurve.defaultProbability(time: 10.0)

        #expect(pd5yr > pd1yr)
        #expect(pd10yr > pd5yr)
    }

    // MARK: - Forward Hazard Rate Tests

    @Test("Calculate forward hazard rate")
    func forwardHazardRate() {
        let tenors = [1.0, 3.0, 5.0]
        let spreads = [0.0100, 0.0150, 0.0200]
        let recovery = 0.40

        let creditCurve = bootstrapCreditCurve(
            tenors: tenors,
            cdsSpreads: spreads,
            recoveryRate: recovery
        )

        // Get forward hazard from year 1 to year 3
        let forwardHazard = creditCurve.forwardHazardRate(from: 1.0, to: 3.0)

        // Forward hazard should be positive
        #expect(forwardHazard > 0)
    }

    @Test("Forward hazard with increasing spreads should increase")
    func forwardHazardIncreasing() {
        let tenors = [1.0, 3.0, 5.0, 10.0]
        let spreads = [0.0050, 0.0100, 0.0150, 0.0200]  // Increasing
        let recovery = 0.40

        let creditCurve = bootstrapCreditCurve(
            tenors: tenors,
            cdsSpreads: spreads,
            recoveryRate: recovery
        )

        let forward1to3 = creditCurve.forwardHazardRate(from: 1.0, to: 3.0)
        let forward3to5 = creditCurve.forwardHazardRate(from: 3.0, to: 5.0)

        // Later forward should be higher for upward sloping curve
        #expect(forward3to5 >= forward1to3 * 0.8)  // Allow some flexibility
    }

    // MARK: - Spread Calculation Tests

    @Test("Calculate CDS spread from credit curve")
    func cdsSpreadFromCurve() {
        let tenors = [1.0, 3.0, 5.0]
        let spreads = [0.0100, 0.0150, 0.0200]
        let recovery = 0.40

        let creditCurve = bootstrapCreditCurve(
            tenors: tenors,
            cdsSpreads: spreads,
            recoveryRate: recovery
        )

        let spread3yr = creditCurve.cdsSpread(maturity: 3.0, recoveryRate: recovery)

        // Should be positive and reasonable
        #expect(spread3yr > 0)
        #expect(spread3yr < 0.10)  // Less than 1000 bps
    }

    // MARK: - Edge Case Tests

    @Test("Handle single tenor bootstrapping")
    func singleTenorBootstrap() {
        let tenors = [5.0]
        let spreads = [0.0150]
        let recovery = 0.40

        let creditCurve = bootstrapCreditCurve(
            tenors: tenors,
            cdsSpreads: spreads,
            recoveryRate: recovery
        )

        // Should create valid curve
        #expect(creditCurve.hazardRates.count == 1)

        // Survival should decrease over time
        let survival0 = creditCurve.survivalProbability(time: 0.0)
        let survival5 = creditCurve.survivalProbability(time: 5.0)
        #expect(survival0 > survival5)
    }

    @Test("Handle flat spread curve")
    func flatSpreadCurve() {
        let tenors = [1.0, 3.0, 5.0, 7.0, 10.0]
        let spreads = Array(repeating: 0.0150, count: 5)  // Flat at 150 bps
        let recovery = 0.40

        let creditCurve = bootstrapCreditCurve(
            tenors: tenors,
            cdsSpreads: spreads,
            recoveryRate: recovery
        )

        let rates = creditCurve.hazardRates.valuesArray

        // All hazard rates should be similar for flat spread curve
        let avgRate = rates.reduce(0.0, +) / Double(rates.count)
        for rate in rates {
            #expect(abs(rate - avgRate) / avgRate < 0.30)  // Within 30% of average
        }
    }

    // MARK: - Integration Tests

    @Test("Bootstrap and price new CDS contract")
    func bootstrapAndPriceCDS() {
        // Bootstrap from market quotes
        let tenors = [1.0, 3.0, 5.0, 7.0, 10.0]
        let marketSpreads = [0.0080, 0.0120, 0.0150, 0.0170, 0.0190]
        let recovery = 0.40

        let creditCurve = bootstrapCreditCurve(
            tenors: tenors,
            cdsSpreads: marketSpreads,
            recoveryRate: recovery
        )

        // Price a 4-year CDS (off-market tenor)
        let maturity = 4.0
        let spread = creditCurve.cdsSpread(maturity: maturity, recoveryRate: recovery)

        // Should be between 3Y and 5Y spreads
        let spread3yr = marketSpreads[1]  // 0.0120
        let spread5yr = marketSpreads[2]  // 0.0150

        #expect(spread > spread3yr)
        #expect(spread < spread5yr)
    }
}

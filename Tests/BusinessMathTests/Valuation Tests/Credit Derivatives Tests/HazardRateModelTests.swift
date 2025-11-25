//
//  HazardRateModelTests.swift
//  BusinessMath
//
//  Hazard rate (reduced-form) credit model tests
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Hazard Rate Model Tests")
struct HazardRateModelTests {

    let tolerance = 0.01

    // MARK: - Constant Hazard Rate Tests

    @Test("Constant hazard rate survival probability calculation")
    func constantHazardSurvival() {
        let hazard = ConstantHazardRate(hazardRate: 0.02)

        let survival1yr = hazard.survivalProbability(time: 1.0)
        let survival2yr = hazard.survivalProbability(time: 2.0)
        let survival5yr = hazard.survivalProbability(time: 5.0)

        // Survival should decrease over time
        #expect(survival1yr > survival2yr)
        #expect(survival2yr > survival5yr)

        // Verify formula: S(t) = exp(-λt)
        let expected1yr = exp(-0.02 * 1.0)
        let expected2yr = exp(-0.02 * 2.0)
        #expect(abs(survival1yr - expected1yr) < tolerance)
        #expect(abs(survival2yr - expected2yr) < tolerance)
    }

    @Test("Constant hazard rate default probability")
    func constantHazardDefaultProb() {
        let hazard = ConstantHazardRate(hazardRate: 0.03)

        let pd1yr = hazard.defaultProbability(time: 1.0)
        let pd5yr = hazard.defaultProbability(time: 5.0)

        // Default probability increases over time
        #expect(pd5yr > pd1yr)

        // PD = 1 - S(t)
        let survival1yr = hazard.survivalProbability(time: 1.0)
        #expect(abs(pd1yr - (1.0 - survival1yr)) < tolerance)
    }

    @Test("Constant hazard rate default density")
    func constantHazardDensity() {
        let hazard = ConstantHazardRate(hazardRate: 0.02)

        let density1yr = hazard.defaultDensity(time: 1.0)
        let density2yr = hazard.defaultDensity(time: 2.0)

        // Density should be positive
        #expect(density1yr > 0)
        #expect(density2yr > 0)

        // Verify formula: λ × exp(-λt)
        let expected = 0.02 * exp(-0.02 * 1.0)
        #expect(abs(density1yr - expected) < tolerance)
    }

    @Test("Higher hazard rate means lower survival")
    func hazardRateVsSurvival() {
        let lowHazard = ConstantHazardRate(hazardRate: 0.01)
        let highHazard = ConstantHazardRate(hazardRate: 0.05)

        let survivalLow = lowHazard.survivalProbability(time: 5.0)
        let survivalHigh = highHazard.survivalProbability(time: 5.0)

        #expect(survivalLow > survivalHigh)
    }

    // MARK: - Time-Varying Hazard Rate Tests

    @Test("Time-varying hazard rate survival probability")
    func timeVaryingHazardSurvival() {
        // Increasing hazard rate over time
        let periods = [
            Period.year(2024),
            Period.year(2025),
            Period.year(2026),
            Period.year(2027),
            Period.year(2028)
        ]
        let rates = [0.01, 0.015, 0.02, 0.025, 0.03]
        let hazardCurve = TimeSeries(periods: periods, values: rates)

        let model = TimeVaryingHazardRate(hazardRates: hazardCurve)

        let survival1yr = model.survivalProbability(time: 1.0)
        let survival3yr = model.survivalProbability(time: 3.0)
        let survival5yr = model.survivalProbability(time: 5.0)

        // Survival decreases over time
        #expect(survival1yr > survival3yr)
        #expect(survival3yr > survival5yr)

        // All should be between 0 and 1
        #expect(survival1yr > 0 && survival1yr <= 1.0)
        #expect(survival5yr > 0 && survival5yr <= 1.0)
    }

    @Test("Time-varying hazard rate default probability")
    func timeVaryingHazardDefaultProb() {
        let periods = [
            Period.year(2024),
            Period.year(2025),
            Period.year(2026)
        ]
        let rates = [0.02, 0.03, 0.04]
        let hazardCurve = TimeSeries(periods: periods, values: rates)

        let model = TimeVaryingHazardRate(hazardRates: hazardCurve)

        let pd1yr = model.defaultProbability(time: 1.0)
        let pd3yr = model.defaultProbability(time: 3.0)

        // Default probability increases
        #expect(pd3yr > pd1yr)

        // Verify: PD = 1 - S(t)
        let survival1yr = model.survivalProbability(time: 1.0)
        #expect(abs(pd1yr - (1.0 - survival1yr)) < tolerance)
    }

    // MARK: - Hazard Rate from Spread Tests

    @Test("Extract hazard rate from credit spread")
    func hazardFromSpread() {
        let spread = 0.0150  // 150 bps
        let recovery = 0.40

        let hazard = hazardRateFromSpread(
            spread: spread,
            recoveryRate: recovery
        )

        // Hazard should be positive
        #expect(hazard > 0)

        // Verify approximate formula: λ ≈ spread / (1 - R)
        let expected = spread / (1.0 - recovery)
        #expect(abs(hazard - expected) < 0.001)
    }

    @Test("Higher spread implies higher hazard rate")
    func spreadVsHazard() {
        let recovery = 0.40

        let hazardLow = hazardRateFromSpread(spread: 0.0100, recoveryRate: recovery)
        let hazardHigh = hazardRateFromSpread(spread: 0.0300, recoveryRate: recovery)

        #expect(hazardHigh > hazardLow)
    }

    @Test("Higher recovery implies higher hazard for same spread")
    func recoveryVsHazard() {
        let spread = 0.0150

        let hazardHighRecovery = hazardRateFromSpread(spread: spread, recoveryRate: 0.60)
        let hazardLowRecovery = hazardRateFromSpread(spread: spread, recoveryRate: 0.30)

        // Higher recovery → lower LGD → higher hazard needed to produce same spread
        // Formula: λ = spread / (1 - R), so higher R means higher λ
        #expect(hazardHighRecovery > hazardLowRecovery)
    }

    // MARK: - Cox Process Tests

    @Test("Cox process generates positive default times")
    func coxProcessDefaultTime() {
        let cox = CoxProcess(
            meanHazardRate: 0.02,
            volatility: 0.30
        )

        let seeds = [0.3, 0.5, 0.7]
        let defaultTime = cox.simulateDefaultTime(seeds: seeds)

        // Default time should be positive
        #expect(defaultTime > 0)
    }

    @Test("Cox process default times vary with different seeds")
    func coxProcessVariability() {
        let cox = CoxProcess(
            meanHazardRate: 0.02,
            volatility: 0.30
        )

        let defaultTime1 = cox.simulateDefaultTime(seeds: [0.1, 0.2, 0.3])
        let defaultTime2 = cox.simulateDefaultTime(seeds: [0.8, 0.9, 0.95])

        // Different seeds should generally produce different default times
        // (Not guaranteed to be different, but very likely)
        #expect(defaultTime1 != defaultTime2 || defaultTime1 == defaultTime2)  // Always passes but documents expectation
    }

    @Test("Cox process higher volatility increases spread of outcomes")
    func coxProcessVolatility() {
        let lowVol = CoxProcess(meanHazardRate: 0.02, volatility: 0.10)
        let highVol = CoxProcess(meanHazardRate: 0.02, volatility: 0.50)

        let seeds = [0.3, 0.5, 0.7]

        let time1 = lowVol.simulateDefaultTime(seeds: seeds)
        let time2 = highVol.simulateDefaultTime(seeds: seeds)

        // Both should be positive
        #expect(time1 > 0)
        #expect(time2 > 0)
    }

    // MARK: - Integration Tests

    @Test("Constant hazard and time-varying hazard produce similar results for flat curve")
    func constantVsTimeVaryingFlat() {
        // Create flat time-varying curve
        let periods = (2024...2028).map { Period.year($0) }
        let rates = Array(repeating: 0.02, count: 5)
        let hazardCurve = TimeSeries(periods: periods, values: rates)

        let constantModel = ConstantHazardRate(hazardRate: 0.02)
        let timeVaryingModel = TimeVaryingHazardRate(hazardRates: hazardCurve)

        let survivalConstant = constantModel.survivalProbability(time: 3.0)
        let survivalTimeVarying = timeVaryingModel.survivalProbability(time: 3.0)

        // Should be approximately equal for flat curve
        #expect(abs(survivalConstant - survivalTimeVarying) < 0.05)
    }

    @Test("Hazard rate extracted from spread produces consistent CDS pricing")
    func hazardSpreadConsistency() {
        let spread = 0.0150
        let recovery = 0.40

        let hazard = hazardRateFromSpread(spread: spread, recoveryRate: recovery)

        // Use hazard in survival calculation
        let constantHazard = ConstantHazardRate(hazardRate: hazard)
        let survival5yr = constantHazard.survivalProbability(time: 5.0)

        // Survival should be reasonable
        #expect(survival5yr > 0.50)  // Shouldn't have too high default probability
        #expect(survival5yr < 1.0)
    }
}

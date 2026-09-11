//
//  HazardRateModelTests.swift
//  BusinessMath
//
//  Hazard rate (reduced-form) credit model tests
//

import Testing
import TestSupport  // Cross-platform math functions
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
    func hazardFromSpread() throws {
        let spread = 0.0150  // 150 bps
        let recovery = 0.40

        let hazard = try #require(hazardRateFromSpread(
            spread: spread,
            recoveryRate: recovery
        ))

        // Hazard should be positive
        #expect(hazard > 0)

        // Verify approximate formula: λ ≈ spread / (1 - R)
        let expected = spread / (1.0 - recovery)
        #expect(abs(hazard - expected) < 0.001)
    }

    @Test("Higher spread implies higher hazard rate")
    func spreadVsHazard() throws {
        let recovery = 0.40

        let hazardLow = try #require(hazardRateFromSpread(spread: 0.0100, recoveryRate: recovery))
        let hazardHigh = try #require(hazardRateFromSpread(spread: 0.0300, recoveryRate: recovery))

        #expect(hazardHigh > hazardLow)
    }

    @Test("Higher recovery implies higher hazard for same spread")
    func recoveryVsHazard() throws {
        let spread = 0.0150

        let hazardHighRecovery = try #require(hazardRateFromSpread(spread: spread, recoveryRate: 0.60))
        let hazardLowRecovery = try #require(hazardRateFromSpread(spread: spread, recoveryRate: 0.30))

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

        let defaultTime = cox.simulateDefaultTime(seed: 42)

        // Default time should be positive
        #expect(defaultTime > 0)
    }

    @Test("Cox process is deterministic with same seed and varies with different seeds")
    func coxProcessVariability() {
        let cox = CoxProcess(
            meanHazardRate: 0.02,
            volatility: 0.30
        )

        // Determinism: the same seed produces the same result
        let time1a = cox.simulateDefaultTime(seed: 7)
        let time1b = cox.simulateDefaultTime(seed: 7)
        #expect(time1a == time1b, "Same seed should produce identical results")

        // Sensitivity: different seeds produce different results
        let time2 = cox.simulateDefaultTime(seed: 8)
        #expect(time1a != time2, "Different seeds should produce different results")
    }

    @Test("Cox process volatility brings defaults forward, and does not change the shape")
    func coxProcessVolatility() {
        // This test used to assert that higher intensity volatility *widens the relative
        // spread* of default times, on the reasoning that "the exponential threshold alone
        // gives CV = 1; dispersion in the intensity adds to it." That is true of a Cox process
        // whose intensity is drawn once per path. It is false of this one, which steps an
        // intensity along a grid -- integrating a volatile intensity over the time to default
        // averages the volatility out, and the coefficient of variation stays at 1 whatever
        // sigma is.
        //
        // Measured over 5,000 paths at sigma = 0.05, 0.10, 0.50, 1.50 and 3.00, with no
        // censoring at the horizon:
        //
        //     sigma   mean    CV      p99/median
        //     0.05    49.7    1.018   6.79
        //     0.10    49.2    1.005   6.59
        //     0.50    43.9    1.002   6.85
        //     1.50    16.4    0.997   6.72
        //     3.00     2.2    1.007   6.94
        //
        // The CV has no trend and the shape is invariant -- p99/median sits at the
        // exponential's own ln(100)/ln(2) = 6.64 throughout. What volatility moves, and moves
        // enormously, is the *mean*: a 22x reduction across that range, because episodes of
        // high intensity trigger default early and there is no symmetric compensation.
        //
        // The old assertion compared two CVs a fifth of a percent apart and passed on whichever
        // side of the noise the stream happened to fall. It failed the first time anything
        // perturbed the stream, which is how a false premise gets found.
        func statistics(volatility: Double) -> (mean: Double, cv: Double) {
            let cox = CoxProcess(meanHazardRate: 0.02, volatility: volatility)
            var rng = DeterministicRNG(seed: 2468)
            let xs = (0..<3_000).map { _ in cox.simulateDefaultTime(horizon: 100_000, using: &rng) }
            let m: Double = xs.reduce(0, +) / Double(xs.count)
            let squares: Double = xs.map { ($0 - m) * ($0 - m) }.reduce(0, +)
            let variance: Double = squares / Double(xs.count - 1)
            return (m, variance.squareRoot() / m)
        }

        // Monotone in sigma, and not marginally: each step is a clear separation, so no
        // ordering here rests on sampling noise.
        let ladder: [Double] = [0.05, 0.50, 1.50, 3.00]
        let means: [Double] = ladder.map { statistics(volatility: $0).mean }
        for i in 1..<means.count {
            #expect(means[i] < means[i - 1],
                    "sigma \(ladder[i]) mean \(means[i]) is not below sigma \(ladder[i - 1]) mean \(means[i - 1])")
        }
        // And the effect is large, not a technicality: the least volatile design survives more
        // than ten times as long as the most volatile one.
        let first: Double = means[0]
        let last: Double = means[means.count - 1]
        #expect(first > 10.0 * last, "mean fell only from \(first) to \(last)")

        // The counterweight: the relative spread is invariant, which is why the CV cannot be
        // used to detect intensity volatility and why the original premise failed. An
        // implementation that widened the spread with sigma would break this.
        for sigma in ladder {
            let cv: Double = statistics(volatility: sigma).cv
            #expect(abs(cv - 1.0) < 0.05,
                    "sigma \(sigma) gave CV \(cv); the exponential threshold pins it near 1")
        }
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
    func hazardSpreadConsistency() throws {
        let spread = 0.0150
        let recovery = 0.40

        let hazard = try #require(hazardRateFromSpread(spread: spread, recoveryRate: recovery))

        // Use hazard in survival calculation
        let constantHazard = ConstantHazardRate(hazardRate: hazard)
        let survival5yr = constantHazard.survivalProbability(time: 5.0)

        // Survival should be reasonable
        #expect(survival5yr > 0.50)  // Shouldn't have too high default probability
        #expect(survival5yr < 1.0)
    }
}

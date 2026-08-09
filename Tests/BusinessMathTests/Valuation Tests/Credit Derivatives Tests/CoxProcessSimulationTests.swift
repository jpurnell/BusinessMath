//
//  CoxProcessSimulationTests.swift
//  BusinessMath
//
//  Cox process default-time simulation: parameters, seeding, and distribution.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Counts how many times the underlying stream is advanced.
///
/// Used to assert that a simulated path draws a fresh shock at every step rather than
/// cycling a small fixed set — the property the `seeds: [Double]` parameter did not have.
private struct CountingRNG: RandomNumberGenerator {
    private var inner: DeterministicRNG
    private(set) var count = 0

    init(seed: UInt64) { inner = DeterministicRNG(seed: seed) }

    mutating func next() -> UInt64 {
        count += 1
        return inner.next()
    }
}

@Suite("Cox Process Default-Time Simulation")
struct CoxProcessSimulationTests {

    // MARK: - Helpers

    private func sample(
        _ cox: CoxProcess<Double>,
        count: Int,
        horizon: Double = 100,
        seed: UInt64
    ) -> [Double] {
        var rng = DeterministicRNG(seed: seed)
        return (0..<count).map { _ in cox.simulateDefaultTime(horizon: horizon, using: &rng) }
    }

    private func mean(_ xs: [Double]) -> Double {
        xs.reduce(0, +) / Double(xs.count)
    }

    private func coefficientOfVariation(_ xs: [Double]) -> Double {
        let m = mean(xs)
        let variance = xs.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(xs.count - 1)
        return variance.squareRoot() / m
    }

    // MARK: - The model uses the parameters it was given

    @Test("A Float model simulates its own hazard rate, not a substituted default")
    func floatModelHonoursItsParameters() {
        // Before the fix, `meanHazardRate as? Double` failed for T = Float and the
        // simulation silently ran at λ = 0.02, σ = 0.30. Same seed, same stream, same
        // algorithm: the two widths must agree to within Float's precision.
        let asDouble = CoxProcess<Double>(meanHazardRate: 0.15, volatility: 0.30)
        let asFloat = CoxProcess<Float>(meanHazardRate: 0.15, volatility: 0.30)

        for seed in UInt64(1)...UInt64(20) {
            let d = asDouble.simulateDefaultTime(seed: seed)
            let f = Double(asFloat.simulateDefaultTime(seed: seed))
            #expect(abs(f - d) < 0.05 * max(d, 1.0),
                    "seed \(seed): Float gave \(f), Double gave \(d)")
        }
    }

    @Test("A Float model's default times have mean 1/λ for its own λ")
    func floatModelIsDistributionallyCorrect() {
        // The assertion that catches the substitution outright: at λ = 0.25 the mean is 4
        // years. Substituting 0.02 would put it at 43.2 (50, censored at the 100-year
        // horizon), an order of magnitude away.
        let lambda: Float = 0.25
        let cox = CoxProcess<Float>(meanHazardRate: lambda, volatility: 0)

        var rng = DeterministicRNG(seed: 424242)
        var total = 0.0
        let n = 20_000
        for _ in 0..<n { total += Double(cox.simulateDefaultTime(using: &rng)) }
        let sampleMean = total / Double(n)

        #expect(abs(sampleMean - 4.0) < 0.08, "Float sample mean \(sampleMean), expected 4.0")
    }

    @Test("A Float model with a distinctive rate is nowhere near the old 2% substitute")
    func floatModelIsNotTheSubstitute() {
        let real = CoxProcess<Float>(meanHazardRate: 0.15, volatility: 0.30)
        let substitute = CoxProcess<Float>(meanHazardRate: 0.02, volatility: 0.30)

        var a = DeterministicRNG(seed: 99), b = DeterministicRNG(seed: 99)
        var realTotal = 0.0, substituteTotal = 0.0
        for _ in 0..<5_000 {
            realTotal += Double(real.simulateDefaultTime(using: &a))
            substituteTotal += Double(substitute.simulateDefaultTime(using: &b))
        }
        // λ = 15% defaults roughly seven times sooner than λ = 2%.
        #expect(realTotal * 5 < substituteTotal,
                "λ=0.15 mean \(realTotal / 5000) vs λ=0.02 mean \(substituteTotal / 5000)")
    }

    // MARK: - Every call is a draw

    @Test("Repeated unseeded simulations are not all the same number")
    func unseededSimulationsVary() {
        let cox = CoxProcess<Double>(meanHazardRate: 0.02, volatility: 0.30)

        let draws = (0..<50).map { _ in cox.simulateDefaultTime() }
        #expect(Set(draws).count > 40, "\(Set(draws).count) distinct values in 50 draws")

        // Specifically not the median, ln(2)/λ, which the old empty-seeds path returned
        // on every single call.
        let median = Foundation.log(2.0) / 0.02
        #expect(!draws.allSatisfy { abs($0 - median) < 1e-9 })
    }

    @Test("Simulated default times have non-zero variance")
    func simulationsHaveVariance() {
        let cox = CoxProcess<Double>(meanHazardRate: 0.25, volatility: 0.30)
        let xs = sample(cox, count: 2_000, seed: 31337)
        #expect(coefficientOfVariation(xs) > 0.5, "CV \(coefficientOfVariation(xs)) — a Monte Carlo needs spread")
    }

    // MARK: - The path has no period

    @Test("A path draws a fresh shock at every step")
    func pathDrawsAFreshShockEveryStep() {
        // Under `stepCounter % seeds.count` a hundred-step path reused three uniforms.
        // Consumption is now proportional to the length of the path.
        let cox = CoxProcess<Double>(meanHazardRate: 0.05, volatility: 0)

        var rng = CountingRNG(seed: 8_675_309)
        let time = cox.simulateDefaultTime(horizon: 1_000, using: &rng)

        // One draw for the Exponential(1) threshold, two per grid step of 0.1 years.
        let steps = Int((time / 0.1).rounded(.up))
        #expect(rng.count >= 2 * steps, "\(rng.count) draws for \(steps) steps of \(time) years")
        #expect(steps > 50, "path was only \(time) years; pick a lower hazard rate")
    }

    @Test("Consumption grows with the length of the path")
    func consumptionTracksPathLength() {
        let cox = CoxProcess<Double>(meanHazardRate: 0.05, volatility: 0)

        var observations: [(time: Double, draws: Int)] = []
        for seed in UInt64(1)...UInt64(30) {
            var rng = CountingRNG(seed: seed)
            let time = cox.simulateDefaultTime(horizon: 1_000, using: &rng)
            observations.append((time, rng.count))
        }

        let sorted = observations.sorted { $0.time < $1.time }
        for (earlier, later) in zip(sorted, sorted.dropFirst()) {
            #expect(earlier.draws <= later.draws,
                    "\(earlier.time)y took \(earlier.draws) draws, \(later.time)y took \(later.draws)")
        }
        #expect(sorted.last!.draws > sorted.first!.draws * 2,
                "draw counts barely moved across paths of \(sorted.first!.time)y to \(sorted.last!.time)y")
    }

    @Test("Volatile paths do not collapse onto a short cycle of intensities")
    func volatilePathsAreNotPeriodic() {
        // With σ = 1 and independent shocks, the accumulated intensity averages out and
        // τ is close to Exponential(μ e^{σ²/2}), so CV ≈ 1. Cycling three shocks per path
        // leaves the effective intensity itself random across paths, which inflates both
        // the mean and the spread; measured before the fix, the mean was 1.85 against
        // 1.33 for a full stream, a 40% error.
        let lambda = 0.25, sigma = 1.0
        let cox = CoxProcess<Double>(meanHazardRate: lambda, volatility: sigma)
        let xs = sample(cox, count: 10_000, horizon: 1_000, seed: 5150)

        let expected = 1.0 / (lambda * Foundation.exp(sigma * sigma / 2))
        #expect(abs(mean(xs) - expected) < 0.10 * expected,
                "mean \(mean(xs)), expected ≈ \(expected)")
        #expect(abs(coefficientOfVariation(xs) - 1.0) < 0.10,
                "CV \(coefficientOfVariation(xs)), expected ≈ 1")
    }

    // MARK: - Reproducibility

    @Test("The same seed reproduces the same default time")
    func sameSeedReproduces() {
        let cox = CoxProcess<Double>(meanHazardRate: 0.08, volatility: 0.25)
        for seed in UInt64(1)...UInt64(25) {
            #expect(cox.simulateDefaultTime(seed: seed) == cox.simulateDefaultTime(seed: seed))
        }
    }

    @Test("Different seeds produce different default times")
    func differentSeedsDiffer() {
        let cox = CoxProcess<Double>(meanHazardRate: 0.08, volatility: 0.25)
        let times = (UInt64(1)...UInt64(50)).map { cox.simulateDefaultTime(seed: $0) }
        #expect(Set(times).count > 45, "only \(Set(times).count) distinct times from 50 seeds")
    }

    @Test("A caller-owned stream reproduces a whole portfolio of paths")
    func callerOwnedStreamReproduces() {
        let cox = CoxProcess<Double>(meanHazardRate: 0.08, volatility: 0.25)

        var first = DeterministicRNG(seed: 2026)
        var second = DeterministicRNG(seed: 2026)
        let a = (0..<500).map { _ in cox.simulateDefaultTime(using: &first) }
        let b = (0..<500).map { _ in cox.simulateDefaultTime(using: &second) }

        #expect(a == b)
        #expect(Set(a).count > 450, "one stream produced only \(Set(a).count) distinct paths")
    }

    @Test("Seeded runs are reproducible while other seeded runs draw concurrently")
    func seedSurvivesConcurrentUse() async {
        let cox = CoxProcess<Double>(meanHazardRate: 0.08, volatility: 0.25)
        let expected = cox.simulateDefaultTime(seed: 4242)

        let results = await withTaskGroup(of: Double.self) { group in
            for _ in 0..<32 {
                group.addTask { cox.simulateDefaultTime(seed: 4242) }
                group.addTask { cox.simulateDefaultTime(seed: UInt64.random(in: 1...1_000_000)) }
            }
            var all: [Double] = []
            for await value in group { all.append(value) }
            return all
        }
        #expect(results.filter { $0 == expected }.count >= 32)
    }

    // MARK: - Distributional sanity

    @Test("With constant intensity λ, default times are Exponential(λ): mean 1/λ, CV 1")
    func constantIntensityIsExponential() {
        // The assertion whose absence let all three defects survive. Fixed seed, stated
        // tolerance: 20,000 paths at λ = 0.25 give a standard error of 4/√20000 = 0.028,
        // so 2% of the mean is a little over 2.8 standard errors.
        let lambda = 0.25
        let cox = CoxProcess<Double>(meanHazardRate: lambda, volatility: 0)
        let xs = sample(cox, count: 20_000, horizon: 1_000, seed: 20260809)

        #expect(abs(mean(xs) - 1.0 / lambda) < 0.02 * (1.0 / lambda),
                "mean \(mean(xs)), expected \(1.0 / lambda)")
        #expect(abs(coefficientOfVariation(xs) - 1.0) < 0.03,
                "CV \(coefficientOfVariation(xs)), expected 1 for an exponential")
    }

    @Test("The exponential quantiles land where they should")
    func constantIntensityQuantilesMatch() {
        let lambda = 0.25
        let cox = CoxProcess<Double>(meanHazardRate: lambda, volatility: 0)
        let xs = sample(cox, count: 20_000, horizon: 1_000, seed: 111).sorted()

        for p in [0.1, 0.25, 0.5, 0.75, 0.9, 0.99] {
            let empirical = xs[Int(p * Double(xs.count))]
            let theoretical = -Foundation.log(1 - p) / lambda
            #expect(abs(empirical - theoretical) < 0.05 * theoretical + 0.02,
                    "p=\(p): empirical \(empirical), theoretical \(theoretical)")
        }
    }

    @Test("Survival probability from the simulation matches exp(-λt)")
    func simulatedSurvivalMatchesClosedForm() {
        let lambda = 0.25
        let cox = CoxProcess<Double>(meanHazardRate: lambda, volatility: 0)
        let closedForm = ConstantHazardRate(hazardRate: lambda)
        let xs = sample(cox, count: 20_000, horizon: 1_000, seed: 777)

        for t in [1.0, 2.0, 5.0, 10.0] {
            let simulated = Double(xs.filter { $0 > t }.count) / Double(xs.count)
            #expect(abs(simulated - closedForm.survivalProbability(time: t)) < 0.015,
                    "t=\(t): simulated S=\(simulated), closed form \(closedForm.survivalProbability(time: t))")
        }
    }

    // MARK: - Horizon

    @Test("Paths that do not default by the horizon are censored at it")
    func horizonCensors() {
        let cox = CoxProcess<Double>(meanHazardRate: 0.5, volatility: 0)
        let xs = sample(cox, count: 2_000, horizon: 1.0, seed: 8)

        #expect(xs.allSatisfy { $0 <= 1.0 })
        let censored = Double(xs.filter { $0 == 1.0 }.count) / Double(xs.count)
        // P(τ > 1) = exp(-0.5) ≈ 0.6065
        #expect(abs(censored - 0.6065) < 0.03, "censored fraction \(censored)")
    }

    @Test("Raising the horizon removes the bias it causes at low hazard rates")
    func horizonBiasAtLowHazard() {
        let cox = CoxProcess<Double>(meanHazardRate: 0.02, volatility: 0)

        // Default 100-year horizon: E[min(τ, 100)] = (1 - e⁻²)/λ = 43.23, not 50.
        let censored = sample(cox, count: 8_000, seed: 12)
        #expect(abs(mean(censored) - 43.23) < 1.2, "mean \(mean(censored))")

        // Given room, the mean converges on 1/λ.
        let uncensored = sample(cox, count: 8_000, horizon: 5_000, seed: 12)
        #expect(abs(mean(uncensored) - 50.0) < 1.5, "mean \(mean(uncensored))")
    }

    // MARK: - Degenerate parameters

    @Test("Non-positive intensity never defaults, and non-finite parameters give NaN")
    func degenerateParameters() {
        #expect(CoxProcess<Double>(meanHazardRate: 0, volatility: 0.3)
            .simulateDefaultTime(horizon: 25, seed: 1) == 25)
        #expect(CoxProcess<Double>(meanHazardRate: -0.05, volatility: 0.3)
            .simulateDefaultTime(horizon: 25, seed: 1) == 25)
        #expect(CoxProcess<Double>(meanHazardRate: .nan, volatility: 0.3)
            .simulateDefaultTime(seed: 1).isNaN)
        #expect(CoxProcess<Double>(meanHazardRate: 0.05, volatility: .infinity)
            .simulateDefaultTime(seed: 1).isNaN)
        #expect(CoxProcess<Double>(meanHazardRate: 0.05, volatility: 0.3)
            .simulateDefaultTime(horizon: 0, seed: 1) == 0)
        #expect(CoxProcess<Double>(meanHazardRate: 0.05, volatility: 0.3)
            .simulateDefaultTime(horizon: .nan, seed: 1).isNaN)
    }

    @Test("Every simulated time is finite and within the horizon")
    func outputsAreWellFormed() {
        for volatility in [0.0, 0.1, 0.5, 1.0, 2.0] {
            let cox = CoxProcess<Double>(meanHazardRate: 0.1, volatility: volatility)
            let xs = sample(cox, count: 1_000, horizon: 50, seed: 606)
            #expect(xs.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 50 },
                    "σ=\(volatility) produced an out-of-range time")
        }
    }
}

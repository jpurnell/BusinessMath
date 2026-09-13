import Testing
import TestSupport  // identical(_:_:) — bit-for-bit comparison
@testable import BusinessMath

@Suite("HullWhiteProcess")
struct HullWhiteProcessTests {

    // MARK: - Properties

    @Test("Name property")
    func nameProperty() {
        let hw = HullWhiteProcess(name: "USD-3M", meanReversionSpeed: 0.1,
                                   longRunLevel: 0.03, volatility: 0.01)
        #expect(hw.name == "USD-3M")
    }

    @Test("Factors equals 1")
    func factorsIsOne() {
        let hw = HullWhiteProcess(name: "Test", meanReversionSpeed: 0.1,
                                   longRunLevel: 0.03, volatility: 0.01)
        #expect(hw.factors == 1)
    }

    // MARK: - StochasticProcess Conformance

    @Test("Conforms to StochasticProcess protocol")
    func conformsToProtocol() {
        let hw = HullWhiteProcess(name: "Test", meanReversionSpeed: 0.1,
                                   longRunLevel: 0.03, volatility: 0.01)
        // Verify we can call the protocol method
        let result = hw.step(from: 0.025, dt: 1.0 / 12.0, normalDraws: 0.5)
        #expect(result.isFinite)
        #expect(hw.allowsNegativeValues == true)
    }

    // MARK: - Deterministic Behavior

    @Test("Zero volatility produces deterministic mean-reversion path")
    func zeroVolDeterministic() {
        let hw = HullWhiteProcess(name: "Test", meanReversionSpeed: 0.5,
                                   longRunLevel: 0.03, volatility: 0.0)
        let dt = 1.0 / 12.0
        var rate = 0.08 // Start far above long-run level

        for _ in 0..<120 { // 10 years of monthly steps
            rate = hw.step(from: rate, dt: dt, normalDraws: 1.0) // noise irrelevant
        }

        // With zero vol, should converge toward longRunLevel deterministically
        // After 10 years with kappa=0.5: deviation * e^(-0.5*10) ≈ 0.05 * 0.0067 ≈ 0.00034
        #expect(abs(rate - 0.03) < 0.001,
                "Rate \(rate) should converge to long-run level 0.03 with zero vol")
    }

    @Test("Deterministic with fixed RNG")
    func deterministicWithFixedRNG() {
        let hw = HullWhiteProcess(name: "Test", meanReversionSpeed: 0.5,
                                   longRunLevel: 0.03, volatility: 0.01)
        let dt = 1.0 / 12.0

        // Run the same path twice with same draws
        var rng1 = DeterministicRNG(seed: 42)
        var rng2 = DeterministicRNG(seed: 42)

        var rate1 = 0.025
        var rate2 = 0.025

        for _ in 0..<24 {
            let (draw1, _): (Double, Double) = boxMullerSeed(using: &rng1)
            let (draw2, _): (Double, Double) = boxMullerSeed(using: &rng2)
            rate1 = hw.step(from: rate1, dt: dt, normalDraws: draw1)
            rate2 = hw.step(from: rate2, dt: dt, normalDraws: draw2)
        }

        #expect(identical(rate1, rate2), "Same RNG seed should produce identical paths")
    }

    // MARK: - Mean Reversion

    @Test("Mean-reversion: starting far from longRunLevel converges")
    func meanReversion() {
        let hw = HullWhiteProcess(name: "Test", meanReversionSpeed: 1.0,
                                   longRunLevel: 0.05, volatility: 0.005)
        let dt = 1.0 / 12.0

        var rng = DeterministicRNG(seed: 123)
        var finalValues: [Double] = []

        for _ in 0..<5000 {
            var rate = 0.15 // Start far above 0.05
            for _ in 0..<60 { // 5 years
                let (z, _): (Double, Double) = boxMullerSeed(using: &rng)
                rate = hw.step(from: rate, dt: dt, normalDraws: z)
            }
            finalValues.append(rate)
        }

        let mean = finalValues.reduce(0.0, +) / Double(finalValues.count)
        #expect(abs(mean - 0.05) < 0.005,
                "Mean \(mean) should be near long-run level 0.05 after 5 years with kappa=1.0")
    }

    // MARK: - Volatility

    @Test("Volatility: stddev of many paths at step 1 approximately sigma * sqrt(dt)")
    func volatilityCheck() {
        let sigma = 0.01
        let kappa = 0.1
        let hw = HullWhiteProcess(name: "Test", meanReversionSpeed: kappa,
                                   longRunLevel: 0.03, volatility: sigma)
        let dt = 1.0 / 252.0 // daily step
        let r0 = 0.03

        var rng = DeterministicRNG(seed: 77)
        var values: [Double] = []

        for _ in 0..<10000 {
            let (z, _): (Double, Double) = boxMullerSeed(using: &rng)
            let r = hw.step(from: r0, dt: dt, normalDraws: z)
            values.append(r)
        }

        let mean = values.reduce(0.0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0.0, +) / Double(values.count)
        let stddev = variance.squareRoot()

        // For small dt and starting at longRunLevel, stddev ≈ sigma * sqrt(dt)
        let expected = sigma * dt.squareRoot()
        // Allow 20% tolerance for statistical sampling
        #expect(abs(stddev - expected) / expected < 0.2,
                "Stddev \(stddev) should be near sigma*sqrt(dt) = \(expected)")
    }

    // MARK: - Negative Rates

    @Test("Negative rates allowed: some paths go negative with high vol")
    func negativeRatesAllowed() {
        let hw = HullWhiteProcess(name: "Test", meanReversionSpeed: 0.1,
                                   longRunLevel: 0.0, volatility: 0.05)
        let dt = 1.0 / 12.0

        var rng = DeterministicRNG(seed: 99)
        var foundNegative = false

        for _ in 0..<5000 {
            var rate = 0.01
            for _ in 0..<12 {
                let (z, _): (Double, Double) = boxMullerSeed(using: &rng)
                rate = hw.step(from: rate, dt: dt, normalDraws: z)
                if rate < 0 {
                    foundNegative = true
                    break
                }
            }
            if foundNegative { break }
        }

        #expect(foundNegative, "With high vol and low starting rate, some paths should go negative")
    }
}

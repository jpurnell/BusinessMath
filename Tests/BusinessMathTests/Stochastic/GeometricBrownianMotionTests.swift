import Testing
@testable import BusinessMath

@Suite("GeometricBrownianMotion")
struct GeometricBrownianMotionTests {

    // MARK: - Golden Path

    @Test("Known step matches validation trace")
    func goldenPathStep() {
        // From proposal: S₀=72.50, μ=0.05, σ=0.25, dt=1/12, dW=0.5
        // S₁ = 72.50 · exp((0.05 - 0.25²/2)·(1/12) + 0.25·√(1/12)·0.5)
        // S₁ = 72.50 · exp(0.001563 + 0.03608) = 72.50 · exp(0.03764) = 75.28
        let gbm = GeometricBrownianMotion(name: "WTI", drift: 0.05, volatility: 0.25)
        let result = gbm.step(from: 72.50, dt: 1.0 / 12.0, normalDraws: 0.5)
        #expect(abs(result - 75.28) < 0.01)
    }

    @Test("Zero drift and zero vol returns current value")
    func zeroDriftZeroVol() {
        let gbm = GeometricBrownianMotion(name: "Flat", drift: 0.0, volatility: 0.0)
        let result = gbm.step(from: 100.0, dt: 1.0, normalDraws: 1.5)
        #expect(abs(result - 100.0) < 1e-10)
    }

    @Test("Name property returns assigned name")
    func nameProperty() {
        let gbm = GeometricBrownianMotion(name: "OilSpot", drift: 0.05, volatility: 0.25)
        #expect(gbm.name == "OilSpot")
    }

    @Test("Factors equals 1")
    func singleFactor() {
        let gbm = GeometricBrownianMotion(name: "Test", drift: 0.0, volatility: 0.0)
        #expect(gbm.factors == 1)
    }

    @Test("Does not allow negative values")
    func noNegativeValues() {
        let gbm = GeometricBrownianMotion(name: "Test", drift: 0.0, volatility: 0.0)
        #expect(gbm.allowsNegativeValues == false)
    }

    // MARK: - Edge Cases

    @Test("dt=0 returns current value")
    func zeroDt() {
        let gbm = GeometricBrownianMotion(name: "Test", drift: 0.05, volatility: 0.25)
        let result = gbm.step(from: 72.50, dt: 0.0, normalDraws: 0.5)
        #expect(abs(result - 72.50) < 1e-10)
    }

    @Test("dW=0 returns deterministic drift-only step")
    func zeroDW() {
        let gbm = GeometricBrownianMotion(name: "Test", drift: 0.10, volatility: 0.30)
        let result = gbm.step(from: 100.0, dt: 1.0, normalDraws: 0.0)
        // exp((0.10 - 0.30²/2) · 1.0) = exp(0.10 - 0.045) = exp(0.055) = 1.05654
        let expected = 100.0 * Double.exp(0.10 - 0.30 * 0.30 / 2.0)
        #expect(abs(result - expected) < 1e-6)
    }

    @Test("Very small starting value stays positive")
    func verySmallStartingValue() {
        let gbm = GeometricBrownianMotion(name: "Test", drift: 0.0, volatility: 0.5)
        let result = gbm.step(from: 1e-10, dt: 1.0 / 12.0, normalDraws: -2.0)
        #expect(result > 0)
    }

    @Test("Zero starting value returns zero")
    func zeroStartingValue() {
        let gbm = GeometricBrownianMotion(name: "Test", drift: 0.05, volatility: 0.25)
        let result = gbm.step(from: 0.0, dt: 1.0 / 12.0, normalDraws: 0.5)
        // GBM: 0 * exp(...) = 0 always
        #expect(result == 0.0)
    }

    // MARK: - Property-Based

    @Test("Output is always positive for positive input",
          arguments: [-3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0])
    func alwaysPositive(dW: Double) {
        let gbm = GeometricBrownianMotion(name: "Test", drift: 0.05, volatility: 1.0)
        let result = gbm.step(from: 50.0, dt: 1.0 / 12.0, normalDraws: dW)
        #expect(result > 0, "GBM must produce positive values for positive inputs, got \(result) for dW=\(dW)")
    }

    @Test("Larger volatility produces larger dispersion")
    func volatilityDispersion() {
        let lowVol = GeometricBrownianMotion(name: "Low", drift: 0.0, volatility: 0.10)
        let highVol = GeometricBrownianMotion(name: "High", drift: 0.0, volatility: 0.50)

        // With same positive dW, high vol should produce more upside
        let lowResult = lowVol.step(from: 100.0, dt: 1.0, normalDraws: 2.0)
        let highResult = highVol.step(from: 100.0, dt: 1.0, normalDraws: 2.0)

        #expect(highResult > lowResult, "Higher vol should produce larger move for positive dW")
    }

    // MARK: - Statistical (Deterministic Seed)

    @Test("Mean converges to analytical expectation over many steps")
    func meanConvergence() {
        let gbm = GeometricBrownianMotion(name: "Test", drift: 0.05, volatility: 0.25)
        let s0 = 100.0
        let dt = 1.0 / 12.0
        let steps = 12 // 1 year

        // Run 10,000 paths with deterministic RNG
        var rng = StochasticTestRNG(seed: 42)
        var finalValues: [Double] = []

        for _ in 0..<10_000 {
            var current = s0
            for _ in 0..<steps {
                let z = rng.nextNormal()
                current = gbm.step(from: current, dt: dt, normalDraws: z)
            }
            finalValues.append(current)
        }

        let mean = finalValues.reduce(0.0, +) / Double(finalValues.count)
        // E[S(T)] = S₀ · e^(μT) = 100 · e^(0.05) = 105.127
        let expected = s0 * Double.exp(0.05 * 1.0)
        #expect(abs(mean - expected) < 2.0,
                "Mean \(mean) should be near analytical \(expected)")
    }

    @Test("No path ever goes negative across 10,000 paths with high vol")
    func positivityGuarantee() {
        let gbm = GeometricBrownianMotion(name: "HighVol", drift: 0.0, volatility: 1.0)
        let dt = 1.0 / 252.0 // daily

        var rng = StochasticTestRNG(seed: 123)
        var minValue = Double.infinity

        for _ in 0..<10_000 {
            var current = 10.0 // Start small to stress positivity
            for _ in 0..<252 {
                let z = rng.nextNormal()
                current = gbm.step(from: current, dt: dt, normalDraws: z)
                minValue = min(minValue, current)
            }
        }

        #expect(minValue > 0, "GBM must never produce negative values, min was \(minValue)")
    }
}

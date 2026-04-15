import Testing
@testable import BusinessMath

@Suite("OrnsteinUhlenbeck")
struct OrnsteinUhlenbeckTests {

    // MARK: - Golden Path

    @Test("Properties are correct")
    func properties() {
        let ou = OrnsteinUhlenbeck(name: "OilSpread", speed: 0.5, longRunMean: 70.0, volatility: 5.0)
        #expect(ou.name == "OilSpread")
        #expect(ou.allowsNegativeValues == true)
        #expect(ou.factors == 1)
    }

    @Test("Known step produces expected value")
    func knownStep() {
        let ou = OrnsteinUhlenbeck(name: "Test", speed: 0.5, longRunMean: 70.0, volatility: 5.0)
        // Exact discretization:
        // X(t+dt) = X(t)·e^(-κdt) + θ·(1 - e^(-κdt)) + σ·√((1 - e^(-2κdt))/(2κ))·Z
        let x0 = 72.50
        let dt = 1.0 / 12.0
        let dW = 0.5
        let kappa = 0.5
        let theta = 70.0
        let sigma = 5.0

        let expKdt = Double.exp(-kappa * dt)
        let meanPart = x0 * expKdt + theta * (1.0 - expKdt)
        let volPart = sigma * ((1.0 - Double.exp(-2.0 * kappa * dt)) / (2.0 * kappa)).squareRoot()
        let expected = meanPart + volPart * dW

        let result = ou.step(from: x0, dt: dt, normalDraws: dW)
        #expect(abs(result - expected) < 1e-10)
    }

    // MARK: - Analytical Moments

    @Test("Expected value matches analytical formula",
          arguments: [0.5, 1.0, 5.0, 100.0])
    func expectedValueAnalytical(t: Double) {
        let ou = OrnsteinUhlenbeck(name: "Test", speed: 0.5, longRunMean: 70.0, volatility: 5.0)
        let x0 = 72.50
        // E[X(t)] = θ + (x₀ - θ)·e^(-κt)
        let expected = 70.0 + (x0 - 70.0) * Double.exp(-0.5 * t)
        let result = ou.expectedValue(from: x0, at: t)
        #expect(abs(result - expected) < 1e-10)
    }

    @Test("Expected value at t=0 equals starting value")
    func expectedValueAtZero() {
        let ou = OrnsteinUhlenbeck(name: "Test", speed: 0.5, longRunMean: 70.0, volatility: 5.0)
        let result = ou.expectedValue(from: 72.50, at: 0.0)
        #expect(abs(result - 72.50) < 1e-10)
    }

    @Test("Expected value at t=infinity equals long-run mean")
    func expectedValueAtInfinity() {
        let ou = OrnsteinUhlenbeck(name: "Test", speed: 0.5, longRunMean: 70.0, volatility: 5.0)
        let result = ou.expectedValue(from: 72.50, at: 1000.0)
        #expect(abs(result - 70.0) < 1e-6)
    }

    @Test("Variance matches analytical formula",
          arguments: [0.5, 1.0, 5.0])
    func varianceAnalytical(t: Double) {
        let ou = OrnsteinUhlenbeck(name: "Test", speed: 0.5, longRunMean: 70.0, volatility: 5.0)
        // Var[X(t)] = σ²/(2κ)·(1 - e^(-2κt))
        let expected = (5.0 * 5.0) / (2.0 * 0.5) * (1.0 - Double.exp(-2.0 * 0.5 * t))
        let result = ou.variance(at: t)
        #expect(abs(result - expected) < 1e-10)
    }

    @Test("Variance at t=0 equals zero")
    func varianceAtZero() {
        let ou = OrnsteinUhlenbeck(name: "Test", speed: 0.5, longRunMean: 70.0, volatility: 5.0)
        let result = ou.variance(at: 0.0)
        #expect(abs(result) < 1e-10)
    }

    @Test("Variance at t=infinity equals stationary variance")
    func stationaryVariance() {
        let ou = OrnsteinUhlenbeck(name: "Test", speed: 0.5, longRunMean: 70.0, volatility: 5.0)
        // σ²/(2κ) = 25/1 = 25
        let result = ou.variance(at: 1000.0)
        #expect(abs(result - 25.0) < 1e-4)
    }

    // From validation trace: E[X(1.0)] = 71.52, Var[X(1.0)] = 15.80
    @Test("Matches proposal validation trace")
    func validationTrace() {
        let ou = OrnsteinUhlenbeck(name: "Test", speed: 0.5, longRunMean: 70.0, volatility: 5.0)
        let expectedMean = ou.expectedValue(from: 72.50, at: 1.0)
        let expectedVar = ou.variance(at: 1.0)
        #expect(abs(expectedMean - 71.52) < 0.01)
        #expect(abs(expectedVar - 15.80) < 0.01)
    }

    // MARK: - Edge Cases

    @Test("Zero mean-reversion speed behaves like drift")
    func zeroSpeed() {
        let ou = OrnsteinUhlenbeck(name: "Test", speed: 0.0, longRunMean: 70.0, volatility: 5.0)
        let result = ou.step(from: 72.50, dt: 1.0 / 12.0, normalDraws: 0.0)
        // With κ=0 and dW=0, should return current (no drift, no diffusion in degenerate case)
        #expect(abs(result - 72.50) < 0.01)
    }

    @Test("Very large speed snaps toward mean")
    func largeSpeed() {
        let ou = OrnsteinUhlenbeck(name: "Test", speed: 100.0, longRunMean: 70.0, volatility: 5.0)
        let result = ou.step(from: 72.50, dt: 1.0, normalDraws: 0.0)
        // e^(-100) ≈ 0, so result ≈ θ = 70.0
        #expect(abs(result - 70.0) < 0.1)
    }

    @Test("Can produce negative values")
    func negativeValues() {
        let ou = OrnsteinUhlenbeck(name: "Test", speed: 0.1, longRunMean: 0.0, volatility: 20.0)
        // Large vol, mean at 0, should go negative with large negative dW
        let result = ou.step(from: 1.0, dt: 1.0, normalDraws: -3.0)
        #expect(result < 0, "OU with high vol and mean=0 should produce negative values")
    }

    // MARK: - Statistical

    @Test("Mean converges to long-run mean over many steps")
    func meanConvergence() {
        let ou = OrnsteinUhlenbeck(name: "Test", speed: 0.5, longRunMean: 70.0, volatility: 5.0)
        let dt = 1.0 / 12.0

        var rng = StochasticTestRNG(seed: 42)
        var finalValues: [Double] = []

        for _ in 0..<10_000 {
            var current = 100.0 // Start far from mean
            for _ in 0..<120 { // 10 years
                let z = rng.nextNormal()
                current = ou.step(from: current, dt: dt, normalDraws: z)
            }
            finalValues.append(current)
        }

        let mean = finalValues.reduce(0.0, +) / Double(finalValues.count)
        // After 10 years with κ=0.5, should have reverted close to θ=70
        #expect(abs(mean - 70.0) < 1.0,
                "Mean \(mean) should be near long-run mean 70.0 after 10 years")
    }
}


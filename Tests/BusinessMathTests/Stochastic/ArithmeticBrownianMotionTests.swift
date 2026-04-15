import Testing
@testable import BusinessMath

@Suite("ArithmeticBrownianMotion")
struct ArithmeticBrownianMotionTests {

    @Test("Properties are correct")
    func properties() {
        let abm = ArithmeticBrownianMotion(name: "WTI_Futures", drift: 0.5, volatility: 5.0)
        #expect(abm.name == "WTI_Futures")
        #expect(abm.allowsNegativeValues == true)
        #expect(abm.factors == 1)
    }

    @Test("Known step: S₀=72.50, μ=0.5, σ=5.0, dt=1/12, dW=0.5")
    func goldenPath() {
        let abm = ArithmeticBrownianMotion(name: "Test", drift: 0.5, volatility: 5.0)
        // S₁ = 72.50 + 0.5·(1/12) + 5.0·√(1/12)·0.5
        let dt = 1.0 / 12.0
        let expected = 72.50 + 0.5 * dt + 5.0 * dt.squareRoot() * 0.5
        let result = abm.step(from: 72.50, dt: dt, normalDraws: 0.5)
        #expect(abs(result - expected) < 1e-10)
    }

    @Test("dt=0 returns current value")
    func zeroDt() {
        let abm = ArithmeticBrownianMotion(name: "Test", drift: 1.0, volatility: 5.0)
        let result = abm.step(from: 72.50, dt: 0.0, normalDraws: 0.5)
        #expect(abs(result - 72.50) < 1e-10)
    }

    @Test("σ=0 returns deterministic drift")
    func zeroVol() {
        let abm = ArithmeticBrownianMotion(name: "Test", drift: 12.0, volatility: 0.0)
        let result = abm.step(from: 72.50, dt: 1.0, normalDraws: 3.0)
        // 72.50 + 12.0·1.0 + 0·√1·3 = 84.50
        #expect(abs(result - 84.50) < 1e-10)
    }

    @Test("Can produce negative values with high vol")
    func negativeValues() {
        let abm = ArithmeticBrownianMotion(name: "Test", drift: 0.0, volatility: 100.0)
        let result = abm.step(from: 10.0, dt: 1.0, normalDraws: -3.0)
        // 10 + 0 + 100·1·(-3) = 10 - 300 = -290
        #expect(result < 0)
    }

    @Test("Mean converges to S₀ + μ·T over many paths")
    func meanConvergence() {
        let abm = ArithmeticBrownianMotion(name: "Test", drift: 6.0, volatility: 10.0)
        let dt = 1.0 / 12.0

        var rng = StochasticTestRNG(seed: 99)
        var finalValues: [Double] = []

        for _ in 0..<10_000 {
            var current = 100.0
            for _ in 0..<12 {
                current = abm.step(from: current, dt: dt, normalDraws: rng.nextNormal())
            }
            finalValues.append(current)
        }

        let mean = finalValues.reduce(0.0, +) / Double(finalValues.count)
        // E[X(1)] = 100 + 6·1 = 106
        #expect(abs(mean - 106.0) < 1.0)
    }
}

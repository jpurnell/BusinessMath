import Testing
@testable import BusinessMath

@Suite("HestonProcess")
struct HestonProcessTests {

    // MARK: - Feller Condition

    @Test("Feller condition satisfied: 2*kappa*theta > xi^2")
    func fellerSatisfied() {
        let heston = HestonProcess(name: "SPX", drift: 0.05,
                                    meanReversionSpeed: 2.0, longRunVariance: 0.04,
                                    volOfVol: 0.3, correlation: -0.7)
        // 2 * 2.0 * 0.04 = 0.16 > 0.09 = 0.3^2
        #expect(heston.fellerConditionSatisfied == true)
    }

    @Test("Feller condition violated: 2*kappa*theta <= xi^2")
    func fellerViolated() {
        let heston = HestonProcess(name: "SPX", drift: 0.05,
                                    meanReversionSpeed: 0.5, longRunVariance: 0.04,
                                    volOfVol: 0.5, correlation: -0.7)
        // 2 * 0.5 * 0.04 = 0.04 < 0.25 = 0.5^2
        #expect(heston.fellerConditionSatisfied == false)
    }

    // MARK: - Step Function

    @Test("Price stays positive with typical parameters")
    func priceStaysPositive() {
        let heston = HestonProcess(name: "SPX", drift: 0.05,
                                    meanReversionSpeed: 2.0, longRunVariance: 0.04,
                                    volOfVol: 0.3, correlation: -0.7)
        let dt = 1.0 / 252.0

        var rng = StochasticTestRNG(seed: 42)
        var state = HestonState(price: 100.0, variance: 0.04)

        for _ in 0..<5000 {
            let z1 = rng.nextNormal()
            let z2 = rng.nextNormal()
            state = heston.step(from: state, dt: dt, normalDraw1: z1, normalDraw2: z2)
            #expect(state.price > 0, "Price should always be positive, got \(state.price)")
        }
    }

    @Test("Variance mean-reverts toward longRunVariance")
    func varianceMeanReverts() {
        let theta = 0.04
        let heston = HestonProcess(name: "SPX", drift: 0.05,
                                    meanReversionSpeed: 5.0, longRunVariance: theta,
                                    volOfVol: 0.2, correlation: -0.7)
        let dt = 1.0 / 252.0

        var rng = StochasticTestRNG(seed: 55)
        var finalVariances: [Double] = []

        for _ in 0..<3000 {
            var state = HestonState(price: 100.0, variance: 0.16) // Start 4x above theta
            for _ in 0..<504 { // ~2 years daily
                let z1 = rng.nextNormal()
                let z2 = rng.nextNormal()
                state = heston.step(from: state, dt: dt, normalDraw1: z1, normalDraw2: z2)
            }
            finalVariances.append(state.variance)
        }

        let meanVar = finalVariances.reduce(0.0, +) / Double(finalVariances.count)
        // With kappa=5 after 2 years, should be close to theta=0.04
        #expect(abs(meanVar - theta) < 0.02,
                "Mean variance \(meanVar) should be near long-run \(theta)")
    }

    @Test("Step function deterministic with fixed draws")
    func stepDeterministic() {
        let heston = HestonProcess(name: "Test", drift: 0.05,
                                    meanReversionSpeed: 2.0, longRunVariance: 0.04,
                                    volOfVol: 0.3, correlation: -0.7)
        let state = HestonState(price: 100.0, variance: 0.04)
        let dt = 1.0 / 252.0

        let result1 = heston.step(from: state, dt: dt, normalDraw1: 0.5, normalDraw2: -0.3)
        let result2 = heston.step(from: state, dt: dt, normalDraw1: 0.5, normalDraw2: -0.3)

        #expect(result1.price == result2.price, "Same draws should give same price")
        #expect(result1.variance == result2.variance, "Same draws should give same variance")
    }

    // MARK: - Analytical Pricing

    @Test("Vol smile: OTM options imply higher vol than ATM")
    func volSmile() {
        let heston = HestonProcess(name: "SPX", drift: 0.05,
                                    meanReversionSpeed: 2.0, longRunVariance: 0.04,
                                    volOfVol: 0.5, correlation: -0.7)
        let spot = 100.0
        let r = 0.05
        let tau = 1.0
        let v0 = 0.04

        let atmCall = heston.europeanCallPrice(spot: spot, strike: 100.0,
                                                riskFreeRate: r, timeToExpiry: tau,
                                                initialVariance: v0)
        let otmCall = heston.europeanCallPrice(spot: spot, strike: 120.0,
                                                riskFreeRate: r, timeToExpiry: tau,
                                                initialVariance: v0)
        let itmCall = heston.europeanCallPrice(spot: spot, strike: 80.0,
                                                riskFreeRate: r, timeToExpiry: tau,
                                                initialVariance: v0)

        // Basic sanity: ATM call should be more expensive than OTM call
        #expect(atmCall > otmCall, "ATM call \(atmCall) should be > OTM call \(otmCall)")
        // ITM call should be more expensive than ATM
        #expect(itmCall > atmCall, "ITM call \(itmCall) should be > ATM call \(atmCall)")
        // All should be positive
        #expect(atmCall > 0)
        #expect(otmCall > 0)
        #expect(itmCall > 0)
    }

    @Test("Put-call parity: call - put = S - K*exp(-r*T)")
    func putCallParity() {
        let heston = HestonProcess(name: "SPX", drift: 0.05,
                                    meanReversionSpeed: 2.0, longRunVariance: 0.04,
                                    volOfVol: 0.3, correlation: -0.7)
        let spot = 100.0
        let strike = 105.0
        let r = 0.05
        let tau = 1.0
        let v0 = 0.04

        let call = heston.europeanCallPrice(spot: spot, strike: strike,
                                             riskFreeRate: r, timeToExpiry: tau,
                                             initialVariance: v0)
        let put = heston.europeanPutPrice(spot: spot, strike: strike,
                                           riskFreeRate: r, timeToExpiry: tau,
                                           initialVariance: v0)

        let lhs = call - put
        let rhs = spot - strike * Double.exp(-r * tau)

        #expect(abs(lhs - rhs) < 0.5,
                "Put-call parity violation: C-P=\(lhs), S-Ke^(-rT)=\(rhs)")
    }

    @Test("Zero vol-of-vol reduces to Black-Scholes within tolerance")
    func zeroVolOfVolReducesToBS() {
        // With xi=0, Heston reduces to constant-vol GBM => Black-Scholes
        let sigma2 = 0.04 // v0 = theta = 0.04, so sigma = 0.2
        let sigma = sigma2.squareRoot()
        let heston = HestonProcess(name: "Test", drift: 0.05,
                                    meanReversionSpeed: 2.0, longRunVariance: sigma2,
                                    volOfVol: 0.0, correlation: 0.0)
        let spot = 100.0
        let strike = 100.0
        let r = 0.05
        let tau = 1.0

        let hestonCall = heston.europeanCallPrice(spot: spot, strike: strike,
                                                   riskFreeRate: r, timeToExpiry: tau,
                                                   initialVariance: sigma2)

        // Black-Scholes analytical price
        let bsCall = blackScholesCall(spot: spot, strike: strike, rate: r,
                                       vol: sigma, time: tau)

        #expect(abs(hestonCall - bsCall) < 0.5,
                "Heston with xi=0 (\(hestonCall)) should match BS (\(bsCall))")
    }

    // MARK: - Black-Scholes Helper

    /// Black-Scholes European call price for comparison.
    private func blackScholesCall(spot: Double, strike: Double, rate: Double,
                                   vol: Double, time: Double) -> Double {
        let d1 = (Double.log(spot / strike) + (rate + vol * vol / 2.0) * time) / (vol * time.squareRoot())
        let d2 = d1 - vol * time.squareRoot()
        return spot * cumulativeNormal(d1) - strike * Double.exp(-rate * time) * cumulativeNormal(d2)
    }

    /// Cumulative standard normal distribution (Abramowitz & Stegun 26.2.17).
    private func cumulativeNormal(_ x: Double) -> Double {
        if x < -10.0 { return 0.0 }
        if x > 10.0 { return 1.0 }

        // For negative x, use symmetry: N(x) = 1 - N(-x)
        if x < 0 { return 1.0 - cumulativeNormal(-x) }

        let a1 = 0.254829592
        let a2 = -0.284496736
        let a3 = 1.421413741
        let a4 = -1.453152027
        let a5 = 1.061405429
        let p = 0.3275911

        let t = 1.0 / (1.0 + p * x)
        let t2 = t * t
        let t3 = t2 * t
        let t4 = t3 * t
        let t5 = t4 * t
        let normalPdf = Double.exp(-x * x / 2.0) / (2.0 * Double.pi).squareRoot()
        // 1 - N(x) ≈ n(x) · (a1·t + a2·t² + a3·t³ + a4·t⁴ + a5·t⁵)
        let tail = normalPdf * (a1 * t + a2 * t2 + a3 * t3 + a4 * t4 + a5 * t5)
        return 1.0 - tail
    }
}

//
//  MonteCarloEngineTests.swift
//  BusinessMathTests
//
//  Tests for the generic MonteCarloEngine pricing engine.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Monte Carlo Engine Tests")
struct MonteCarloEngineTests {

    // MARK: - Test 1: GBM + European Call vs Black-Scholes

    /// Verify that MC call price matches Black-Scholes analytical within 2 standard errors.
    @Test func gBMEuropeanCallVsBlackScholes() {
        let spot = 100.0
        let strike = 105.0
        let r = 0.05
        let vol = 0.20
        let T = 1.0

        let gbm = GeometricBrownianMotion(name: "Test", drift: r, volatility: vol)
        let call = EuropeanPayoff(strike: strike, optionType: .call)

        let result = MonteCarloEngine.price(
            process: gbm,
            payoff: call,
            spot: spot,
            riskFreeRate: r,
            timeToExpiry: T,
            steps: 252,
            paths: 5000,
            seed: 42
        )

        let bsPrice = BlackScholesModel<Double>.price(
            optionType: .call,
            spotPrice: spot,
            strikePrice: strike,
            timeToExpiry: T,
            riskFreeRate: r,
            volatility: vol
        )

        let tolerance = 2.0 * result.standardError
        #expect(abs((result.price) - (bsPrice)) <= (tolerance),
                "MC call price \(result.price) should be within 2 SE (\(tolerance)) of BS price \(bsPrice)")
    }

    // MARK: - Test 2: GBM + European Put vs Black-Scholes

    /// Verify that MC put price matches Black-Scholes analytical within 2 standard errors.
    @Test func gBMEuropeanPutVsBlackScholes() {
        let spot = 100.0
        let strike = 95.0
        let r = 0.05
        let vol = 0.20
        let T = 1.0

        let gbm = GeometricBrownianMotion(name: "Test", drift: r, volatility: vol)
        let put = EuropeanPayoff(strike: strike, optionType: .put)

        let result = MonteCarloEngine.price(
            process: gbm,
            payoff: put,
            spot: spot,
            riskFreeRate: r,
            timeToExpiry: T,
            steps: 252,
            paths: 5000,
            seed: 99
        )

        let bsPrice = BlackScholesModel<Double>.price(
            optionType: .put,
            spotPrice: spot,
            strikePrice: strike,
            timeToExpiry: T,
            riskFreeRate: r,
            volatility: vol
        )

        let tolerance = 2.0 * result.standardError
        #expect(abs((result.price) - (bsPrice)) <= (tolerance),
                "MC put price \(result.price) should be within 2 SE (\(tolerance)) of BS price \(bsPrice)")
    }

    // MARK: - Test 3: The Antithetic Standard Error Is the Spread of Pair Means

    /// A payoff linear in the underlying makes every antithetic pair mean to the same
    /// constant, so the reported standard error must collapse to rounding noise.
    ///
    /// ``ArithmeticBrownianMotion/step(from:dt:normalDraws:)`` is `S + mu*dt + sigma*sqrt(dt)*Z`,
    /// linear in the draw, and `EuropeanPayoff(strike: 0, optionType: .call)` is
    /// `max(S - 0, 0)`, the identity on positive spots. A pair's two terminal values are
    /// therefore `spot + mu*T + sigma*sqrt(dt)*sum(Z)` and `spot + mu*T - sigma*sqrt(dt)*sum(Z)`,
    /// and their mean is `spot + mu*T` for every pair, whatever the draws. The variance of
    /// the pair means is exactly zero in real arithmetic.
    ///
    /// The bound is the rounding, derived rather than tuned. A pair mean can miss the
    /// constant only by the roundings of `steps` additions at the scale of `spot`: one ulp
    /// of 128 is 1.4e-14, and a few hundred of them is under 1e-11. The standard error
    /// divides that spread by `sqrt(pairs)` again, so 1e-9 is a ceiling with room, not a
    /// fitted tolerance.
    ///
    /// Pooling the 2N paths as independent observations reports the spread of the
    /// individual paths instead — about `exp(-r*T) * sigma * sqrt(T) / sqrt(2N)`, near
    /// 0.043 here, seven orders of magnitude above the truth.
    @Test func antitheticStandardErrorIsTheSpreadOfPairMeans() {
        let spot = 100.0
        let drift = 3.0
        let vol = 2.0
        let r = 0.05
        let T = 1.0

        let abm = ArithmeticBrownianMotion(name: "Linear", drift: drift, volatility: vol)
        let identity = EuropeanPayoff(strike: 0.0, optionType: .call)

        let result = MonteCarloEngine.price(
            process: abm, payoff: identity,
            spot: spot, riskFreeRate: r,
            timeToExpiry: T, steps: 20, paths: 2_000, seed: 7,
            antithetic: true
        )

        #expect(result.standardError < 1e-9,
                "Every antithetic pair means to the same constant, so the standard error is rounding; got \(result.standardError)")
    }

    /// The same linear construction pins the price itself: the antithetic estimate is the
    /// discounted constant, with no sampling error left in it at all.
    ///
    /// This is what makes the standard error above meaningful rather than merely small —
    /// the estimator is not small because it is broken, it is small because every pair
    /// lands on the same answer.
    @Test func antitheticPriceOfALinearPayoffIsExact() {
        let spot = 100.0
        let drift = 3.0
        let r = 0.05
        let T = 1.0

        let abm = ArithmeticBrownianMotion(name: "Linear", drift: drift, volatility: 2.0)
        let identity = EuropeanPayoff(strike: 0.0, optionType: .call)

        let result = MonteCarloEngine.price(
            process: abm, payoff: identity,
            spot: spot, riskFreeRate: r,
            timeToExpiry: T, steps: 20, paths: 2_000, seed: 7,
            antithetic: true
        )

        let discount: Double = Double.exp(-r * T)
        let terminal: Double = spot + drift * T
        let expected: Double = discount * terminal
        let gap: Double = abs(result.price - expected)

        #expect(gap < 1e-9,
                "Linear payoff, antithetic: price \(result.price) should be the discounted constant \(expected), off by \(gap)")
    }

    /// The reported standard error must predict how far the price actually moves when the
    /// seed changes — for antithetic runs as much as for plain ones.
    ///
    /// ``MonteCarloPricingResult`` documents `price +/- 2 * standardError` at 95%
    /// confidence, which is a claim about the spread of the estimator across independent
    /// runs. So this measures that spread directly: 200 fixed seeds, and the ratio of the
    /// mean reported standard error to the realised standard deviation of the 200 prices.
    /// Honest reporting puts the ratio at 1.
    ///
    /// The band is the sampling error of a variance estimate, derived rather than tuned:
    /// from 200 samples the realised standard deviation carries a relative error of
    /// `1/sqrt(2*199)` = 5.0%, so the 15% band is three of those. Pooling 2N negatively
    /// correlated paths as independent observations puts the antithetic ratio near 1.40,
    /// eight standard errors out — the 40% overstatement this test exists to catch. The
    /// seeds are fixed, so the measurement is deterministic: this test cannot flake.
    @Test func reportedStandardErrorMatchesRealisedSpread() {
        let gbm = GeometricBrownianMotion(name: "Test", drift: 0.05, volatility: 0.25)
        let call = EuropeanPayoff(strike: 100.0, optionType: .call)
        let seedCount = 200

        func measure(antithetic: Bool) -> (realised: Double, claimed: Double) {
            var prices = [Double]()
            var reported = [Double]()
            prices.reserveCapacity(seedCount)
            reported.reserveCapacity(seedCount)

            for seed in 1...seedCount {
                let result = MonteCarloEngine.price(
                    process: gbm, payoff: call,
                    spot: 100.0, riskFreeRate: 0.05,
                    timeToExpiry: 1.0, steps: 20, paths: 800, seed: UInt64(seed),
                    antithetic: antithetic
                )
                prices.append(result.price)
                reported.append(result.standardError)
            }

            let realised: Double = stdDev(prices)
            let claimed: Double = mean(reported)
            return (realised, claimed)
        }

        let plain = measure(antithetic: false)
        let anti = measure(antithetic: true)

        let plainHonesty: Double = plain.claimed / plain.realised
        let plainInBand: Bool = plainHonesty > 0.85 && plainHonesty < 1.15
        #expect(plainInBand,
                "plain: reported SE \(plain.claimed) against realised spread \(plain.realised) is a ratio of \(plainHonesty), outside the 15% band")

        let antiHonesty: Double = anti.claimed / anti.realised
        let antiInBand: Bool = antiHonesty > 0.85 && antiHonesty < 1.15
        #expect(antiInBand,
                "antithetic: reported SE \(anti.claimed) against realised spread \(anti.realised) is a ratio of \(antiHonesty), outside the 15% band")

        // The variance reduction is real — the antithetic prices genuinely cluster more
        // tightly — so an honest standard error has to be visibly smaller. The old
        // estimator reported no reduction at all: over these same seeds it put the two
        // within 0.1% of each other, and which one came out ahead was a coin flip.
        let realisedReduction: Double = anti.realised / plain.realised
        let reportedReduction: Double = anti.claimed / plain.claimed
        #expect(realisedReduction < 0.9,
                "Antithetic prices should cluster more tightly; realised ratio was \(realisedReduction)")
        #expect(reportedReduction < 0.9,
                "The reported standard error should show the reduction; reported ratio was \(reportedReduction) against a realised \(realisedReduction)")
    }

    /// Antithetic sampling below one pair has no meaning, and must not produce a NaN price.
    ///
    /// `paths / 2` is zero when `paths` is 1, so the loop ran zero times, `effectivePaths`
    /// was zero and the mean divided 0.0 by 0.0. One pair is the floor; `pathCount` reports
    /// the two paths honestly rather than the one that was asked for.
    @Test func singlePathAntitheticSimulatesOnePair() {
        let gbm = GeometricBrownianMotion(name: "Test", drift: 0.05, volatility: 0.20)
        let call = EuropeanPayoff(strike: 100.0, optionType: .call)

        let result = MonteCarloEngine.price(
            process: gbm, payoff: call,
            spot: 100.0, riskFreeRate: 0.05,
            timeToExpiry: 1.0, steps: 10, paths: 1, seed: 42,
            antithetic: true
        )

        // One of an antithetic pair always finishes above spot*exp((mu - sigma^2/2)*T) = 103,
        // which is in the money against a strike of 100, so the price is strictly positive.
        #expect(result.price > 0.0,
                "A single-path antithetic request priced at \(result.price)")
        #expect(result.pathCount == 2)
    }

    // MARK: - Test 4: Deterministic — Same Seed = Same Price

    /// Running with the same seed must produce identical results.
    @Test func deterministicSameSeed() {
        let gbm = GeometricBrownianMotion(name: "Test", drift: 0.05, volatility: 0.20)
        let call = EuropeanPayoff(strike: 100.0, optionType: .call)

        let result1 = MonteCarloEngine.price(
            process: gbm, payoff: call,
            spot: 100.0, riskFreeRate: 0.05,
            timeToExpiry: 1.0, steps: 50, paths: 1000, seed: 123
        )

        let result2 = MonteCarloEngine.price(
            process: gbm, payoff: call,
            spot: 100.0, riskFreeRate: 0.05,
            timeToExpiry: 1.0, steps: 50, paths: 1000, seed: 123
        )

        #expect(result1.price == result2.price,
                "Same seed must produce identical prices")
        #expect(result1.standardError == result2.standardError,
                "Same seed must produce identical standard errors")
    }

    // MARK: - Test 5: Different Seeds = Different Prices

    /// Different seeds should (with overwhelming probability) produce different prices.
    @Test func differentSeedsDifferentPrices() {
        let gbm = GeometricBrownianMotion(name: "Test", drift: 0.05, volatility: 0.20)
        let call = EuropeanPayoff(strike: 100.0, optionType: .call)

        let result1 = MonteCarloEngine.price(
            process: gbm, payoff: call,
            spot: 100.0, riskFreeRate: 0.05,
            timeToExpiry: 1.0, steps: 50, paths: 1000, seed: 42
        )

        let result2 = MonteCarloEngine.price(
            process: gbm, payoff: call,
            spot: 100.0, riskFreeRate: 0.05,
            timeToExpiry: 1.0, steps: 50, paths: 1000, seed: 999
        )

        #expect((result1.price) != (result2.price),
                "Different seeds should produce different prices")
    }

    // MARK: - Test 6: Path Count Matches Request

    /// The result's pathCount should match the requested number of paths.
    @Test func pathCountMatchesRequest() {
        let gbm = GeometricBrownianMotion(name: "Test", drift: 0.05, volatility: 0.20)
        let call = EuropeanPayoff(strike: 100.0, optionType: .call)

        let plainResult = MonteCarloEngine.price(
            process: gbm, payoff: call,
            spot: 100.0, riskFreeRate: 0.05,
            timeToExpiry: 1.0, steps: 10, paths: 500, seed: 42,
            antithetic: false
        )
        #expect(plainResult.pathCount == 500)

        // Antithetic with even path count: N/2 pairs * 2 = N
        let antitheticResult = MonteCarloEngine.price(
            process: gbm, payoff: call,
            spot: 100.0, riskFreeRate: 0.05,
            timeToExpiry: 1.0, steps: 10, paths: 500, seed: 42,
            antithetic: true
        )
        #expect(antitheticResult.pathCount == 500)
        #expect(antitheticResult.antithetic)
    }

    // MARK: - Test 7: Asian Payoff — Positive Price for ITM

    /// An Asian call with ITM parameters should produce a positive price.
    @Test func asianPayoffPositiveForITM() {
        let spot = 110.0
        let strike = 100.0
        let r = 0.05
        let vol = 0.20
        let T = 1.0

        let gbm = GeometricBrownianMotion(name: "Test", drift: r, volatility: vol)
        let asian = AsianPayoff(strike: strike, optionType: .call)

        let result = MonteCarloEngine.price(
            process: gbm,
            payoff: asian,
            spot: spot,
            riskFreeRate: r,
            timeToExpiry: T,
            steps: 100,
            paths: 3000,
            seed: 42
        )

        #expect(result.price > 0.0,
                "ITM Asian call should have a positive price, got \(result.price)")
    }

    // MARK: - Test 8: Barrier Knock-Out Price < Vanilla

    /// A down-and-out barrier call should be cheaper than (or equal to) the vanilla call.
    @Test func barrierKnockOutCheaperThanVanilla() {
        let spot = 100.0
        let strike = 100.0
        let r = 0.05
        let vol = 0.25
        let T = 1.0

        let gbm = GeometricBrownianMotion(name: "Test", drift: r, volatility: vol)
        let vanilla = EuropeanPayoff(strike: strike, optionType: .call)
        let barrier = BarrierPayoff(
            strike: strike,
            barrier: 80.0,
            barrierType: .downAndOut,
            optionType: .call
        )

        let vanillaResult = MonteCarloEngine.price(
            process: gbm, payoff: vanilla,
            spot: spot, riskFreeRate: r,
            timeToExpiry: T, steps: 252, paths: 5000, seed: 42
        )

        let barrierResult = MonteCarloEngine.price(
            process: gbm, payoff: barrier,
            spot: spot, riskFreeRate: r,
            timeToExpiry: T, steps: 252, paths: 5000, seed: 42
        )

        #expect(barrierResult.price <= vanillaResult.price,
                "Barrier knock-out (\(barrierResult.price)) should be <= vanilla (\(vanillaResult.price))")
    }

    // MARK: - Test 9: Convergence — More Paths = Lower SE

    /// Standard error should decrease when path count increases.
    @Test func convergenceMorePathsLowerSE() {
        let gbm = GeometricBrownianMotion(name: "Test", drift: 0.05, volatility: 0.20)
        let call = EuropeanPayoff(strike: 100.0, optionType: .call)

        let fewPaths = MonteCarloEngine.price(
            process: gbm, payoff: call,
            spot: 100.0, riskFreeRate: 0.05,
            timeToExpiry: 1.0, steps: 50, paths: 500, seed: 42
        )

        let manyPaths = MonteCarloEngine.price(
            process: gbm, payoff: call,
            spot: 100.0, riskFreeRate: 0.05,
            timeToExpiry: 1.0, steps: 50, paths: 5000, seed: 42
        )

        #expect(manyPaths.standardError < fewPaths.standardError,
                "More paths (\(manyPaths.standardError)) should have lower SE than fewer paths (\(fewPaths.standardError))")
    }

    // MARK: - Test 10: Zero Vol — Price Equals Discounted Intrinsic

    /// With zero volatility, the MC price should equal the discounted intrinsic value exactly.
    @Test func zeroVolEqualsDiscountedIntrinsic() {
        let spot = 100.0
        let strike = 95.0
        let r = 0.05
        let T = 1.0

        let gbm = GeometricBrownianMotion(name: "Test", drift: r, volatility: 0.0)
        let call = EuropeanPayoff(strike: strike, optionType: .call)

        let result = MonteCarloEngine.price(
            process: gbm, payoff: call,
            spot: spot, riskFreeRate: r,
            timeToExpiry: T, steps: 50, paths: 100, seed: 42
        )

        // With zero vol, the stock grows deterministically: S(T) = S0 * exp(r * T)
        // But GBM step uses drift - vol^2/2, so with vol=0: S(T) = S0 * exp(r * T)
        let terminalSpot = spot * Double.exp(r * T)
        let intrinsic = max(terminalSpot - strike, 0.0)
        let discountedIntrinsic = intrinsic * Double.exp(-r * T)

        #expect(abs((result.price) - (discountedIntrinsic)) <= (1e-10),
                "Zero vol MC price \(result.price) should equal discounted intrinsic \(discountedIntrinsic)")
        #expect(abs((result.standardError) - (0.0)) <= (1e-6),
                "Zero vol should have near-zero standard error")
    }
}

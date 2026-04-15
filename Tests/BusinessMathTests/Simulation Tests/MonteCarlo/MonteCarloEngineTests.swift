//
//  MonteCarloEngineTests.swift
//  BusinessMathTests
//
//  Tests for the generic MonteCarloEngine pricing engine.
//

import XCTest
@testable import BusinessMath

final class MonteCarloEngineTests: XCTestCase {

    // MARK: - Test 1: GBM + European Call vs Black-Scholes

    /// Verify that MC call price matches Black-Scholes analytical within 2 standard errors.
    func testGBMEuropeanCallVsBlackScholes() {
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
        XCTAssertEqual(result.price, bsPrice, accuracy: tolerance,
                       "MC call price \(result.price) should be within 2 SE (\(tolerance)) of BS price \(bsPrice)")
    }

    // MARK: - Test 2: GBM + European Put vs Black-Scholes

    /// Verify that MC put price matches Black-Scholes analytical within 2 standard errors.
    func testGBMEuropeanPutVsBlackScholes() {
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
        XCTAssertEqual(result.price, bsPrice, accuracy: tolerance,
                       "MC put price \(result.price) should be within 2 SE (\(tolerance)) of BS price \(bsPrice)")
    }

    // MARK: - Test 3: Antithetic Reduces Standard Error

    /// Antithetic variates should produce a lower standard error than plain MC for the same path count.
    func testAntitheticReducesStandardError() {
        let spot = 100.0
        let strike = 100.0
        let r = 0.05
        let vol = 0.25
        let T = 1.0

        let gbm = GeometricBrownianMotion(name: "Test", drift: r, volatility: vol)
        let call = EuropeanPayoff(strike: strike, optionType: .call)

        let plainResult = MonteCarloEngine.price(
            process: gbm,
            payoff: call,
            spot: spot,
            riskFreeRate: r,
            timeToExpiry: T,
            steps: 100,
            paths: 4000,
            seed: 42,
            antithetic: false
        )

        let antitheticResult = MonteCarloEngine.price(
            process: gbm,
            payoff: call,
            spot: spot,
            riskFreeRate: r,
            timeToExpiry: T,
            steps: 100,
            paths: 4000,
            seed: 42,
            antithetic: true
        )

        XCTAssertLessThan(antitheticResult.standardError, plainResult.standardError,
                          "Antithetic SE (\(antitheticResult.standardError)) should be less than plain SE (\(plainResult.standardError))")
    }

    // MARK: - Test 4: Deterministic — Same Seed = Same Price

    /// Running with the same seed must produce identical results.
    func testDeterministicSameSeed() {
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

        XCTAssertEqual(result1.price, result2.price,
                       "Same seed must produce identical prices")
        XCTAssertEqual(result1.standardError, result2.standardError,
                       "Same seed must produce identical standard errors")
    }

    // MARK: - Test 5: Different Seeds = Different Prices

    /// Different seeds should (with overwhelming probability) produce different prices.
    func testDifferentSeedsDifferentPrices() {
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

        XCTAssertNotEqual(result1.price, result2.price,
                          "Different seeds should produce different prices")
    }

    // MARK: - Test 6: Path Count Matches Request

    /// The result's pathCount should match the requested number of paths.
    func testPathCountMatchesRequest() {
        let gbm = GeometricBrownianMotion(name: "Test", drift: 0.05, volatility: 0.20)
        let call = EuropeanPayoff(strike: 100.0, optionType: .call)

        let plainResult = MonteCarloEngine.price(
            process: gbm, payoff: call,
            spot: 100.0, riskFreeRate: 0.05,
            timeToExpiry: 1.0, steps: 10, paths: 500, seed: 42,
            antithetic: false
        )
        XCTAssertEqual(plainResult.pathCount, 500)

        // Antithetic with even path count: N/2 pairs * 2 = N
        let antitheticResult = MonteCarloEngine.price(
            process: gbm, payoff: call,
            spot: 100.0, riskFreeRate: 0.05,
            timeToExpiry: 1.0, steps: 10, paths: 500, seed: 42,
            antithetic: true
        )
        XCTAssertEqual(antitheticResult.pathCount, 500)
        XCTAssertTrue(antitheticResult.antithetic)
    }

    // MARK: - Test 7: Asian Payoff — Positive Price for ITM

    /// An Asian call with ITM parameters should produce a positive price.
    func testAsianPayoffPositiveForITM() {
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

        XCTAssertGreaterThan(result.price, 0.0,
                             "ITM Asian call should have a positive price, got \(result.price)")
    }

    // MARK: - Test 8: Barrier Knock-Out Price < Vanilla

    /// A down-and-out barrier call should be cheaper than (or equal to) the vanilla call.
    func testBarrierKnockOutCheaperThanVanilla() {
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

        XCTAssertLessThanOrEqual(barrierResult.price, vanillaResult.price,
                                 "Barrier knock-out (\(barrierResult.price)) should be <= vanilla (\(vanillaResult.price))")
    }

    // MARK: - Test 9: Convergence — More Paths = Lower SE

    /// Standard error should decrease when path count increases.
    func testConvergenceMorePathsLowerSE() {
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

        XCTAssertLessThan(manyPaths.standardError, fewPaths.standardError,
                          "More paths (\(manyPaths.standardError)) should have lower SE than fewer paths (\(fewPaths.standardError))")
    }

    // MARK: - Test 10: Zero Vol — Price Equals Discounted Intrinsic

    /// With zero volatility, the MC price should equal the discounted intrinsic value exactly.
    func testZeroVolEqualsDiscountedIntrinsic() {
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

        XCTAssertEqual(result.price, discountedIntrinsic, accuracy: 1e-10,
                       "Zero vol MC price \(result.price) should equal discounted intrinsic \(discountedIntrinsic)")
        XCTAssertEqual(result.standardError, 0.0, accuracy: 1e-6,
                       "Zero vol should have near-zero standard error")
    }
}

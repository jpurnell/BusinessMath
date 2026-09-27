//
//  RisklessOptimizationTests.swift
//  BusinessMathTests
//
//  `maximumSharpePortfolio` minimises a negative-Sharpe objective, and that objective used to
//  bail out on a near-zero volatility with a flat penalty:
//
//      if volatility < 1e-10 { return 1e10 }
//
//  `1e10` is the *worst* value for a minimiser, so a riskless portfolio beating the risk-free
//  rate — the best portfolio available — was declared the worst. And because the penalty is a
//  constant, the objective went flat: with nothing to descend, the search returned its own
//  starting point and reported `converged: true`.
//
//  Measured on a zero-covariance pair returning 10% and 8% against a 2% risk-free rate, whose
//  optimum is plainly 100% of the 10% asset:
//
//  | weights before | weights after          |
//  |----------------|------------------------|
//  | [0.5, 0.5]     | [0.99999989, 6.39e-08] |
//
//  Ranking by excess return at the same 1e10 scale — what dividing by the 1e-10 floor gives —
//  restores both the sense and the gradient. The risky path is untouched: the guard never
//  fires there, and the two controls below were bit-identical before and after the change.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Optimising a portfolio with no risk")
struct RisklessOptimizationTests {

    private let riskless: [[Double]] = [[0, 0], [0, 0]]

    /// The fixture has to actually be riskless, or nothing below is about the guard.
    @Test("Fixture_ReallyHasNoVolatility")
    func fixtureReallyHasNoVolatility() throws {
        let portfolio = try PortfolioOptimizer().maximumSharpePortfolio(
            expectedReturns: VectorN([0.10, 0.08]), covariance: riskless, riskFreeRate: 0.02)
        #expect(portfolio.volatility.isEqual(to: 0.0))
    }

    /// With no risk anywhere, the best portfolio is simply the highest return. The search used
    /// to return its [0.5, 0.5] starting point instead.
    @Test("Riskless_AllocatesToTheHigherReturningAsset")
    func risklessAllocatesToTheHigherReturningAsset() throws {
        let portfolio = try PortfolioOptimizer().maximumSharpePortfolio(
            expectedReturns: VectorN([0.10, 0.08]), covariance: riskless, riskFreeRate: 0.02)
        let weights = portfolio.weights.toArray()
        #expect(weights[0] > 0.999, "weights were \(weights)")
        #expect(weights[1] < 0.001)
    }

    /// The consequence in the units a caller cares about: the portfolio earns the better
    /// asset's 10%, not the 9% average of an unoptimised half-and-half split.
    @Test("Riskless_EarnsTheBestAvailableReturn")
    func risklessEarnsTheBestAvailableReturn() throws {
        let portfolio = try PortfolioOptimizer().maximumSharpePortfolio(
            expectedReturns: VectorN([0.10, 0.08]), covariance: riskless, riskFreeRate: 0.02)
        #expect(abs(portfolio.expectedReturn - 0.10) < 1e-6,
                "got \(portfolio.expectedReturn); the old flat penalty left it at 0.09")
    }

    /// Control: a two-asset risky problem. Measured bit-identical across the change; asserted
    /// to 1e-12 so it cannot flake on a different architecture.
    @Test("RiskyTwoAsset_Unchanged")
    func riskyTwoAssetUnchanged() throws {
        let portfolio = try PortfolioOptimizer().maximumSharpePortfolio(
            expectedReturns: VectorN([0.10, 0.08]),
            covariance: [[0.04, 0.01], [0.01, 0.09]],
            riskFreeRate: 0.02
        )
        let weights = portfolio.weights.toArray()
        #expect(abs(weights[0] - 0.8048781703795808) < 1e-12, "got \(weights)")
        #expect(abs(weights[1] - 0.19512179072993066) < 1e-12)
        #expect(portfolio.sharpeRatio.isEqual(to: 0.4222389260135855))
        #expect(portfolio.iterations == 6, "and it still takes the same number of steps")
    }

    /// Control: three assets, to exercise a path the two-asset case cannot.
    @Test("RiskyThreeAsset_Unchanged")
    func riskyThreeAssetUnchanged() throws {
        let covariance: [[Double]] = [
            [0.04, 0.01, 0.00],
            [0.01, 0.09, 0.02],
            [0.00, 0.02, 0.0625],
        ]
        let portfolio = try PortfolioOptimizer().maximumSharpePortfolio(
            expectedReturns: VectorN([0.12, 0.10, 0.07]),
            covariance: covariance,
            riskFreeRate: 0.03
        )
        let weights = portfolio.weights.toArray()
        #expect(abs(weights[0] - 0.6971521891187674) < 1e-12, "got \(weights)")
        #expect(abs(weights[1] - 0.13918982018065296) < 1e-12)
        #expect(abs(weights[2] - 0.1636579798832817) < 1e-12)
        #expect(portfolio.sharpeRatio.isEqual(to: 0.4928965175805628))
        #expect(portfolio.iterations == 6)
    }
}

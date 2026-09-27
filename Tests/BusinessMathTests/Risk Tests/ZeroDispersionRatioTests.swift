//
//  ZeroDispersionRatioTests.swift
//  BusinessMathTests
//
//  Every risk-adjusted ratio here is `excess return / risk`, and each one returned **0** when
//  the risk was zero. Zero is not a neutral fallback for a ratio that gets ranked — it is a
//  mediocre score, sitting squarely in the middle of any ordering.
//
//  Measured before the fix, with a zero-covariance (riskless) two-asset portfolio and a 2%
//  risk-free rate:
//
//  | portfolio    | excess return      | reported Sharpe |
//  |--------------|--------------------|-----------------|
//  | returns 9%   | +7%, guaranteed    | 0.0             |
//  | returns 0.75%| -1.25%, guaranteed | 0.0             |
//
//  The best conceivable portfolio and a guaranteed shortfall received the identical score.
//  `PortfolioOptimizer.efficientFrontier` then picks its answer with
//  `max(by: { $0.sharpeRatio < $1.sharpeRatio })`, so a riskless arbitrage on the frontier
//  lost to any mediocre risky portfolio.
//
//  A riskless portfolio's Sharpe ratio is unbounded in the sign of its excess return, which
//  is what is now reported.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Risk-adjusted ratios when the risk is zero")
struct ZeroDispersionRatioTests {

    private let riskless: [[Double]] = [[0, 0], [0, 0]]

    // MARK: - PortfolioOptimizer

    /// A guaranteed 7% over the risk-free rate, with no risk at all.
    @Test("Portfolio_RisklessGain_IsUnboundedlyAttractive")
    func portfolioRisklessGainIsUnboundedlyAttractive() throws {
        let portfolio = try PortfolioOptimizer().maximumSharpePortfolio(
            expectedReturns: VectorN([0.10, 0.08]),
            covariance: riskless,
            riskFreeRate: 0.02
        )
        #expect(portfolio.volatility.isEqual(to: 0.0), "the fixture really is riskless")
        #expect(portfolio.sharpeRatio.isEqual(to: .infinity))
    }

    /// The mirror: a guaranteed shortfall against the risk-free rate.
    @Test("Portfolio_RisklessLoss_IsUnboundedlyUnattractive")
    func portfolioRisklessLossIsUnboundedlyUnattractive() throws {
        let portfolio = try PortfolioOptimizer().maximumSharpePortfolio(
            expectedReturns: VectorN([0.01, 0.005]),
            covariance: riskless,
            riskFreeRate: 0.02
        )
        #expect(portfolio.sharpeRatio.isEqual(to: -.infinity))
    }

    /// The property that actually broke: these two were indistinguishable.
    @Test("Portfolio_GainAndLoss_AreOrdered")
    func portfolioGainAndLossAreOrdered() throws {
        let optimizer = PortfolioOptimizer()
        let winner = try optimizer.maximumSharpePortfolio(
            expectedReturns: VectorN([0.10, 0.08]), covariance: riskless, riskFreeRate: 0.02)
        let loser = try optimizer.maximumSharpePortfolio(
            expectedReturns: VectorN([0.01, 0.005]), covariance: riskless, riskFreeRate: 0.02)
        #expect(loser.sharpeRatio < winner.sharpeRatio,
                "a guaranteed gain must outrank a guaranteed loss")
    }

    /// Control: an ordinary risky covariance is untouched.
    @Test("Portfolio_RiskyCovariance_Unchanged")
    func portfolioRiskyCovarianceUnchanged() throws {
        let portfolio = try PortfolioOptimizer().maximumSharpePortfolio(
            expectedReturns: VectorN([0.10, 0.08]),
            covariance: [[0.04, 0.01], [0.01, 0.09]],
            riskFreeRate: 0.02
        )
        #expect(portfolio.sharpeRatio.isEqual(to: 0.4222389260135855))
    }

    // MARK: - PortfolioUtilities.sharpeRatio

    /// A sixth, independently written Sharpe ratio lives at `Portfolio.sharpeRatio(weights:)`,
    /// and it already returns an infinity here — its DocC argues the case explicitly:
    /// "a real signal ... which a zero is far better at hiding than an infinity is".
    ///
    /// The free function in `PortfolioUtilities` was the sibling that diverged from it.
    @Test("PortfolioUtilities_RisklessGain_MatchesItsCorrectSibling")
    func portfolioUtilitiesRisklessGainMatchesItsCorrectSibling() {
        let weights = VectorN([0.5, 0.5])
        let returns = VectorN([0.10, 0.08])
        let ratio = sharpeRatio(
            weights: weights,
            expectedReturns: returns,
            covarianceMatrix: riskless,
            riskFreeRate: 0.02
        )
        #expect(ratio.isEqual(to: .infinity), "9% guaranteed against a 2% bar, with no risk")
    }

    @Test("PortfolioUtilities_RisklessLoss_IsUnboundedlyUnattractive")
    func portfolioUtilitiesRisklessLossIsUnboundedlyUnattractive() {
        let weights = VectorN([0.5, 0.5])
        let returns = VectorN([0.01, 0.005])
        let ratio = sharpeRatio(
            weights: weights,
            expectedReturns: returns,
            covarianceMatrix: riskless,
            riskFreeRate: 0.02
        )
        #expect(ratio.isEqual(to: -.infinity))
    }

    /// Control: a real covariance is untouched.
    @Test("PortfolioUtilities_RiskyCovariance_Unchanged")
    func portfolioUtilitiesRiskyCovarianceUnchanged() {
        let weights = VectorN([0.5, 0.5])
        let returns = VectorN([0.10, 0.08])
        let ratio = sharpeRatio(
            weights: weights,
            expectedReturns: returns,
            covarianceMatrix: [[0.04, 0.01], [0.01, 0.09]],
            riskFreeRate: 0.02
        )
        #expect(ratio.isFinite)
        #expect(ratio > 0, "measured: \(ratio)")
    }

    // MARK: - SharpeRatio

    /// The same defect in an independently written file: a constant return series has zero
    /// standard deviation.
    @Test("SharpeRatio_ConstantSeriesAboveTheRiskFreeRate")
    func sharpeRatioConstantSeriesAboveTheRiskFreeRate() {
        let steady: [Double] = [0.05, 0.05, 0.05, 0.05]
        let gain: Double = SharpeRatio.calculate(values: steady, riskFreeRate: 0.03)
        #expect(gain.isEqual(to: .infinity), "2% every period, never varying, is riskless")
    }

    @Test("SharpeRatio_ConstantSeriesBelowTheRiskFreeRate")
    func sharpeRatioConstantSeriesBelowTheRiskFreeRate() {
        let steady: [Double] = [0.01, 0.01, 0.01, 0.01]
        let loss: Double = SharpeRatio.calculate(values: steady, riskFreeRate: 0.03)
        #expect(loss.isEqual(to: -.infinity))
    }

    /// A constant series *at* the risk-free rate earns no excess and takes no risk, so the
    /// ratio is genuinely zero rather than unbounded. The guard has to tell the two apart.
    @Test("SharpeRatio_ConstantSeriesAtTheRiskFreeRate")
    func sharpeRatioConstantSeriesAtTheRiskFreeRate() {
        let steady: [Double] = [0.03, 0.03, 0.03]
        let matched: Double = SharpeRatio.calculate(values: steady, riskFreeRate: 0.03)
        #expect(matched.isEqual(to: 0.0))
    }

    /// Control: a varying series is untouched.
    @Test("SharpeRatio_VaryingSeries_Unchanged")
    func sharpeRatioVaryingSeriesUnchanged() {
        let varying: [Double] = [0.08, 0.10, 0.05, 0.12]
        let ratio: Double = SharpeRatio.calculate(values: varying, riskFreeRate: 0.03)
        #expect(ratio.isFinite)
        #expect(ratio > 0.5, "measured: \(ratio)")
    }

    // MARK: - SortinoRatio

    /// Sortino's own definition makes this the best possible outcome: no period ever fell
    /// below the risk-free rate, so there is no downside deviation to divide by. It scored 0,
    /// under a comment that said `// No downside risk`.
    @Test("SortinoRatio_NoDownsideAtAll_IsUnbounded")
    func sortinoRatioNoDownsideAtAllIsUnbounded() {
        let flawlessReturns: [Double] = [0.10, 0.15, 0.12]
        let flawless: Double = SortinoRatio.calculate(values: flawlessReturns, riskFreeRate: 0.03)
        #expect(flawless.isEqual(to: .infinity), "never once below the bar")
    }

    /// The second zero-risk branch: a series sitting exactly on the risk-free rate earns no
    /// excess and risks nothing, so zero is the right answer here.
    @Test("SortinoRatio_ConstantSeriesAtTheRiskFreeRate")
    func sortinoRatioConstantSeriesAtTheRiskFreeRate() {
        let steady: [Double] = [0.03, 0.03, 0.03]
        let matched: Double = SortinoRatio.calculate(values: steady, riskFreeRate: 0.03)
        #expect(matched.isEqual(to: 0.0), "no excess and no downside is genuinely zero")
    }

    /// Control: real downside deviation is untouched.
    @Test("SortinoRatio_WithDownside_Unchanged")
    func sortinoRatioWithDownsideUnchanged() {
        let mixed: [Double] = [0.10, 0.15, -0.02, 0.08]
        let ordinary: Double = SortinoRatio.calculate(values: mixed, riskFreeRate: 0.03)
        #expect(ordinary.isFinite)
        #expect(ordinary > 0, "measured: \(ordinary)")
    }
}

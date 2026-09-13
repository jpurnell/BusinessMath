//
//  SharpeZeroRiskTests.swift
//  BusinessMathTests
//
//  What the Sharpe ratio is when there is no risk to divide by.
//

import Testing
import Foundation
@testable import BusinessMath

/// A zero-risk portfolio has a Sharpe ratio, and it is not zero.
///
/// `sharpeRatio` guarded its denominator with `guard risk > 0 else { return 0 }`. Zero is
/// a plausible number and the wrong one: a Sharpe of zero means *no excess return per
/// unit of risk*, and a portfolio earning positive excess return at exactly zero risk is
/// the best case there is. The guard reported the best possible outcome as mediocre.
///
/// Same family as `a * 0 → 0` in the bytecode optimizer and the antithetic standard
/// error: a guard that returns a plausible value where the answer is undefined, or
/// where it is defined and inconvenient.
///
/// Without the guard each case answers for itself, which is what IEEE division is for:
///
/// | excess return | risk | Sharpe |
/// |---|---|---|
/// | positive | 0 | `+infinity` — infinitely good, and true |
/// | negative | 0 | `-infinity` — infinitely bad, and true |
/// | zero | 0 | `NaN` — 0/0, genuinely undefined |
@Suite("Sharpe ratio at zero risk")
struct SharpeZeroRiskTests {

    /// Constant returns give a covariance matrix of zeros, so risk is exactly zero.
    private func constantReturns(_ monthly: [Double]) -> Portfolio<Double> {
        let periods = (0..<12).map { Period.month(year: 2025, month: $0 + 1) }
        let series = monthly.map { rate in
            TimeSeries(periods: periods, values: Array(repeating: rate, count: 12))
        }
        let names = (0..<monthly.count).map { "A\($0)" }
        return Portfolio(assets: names, returns: series, riskFreeRate: 0.0)
    }

    @Test("The fixture really does have zero risk")
    func fixtureHasZeroRisk() {
        let portfolio = constantReturns([0.10 / 12.0, 0.05 / 12.0])
        let risk = portfolio.portfolioRisk(weights: [0.5, 0.5])
        #expect(risk.isEqual(to: 0.0), "risk was \(risk); this suite assumes exactly zero")
    }

    @Test("Positive excess return at zero risk is infinitely good")
    func positiveExcessIsPositiveInfinity() {
        let portfolio = constantReturns([0.10 / 12.0, 0.05 / 12.0])
        let sharpe = portfolio.sharpeRatio(weights: [0.5, 0.5])

        #expect(portfolio.portfolioReturn(weights: [0.5, 0.5]) > 0.0)
        #expect(sharpe.isInfinite, "zero-risk positive excess gave \(sharpe)")
        #expect(sharpe > 0.0, "gave \(sharpe), which is not +infinity")
    }

    @Test("Negative excess return at zero risk is infinitely bad")
    func negativeExcessIsNegativeInfinity() {
        let periods = (0..<12).map { Period.month(year: 2025, month: $0 + 1) }
        let flat = TimeSeries(periods: periods, values: Array(repeating: 0.01 / 12.0, count: 12))
        // A risk-free rate above the portfolio's return: the excess is negative.
        let portfolio = Portfolio(assets: ["A"], returns: [flat], riskFreeRate: 0.50)
        let sharpe = portfolio.sharpeRatio(weights: [1.0])

        #expect(sharpe.isInfinite, "zero-risk negative excess gave \(sharpe)")
        #expect(sharpe < 0.0, "gave \(sharpe), which is not −infinity")
    }

    /// Zero excess over zero risk is 0/0, which is the one case with no answer.
    @Test("Zero excess at zero risk is undefined")
    func zeroExcessIsNaN() {
        let periods = (0..<12).map { Period.month(year: 2025, month: $0 + 1) }
        let flat = TimeSeries(periods: periods, values: Array(repeating: 0.25, count: 12))
        let portfolio = Portfolio(assets: ["A"], returns: [flat], riskFreeRate: 0.25)
        let sharpe = portfolio.sharpeRatio(weights: [1.0])

        #expect(sharpe.isNaN, "0/0 gave \(sharpe)")
    }

    /// The ordinary case is untouched: real risk, an ordinary finite ratio.
    @Test("A portfolio with real risk is unaffected")
    func ordinaryPortfolioIsUnchanged() {
        let periods = (0..<6).map { Period.month(year: 2025, month: $0 + 1) }
        let a = TimeSeries(periods: periods, values: [0.02, -0.01, 0.03, 0.00, 0.04, -0.02])
        let b = TimeSeries(periods: periods, values: [0.01, 0.02, -0.01, 0.03, -0.02, 0.02])
        let portfolio = Portfolio(assets: ["A", "B"], returns: [a, b], riskFreeRate: 0.0)

        let risk = portfolio.portfolioRisk(weights: [0.5, 0.5])
        let sharpe = portfolio.sharpeRatio(weights: [0.5, 0.5])
        #expect(risk > 0.0, "this fixture is meant to carry real risk; got \(risk)")
        #expect(sharpe.isFinite, "an ordinary portfolio gave \(sharpe)")

        let expected = portfolio.portfolioReturn(weights: [0.5, 0.5]) / risk
        #expect(abs(sharpe - expected) < 1e-12)
    }
}

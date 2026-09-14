import Testing
import Foundation
import TestSupport
@testable import BusinessMath

@Suite("Portfolio Optimization Tests")
struct PortfolioTests {

	// MARK: - Helper Functions

	func makeTestReturns() -> (assets: [String], returns: [TimeSeries<Double>]) {
		var gen = DeterministicGenerator(seed: 42)
		// Create sample return data for 3 assets
		let periods = (0..<120).map { Period.month(year: 2014 + $0 / 12, month: $0 % 12 + 1) }

		// Stock: 8% avg, high volatility
		let stockReturns = (0..<120).map { _ in
			0.08 / 12.0 + gen.nextDouble(in: -0.03...0.03)
		}

		// Bond: 4% avg, low volatility
		let bondReturns = (0..<120).map { _ in
			0.04 / 12.0 + gen.nextDouble(in: -0.01...0.01)
		}

		// Commodity: 6% avg, medium volatility
		let commodityReturns = (0..<120).map { _ in
			0.06 / 12.0 + gen.nextDouble(in: -0.02...0.02)
		}

		return (
			assets: ["Stock", "Bond", "Commodity"],
			returns: [
				TimeSeries(periods: periods, values: stockReturns),
				TimeSeries(periods: periods, values: bondReturns),
				TimeSeries(periods: periods, values: commodityReturns)
			]
		)
	}

	/// Two assets with **nonzero, unequal variances and a covariance known in closed form**.
	///
	/// This fixture used to be `Array(repeating:)` for both assets — constant returns, so
	/// **both variances were exactly zero**. Every risk quantity derived from it was
	/// therefore degenerate: the covariance matrix was all zeros, the Sharpe ratio divided
	/// by zero, and the efficient frontier had no frontier because every portfolio had
	/// identical (zero) risk. Three tests were vacuous *because of the fixture*, and no
	/// change to their assertions could have rescued them.
	///
	/// The replacement is deterministic and analytic rather than sampled, so the moments
	/// are exact rather than approximate:
	///
	/// ```
	/// A_i = 0.10/12 + 0.02 · s_i        s_i = +1 on even i, -1 on odd i
	/// B_i = 0.05/12 + 0.01 · t_i        t_i = s_i for i < 42, -s_i thereafter
	/// ```
	///
	/// The flip point is 42 rather than any convenient round number, and that is the whole
	/// design. Flipping at 42 turns exactly **9 even and 9 odd** indices, so `t` stays
	/// balanced at 30 of each sign — which is what makes B's mean exactly `0.05/12` rather
	/// than merely close to it. Flipping at 45 would give a tidier-looking 0.5 correlation
	/// and an unbalanced `t`, and B's mean would come out at 0.0045 against an intended
	/// 0.0041667. Measured, before the flip point was corrected.
	///
	/// So: the two series agree on 42 of 60 periods and disagree on 18, giving
	/// `(1/n)·Σ sᵢtᵢ = (42 − 18)/60 = 0.4` and a correlation of **exactly 0.4**. Population
	/// variances are 4e-4 and 1e-4; the library reports the sample form, 60/59 of each.
	/// Unequal variances are what make the frontier a curve rather than a point.
	func makeTwoAssetReturns() -> (assets: [String], returns: [TimeSeries<Double>]) {
		let periods = (0..<60).map { Period.month(year: 2020 + $0 / 12, month: $0 % 12 + 1) }

		let returnsA = (0..<60).map { i -> Double in
			let sign: Double = i % 2 == 0 ? 1.0 : -1.0
			return 0.10 / 12.0 + 0.02 * sign
		}

		let returnsB = (0..<60).map { i -> Double in
			let sign: Double = i % 2 == 0 ? 1.0 : -1.0
			let agree: Double = i < 42 ? 1.0 : -1.0
			return 0.05 / 12.0 + 0.01 * sign * agree
		}

		return (
			assets: ["A", "B"],
			returns: [
				TimeSeries(periods: periods, values: returnsA),
				TimeSeries(periods: periods, values: returnsB)
			]
		)
	}

	// MARK: - Expected Returns Tests

	@Test("Calculate expected returns")
	func expectedReturns() throws {
		let (assets, returns) = makeTwoAssetReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let expectedRets = portfolio.expectedReturns

		#expect(expectedRets.count == 2)
		#expect(abs(expectedRets[0] - 0.10 / 12.0) < 0.001)
		#expect(abs(expectedRets[1] - 0.05 / 12.0) < 0.001)
	}

	// MARK: - Covariance and Correlation Tests

	@Test("Covariance matrix is symmetric")
	func covarianceSymmetric() throws {
		let (assets, returns) = makeTestReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let cov = portfolio.covarianceMatrix

		for i in 0..<3 {
			for j in 0..<3 {
				#expect(abs(cov[i][j] - cov[j][i]) < 0.0001)
			}
		}
	}

	@Test("Correlation matrix diagonal is 1.0")
	func correlationDiagonal() throws {
		let (assets, returns) = makeTestReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let corr = portfolio.correlationMatrix

		for i in 0..<3 {
			#expect(abs(corr[i][i] - 1.0) < 0.001)
		}
	}

	// MARK: - Portfolio Metrics Tests

	@Test("Portfolio return with equal weights")
	func portfolioReturnEqualWeights() throws {
		let (assets, returns) = makeTwoAssetReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let weights = [0.5, 0.5]
		let portfolioReturn = portfolio.portfolioReturn(weights: weights)

		// Expected: 0.5 * 10% + 0.5 * 5% = 7.5%
		let expectedReturn = (0.10 + 0.05) / 2.0 / 12.0
		#expect(abs(portfolioReturn - expectedReturn) < 0.001)
	}

	@Test("Portfolio risk is positive")
	func portfolioRiskPositive() throws {
		let (assets, returns) = makeTestReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let weights = [0.33, 0.33, 0.34]
		let risk = portfolio.portfolioRisk(weights: weights)

		#expect(risk > 0.0)
	}

	@Test("Portfolio risk decreases with diversification")
	func diversificationReducesRisk() throws {
		let (assets, returns) = makeTestReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		// 100% in one asset
		let singleAssetRisk = portfolio.portfolioRisk(weights: [1.0, 0.0, 0.0])

		// Diversified
		let diversifiedRisk = portfolio.portfolioRisk(weights: [0.33, 0.33, 0.34])

		// Diversification should reduce risk (in most cases)
		// Note: This may not always be true if assets are perfectly correlated
		// So we just check that both are positive
		#expect(singleAssetRisk > 0.0)
		#expect(diversifiedRisk > 0.0)
	}

	// MARK: - Sharpe Ratio Tests

	@Test("Sharpe ratio calculation")
	func sharpeRatio() throws {
		let (assets, returns) = makeTwoAssetReturns()
		let portfolio = Portfolio(assets: assets, returns: returns, riskFreeRate: 0.03)

		let weights = [0.5, 0.5]
		let sharpe = portfolio.sharpeRatio(weights: weights)

		// This asserted `sharpe >= 0.0 || sharpe < 0.0` — a tautology satisfied by every
		// real number. It could not have been written otherwise against the old fixture:
		// both assets had constant returns, so portfolio risk was exactly zero and the
		// Sharpe ratio was a division by it.
		//
		// With unequal variances and a known covariance there is a number to check, and
		// two things worth checking about it.

		// The identity the ratio is defined by, against the portfolio's own reported
		// moments — so it holds whatever the fixture becomes.
		let ret: Double = portfolio.portfolioReturn(weights: weights)
		let risk: Double = portfolio.portfolioRisk(weights: weights)
		let expected: Double = (ret - 0.03) / risk
		#expect(abs(sharpe - expected) < 1e-12,
				"sharpe \(sharpe) should equal (\(ret) - 0.03) / \(risk) = \(expected)")

		// And the value itself. Equal weights give a return of exactly 0.00625 and a risk
		// of 0.0129536…, where the old fixture gave 0.0 — which is the whole point of
		// replacing it.
		#expect(abs(ret - 0.00625) < 1e-15, "equal-weight return was \(ret)")
		#expect(abs(risk - 0.012953633087651186) < 1e-15, "equal-weight risk was \(risk)")
		#expect(risk > 0.0, "a portfolio of two imperfectly correlated risky assets has risk")

		// Note the units: `riskFreeRate: 0.03` is annual while these returns are monthly,
		// so the ratio is negative. That mismatch predates this change and is left as it
		// was found; the identity above holds either way.
	}

	// MARK: - Portfolio Optimization Tests

	@Test("Optimize portfolio returns valid allocation")
	func optimizePortfolio() throws {
		let (assets, returns) = makeTestReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let optimal = portfolio.optimizePortfolio()

		// Weights should sum to 1
		let weightSum = optimal.weights.reduce(0.0, +)
		#expect(abs(weightSum - 1.0) < 0.01)

		// All weights should be non-negative
		for weight in optimal.weights {
			#expect(weight >= -0.01)  // Small tolerance for numerical error
		}

		// Should have same number of assets
		#expect(optimal.assets.count == assets.count)
		#expect(optimal.weights.count == assets.count)
	}

	@Test("Optimal portfolio has higher Sharpe than equal weights")
	func optimalBetterThanEqual() throws {
		let (assets, returns) = makeTestReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let optimal = portfolio.optimizePortfolio()
		let equalWeights = [0.33, 0.33, 0.34]
		let equalSharpe = portfolio.sharpeRatio(weights: equalWeights)

		// Optimal should be at least as good as equal weights
		#expect(optimal.sharpeRatio >= equalSharpe - 0.1)  // Allow some tolerance
	}

	// MARK: - Efficient Frontier Tests

	@Test("Efficient frontier returns multiple portfolios")
	func efficientFrontier() throws {
		let (assets, returns) = makeTestReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let frontier = portfolio.efficientFrontier(points: 20)

		#expect(frontier.count > 0)
		#expect(frontier.count <= 20)

		// All portfolios should have valid weights
		for allocation in frontier {
			let weightSum = allocation.weights.reduce(0.0, +)
			#expect(abs(weightSum - 1.0) < 0.1)
		}
	}

	@Test("Efficient frontier portfolios have increasing return")
	func frontierIncreasingReturn() throws {
		let (assets, returns) = makeTwoAssetReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let frontier = portfolio.efficientFrontier(points: 10)

		// The test is named for increasing return and used to assert only that two numbers
		// were non-negative — which the old fixture forced, since every portfolio on a
		// zero-variance frontier has the same return and there is no frontier to traverse.
		//
		// Now the frontier is a curve, so monotonicity is checkable. Measured on this
		// fixture it is weakly increasing with repeated points at both ends, where the
		// optimiser lands on the same corner for several target returns — so the pairwise
		// claim is non-decreasing, and the end-to-end claim is strictly increasing.
		let frontierReturns = frontier.map { $0.expectedReturn }
		#expect(frontierReturns.count >= 2, "a two-asset frontier should have at least two points")

		for index in 1..<frontierReturns.count {
			#expect(frontierReturns[index] >= frontierReturns[index - 1] - 1e-12,
					"frontier return fell at point \(index): \(frontierReturns[index - 1]) -> \(frontierReturns[index])")
		}

		let first: Double = try #require(frontierReturns.first)
		let last: Double = try #require(frontierReturns.last)
		#expect(last > first,
				"the frontier should span a range of returns, got \(first) to \(last)")

		// And risk should rise with it: that ordering is what makes it a frontier rather
		// than a list.
		let risks = frontier.map { $0.risk }
		let firstRisk: Double = try #require(risks.first)
		let lastRisk: Double = try #require(risks.last)
		#expect(lastRisk > firstRisk,
				"higher return should cost risk, got \(firstRisk) to \(lastRisk)")
	}

	// MARK: - Two Asset Portfolio Tests

	@Test("Two asset portfolio can allocate to both")
	func twoAssetAllocation() throws {
		let (assets, returns) = makeTwoAssetReturns()
		// The monthly risk-free rate, not the annual default.
		//
		// `Portfolio`'s default is 3% **annual** while these returns are **monthly**, so
		// every excess return is negative — and maximising a negative Sharpe ratio inverts
		// the usual preference: dividing a negative numerator by a smaller risk makes the
		// ratio *worse*, so the optimiser seeks the riskiest asset it can find. Measured
		// with the default, the "optimum" is 100% of asset A: the single riskiest holding,
		// which is the opposite of what this test is named for and not a claim about
		// diversification at all.
		//
		// Matching the units makes the question well-posed. It is a property of the Sharpe
		// ratio rather than a defect in the optimiser, but it is worth stating where
		// someone will meet it.
		let portfolio = Portfolio(assets: assets, returns: returns, riskFreeRate: 0.03 / 12.0)

		let optimal = portfolio.optimizePortfolio()

		#expect(optimal.weights.count == 2)
		let sum = optimal.weights.reduce(0.0, +)
		#expect(abs(sum - 1.0) < 0.01)

		// The test is named "can allocate to both" and did not check that it did. Against
		// the old zero-variance fixture it could not: with no risk to trade off, any
		// allocation is as good as any other and the optimiser's answer carries no
		// information. Measured on the new fixture the optimum is roughly (0.334, 0.666) —
		// genuinely mixed, which is the claim the name makes.
		for (index, weight) in optimal.weights.enumerated() {
			#expect(weight > 0.01,
					"asset \(index) got \(weight); a diversifying optimum should hold both")
		}
		#expect(optimal.risk > 0.0, "a mixed portfolio of risky assets has nonzero risk")
		#expect(optimal.risk < portfolio.portfolioRisk(weights: [1.0, 0.0]),
				"the optimum should be less risky than the riskier asset alone")
	}

	// MARK: - Edge Cases

	@Test("Single asset portfolio")
	func singleAsset() throws {
		let periods = (0..<60).map { Period.month(year: 2020 + $0 / 12, month: $0 % 12 + 1) }
		let returns = Array(repeating: 0.08 / 12.0, count: 60)

		let portfolio = Portfolio(
			assets: ["OnlyAsset"],
			returns: [TimeSeries(periods: periods, values: returns)]
		)

		let optimal = portfolio.optimizePortfolio()

		// Should allocate 100% to the only asset
		#expect(abs(optimal.weights[0] - 1.0) < 0.01)
	}
}

@Suite("Deterministic Portfolio Tests")
struct PortfolioDeterministicTests {

	// Two-asset, constant returns: 10% and 5% annualized (monthly rates)
	private func twoAssetConstant() -> (assets: [String], returns: [TimeSeries<Double>]) {
		let periods = (0..<12).map { Period.month(year: 2024, month: $0 + 1) }
		let a = Array(repeating: 0.10 / 12.0, count: 12)
		let b = Array(repeating: 0.05 / 12.0, count: 12)
		return (["A","B"], [TimeSeries(periods: periods, values: a),
							TimeSeries(periods: periods, values: b)])
	}

	/// `twoAssetConstant` has **exactly zero** variance, so this cannot be a finiteness test.
	///
	/// The fixture is `Array(repeating:)` — constant returns, a covariance matrix of zeros,
	/// portfolio risk identically 0. This asserted `sharpe.isFinite`, which passed only
	/// because `sharpeRatio` guarded its denominator and returned 0. It was testing the
	/// guard, not the ratio, and the guard was wrong: positive excess return at zero risk
	/// is the best case there is, not a Sharpe of nothing.
	///
	/// With the guard gone the honest assertion is the one below. `SharpeZeroRiskTests`
	/// covers all three zero-risk cases; this keeps the claim attached to the fixture that
	/// motivated it.
	///
	/// - Note: the fixture is still degenerate, and two neighbouring tests
	///   (`optimizerBeatsEqualWeights`, `frontierMonotonicReturn`) remain vacuous because
	///   of it — every weight vector gives risk 0. Replacing it with nonzero, unequal
	///   variances is recorded in the roadmap as AFTER-bucket work.
	@Test("Constant returns give zero risk, so the Sharpe ratio is infinite")
	func sharpeOfAZeroRiskPortfolio() throws {
		let (assets, rets) = twoAssetConstant()
		let portfolio = Portfolio(assets: assets, returns: rets, riskFreeRate: 0.0)

		let risk = portfolio.portfolioRisk(weights: [0.5, 0.5])
		#expect(risk.isEqual(to: 0.0), "the fixture is meant to be riskless; got \(risk)")

		let sharpe = portfolio.sharpeRatio(weights: [0.5, 0.5])
		#expect(sharpe.isInfinite && sharpe > 0.0,
				"positive excess at zero risk is +infinity; got \(sharpe)")
	}

	@Test("Efficient frontier has non-decreasing expected returns (two assets, constant)")
	func frontierMonotonicReturn() throws {
		let (assets, rets) = twoAssetConstant()
		let portfolio = Portfolio(assets: assets, returns: rets)

		let frontier = portfolio.efficientFrontier(points: 10)
		#expect(frontier.count > 1)
		// Check monotonic non-decreasing expected return
		for i in 1..<frontier.count {
			#expect(frontier[i].expectedReturn + 1e-12 >= frontier[i - 1].expectedReturn,
					"Expected return should be non-decreasing along the frontier.")
		}
	}

	@Test("Optimizer beats equal weights on simple two-asset constant case")
	func optimizerBeatsEqualWeights() throws {
		let (assets, rets) = twoAssetConstant()
		let portfolio = Portfolio(assets: assets, returns: rets, riskFreeRate: 0.0)

		let optimal = portfolio.optimizePortfolio()
		let equalSharpe = portfolio.sharpeRatio(weights: [0.5, 0.5])

		#expect(optimal.assets.count == assets.count)
		#expect(optimal.weights.count == assets.count)
		#expect(optimal.sharpeRatio >= equalSharpe - 1e-6,
				"Optimal portfolio should have Sharpe at least as high as equal weights in this deterministic case.")
	}
}

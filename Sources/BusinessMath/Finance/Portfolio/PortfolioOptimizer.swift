//
//  PortfolioOptimizer.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Constraint Sets

/// Predefined constraint sets for portfolio optimization.
///
/// Common combinations of constraints for different investment strategies.
public enum PortfolioConstraintSet {
	/// No constraints (allows any weights, including short-selling and leverage)
	case unconstrained

	/// Long-only: weights must be non-negative and sum to 1
	/// Σw = 1, w ≥ 0
	case longOnly

	/// Long-short with leverage limit
	/// Σw = 1, Σ|w| ≤ leverage
	case longShort(maxLeverage: Double)

	/// Box constraints: weights between min and max
	/// Σw = 1, min ≤ w ≤ max
	case boxConstrained(min: Double, max: Double)

	/// Custom constraints
	case custom([MultivariateConstraint<VectorN<Double>>])

	/// Convert to array of constraints for the given dimension
	public func constraints(dimension: Int) -> [MultivariateConstraint<VectorN<Double>>] {
		switch self {
		case .unconstrained:
			// Only budget constraint
			return [.budgetConstraint]

		case .longOnly:
			// Budget + non-negativity
			return [.budgetConstraint] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: dimension)

		case .longShort(let maxLeverage):
			// Budget + leverage limit
			return [
				.budgetConstraint,
				.leverageLimit(maxLeverage, dimension: dimension)
			]

		case .boxConstrained(let min, let max):
			// Budget + box constraints
			return [.budgetConstraint] + MultivariateConstraint<VectorN<Double>>.boxConstraints(min: min, max: max, dimension: dimension)

		case .custom(let constraints):
			return constraints
		}
	}

	/// Whether this constraint set includes inequality constraints
	public var hasInequalityConstraints: Bool {
		switch self {
		case .unconstrained:
			return false
		case .longOnly, .longShort, .boxConstrained, .custom:
			return true
		}
	}
}

// MARK: - Portfolio Optimization Errors

/// Errors that can occur during portfolio optimization.
public enum PortfolioOptimizerError: Error, Sendable, Equatable {
	/// Expected returns vector must contain at least one asset.
	case emptyReturns
}

// MARK: - Portfolio Optimization Results

/// Results from portfolio optimization
public struct OptimalPortfolio {
	/// Optimal portfolio weights
	public let weights: VectorN<Double>

	/// Expected return
	public let expectedReturn: Double

	/// Portfolio volatility (standard deviation)
	public let volatility: Double

	/// Sharpe ratio (return/risk)
	public let sharpeRatio: Double

	/// Whether the optimization converged
	public let converged: Bool

	/// Number of iterations used
	public let iterations: Int
}

/// Efficient frontier containing multiple portfolios
public struct EfficientFrontier {
	/// Array of efficient portfolios
	public let portfolios: [OptimalPortfolio]

	/// Target returns used to generate frontier
	public let targetReturns: [Double]

	/// Portfolio with maximum Sharpe ratio.
	///
	/// Portfolios whose Sharpe ratio is not a number take no part in the comparison, and that
	/// is a correction rather than an omission: `max(by:)` seeds with the first element and
	/// replaces it only when the predicate says so, so an unratable portfolio sitting in slot
	/// zero was **returned as the best one**, while the same portfolio anywhere else was
	/// ignored. Which portfolio this property named depended on nothing but array position.
	/// Comparing only the ratable ones makes the answer the same either way.
	public var maximumSharpePortfolio: OptimalPortfolio {
		let ratable = portfolios.filter { !$0.sharpeRatio.isNaN }
		guard let portfolio = ratable.max(by: { $0.sharpeRatio < $1.sharpeRatio }) else {
			preconditionFailure("EfficientFrontier must contain at least one portfolio with a Sharpe ratio")
		}
		return portfolio
	}

	/// Portfolio with minimum variance. Same mechanism as ``maximumSharpePortfolio``:
	/// a portfolio with no measurable volatility cannot be the least volatile one, and it must
	/// not become the answer by virtue of being first.
	public var minimumVariancePortfolio: OptimalPortfolio {
		let measurable = portfolios.filter { !$0.volatility.isNaN }
		guard let portfolio = measurable.min(by: { $0.volatility < $1.volatility }) else {
			preconditionFailure("EfficientFrontier must contain at least one portfolio with a volatility")
		}
		return portfolio
	}
}

// MARK: - Optimization Strategy

/// Strategy for selecting optimization algorithm.
///
/// Allows runtime selection of optimization algorithm via the ``MultivariateOptimizer`` protocol.
/// Different strategies may perform better depending on problem size, constraint types, and desired speed/accuracy trade-offs.
public enum OptimizationStrategy {
	/// Automatically select algorithm based on problem characteristics (default)
	case automatic

	/// Use constrained optimizer (augmented Lagrangian method)
	case constrained

	/// Use inequality optimizer (penalty-barrier method)
	case inequality

	/// Use adaptive optimizer (selects algorithm dynamically)
	case adaptive
}

// MARK: - Portfolio Optimizer

/// Optimizer for portfolio allocation problems using modern portfolio theory.
///
/// Implements Markowitz mean-variance optimization, efficient frontier calculation,
/// Sharpe ratio maximization, and risk parity allocation.
///
/// ## Basic Usage
/// ```swift
/// let returns = VectorN([0.08, 0.12, 0.15])  // Expected returns
/// let covariance = [
///     [0.04, 0.01, 0.02],
///     [0.01, 0.09, 0.03],
///     [0.02, 0.03, 0.16]
/// ]
///
/// let optimizer = PortfolioOptimizer()
///
/// // Find minimum variance portfolio
/// let minVar = try optimizer.minimumVariancePortfolio(
///     expectedReturns: returns,
///     covariance: covariance
/// )
///
/// // Find maximum Sharpe ratio portfolio
/// let maxSharpe = try optimizer.maximumSharpePortfolio(
///     expectedReturns: returns,
///     covariance: covariance,
///     riskFreeRate: 0.02
/// )
///
/// // Generate efficient frontier
/// let frontier = try optimizer.efficientFrontier(
///     expectedReturns: returns,
///     covariance: covariance,
///     numberOfPoints: 20
/// )
/// ```
///
/// ## Algorithm Selection
/// ```swift
/// let returns = VectorN<Double>([0.09, 0.07, 0.06])
/// let covariance: [[Double]] = [
///     [0.040, 0.010, 0.005],
///     [0.010, 0.030, 0.008],
///     [0.005, 0.008, 0.020]
/// ]
///
/// // Use adaptive algorithm selection
/// let adaptiveOptimizer = PortfolioOptimizer(strategy: .adaptive)
/// let portfolio = try adaptiveOptimizer.minimumVariancePortfolio(
///     expectedReturns: returns,
///     covariance: covariance
/// )
/// ```
public struct PortfolioOptimizer {

	/// Optimization strategy (defaults to automatic selection)
	public let strategy: OptimizationStrategy

	/// Creates a portfolio optimizer with specified strategy.
	///
	/// - Parameter strategy: Algorithm selection strategy (default: .automatic)
	public init(strategy: OptimizationStrategy = .automatic) {
		self.strategy = strategy
	}

	// MARK: - Algorithm Factory

	/// Creates an optimizer instance based on strategy and constraints.
	///
	/// This factory method demonstrates the ``MultivariateOptimizer`` protocol in action,
	/// enabling runtime algorithm selection and swapping.
	///
	/// - Parameters:
	///   - hasInequalityConstraints: Whether the problem includes inequality constraints
	///   - maxIterations: Maximum iterations for optimization
	/// - Returns: Optimizer conforming to ``MultivariateOptimizer`` protocol
	private func createOptimizer(
		hasInequalityConstraints: Bool,
		maxIterations: Int = 100
	) -> any MultivariateOptimizer<VectorN<Double>> {
		switch strategy {
		case .automatic:
			// Automatic selection based on constraint type
			if hasInequalityConstraints {
				return InequalityOptimizer<VectorN<Double>>(
					maxIterations: maxIterations,
					maxInnerIterations: 500
				)
			} else {
				return ConstrainedOptimizer<VectorN<Double>>(
					maxIterations: maxIterations,
					maxInnerIterations: 500
				)
			}

		case .constrained:
			return ConstrainedOptimizer<VectorN<Double>>(
				maxIterations: maxIterations,
				maxInnerIterations: 500
			)

		case .inequality:
			return InequalityOptimizer<VectorN<Double>>(
				maxIterations: maxIterations,
				maxInnerIterations: 500
			)

		case .adaptive:
			return AdaptiveOptimizer<VectorN<Double>>(
				maxIterations: maxIterations,
				tolerance: 1e-6
			)
		}
	}

	// MARK: - Minimum Variance Portfolio

	/// Finds the portfolio with minimum variance.
	///
	/// Minimizes: σ² = w'Σw
	/// Subject to: Σw = 1 (and optionally w ≥ 0 if no short-selling)
	///
	/// This method demonstrates the ``MultivariateOptimizer`` protocol by using the factory
	/// method to create an optimizer instance. The algorithm is selected based on the
	/// ``OptimizationStrategy`` specified during initialization.
	///
	/// - Parameters:
	///   - expectedReturns: Expected return for each asset
	///   - covariance: Covariance matrix (n×n)
	///   - allowShortSelling: Whether to allow negative weights (default: false, ignored if constraintSet is provided)
	///   - constraintSet: Constraint set to use (default: nil, uses allowShortSelling to determine)
	/// - Returns: Optimal portfolio with minimum variance
	public func minimumVariancePortfolio(
		expectedReturns: VectorN<Double>,
		covariance: [[Double]],
		allowShortSelling: Bool = false,
		constraintSet: PortfolioConstraintSet? = nil
	) throws -> OptimalPortfolio {
		let n = expectedReturns.count
		guard n > 0 else { throw PortfolioOptimizerError.emptyReturns }
		let initialWeights = VectorN(Array(repeating: 1.0 / Double(n), count: n))

		// Portfolio variance: σ² = w'Σw
		let varianceFunction: @Sendable (VectorN<Double>) -> Double = { weights in
			let w = weights.toArray()
			var variance = 0.0
			for i in 0..<w.count {
				for j in 0..<w.count {
					variance += w[i] * covariance[i][j] * w[j]
				}
			}
			return variance
		}

		// Determine constraints based on constraintSet parameter or allowShortSelling
		let finalConstraintSet: PortfolioConstraintSet = constraintSet ?? (allowShortSelling ? .unconstrained : .longOnly)
		let constraints = finalConstraintSet.constraints(dimension: n)

		// Create optimizer via factory (demonstrates protocol usage)
		let optimizer = createOptimizer(
			hasInequalityConstraints: finalConstraintSet.hasInequalityConstraints,
			maxIterations: 100
		)

		// Optimize using protocol method
		let result = try optimizer.minimize(
			varianceFunction,
			from: initialWeights,
			constraints: constraints
		)

		// Calculate portfolio metrics
		let portfolioReturn = expectedReturns.dot(result.solution)
		let portfolioVariance = varianceFunction(result.solution)
		let portfolioVolatility = Double.sqrt(portfolioVariance)

		return OptimalPortfolio(
			weights: result.solution,
			expectedReturn: portfolioReturn,
			volatility: portfolioVolatility,
			sharpeRatio: riskAdjustedRatio(excessReturn: portfolioReturn, risk: portfolioVolatility),
			converged: result.converged,
			iterations: result.iterations
		)
	}

	// MARK: - Maximum Sharpe Ratio Portfolio

	/// Finds the portfolio with maximum Sharpe ratio.
	///
	/// Maximizes: (μ - rf) / σ where μ is return, rf is risk-free rate, σ is volatility
	///
	/// - Parameters:
	///   - expectedReturns: Expected return for each asset
	///   - covariance: Covariance matrix (n×n)
	///   - riskFreeRate: Risk-free rate (default: 0.02)
	///   - constraintSet: A set of Portfolio Constraints
	/// - Returns: Optimal portfolio with maximum Sharpe ratio
	public func maximumSharpePortfolio(
		expectedReturns: VectorN<Double>,
		covariance: [[Double]],
		riskFreeRate: Double = 0.02,
		constraintSet: PortfolioConstraintSet = .longOnly
	) throws -> OptimalPortfolio {
		let n = expectedReturns.count
		guard n > 0 else { throw PortfolioOptimizerError.emptyReturns }
		let initialWeights = VectorN(Array(repeating: 1.0 / Double(n), count: n))

		// Negative Sharpe ratio (minimize negative = maximize positive)
		let negativeSharpeFunction: @Sendable (VectorN<Double>) -> Double = { weights in
			let w = weights.toArray()

			// Calculate return
			let portfolioReturn = expectedReturns.dot(weights)

			// Calculate variance
			var variance = 0.0
			for i in 0..<w.count {
				for j in 0..<w.count {
					variance += w[i] * covariance[i][j] * w[j]
				}
			}

			let volatility = Double.sqrt(variance)

			// A near-zero volatility used to `return 1e10` here — the *worst* value for a
			// minimiser, and so exactly the wrong ranking. A riskless portfolio that beats
			// the risk-free rate is the best portfolio available, and this told the search it
			// was the worst. Worse, the penalty is a *constant*, so the objective went flat:
			// measured on a zero-covariance pair whose optimum is 100% of the higher-return
			// asset, the search returned its [0.5, 0.5] starting point and still reported
			// `converged: true`.
			//
			// Ranking by excess return at the same 1e10 scale keeps the sense right and,
			// unlike a constant, leaves a gradient for the search to follow. It is what
			// dividing by the 1e-10 floor would give, written so the guard below is one the
			// fp-safety checker can see. The magnitude range is unchanged.
			guard volatility > 1e-10 else {
				return -(portfolioReturn - riskFreeRate) * 1e10
			}

			// Return negative Sharpe ratio (we minimize)
			let sharpeRatio = (portfolioReturn - riskFreeRate) / volatility
			return -sharpeRatio
		}

		let finalWeights: VectorN<Double>
		let converged: Bool
		let iterations: Int

		let constraints = constraintSet.constraints(dimension: n)

		if constraintSet.hasInequalityConstraints {
			// Use inequality optimizer for constrained portfolios
			let optimizer = InequalityOptimizer<VectorN<Double>>(
				maxIterations: 100,
				maxInnerIterations: 500
			)
			let result = try optimizer.minimize(
				negativeSharpeFunction,
				from: initialWeights,
				subjectTo: constraints
			)
			finalWeights = result.solution
			converged = result.converged
			iterations = result.iterations
		} else {
			// Use equality-only optimizer for unconstrained
			let optimizer = ConstrainedOptimizer<VectorN<Double>>(
				maxIterations: 100,
				maxInnerIterations: 500
			)
			let result = try optimizer.minimize(
				negativeSharpeFunction,
				from: initialWeights,
				subjectTo: constraints
			)
			finalWeights = result.solution
			converged = result.converged
			iterations = result.iterations
		}

		// Calculate portfolio metrics
		let portfolioReturn = expectedReturns.dot(finalWeights)
		let portfolioVariance = calculateVariance(weights: finalWeights, covariance: covariance)
		let portfolioVolatility = Double.sqrt(portfolioVariance)
		let sharpeRatio = riskAdjustedRatio(excessReturn: portfolioReturn - riskFreeRate, risk: portfolioVolatility)

		return OptimalPortfolio(
			weights: finalWeights,
			expectedReturn: portfolioReturn,
			volatility: portfolioVolatility,
			sharpeRatio: sharpeRatio,
			converged: converged,
			iterations: iterations
		)
	}

	// MARK: - Efficient Frontier

	/// Generates the efficient frontier by computing optimal portfolios for different target returns.
	///
	/// - Parameters:
	///   - expectedReturns: Expected return for each asset
	///   - covariance: Covariance matrix (n×n)
	///   - riskFreeRate: Risk-free rate (default: 0.02)
	///   - numberOfPoints: Number of portfolios to compute (default: 20). Must be at least 2:
	///     a frontier is a spread between two endpoints, and one point has no spacing.
	/// - Returns: Efficient frontier with optimal portfolios
	/// - Throws: ``PortfolioOptimizerError/emptyReturns`` when no assets are supplied, and
	///   ``BusinessMathError/invalidInput(message:value:expectedRange:)`` when fewer than two
	///   points are asked for.
	public func efficientFrontier(
		expectedReturns: VectorN<Double>,
		covariance: [[Double]],
		riskFreeRate: Double = 0.02,
		numberOfPoints: Int = 20
	) throws -> EfficientFrontier {
		// The guard every sibling here already has — `minimumVariancePortfolio`,
		// `maximumSharpePortfolio`, `riskParityPortfolio` and `portfolioForTargetReturn` all
		// refuse an empty vector. This one did not, and instead took its endpoints from
		// `?? 0.0` and `?? 0.1`: a frontier spanning 0% to 10% returns, invented for a
		// portfolio with no assets in it.
		guard expectedReturns.count > 0 else { throw PortfolioOptimizerError.emptyReturns }

		// `numberOfPoints >= 2` was asserted in a suppression comment on the division below
		// and enforced nowhere. At 1 the divisor is zero, `step` is an infinity, and
		// `0.0 * .infinity` is NaN — so the single "target return" handed to
		// `portfolioForTargetReturn` was not a number, and the frontier came back holding a
		// portfolio optimised toward it. A claim in a comment is not a guard.
		guard numberOfPoints >= 2 else {
			throw BusinessMathError.invalidInput(
				message: "An efficient frontier needs at least two points",
				value: "\(numberOfPoints)",
				expectedRange: ">= 2"
			)
		}

		// The other half of the same endpoint problem. The empty vector above was one way the
		// span could be invented; an asset with no expected return is the other. `min()` and
		// `max()` order with `<`, and every comparison against a `nan` is false, so that asset
		// was skipped and the targets were laid out between the extremes of the *rest* — a
		// complete-looking frontier, optimised over an asset set one member short of the one
		// the caller passed, with nothing in the result to say which member.
		let returnValues = expectedReturns.toArray()
		guard returnValues.allSatisfy({ !$0.isNaN }) else {
			throw BusinessMathError.dataQuality(
				message: "An efficient frontier requires an expected return for every asset",
				context: ["invalid_count": "\(returnValues.filter { $0.isNaN }.count)"]
			)
		}

		// Find min and max returns
		let minReturn = returnValues.min() ?? 0.0
		let maxReturn = returnValues.max() ?? 0.1

		// Generate target returns
		let step = (maxReturn - minReturn) / Double(numberOfPoints - 1) // fp-safety:disable — the guard above rejects numberOfPoints < 2, so the divisor is at least 1
		let targetReturns = (0..<numberOfPoints).map { minReturn + Double($0) * step }

		var portfolios: [OptimalPortfolio] = []

		for targetReturn in targetReturns {
			// Minimize variance for this target return
			let portfolio = try portfolioForTargetReturn(
				targetReturn: targetReturn,
				expectedReturns: expectedReturns,
				covariance: covariance,
				riskFreeRate: riskFreeRate
			)

			portfolios.append(portfolio)
		}

		return EfficientFrontier(
			portfolios: portfolios,
			targetReturns: targetReturns
		)
	}

	// MARK: - Risk Parity

	/// Finds a risk parity portfolio where each asset contributes equally to total risk.
	///
	/// Risk contribution: RC_i = w_i * (Σw)_i / σ
	/// Goal: RC_1 = RC_2 = ... = RC_n
	///
	/// - Parameters:
	///   - expectedReturns: Expected return for each asset
	///   - covariance: Covariance matrix (n×n)
	///   - constraintSet: A set of Portfolio Constraints
	/// - Returns: Risk parity portfolio
	public func riskParityPortfolio(
		expectedReturns: VectorN<Double>,
		covariance: [[Double]],
		constraintSet: PortfolioConstraintSet = .longOnly
	) throws -> OptimalPortfolio {
		let n = expectedReturns.count
		guard n > 0 else { throw PortfolioOptimizerError.emptyReturns }
		let initialWeights = VectorN(Array(repeating: 1.0 / Double(n), count: n))

		// Objective: minimize sum of squared differences in risk contributions
		let riskParityObjective: @Sendable (VectorN<Double>) -> Double = { weights in
			let w = weights.toArray()

			// Calculate portfolio variance
			var variance = 0.0
			for i in 0..<n {
				for j in 0..<n {
					variance += w[i] * covariance[i][j] * w[j]
				}
			}

			let volatility = Double.sqrt(variance)
			if volatility < 1e-10 {
				return 1e10
			}

			// Calculate marginal risk contributions
			var marginalRisk = Array(repeating: 0.0, count: n)
			for i in 0..<n {
				for j in 0..<n {
					marginalRisk[i] += covariance[i][j] * w[j]
				}
			}

			// Calculate risk contributions
			var riskContributions = Array(repeating: 0.0, count: n)
			for i in 0..<n {
				riskContributions[i] = w[i] * marginalRisk[i] / volatility // fp-safety:disable — guarded above
			}

			// Target: equal risk contribution (1/n of total risk)
			let targetRC = volatility / Double(n) // fp-safety:disable — n >= 1 from expectedReturns.count

			// Sum of squared errors
			var error = 0.0
			for rc in riskContributions {
				let diff = rc - targetRC
				error += diff * diff
			}

			return error
		}

		let finalWeights: VectorN<Double>
		let converged: Bool
		let iterations: Int

		let constraints = constraintSet.constraints(dimension: n)

		if constraintSet.hasInequalityConstraints {
			// Use inequality optimizer for constrained portfolios
			let optimizer = InequalityOptimizer<VectorN<Double>>(
				maxIterations: 100,
				maxInnerIterations: 500
			)
			let result = try optimizer.minimize(
				riskParityObjective,
				from: initialWeights,
				subjectTo: constraints
			)
			finalWeights = result.solution
			converged = result.converged
			iterations = result.iterations
		} else {
			// Use equality-only optimizer for unconstrained
			let optimizer = ConstrainedOptimizer<VectorN<Double>>(
				maxIterations: 100,
				maxInnerIterations: 500
			)
			let result = try optimizer.minimize(
				riskParityObjective,
				from: initialWeights,
				subjectTo: constraints
			)
			finalWeights = result.solution
			converged = result.converged
			iterations = result.iterations
		}

		// Calculate portfolio metrics
		let portfolioReturn = expectedReturns.dot(finalWeights)
		let portfolioVariance = calculateVariance(weights: finalWeights, covariance: covariance)
		let portfolioVolatility = Double.sqrt(portfolioVariance)

		return OptimalPortfolio(
			weights: finalWeights,
			expectedReturn: portfolioReturn,
			volatility: portfolioVolatility,
			sharpeRatio: riskAdjustedRatio(excessReturn: portfolioReturn, risk: portfolioVolatility),
			converged: converged,
			iterations: iterations
		)
	}

	// MARK: - Target Return Portfolio

	/// Finds the portfolio with minimum variance for a given target return.
	///
	/// Minimizes: σ² = w'Σw
	/// Subject to: Σw = 1, μ'w = targetReturn
	///
	/// - Parameters:
	///   - targetReturn: Desired portfolio return
	///   - expectedReturns: Expected return for each asset
	///   - covariance: Covariance matrix (n×n)
	///   - riskFreeRate: Risk-free rate for Sharpe calculation (default: 0.02)
	/// - Returns: Optimal portfolio achieving target return with minimum variance
	public func portfolioForTargetReturn(
		targetReturn: Double,
		expectedReturns: VectorN<Double>,
		covariance: [[Double]],
		riskFreeRate: Double = 0.02
	) throws -> OptimalPortfolio {
		// Minimize variance subject to budget constraint and target return
		// Now properly implemented with Lagrange multipliers

		let n = expectedReturns.count
		guard n > 0 else { throw PortfolioOptimizerError.emptyReturns }
		let initialWeights = VectorN(Array(repeating: 1.0 / Double(n), count: n))

		let varianceFunction: @Sendable (VectorN<Double>) -> Double = { weights in
			let w = weights.toArray()
			var variance = 0.0
			for i in 0..<w.count {
				for j in 0..<w.count {
					variance += w[i] * covariance[i][j] * w[j]
				}
			}
			return variance
		}

		// Two equality constraints:
		// 1. Budget: Σw = 1
		// 2. Target return: μ'w = targetReturn
		let constraints = [
			MultivariateConstraint<VectorN<Double>>.budgetConstraint,
			MultivariateConstraint<VectorN<Double>>.targetReturn(expectedReturns, target: targetReturn)
		]

		let optimizer = ConstrainedOptimizer<VectorN<Double>>(
			maxIterations: 100,
			maxInnerIterations: 500
		)

		let result = try optimizer.minimize(
			varianceFunction,
			from: initialWeights,
			subjectTo: constraints
		)

		let finalWeights = result.solution
		let portfolioReturn = expectedReturns.dot(finalWeights)
		let portfolioVariance = calculateVariance(weights: finalWeights, covariance: covariance)
		let portfolioVolatility = Double.sqrt(portfolioVariance)
		let sharpeRatio = riskAdjustedRatio(excessReturn: portfolioReturn - riskFreeRate, risk: portfolioVolatility)

		return OptimalPortfolio(
			weights: finalWeights,
			expectedReturn: portfolioReturn,
			volatility: portfolioVolatility,
			sharpeRatio: sharpeRatio,
			converged: result.converged,
			iterations: result.iterations
		)
	}

	// MARK: - Helper Functions

	private func calculateVariance(weights: VectorN<Double>, covariance: [[Double]]) -> Double {
		let w = weights.toArray()
		var variance = 0.0
		for i in 0..<w.count {
			for j in 0..<w.count {
				variance += w[i] * covariance[i][j] * w[j]
			}
		}
		return variance
	}
}

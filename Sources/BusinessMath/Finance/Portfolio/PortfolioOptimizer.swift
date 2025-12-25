//
//  PortfolioOptimizer.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
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

	/// Portfolio with maximum Sharpe ratio
	public var maximumSharpePortfolio: OptimalPortfolio {
		portfolios.max(by: { $0.sharpeRatio < $1.sharpeRatio })!
	}

	/// Portfolio with minimum variance
	public var minimumVariancePortfolio: OptimalPortfolio {
		portfolios.min(by: { $0.volatility < $1.volatility })!
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
		let initialWeights = VectorN(Array(repeating: 1.0 / Double(n), count: n))

		// Portfolio variance: σ² = w'Σw
		let varianceFunction: (VectorN<Double>) -> Double = { weights in
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
			sharpeRatio: portfolioReturn / portfolioVolatility,
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
	/// - Returns: Optimal portfolio with maximum Sharpe ratio
	public func maximumSharpePortfolio(
		expectedReturns: VectorN<Double>,
		covariance: [[Double]],
		riskFreeRate: Double = 0.02,
		constraintSet: PortfolioConstraintSet = .longOnly
	) throws -> OptimalPortfolio {
		let n = expectedReturns.count
		let initialWeights = VectorN(Array(repeating: 1.0 / Double(n), count: n))

		// Negative Sharpe ratio (minimize negative = maximize positive)
		let negativeSharpeFunction: (VectorN<Double>) -> Double = { weights in
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

			// Avoid division by zero
			if volatility < 1e-10 {
				return 1e10
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
		let sharpeRatio = (portfolioReturn - riskFreeRate) / portfolioVolatility

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
	///   - numberOfPoints: Number of portfolios to compute (default: 20)
	/// - Returns: Efficient frontier with optimal portfolios
	public func efficientFrontier(
		expectedReturns: VectorN<Double>,
		covariance: [[Double]],
		riskFreeRate: Double = 0.02,
		numberOfPoints: Int = 20
	) throws -> EfficientFrontier {
		// Find min and max returns
		let minReturn = expectedReturns.toArray().min() ?? 0.0
		let maxReturn = expectedReturns.toArray().max() ?? 0.1

		// Generate target returns
		let step = (maxReturn - minReturn) / Double(numberOfPoints - 1)
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
	/// - Returns: Risk parity portfolio
	public func riskParityPortfolio(
		expectedReturns: VectorN<Double>,
		covariance: [[Double]],
		constraintSet: PortfolioConstraintSet = .longOnly
	) throws -> OptimalPortfolio {
		let n = expectedReturns.count
		let initialWeights = VectorN(Array(repeating: 1.0 / Double(n), count: n))

		// Objective: minimize sum of squared differences in risk contributions
		let riskParityObjective: (VectorN<Double>) -> Double = { weights in
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
				riskContributions[i] = w[i] * marginalRisk[i] / volatility
			}

			// Target: equal risk contribution (1/n of total risk)
			let targetRC = volatility / Double(n)

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
			sharpeRatio: portfolioReturn / portfolioVolatility,
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
		let initialWeights = VectorN(Array(repeating: 1.0 / Double(n), count: n))

		let varianceFunction: (VectorN<Double>) -> Double = { weights in
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
		let sharpeRatio = (portfolioReturn - riskFreeRate) / portfolioVolatility

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

	private func normalizeWeights(_ weights: VectorN<Double>) -> VectorN<Double> {
		let sum = weights.toArray().reduce(0.0, +)
		if abs(sum) < 1e-10 {
			// If sum is zero, return equal weights
			let n = weights.count
			return VectorN(Array(repeating: 1.0 / Double(n), count: n))
		}
		return VectorN(weights.toArray().map { $0 / sum })
	}

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

//
//  LogisticRegression+Penalty.swift
//  BusinessMath
//
//  A ridge-type penalised fit for ``LogisticRegression``. Additive: the unpenalised
//  `fit(maxIterations:tolerance:)` is not touched.
//

import Foundation
import Numerics

/// A ridge penalty, centred on a supplied value, for ``LogisticRegression/fit(penalty:maxIterations:tolerance:)``.
///
/// The fit maximises
///
/// ```
/// log L(β)  −  (λ / 2) · Σ over slopes k of (β_k − c_k)²
/// ```
///
/// The intercept is never penalised. With `centre` omitted, `c` is zero and this is
/// ordinary ridge regression; with a centre it shrinks the slopes toward values you
/// supply (a reference model, a previous fit) instead of toward zero.
///
/// This penalty is in **coefficient space**: it measures how far a coefficient is from its
/// centre in the coefficient's own units, so it depends on how the predictors are scaled.
/// Standardise predictors first, as for any ridge fit. It is not Firth's penalty (a
/// Jeffreys-prior term); it does remove the infinite estimates that separation causes, but
/// by a different route.
///
/// ```swift
/// let ridge = LogisticPenalty<Double>(lambda: 1.0)
/// let towardReference = LogisticPenalty<Double>(lambda: 0.5, centre: [0.8, -0.2])
/// ```
public struct LogisticPenalty<T: Real & Sendable & Codable & BinaryFloatingPoint>: Sendable, Codable, Equatable {

	/// The penalty strength λ. Must be positive and finite. A very small value gives a fit
	/// close to the unpenalised optimum where one exists; zero is refused, because it asks
	/// for the unpenalised fit, which is what ``LogisticRegression/fit(maxIterations:tolerance:)``
	/// is for.
	public let lambda: T

	/// The value each slope is pulled toward, one per predictor and in the same order,
	/// without an entry for the intercept. `nil` means zero for every slope.
	public let centre: [T]?

	/// Creates a penalty.
	///
	/// Nothing is validated here; ``LogisticRegression/fit(penalty:maxIterations:tolerance:)``
	/// checks the strength and the centre against the data, as the unpenalised fit checks its
	/// inputs, so a caller building penalties in a loop gets its errors at one place.
	///
	/// - Parameters:
	///   - lambda: The penalty strength.
	///   - centre: The slopes' reference values, or `nil` for zero.
	public init(lambda: T, centre: [T]? = nil) {
		self.lambda = lambda
		self.centre = centre
	}
}

/// A penalised binomial GLM fit.
///
/// This carries no standard errors. The classical ones, from `(XᵀWX)⁻¹`, describe the
/// unpenalised estimator and are not valid for a penalised one, and a penalised estimate is
/// biased by design. Resample the observations (a bootstrap) for intervals.
public struct PenalisedLogisticFit<T: Real & Sendable & Codable & BinaryFloatingPoint>: Sendable, Codable {

	/// The coefficients, intercept first when one was fitted.
	public let coefficients: [T]

	/// The ordinary log-likelihood of the data at ``coefficients``, without the penalty.
	public let logLikelihood: T

	/// The maximised objective: ``logLikelihood`` minus the penalty term.
	public let penalisedObjective: T

	/// How many Newton steps were taken.
	public let iterations: Int

	/// Whether an intercept was fitted, which decides how ``probability(_:)`` reads its argument.
	public let hasIntercept: Bool

	/// The penalty this fit was made with.
	public let penalty: LogisticPenalty<T>

	/// The probability of a positive outcome at a point.
	///
	/// - Parameter predictors: One value per predictor, *without* an intercept term; the
	///   intercept is applied here if the fit has one.
	/// - Returns: A probability in [0, 1], or one half if the argument is the wrong width
	///   (a probability is the return type, so this cannot throw; it matches
	///   ``LogisticFit/probability(_:)``).
	public func probability(_ predictors: [T]) -> T {
		let offset = hasIntercept ? 1 : 0
		guard predictors.count == coefficients.count - offset else { return T(1) / T(2) }
		var linear: T = hasIntercept ? coefficients[0] : T.zero
		for index in 0..<predictors.count {
			let weighted: T = coefficients[index + offset] * predictors[index]
			linear += weighted
		}
		return LogisticRegression<T>.logistic(linear)
	}
}

extension LogisticRegression {

	/// Fits by Newton's method on the penalised log-likelihood.
	///
	/// With λ > 0 the objective is strictly concave, so a maximum exists and is unique
	/// whatever the data: under **separation**, where the unpenalised fit throws
	/// ``LogisticRegressionError/separation(variables:)``, and under a **rank-deficient**
	/// design, where it throws ``LogisticRegressionError/rankDeficient(columns:)``, this
	/// returns a fit. Identical columns share their effect equally. There is one exception,
	/// below.
	///
	/// ```swift
	/// let model = LogisticRegression(predictors: [[1], [2], [3], [4], [5], [6]],
	///                                outcomes: [false, false, false, true, true, true])
	/// let fit = try model.fit(penalty: LogisticPenalty(lambda: 1.0))   // separated; fitted anyway
	/// ```
	///
	/// ## What it still refuses
	///
	/// - **A constant outcome with an intercept.** The intercept is not penalised, so with
	///   every outcome the same class it still runs off to infinity; this throws
	///   ``LogisticRegressionError/separation(variables:)`` with no variables, as the
	///   unpenalised fit does. Without an intercept the same data has a finite penalised fit.
	/// - **Malformed input**, including a penalty that is not positive and finite and a
	///   centre of the wrong width.
	/// - **An exhausted budget**, as ``LogisticRegressionError/didNotConverge(iterations:gradientNorm:)``.
	///   A penalty so small it is nearly the unpenalised problem on separated data takes
	///   many steps for the same reason the unpenalised fit diverges.
	///
	/// Each Newton step is shortened by halving until the penalised objective does not fall,
	/// so a poor first step on strongly separated data cannot overshoot.
	///
	/// - Parameters:
	///   - penalty: The strength and centre.
	///   - maxIterations: Newton steps allowed.
	///   - tolerance: Convergence is declared when the largest absolute coefficient change
	///     in a full Newton step falls below this.
	/// - Returns: The fit. It carries no standard errors; see ``PenalisedLogisticFit``.
	/// - Throws: ``LogisticRegressionError``.
	public func fit(penalty: LogisticPenalty<T>,
					maxIterations: Int = 25,
					tolerance: T = T(1) / T(100_000_000)) throws -> PenalisedLogisticFit<T> {
		let design = try validatedDesign(requireIdentifiable: false)
		let rows = design.count
		let columns = design[0].count
		let slopes = predictors[0].count
		let offset = intercept ? 1 : 0

		guard penalty.lambda.isFinite, penalty.lambda > T.zero else {
			throw LogisticRegressionError.malformedInput(reason: "the penalty must be positive and finite")
		}
		let centre: [T] = penalty.centre ?? [T](repeating: T.zero, count: slopes)
		guard centre.count == slopes else {
			throw LogisticRegressionError.malformedInput(
				reason: "a centre of \(centre.count) values for \(slopes) predictors")
		}
		guard centre.allSatisfy({ $0.isFinite }) else {
			throw LogisticRegressionError.malformedInput(reason: "a centre value is not finite")
		}
		if intercept, let first = outcomes.first, outcomes.allSatisfy({ $0 == first }) {
			throw LogisticRegressionError.separation(variables: [])
		}

		let lambda: T = penalty.lambda
		var beta = [T](repeating: T.zero, count: columns)
		for index in 0..<slopes { beta[index + offset] = centre[index] }
		var objective = Self.penalisedObjective(design: design, outcomes: outcomes, beta: beta,
												lambda: lambda, centre: centre, offset: offset)
		var taken = 0

		for step in 1...Swift.max(1, maxIterations) {
			taken = step
			var information = [[T]](repeating: [T](repeating: T.zero, count: columns), count: columns)
			var score = [T](repeating: T.zero, count: columns)
			for row in 0..<rows {
				let p: T = Self.logistic(Self.linearPredictor(design[row], beta))
				let weight: T = p * (1 - p)
				let observed: T = outcomes[row] ? T(1) : T.zero
				let residual: T = observed - p
				for i in 0..<columns {
					let xi: T = design[row][i]
					score[i] += xi * residual
					let weighted: T = xi * weight
					for j in 0..<columns {
						information[i][j] += weighted * design[row][j]
					}
				}
			}
			for index in 0..<slopes {
				let column = index + offset
				let shift: T = beta[column] - centre[index]
				let pull: T = lambda * shift
				score[column] -= pull
				information[column][column] += lambda
			}

			guard let delta = Self.dampedSolve(information, score) else {
				// The system stayed unsolvable under heavy damping: the information overflowed or
				// holds a NaN. That is a numerical failure and is reported as one, not as a fit.
				throw LogisticRegressionError.didNotConverge(iterations: step, gradientNorm: Double.infinity)
			}
			var largest: T = T.zero
			for index in 0..<columns {
				let size: T = delta[index] < T.zero ? -delta[index] : delta[index]
				if size > largest { largest = size }
			}

			// Halve the step until the objective does not fall. A full Newton step is accepted
			// whenever it improves, so the quadratic convergence near the optimum is kept.
			// "Does not fall" is judged to the rounding floor of the objective: near the
			// optimum a correct step changes it by less than the last digit, and rejecting
			// those steps would shrink them to nothing and stall short of the tolerance.
			let magnitude: T = objective < T.zero ? -objective : objective
			let slack: T = T(64) * T.ulpOfOne * Swift.max(T(1), magnitude)
			var scale: T = T(1)
			var next = beta
			var nextObjective = objective
			var halvings = 0
			while halvings <= 40 {
				for index in 0..<columns { next[index] = beta[index] + scale * delta[index] }
				nextObjective = Self.penalisedObjective(design: design, outcomes: outcomes, beta: next,
														lambda: lambda, centre: centre, offset: offset)
				// A NaN or -infinity objective fails this comparison, so it needs no separate finiteness test.
				if nextObjective >= objective - slack { break }
				scale /= T(2)
				halvings += 1
			}
			if halvings <= 40 {
				beta = next
				objective = nextObjective
			}
			if largest < tolerance { break }
			if step == Swift.max(1, maxIterations) {
				let norm: Double = Self.approximateDouble(largest)
				throw LogisticRegressionError.didNotConverge(iterations: step, gradientNorm: norm)
			}
		}

		var probabilities = [T](repeating: T.zero, count: rows)
		for row in 0..<rows {
			probabilities[row] = Self.logistic(Self.linearPredictor(design[row], beta))
		}
		let likelihood = Self.logLikelihood(probabilities: probabilities, outcomes: outcomes)
		return PenalisedLogisticFit(coefficients: beta,
									logLikelihood: likelihood,
									penalisedObjective: objective,
									iterations: taken,
									hasIntercept: intercept,
									penalty: LogisticPenalty(lambda: lambda, centre: centre))
	}

	/// Solves the Newton system, adding damping when it is singular.
	///
	/// The penalised information is positive definite on the slopes, but the *intercept*
	/// entry is the sum of the fitted weights `p(1 − p)`, which is zero to working precision
	/// when every fitted probability is saturated (a start far from the optimum, or very large
	/// predictors). The exact system is then singular though the objective is not. Levenberg
	/// damping, adding `μ` to the diagonal with `μ` growing by a factor of one hundred, gives a
	/// step that still ascends; the caller's step-halving keeps it honest.
	///
	/// - Returns: The step, or `nil` if even a heavily damped system cannot be solved.
	static func dampedSolve(_ matrix: [[T]], _ rhs: [T]) -> [T]? {
		if let exact = solveSymmetric(matrix, rhs), exact.allSatisfy({ $0.isFinite }) { return exact }
		var largestDiagonal: T = T(1)
		for index in 0..<matrix.count where matrix[index][index].isFinite && matrix[index][index] > largestDiagonal {
			largestDiagonal = matrix[index][index]
		}
		var damping: T = T(1) / T(100_000_000) * largestDiagonal
		for _ in 0..<12 {
			var damped = matrix
			for index in 0..<matrix.count { damped[index][index] += damping }
			if let step = solveSymmetric(damped, rhs), step.allSatisfy({ $0.isFinite }) { return step }
			damping *= T(100)
		}
		return nil
	}

	/// `log L(β) − (λ/2)·Σ (β_k − c_k)²` over the slopes, written so a large linear
	/// predictor does not overflow: `y·z − log(1 + eᶻ)` with the log term split by sign.
	static func penalisedObjective(design: [[T]], outcomes: [Bool], beta: [T],
								   lambda: T, centre: [T], offset: Int) -> T {
		var total: T = T.zero
		for row in 0..<design.count {
			let z: T = linearPredictor(design[row], beta)
			let observed: T = outcomes[row] ? T(1) : T.zero
			let softplus: T = z > T.zero ? z + T.log(1 + T.exp(-z)) : T.log(1 + T.exp(z))
			let term: T = observed * z - softplus
			total += term
		}
		var cost: T = T.zero
		for index in 0..<centre.count {
			let shift: T = beta[index + offset] - centre[index]
			let square: T = shift * shift
			cost += square
		}
		let halfLambda: T = lambda / T(2)
		let penalty: T = halfLambda * cost
		return total - penalty
	}
}

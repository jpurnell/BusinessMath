//
//  LogisticRegression.swift
//  BusinessMath
//

import Foundation
import Numerics

/// What can go wrong fitting a binomial GLM.
public enum LogisticRegressionError: Error, Sendable, Equatable {

	/// The data is perfectly or quasi-perfectly separated by the named predictors, so
	/// the maximum-likelihood estimate does not exist.
	///
	/// - Parameter variables: Column indices of the predictors that separate the
	///   outcome, as indices into the *predictor* list — the intercept is not counted.
	///   An empty array means the outcome is constant, which the intercept alone
	///   separates.
	case separation(variables: [Int])

	/// The iteration budget ran out before the coefficients settled.
	case didNotConverge(iterations: Int, gradientNorm: Double)

	/// The design matrix does not have full column rank, so the coefficients are not
	/// identified — any split of the effect between the collinear columns fits equally.
	case rankDeficient(columns: [Int])

	/// The predictors and outcomes disagree on length, a row is the wrong width, or
	/// there is no data at all.
	case malformedInput(reason: String)
}

/// A fitted binomial GLM.
public struct LogisticFit<T: Real & Sendable & Codable & BinaryFloatingPoint>: Sendable, Codable {

	/// The coefficients, intercept first when one was fitted.
	public let coefficients: [T]

	/// The standard error of each coefficient, from the observed information matrix at
	/// the optimum — the square roots of the diagonal of `(XᵀWX)⁻¹`.
	public let standardErrors: [T]

	/// The maximised log-likelihood.
	public let logLikelihood: T

	/// How many IRLS steps were taken.
	public let iterations: Int

	/// Whether an intercept was fitted, which is what decides how ``probability(_:)``
	/// reads its argument.
	public let hasIntercept: Bool

	/// The probability of a positive outcome at a point.
	///
	/// - Parameter predictors: One value per predictor, *without* an intercept term;
	///   the intercept is applied here if the fit has one.
	/// - Returns: A probability strictly inside (0, 1), or `nil`-free zero if the
	///   argument is the wrong width — see the guard, which returns one half rather
	///   than fail, since a probability is the return type.
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

/// Binomial GLM by iteratively reweighted least squares.
///
/// ```swift
/// let model = LogisticRegression(predictors: [[1], [2], [3], [4], [5], [6]],
///                                outcomes: [false, false, true, false, true, true])
/// let fit = try model.fit()
/// let p = fit.probability([3.5])
/// ```
///
/// ## Why this refuses more often than most implementations
///
/// Under **separation** — where some combination of predictors splits the outcome
/// perfectly — the maximum-likelihood estimate does not exist. The likelihood keeps
/// climbing as the coefficients diverge, and there is no maximum to find. What most
/// libraries return is wherever their optimizer happened to stop: enormous coefficients,
/// a perfect in-sample AUC, and no predictive validity whatsoever.
///
/// Nothing about the shape of that result says it is meaningless. It looks like an
/// unusually good model. This throws ``LogisticRegressionError/separation(variables:)``
/// instead, naming the predictors responsible. The remedy is Firth's penalised
/// likelihood, which has a finite estimate under separation; it is not implemented here,
/// and saying so is better than returning the artifact.
///
/// The same reasoning applies to a **rank-deficient** design, where two collinear columns
/// can trade effect between them without changing the fit at all.
public struct LogisticRegression<T: Real & Sendable & Codable & BinaryFloatingPoint>: Sendable {

	/// One row per observation, one column per predictor, without an intercept column.
	public let predictors: [[T]]

	/// The observed outcomes.
	public let outcomes: [Bool]

	/// Whether to fit an intercept.
	public let intercept: Bool

	/// Creates a model. Nothing is validated here; ``fit(maxIterations:tolerance:)``
	/// does the validation, so that a caller building models in a loop gets its errors
	/// at one place rather than two.
	///
	/// - Parameters:
	///   - predictors: One row per observation, all rows the same width.
	///   - outcomes: One outcome per row.
	///   - intercept: Whether to fit an intercept. Defaults to `true`.
	public init(predictors: [[T]], outcomes: [Bool], intercept: Bool = true) {
		self.predictors = predictors
		self.outcomes = outcomes
		self.intercept = intercept
	}

	/// Fits by iteratively reweighted least squares.
	///
	/// IRLS is Newton–Raphson on the score with the observed information replaced by
	/// the expected information, which for a canonical link are the same matrix — so
	/// this is exact Newton and converges quadratically. Each step solves
	/// `(XᵀWX)β = XᵀWz` for the working response `z = Xβ + W⁻¹(y − p)`.
	///
	/// - Parameters:
	///   - maxIterations: Newton steps allowed. Twenty-five is generous; a well-posed
	///     fit converges in five or six, and one that has not converged in
	///     twenty-five is usually separated rather than slow.
	///   - tolerance: Convergence is declared when the largest absolute coefficient
	///     change falls below this.
	/// - Returns: The fit.
	/// - Throws: ``LogisticRegressionError``.
	public func fit(maxIterations: Int = 25,
					tolerance: T = T(1) / T(100_000_000)) throws -> LogisticFit<T> {
		let design = try validatedDesign()
		let rows = design.count
		let columns = design[0].count

		try refuseSeparation()

		var beta = [T](repeating: T.zero, count: columns)
		var probabilities = [T](repeating: T(1) / T(2), count: rows)
		var taken = 0

		for step in 1...Swift.max(1, maxIterations) {
			taken = step
			for row in 0..<rows {
				probabilities[row] = Self.logistic(Self.linearPredictor(design[row], beta))
			}

			// XᵀWX and Xᵀ(y − p). Working with the score directly rather than forming
			// the working response keeps one fewer division by a weight that goes to
			// zero as a fitted probability approaches certainty.
			var information = [[T]](repeating: [T](repeating: T.zero, count: columns), count: columns)
			var score = [T](repeating: T.zero, count: columns)
			for row in 0..<rows {
				let p: T = probabilities[row]
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

			guard let delta = Self.solveSymmetric(information, score) else {
				throw LogisticRegressionError.rankDeficient(columns: Array(0..<columns))
			}
			var largest: T = T.zero
			for index in 0..<columns {
				beta[index] += delta[index]
				let size: T = delta[index] < T.zero ? -delta[index] : delta[index]
				if size > largest { largest = size }
			}
			guard beta.allSatisfy({ $0.isFinite }) else {
				throw LogisticRegressionError.separation(variables: Array(0..<predictors[0].count))
			}
			if largest < tolerance { break }
			if step == Swift.max(1, maxIterations) {
				let norm: Double = Self.approximateDouble(largest)
				throw LogisticRegressionError.didNotConverge(iterations: step, gradientNorm: norm)
			}
		}

		for row in 0..<rows {
			probabilities[row] = Self.logistic(Self.linearPredictor(design[row], beta))
		}
		let errors = try standardErrors(design: design, probabilities: probabilities, columns: columns)
		let likelihood = Self.logLikelihood(probabilities: probabilities, outcomes: outcomes)

		return LogisticFit(coefficients: beta,
						   standardErrors: errors,
						   logLikelihood: likelihood,
						   iterations: taken,
						   hasIntercept: intercept)
	}
}

// MARK: - The parts that do the work

extension LogisticRegression {

	/// The logistic function, written so neither tail overflows.
	///
	/// `1/(1 + e^-x)` overflows for large negative `x` and `e^x/(1 + e^x)` for large
	/// positive, so each branch takes the form whose exponential argument is negative.
	/// It matters here because IRLS drives the linear predictor far out on separated
	/// or near-separated data, which is exactly the case this type has to survive long
	/// enough to diagnose.
	///
	/// - Parameter x: The linear predictor.
	/// - Returns: A probability in (0, 1).
	static func logistic(_ x: T) -> T {
		if x >= T.zero {
			let decay: T = T.exp(-x)
			return 1 / (1 + decay)
		}
		let growth: T = T.exp(x)
		return growth / (1 + growth)
	}

	/// `xᵀβ`.
	static func linearPredictor(_ row: [T], _ beta: [T]) -> T {
		var total: T = T.zero
		for index in 0..<row.count {
			let term: T = row[index] * beta[index]
			total += term
		}
		return total
	}

	/// The design matrix, with an intercept column prepended when one is wanted.
	///
	/// - Returns: One row per observation.
	/// - Throws: ``LogisticRegressionError/malformedInput(reason:)``.
	func validatedDesign() throws -> [[T]] {
		guard !predictors.isEmpty, !outcomes.isEmpty else {
			throw LogisticRegressionError.malformedInput(reason: "no observations")
		}
		guard predictors.count == outcomes.count else {
			throw LogisticRegressionError.malformedInput(
				reason: "\(predictors.count) rows against \(outcomes.count) outcomes")
		}
		let width = predictors[0].count
		guard width > 0 || intercept else {
			throw LogisticRegressionError.malformedInput(reason: "no predictors and no intercept")
		}
		guard predictors.allSatisfy({ $0.count == width }) else {
			throw LogisticRegressionError.malformedInput(reason: "rows are not all \(width) wide")
		}
		guard predictors.allSatisfy({ $0.allSatisfy { $0.isFinite } }) else {
			throw LogisticRegressionError.malformedInput(reason: "a predictor is not finite")
		}
		guard predictors.count > width else {
			throw LogisticRegressionError.malformedInput(
				reason: "\(predictors.count) observations cannot identify \(width) predictors")
		}
		return predictors.map { row in intercept ? [T(1)] + row : row }
	}

	/// Refuses data whose maximum-likelihood estimate does not exist.
	///
	/// Three cases, cheapest first.
	///
	/// **A constant outcome.** Every observation the same class. The intercept alone
	/// separates it and diverges; there is no finite fit and no predictor to blame,
	/// so the error names none.
	///
	/// **Complete separation on one predictor.** Sort by that column: if every positive
	/// outcome lies above every negative, or below, a threshold splits the data
	/// perfectly and the coefficient runs away. This is the textbook case.
	///
	/// **Quasi-complete separation on a categorical predictor.** A level of a
	/// low-cardinality column whose observations are all one class. The fitted
	/// probability there wants to be exactly zero or one, which again needs an infinite
	/// coefficient. The cardinality test is what keeps this from firing on continuous
	/// data, where every value is its own level and every level is trivially pure.
	///
	/// What this does *not* catch is separation by a linear combination of predictors
	/// that no single column exhibits — detecting that exactly is a linear program. The
	/// fit catches those anyway, by the coefficients going non-finite, and reports them
	/// as separation rather than as convergence failure.
	///
	/// - Throws: ``LogisticRegressionError/separation(variables:)``.
	func refuseSeparation() throws {
		guard let first = outcomes.first else { return }
		if outcomes.allSatisfy({ $0 == first }) {
			throw LogisticRegressionError.separation(variables: [])
		}
		let width = predictors[0].count
		guard width > 0 else { return }
		var offenders: [Int] = []
		for column in 0..<width {
			let values = predictors.map { $0[column] }
			if Self.separatesByThreshold(values: values, outcomes: outcomes) {
				offenders.append(column)
				continue
			}
			if Self.separatesByLevel(values: values, outcomes: outcomes) {
				offenders.append(column)
			}
		}
		guard offenders.isEmpty else {
			throw LogisticRegressionError.separation(variables: offenders)
		}
	}

	/// Whether a threshold on this column splits the outcome perfectly.
	static func separatesByThreshold(values: [T], outcomes: [Bool]) -> Bool {
		var positive: [T] = []
		var negative: [T] = []
		for (value, outcome) in zip(values, outcomes) {
			if outcome { positive.append(value) } else { negative.append(value) }
		}
		guard let lowPositive = positive.min(), let highPositive = positive.max(),
			  let lowNegative = negative.min(), let highNegative = negative.max() else {
			return false
		}
		// Strictly above, or strictly below. Touching at a shared value is overlap, not
		// separation — the likelihood stays finite there.
		return lowPositive > highNegative || highPositive < lowNegative
	}

	/// Whether some level of a low-cardinality column carries only one outcome.
	static func separatesByLevel(values: [T], outcomes: [Bool]) -> Bool {
		var levels: [T] = []
		for value in values where !levels.contains(where: { $0 == value }) {
			levels.append(value)
		}
		// Continuous data has as many levels as rows, and every level is trivially
		// pure; requiring at most half the rows keeps this to genuinely categorical
		// columns, which is where quasi-separation is a real phenomenon.
		let ceiling = values.count / 2
		guard levels.count <= ceiling, levels.count > 1 else { return false }
		for level in levels {
			var sawTrue = false
			var sawFalse = false
			for (value, outcome) in zip(values, outcomes) where value == level {
				if outcome { sawTrue = true } else { sawFalse = true }
			}
			if sawTrue != sawFalse { return true }
		}
		return false
	}

	/// Solves a symmetric system by Gaussian elimination with partial pivoting.
	///
	/// - Returns: The solution, or `nil` when the matrix is singular to working
	///   precision — which for `XᵀWX` means the design has collinear columns.
	static func solveSymmetric(_ matrix: [[T]], _ rhs: [T]) -> [T]? {
		let n = rhs.count
		guard n > 0, matrix.count == n else { return nil }
		var a = matrix
		var b = rhs
		var scale: T = T.zero
		for row in a {
			for value in row {
				let size: T = value < T.zero ? -value : value
				if size > scale { scale = size }
			}
		}
		guard scale > T.zero else { return nil }
		let threshold: T = scale * T.ulpOfOne * T(n * n)

		for column in 0..<n {
			var pivotRow = column
			var best: T = T.zero
			for row in column..<n {
				let size: T = a[row][column] < T.zero ? -a[row][column] : a[row][column]
				if size > best { best = size; pivotRow = row }
			}
			guard best > threshold else { return nil }
			if pivotRow != column {
				a.swapAt(pivotRow, column)
				b.swapAt(pivotRow, column)
			}
			let pivot: T = a[column][column]
			for row in (column + 1)..<n {
				let factor: T = a[row][column] / pivot
				guard factor.isFinite else { return nil }
				for k in column..<n {
					let adjustment: T = factor * a[column][k]
					a[row][k] -= adjustment
				}
				let scaled: T = factor * b[column]
				b[row] -= scaled
			}
		}

		var solution = [T](repeating: T.zero, count: n)
		for row in stride(from: n - 1, through: 0, by: -1) {
			var total: T = b[row]
			for k in (row + 1)..<n {
				let term: T = a[row][k] * solution[k]
				total -= term
			}
			let pivot: T = a[row][row]
			guard pivot != T.zero else { return nil }
			solution[row] = total / pivot
		}
		return solution.allSatisfy { $0.isFinite } ? solution : nil
	}

	/// The standard errors: square roots of the diagonal of `(XᵀWX)⁻¹`.
	///
	/// Each column of the inverse is obtained by solving against a unit vector, which
	/// reuses the same elimination the fit already relies on rather than adding a
	/// second matrix routine that could disagree with it.
	///
	/// - Throws: ``LogisticRegressionError/rankDeficient(columns:)`` if the information
	///   matrix cannot be inverted.
	func standardErrors(design: [[T]], probabilities: [T], columns: Int) throws -> [T] {
		var information = [[T]](repeating: [T](repeating: T.zero, count: columns), count: columns)
		for row in 0..<design.count {
			let p: T = probabilities[row]
			let weight: T = p * (1 - p)
			for i in 0..<columns {
				let weighted: T = design[row][i] * weight
				for j in 0..<columns {
					information[i][j] += weighted * design[row][j]
				}
			}
		}
		var errors = [T](repeating: T.zero, count: columns)
		for index in 0..<columns {
			var unit = [T](repeating: T.zero, count: columns)
			unit[index] = T(1)
			guard let column = Self.solveSymmetric(information, unit) else {
				throw LogisticRegressionError.rankDeficient(columns: Array(0..<columns))
			}
			let variance: T = column[index]
			guard variance >= T.zero else {
				throw LogisticRegressionError.rankDeficient(columns: [index])
			}
			errors[index] = T.sqrt(variance)
		}
		return errors
	}

	/// `Σ y·log p + (1 − y)·log(1 − p)`.
	static func logLikelihood(probabilities: [T], outcomes: [Bool]) -> T {
		var total: T = T.zero
		for (p, outcome) in zip(probabilities, outcomes) {
			let contribution: T = outcome ? T.log(p) : T.log(1 - p)
			total += contribution
		}
		return total
	}

	/// A `Double` view of a scalar, for an error payload that is reported rather than
	/// computed with.
	static func approximateDouble(_ value: T) -> Double {
		Double(value)
	}
}

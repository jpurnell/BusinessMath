//
//  distributionMetalog.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Where a metalog's support ends.
///
/// The unbounded metalog runs over the whole real line, which is wrong for a cost, a
/// duration or a market share. Keelin's transforms fix that without changing the
/// fitting machinery: the data is mapped onto the whole line, an ordinary metalog is
/// fitted there, and the inverse map is applied to every quantile coming out. The
/// shape flexibility survives the round trip and the bounds are exact rather than
/// approximate.
public enum MetalogBoundedness: Sendable, Equatable {

	/// The whole real line.
	case unbounded

	/// `[lower, ∞)`. Fitted through `z = log(x − lower)`.
	case boundedBelow(lower: Double)

	/// `(−∞, upper]`. Fitted through `z = −log(upper − x)`.
	case boundedAbove(upper: Double)

	/// `[lower, upper]`. Fitted through the logit `z = log((x − lower)/(upper − x))`.
	case bounded(lower: Double, upper: Double)
}

/// Why a metalog could not be built.
public enum MetalogError: Error, Sendable, Equatable {

	/// Fewer probability/value pairs than terms requested, or fewer than two of
	/// either. A metalog with more terms than data is underdetermined.
	case insufficientData(pairs: Int, terms: Int)

	/// The probabilities and the values are different lengths.
	case dimensionMismatch

	/// A probability was outside the open interval (0, 1), or two were equal.
	case invalidProbability

	/// A value fell outside the bounds the boundedness declares, so the transform
	/// onto the real line is undefined.
	case valueOutsideBounds

	/// The fitted coefficients do not give an increasing quantile function.
	///
	/// Not every set of coefficients is a distribution — this is Keelin's feasibility
	/// condition — and the family gives no advance guarantee. Reported rather than
	/// silently repaired: a non-monotone quantile is not a distribution, and the fix
	/// is fewer terms or different data, which is the caller's decision.
	case infeasible

	/// The normal equations were singular, which means the requested terms are
	/// linearly dependent on the supplied probabilities.
	case singularFit
}

/// A metalog distribution: a quantile function flexible enough to fit almost any
/// shape, fitted directly to quantiles rather than to moments.
///
/// Most families are chosen first and fitted second, so the shape is whatever the
/// family allows. The metalog inverts that. Its quantile function is a linear
/// combination of fixed basis functions, so fitting it to a set of
/// (probability, value) pairs is ordinary least squares — and with as many terms as
/// pairs it passes through **every one of them exactly**.
///
/// Binds Risk Solver's `PsiMetalog` (coefficients given) and `PsiMetalogFit` (fitted
/// to data).
///
/// ```swift
/// // Three elicited points, three terms: reproduced exactly.
/// let forecast = try DistributionMetalog(
///     fittingProbabilities: [0.1, 0.5, 0.9],
///     values: [15.0, 40.0, 100.0]
/// )
/// print(forecast.quantile(0.5))   // 40.0
/// ```
///
/// ## The basis
///
/// Writing `L = ln(y/(1−y))` for the logit and `c = y − 0.5`:
///
/// ```
/// M(y) = a₁ + a₂·L + a₃·c·L + a₄·c + a₅·c² + a₆·c²·L + a₇·c³ + a₈·c³·L + …
/// ```
///
/// Two terms give the logistic distribution. Three add skew. Four add a shape the
/// usual families cannot reach at all, and so on — each pair of terms adds a power of
/// `c`, with and without the logit factor.
///
/// ## Feasibility is not free
///
/// A linear combination of these functions is a distribution only if it *increases*
/// in `y`, and nothing about least squares enforces that. Fitting too many terms to
/// too few or too noisy points routinely produces a quantile function that doubles
/// back, which is not a distribution at all. The initialiser checks monotonicity over
/// a fine grid and throws ``MetalogError/infeasible`` rather than returning something
/// that would sample happily and be wrong. The remedy is fewer terms.
///
/// ## What has no closed form
///
/// The CDF. The quantile is the primitive here and there is no analytic inverse for
/// it, so ``cdf(_:)`` bisects on the monotone quantile. That is exact to the
/// tolerance it converges to and costs about fifty evaluations; sampling does not use
/// it, because inverse-transform sampling calls `quantile` directly.
public struct DistributionMetalog: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The fitted coefficients, `a₁` first.
	public let coefficients: [Double]

	/// Where the support ends, and which transform was used to get there.
	public let boundedness: MetalogBoundedness

	/// The number of terms, which is `coefficients.count`.
	public var terms: Int { coefficients.count }

	// MARK: - Construction

	/// Creates a metalog from coefficients that are already known.
	///
	/// - Parameters:
	///   - coefficients: `a₁` first, at least two.
	///   - boundedness: Where the support ends. Defaults to unbounded.
	/// - Throws: ``MetalogError/insufficientData(pairs:terms:)`` for fewer than two
	///   coefficients, or ``MetalogError/infeasible`` if they do not give an
	///   increasing quantile function.
	public init(coefficients: [Double], boundedness: MetalogBoundedness = .unbounded) throws {
		guard coefficients.count >= 2 else {
			throw MetalogError.insufficientData(pairs: 0, terms: coefficients.count)
		}
		guard coefficients.allSatisfy({ $0.isFinite }) else { throw MetalogError.infeasible }
		try Self.validateBounds(boundedness)
		self.coefficients = coefficients
		self.boundedness = boundedness
		guard Self.isFeasible(coefficients: coefficients, boundedness: boundedness) else {
			throw MetalogError.infeasible
		}
	}

	/// Fits a metalog to a set of (probability, value) pairs.
	///
	/// - Parameters:
	///   - fittingProbabilities: Probabilities in the open interval (0, 1), all
	///     distinct. Need not be sorted.
	///   - values: The value at each probability, same length.
	///   - terms: How many basis terms to fit. Defaults to one per pair, which makes
	///     the fit exact — the quantile function then passes through every supplied
	///     point. Fewer terms gives a least-squares fit, which is what to use when the
	///     points come from data rather than from elicitation.
	///   - boundedness: Where the support ends. Defaults to unbounded.
	/// - Throws: ``MetalogError`` naming which argument was rejected, or
	///   ``MetalogError/infeasible`` if the fit does not increase.
	public init(fittingProbabilities: [Double],
				values: [Double],
				terms: Int? = nil,
				boundedness: MetalogBoundedness = .unbounded) throws {
		guard fittingProbabilities.count == values.count else { throw MetalogError.dimensionMismatch }
		let pairs = fittingProbabilities.count
		let requested = terms ?? pairs
		guard pairs >= 2, requested >= 2, requested <= pairs else {
			throw MetalogError.insufficientData(pairs: pairs, terms: requested)
		}
		guard fittingProbabilities.allSatisfy({ $0 > 0 && $0 < 1 }) else {
			throw MetalogError.invalidProbability
		}
		guard Set(fittingProbabilities.map { $0.bitPattern }).count == pairs else {
			throw MetalogError.invalidProbability
		}
		guard values.allSatisfy({ $0.isFinite }) else { throw MetalogError.valueOutsideBounds }
		try Self.validateBounds(boundedness)

		// Onto the whole real line, where the basis lives. For the unbounded case
		// this is the identity.
		let transformed = try values.map { try Self.toUnbounded($0, boundedness) }

		// Least squares by normal equations: (XᵀX)a = Xᵀz. XᵀX is symmetric positive
		// definite when the columns are independent, so this is a Cholesky solve —
		// the package's own, which is checked against LAPACK.
		var design = [[Double]]()
		design.reserveCapacity(pairs)
		for probability in fittingProbabilities {
			design.append(Self.basis(at: probability, terms: requested))
		}

		var normal = [[Double]](repeating: [Double](repeating: 0, count: requested), count: requested)
		var rightHandSide = [Double](repeating: 0, count: requested)
		for row in 0..<pairs {
			for i in 0..<requested {
				rightHandSide[i] += design[row][i] * transformed[row]
				for j in 0..<requested {
					normal[i][j] += design[row][i] * design[row][j]
				}
			}
		}

		let solved: [Double]
		do {
			let matrix = try DenseMatrix(normal)
			solved = try matrix.choleskySolve(rightHandSide)
		} catch {
			throw MetalogError.singularFit
		}
		guard solved.allSatisfy({ $0.isFinite }) else { throw MetalogError.singularFit }

		self.coefficients = solved
		self.boundedness = boundedness
		guard Self.isFeasible(coefficients: solved, boundedness: boundedness) else {
			throw MetalogError.infeasible
		}
	}

	// MARK: - The distribution

	/// The value below which a draw falls with probability `p`.
	///
	/// - Parameter p: A probability in the open interval (0, 1).
	/// - Returns: The quantile, inside the declared bounds.
	public func quantile(_ p: Double) -> Double {
		guard p > 0, p < 1 else {
			return p <= 0 ? Self.lowerLimit(boundedness) : Self.upperLimit(boundedness)
		}
		let unbounded = Self.evaluate(coefficients: coefficients, at: p)
		return Self.fromUnbounded(unbounded, boundedness)
	}

	/// The probability that a draw falls at or below `x`.
	///
	/// No closed form exists, so this bisects on the quantile function, which the
	/// initialiser has already established is increasing.
	///
	/// - Parameter x: Any value.
	/// - Returns: A probability in [0, 1]; 0 or 1 outside the support.
	public func cdf(_ x: Double) -> Double {
		guard x.isFinite else { return x > 0 ? 1 : 0 }
		if x <= Self.lowerLimit(boundedness) { return 0 }
		if x >= Self.upperLimit(boundedness) { return 1 }

		var low = 1e-12
		var high = 1 - 1e-12
		if x <= quantile(low) { return 0 }
		if x >= quantile(high) { return 1 }

		// Fifty halvings take the interval below 1e-15, which is past the resolution
		// of a Double probability, so this always exits on the width test in practice
		// and the loop bound is a backstop rather than the mechanism.
		for _ in 0..<80 {
			let middle: Double = (low + high) / 2
			if quantile(middle) < x { low = middle } else { high = middle }
			if high - low < 1e-15 { break }
		}
		return (low + high) / 2
	}

	// MARK: - The basis and the transforms

	/// The basis functions evaluated at one probability.
	///
	/// `[1, L, c·L, c, c², c²·L, c³, c³·L, …]` with `L = ln(y/(1−y))` and `c = y − 0.5`.
	static func basis(at y: Double, terms: Int) -> [Double] {
		let logit: Double = Foundation.log(y / (1 - y))
		let centred: Double = y - 0.5
		var out = [Double](repeating: 0, count: terms)
		for index in 0..<terms {
			let k = index + 1
			switch k {
			case 1: out[index] = 1
			case 2: out[index] = logit
			case 3: out[index] = centred * logit
			case 4: out[index] = centred
			default:
				if k % 2 == 1 {
					let power = (k - 1) / 2
					out[index] = Foundation.pow(centred, Double(power))
				} else {
					let power = k / 2 - 1
					let raised: Double = Foundation.pow(centred, Double(power))
					out[index] = raised * logit
				}
			}
		}
		return out
	}

	/// `M(y)`, the unbounded quantile before any boundedness transform.
	static func evaluate(coefficients: [Double], at y: Double) -> Double {
		let functions = basis(at: y, terms: coefficients.count)
		var total = 0.0
		for index in 0..<coefficients.count {
			total += coefficients[index] * functions[index]
		}
		return total
	}

	/// Whether the quantile function increases across the whole open interval.
	///
	/// Sampled on a grid that is dense near the ends, where a metalog turns back if it
	/// is going to: the basis functions carry `ln(y/(1−y))`, which is where all the
	/// curvature lives.
	/// - Parameters:
	///   - coefficients: The fitted coefficients.
	///   - boundedness: Ignored — every boundedness transform is strictly increasing,
	///     so monotonicity of the unbounded quantile settles it for all of them.
	///   - gridSteps: How finely to sample the interval. A parameter rather than a
	///     literal so the resolution is stateable, and so the guard below is a real
	///     runtime check rather than one the optimiser folds away.
	static func isFeasible(coefficients: [Double],
						   boundedness: MetalogBoundedness,
						   gridSteps: Int = 1_000) -> Bool {
		// The boundedness transforms are all strictly increasing, so they preserve
		// monotonicity exactly: checking the unbounded quantile settles it for every
		// variant, and the argument is here rather than a parameter this ignores.
		_ = boundedness

		// A uniform grid plus a geometric refinement at each end. The refinement is
		// the part that matters: the basis carries `ln(y/(1−y))`, so all the curvature
		// lives within a whisker of 0 and 1, and a uniform grid alone would miss a
		// quantile that turns back only in the last 1e-4 of the interval.
		// A grid too coarse to resolve anything cannot establish feasibility, and
		// saying so is better than sampling three points and returning true.
		guard gridSteps > 1 else { return false }
		// `gridSteps` is a parameter, so this guard is a real runtime check rather
		// than one the optimiser folds away — which is what made the previous version
		// of it dead code.
		let stepCount: Double = Double(gridSteps)
		guard stepCount > 0 else { return false }
		let stride: Double = 1 / stepCount

		var probabilities: [Double] = []
		probabilities.reserveCapacity(gridSteps + 16)
		for step in 1..<gridSteps {
			probabilities.append(Double(step) * stride)
		}
		let refinements: [Double] = [1e-4, 1e-5, 1e-6, 1e-7, 1e-8, 1e-9]
		for epsilon in refinements {
			probabilities.append(epsilon)
			let upper: Double = 1 - epsilon
			probabilities.append(upper)
		}
		probabilities.sort()

		var previous = -Double.infinity
		for y in probabilities {
			let value = evaluate(coefficients: coefficients, at: y)
			guard value.isFinite else { return false }
			guard value >= previous else { return false }
			previous = value
		}
		return true
	}

	static func validateBounds(_ boundedness: MetalogBoundedness) throws {
		switch boundedness {
		case .unbounded:
			return
		case .boundedBelow(let lower):
			guard lower.isFinite else { throw MetalogError.valueOutsideBounds }
		case .boundedAbove(let upper):
			guard upper.isFinite else { throw MetalogError.valueOutsideBounds }
		case .bounded(let lower, let upper):
			guard lower.isFinite, upper.isFinite, upper > lower else {
				throw MetalogError.valueOutsideBounds
			}
		}
	}

	/// Maps a value onto the whole real line, where the basis is fitted.
	static func toUnbounded(_ x: Double, _ boundedness: MetalogBoundedness) throws -> Double {
		switch boundedness {
		case .unbounded:
			return x
		case .boundedBelow(let lower):
			guard x > lower else { throw MetalogError.valueOutsideBounds }
			return Foundation.log(x - lower)
		case .boundedAbove(let upper):
			guard x < upper else { throw MetalogError.valueOutsideBounds }
			return -Foundation.log(upper - x)
		case .bounded(let lower, let upper):
			guard x > lower, x < upper else { throw MetalogError.valueOutsideBounds }
			return Foundation.log((x - lower) / (upper - x))
		}
	}

	/// The inverse of ``toUnbounded(_:_:)``.
	static func fromUnbounded(_ z: Double, _ boundedness: MetalogBoundedness) -> Double {
		switch boundedness {
		case .unbounded:
			return z
		case .boundedBelow(let lower):
			return lower + Foundation.exp(z)
		case .boundedAbove(let upper):
			return upper - Foundation.exp(-z)
		case .bounded(let lower, let upper):
			// Written with `expit` rather than `(l + u·e^z)/(1 + e^z)` so a large
			// positive `z` saturates at `upper` instead of overflowing to a NaN.
			let weight: Double = 1 / (1 + Foundation.exp(-z))
			return lower + (upper - lower) * weight
		}
	}

	static func lowerLimit(_ boundedness: MetalogBoundedness) -> Double {
		switch boundedness {
		case .unbounded, .boundedAbove: return -.infinity
		case .boundedBelow(let lower): return lower
		case .bounded(let lower, _): return lower
		}
	}

	static func upperLimit(_ boundedness: MetalogBoundedness) -> Double {
		switch boundedness {
		case .unbounded, .boundedBelow: return .infinity
		case .boundedAbove(let upper): return upper
		case .bounded(_, let upper): return upper
		}
	}
}

//
//  distributionMetalogShape.swift
//  BusinessMath
//
//  The shape statistics Risk Solver's `PsiMetalog2` reports over `PsiMetalog`:
//  modes, anti-modes, and a feasibility answer a caller can ask for rather than
//  catch.
//
//  The rest of what `PsiMetalog2` adds, ``DistributionMetalog`` already had. Its
//  headline difference upstream is that it "guarantees a feasible or valid
//  distribution", and this initialiser has always refused an infeasible coefficient
//  set rather than handing back a quantile function that runs backwards; and Frontline
//  says the two behave identically for six or fewer coefficients, which is the regime
//  where feasibility is rarely in question anyway.
//

import Foundation
import Numerics

public extension DistributionMetalog {

	// MARK: - The slope of the quantile function

	/// `dQ/dp`, the derivative of the quantile function.
	///
	/// The quantity everything else here is built on, because the density is its
	/// reciprocal: if `x = Q(p)` then `f(x) = 1 / Q'(p)`. So a *maximum* of the density
	/// is a *minimum* of this, which is why ``modes(gridSteps:)`` searches for minima.
	///
	/// Analytic rather than a finite difference. A difference of a quantile function
	/// near the ends subtracts two nearly equal large numbers, and the cancellation
	/// arrives exactly where a metalog's curvature lives — so the numerical version is
	/// least trustworthy in the region that decides feasibility and tail shape.
	///
	/// - Parameter p: A probability in the open interval (0, 1).
	/// - Returns: The slope, or `nil` outside the open interval.
	func quantileSlope(at p: Double) -> Double? {
		guard let derivative = Self.basisDerivative(at: p, terms: coefficients.count) else {
			return nil
		}
		var inner: Double = 0
		for index in 0..<coefficients.count {
			inner += coefficients[index] * derivative[index]
		}
		// The chain rule through the boundedness transform. Omitting it would give the
		// modes of the *unbounded* metalog, which for a bounded one are somewhere else
		// entirely — the transform is what bends the density against its bounds.
		let unbounded: Double = Self.evaluate(coefficients: coefficients, at: p)
		let outer: Double = Self.transformDerivative(unbounded, boundedness)
		let slope: Double = outer * inner
		return slope.isFinite ? slope : nil
	}

	/// The probability density at the value the quantile function returns for `p`.
	///
	/// Indexed by probability rather than by value because that is the direction a
	/// metalog runs: `Q` is closed form and `F` is a bisection, so asking at `p` costs
	/// one evaluation where asking at `x` costs eighty.
	///
	/// - Parameter p: A probability in the open interval (0, 1).
	/// - Returns: `f(Q(p))`, or `nil` outside the interval or where the slope has
	///   collapsed — which a feasible metalog does not do, so `nil` here means the
	///   coefficients were never feasible.
	func density(atProbability p: Double) -> Double? {
		guard let slope = quantileSlope(at: p), slope > 0 else { return nil }
		return 1 / slope
	}

	// MARK: - Modes and anti-modes

	/// Every local maximum of the density, as values on the x axis.
	///
	/// A metalog with enough terms is free to be multimodal, and that is a property
	/// worth reporting rather than discovering during a simulation: a fit that looks
	/// reasonable by its percentiles can carry a second bump nobody elicited.
	///
	/// - Parameter gridSteps: How finely to bracket before refining. A parameter
	///   rather than a literal so the resolution is stateable, and so the guard on it
	///   is a real runtime check.
	/// - Returns: The modes, in increasing order of value. Empty when the density has
	///   no interior turning point, which cannot happen for a proper density on an
	///   unbounded support but can for a bounded one whose mass piles against an edge.
	func modes(gridSteps: Int = 2_000) -> [Double] {
		turningPoints(gridSteps: gridSteps, minimisingSlope: true)
	}

	/// Every local minimum of the density, as values on the x axis.
	///
	/// A dip between two bumps. There cannot be one without at least two modes on
	/// either side of it, so this is empty whenever ``modes(gridSteps:)`` returns fewer
	/// than two — a consistency the tests check rather than a claim made here.
	///
	/// - Parameter gridSteps: As for ``modes(gridSteps:)``.
	/// - Returns: The anti-modes, in increasing order of value.
	func antiModes(gridSteps: Int = 2_000) -> [Double] {
		turningPoints(gridSteps: gridSteps, minimisingSlope: false)
	}

	/// Whether a coefficient set describes a distribution at all.
	///
	/// The same test the initialiser applies, exposed so a caller can ask before
	/// building rather than by catching ``MetalogError/infeasible``. Useful when
	/// coefficients are being searched over: a rejected candidate is an ordinary step
	/// in a fit, not an error condition.
	///
	/// - Parameters:
	///   - coefficients: The candidate coefficients.
	///   - boundedness: Where the support ends.
	/// - Returns: `true` when the quantile function increases across the interval.
	static func describesADistribution(coefficients: [Double],
									   boundedness: MetalogBoundedness = .unbounded) -> Bool {
		isFeasible(coefficients: coefficients, boundedness: boundedness)
	}

	// MARK: - Private

	/// Brackets the turning points of the slope on a grid, then refines each.
	///
	/// - Parameters:
	///   - gridSteps: Bracketing resolution.
	///   - minimisingSlope: `true` finds minima of `Q'`, which are density maxima.
	/// - Returns: The turning points as x values, increasing, de-duplicated.
	private func turningPoints(gridSteps: Int, minimisingSlope: Bool) -> [Double] {
		guard gridSteps > 2 else { return [] }
		let probabilities = Self.shapeGrid(gridSteps: gridSteps)
		guard probabilities.count > 2 else { return [] }

		var slopes = [Double]()
		slopes.reserveCapacity(probabilities.count)
		for p in probabilities {
			guard let slope = quantileSlope(at: p) else { return [] }
			slopes.append(slope)
		}

		var found = [Double]()
		for index in 1..<(probabilities.count - 1) {
			let left: Double = slopes[index - 1]
			let here: Double = slopes[index]
			let right: Double = slopes[index + 1]
			let isTurning = minimisingSlope ? (here < left && here < right)
										    : (here > left && here > right)
			guard isTurning else { continue }
			let refined = refine(lower: probabilities[index - 1],
								 upper: probabilities[index + 1],
								 minimising: minimisingSlope)
			found.append(quantile(refined))
		}

		// Two adjacent grid cells can bracket the same turning point once the grid is
		// refined at the ends, where consecutive probabilities differ by less than the
		// resolution of the refinement.
		var unique = [Double]()
		for value in found.sorted() {
			guard let last = unique.last else { unique.append(value); continue }
			let separation: Double = Swift.abs(value - last)
			let scale: Double = Swift.max(Swift.abs(value), 1)
			let tolerance: Double = scale * 1e-7
			if separation > tolerance { unique.append(value) }
		}
		return unique
	}

	/// Golden-section refinement of a bracketed turning point of the slope.
	///
	/// Golden section rather than a Newton step on the second derivative: it needs
	/// only the slope itself, converges on any continuous function, and cannot leave
	/// the bracket the grid established — which matters because a metalog's slope can
	/// have several turning points close together and a Newton step is entitled to
	/// jump to a different one.
	///
	/// - Parameters:
	///   - lower: The left edge of the bracket, in probability.
	///   - upper: The right edge.
	///   - minimising: Whether the turning point is a minimum of the slope.
	/// - Returns: The probability at the turning point.
	private func refine(lower: Double, upper: Double, minimising: Bool) -> Double {
		let root: Double = 5.0.squareRoot()
		let inversePhi: Double = (root - 1) / 2
		var left: Double = lower
		var right: Double = upper
		for _ in 0..<200 {
			let width: Double = right - left
			guard width > 1e-14 else { break }
			let step: Double = width * inversePhi
			let probeLeft: Double = right - step
			let probeRight: Double = left + step
			guard let valueLeft = quantileSlope(at: probeLeft),
				  let valueRight = quantileSlope(at: probeRight) else { break }
			let takeLeft = minimising ? (valueLeft < valueRight) : (valueLeft > valueRight)
			if takeLeft { right = probeRight } else { left = probeLeft }
		}
		let total: Double = left + right
		return total / 2
	}

	/// The probability grid the shape search runs on.
	///
	/// Uniform through the middle and geometric at both ends, for the reason
	/// ``isFeasible(coefficients:boundedness:gridSteps:)`` uses the same shape: the
	/// basis carries `ln(y/(1−y))`, so all the curvature lives within a whisker of 0
	/// and 1, and a uniform grid alone would step straight over a bump that only
	/// exists in the last 1e-4 of the interval.
	///
	/// - Parameter gridSteps: The uniform resolution.
	/// - Returns: Probabilities in increasing order, strictly inside (0, 1).
	private static func shapeGrid(gridSteps: Int) -> [Double] {
		guard gridSteps > 2 else { return [] }
		let stepCount: Double = Double(gridSteps)
		guard stepCount > 0 else { return [] }
		let stride: Double = 1 / stepCount
		var probabilities = [Double]()
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
		return probabilities
	}
}

extension DistributionMetalog {

	/// `dM/dy` for each basis function, matching ``basis(at:terms:)`` term for term.
	///
	/// With `L = ln(y/(1−y))`, `L' = 1/(y(1−y))` and `c = y − 1/2`:
	///
	/// | k | term | derivative |
	/// |---|---|---|
	/// | 1 | `1` | `0` |
	/// | 2 | `L` | `L'` |
	/// | 3 | `c·L` | `L + c·L'` |
	/// | 4 | `c` | `1` |
	/// | odd ≥ 5 | `c^m`, `m = (k−1)/2` | `m·c^(m−1)` |
	/// | even ≥ 6 | `c^m·L`, `m = k/2 − 1` | `m·c^(m−1)·L + c^m·L'` |
	///
	/// - Parameters:
	///   - y: A probability in the open interval (0, 1).
	///   - terms: How many basis functions to differentiate.
	/// - Returns: One derivative per term, or `nil` outside the open interval.
	static func basisDerivative(at y: Double, terms: Int) -> [Double]? {
		guard y > 0, y < 1 else { return nil }
		let span: Double = y * (1 - y)
		guard span > 0 else { return nil }
		let logit: Double = Foundation.log(y / (1 - y))
		let logitSlope: Double = 1 / span
		let centred: Double = y - 0.5
		var out = [Double](repeating: 0, count: terms)
		for index in 0..<terms {
			let k = index + 1
			switch k {
			case 1: out[index] = 0
			case 2: out[index] = logitSlope
			case 3:
				let carried: Double = centred * logitSlope
				out[index] = logit + carried
			case 4: out[index] = 1
			default:
				if k % 2 == 1 {
					let power = (k - 1) / 2
					let lowered: Double = Foundation.pow(centred, Double(power - 1))
					out[index] = Double(power) * lowered
				} else {
					let power = k / 2 - 1
					let lowered: Double = Foundation.pow(centred, Double(power - 1))
					let raised: Double = Foundation.pow(centred, Double(power))
					let sized: Double = Double(power) * lowered
					let first: Double = sized * logit
					let second: Double = raised * logitSlope
					out[index] = first + second
				}
			}
		}
		return out
	}

	/// `dT/dz` for the boundedness transform, matching ``fromUnbounded(_:_:)``.
	///
	/// - Parameters:
	///   - z: A point on the unbounded scale.
	///   - boundedness: Which transform is in force.
	/// - Returns: The transform's derivative there.
	static func transformDerivative(_ z: Double, _ boundedness: MetalogBoundedness) -> Double {
		switch boundedness {
		case .unbounded:
			return 1
		case .boundedBelow:
			return Foundation.exp(z)
		case .boundedAbove:
			return Foundation.exp(-z)
		case .bounded(let lower, let upper):
			// σ(z)(1 − σ(z)), written through `expit` for the same saturation reason
			// `fromUnbounded` is.
			let weight: Double = 1 / (1 + Foundation.exp(-z))
			let complement: Double = 1 - weight
			let range: Double = upper - lower
			let bell: Double = weight * complement
			return range * bell
		}
	}
}

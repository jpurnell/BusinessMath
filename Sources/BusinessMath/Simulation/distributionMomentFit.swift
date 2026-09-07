//
//  distributionMomentFit.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Which member of the Johnson system a set of moments selects.
public enum JohnsonFamily: Sendable, Equatable {

	/// Skew zero and kurtosis three: the normal itself.
	case normal

	/// On the lognormal line. Bounded on one side, unbounded on the other.
	case lognormal

	/// Below the lognormal line: bounded on both sides.
	case bounded

	/// Above the lognormal line: unbounded, with tails heavier than a lognormal's.
	case unbounded
}

/// Why a set of moments could not be fitted.
public enum MomentFitError: Error, Sendable, Equatable {

	/// The standard deviation was zero, negative or not finite.
	case nonPositiveStandardDeviation

	/// The mean, skewness or kurtosis was not finite.
	case nonFiniteMoment

	/// `kurtosis ≤ skewness² + 1`, which no distribution satisfies.
	///
	/// The inequality `β₂ > β₁ + 1` is a theorem, not a limitation of this family:
	/// it follows from `Var[(X − μ)²] ≥ 0`. A request below the line describes
	/// nothing, and the moments were most likely estimated from too small a sample.
	case impossibleMoments(skewness: Double, kurtosis: Double)

	/// The shape solve did not converge from any starting point tried.
	case didNotConverge
}

/// A distribution fitted to a mean, standard deviation, skewness and kurtosis.
///
/// Someone with four summary statistics and no sample can still simulate, and this is
/// how. It binds Risk Solver's `PsiMomentFit`.
///
/// ```swift
/// // Right-skewed with fat tails — a loss distribution.
/// let fitted = try DistributionMomentFit(mean: 100, standardDeviation: 25,
///                                        skewness: 1.2, kurtosis: 6.0)
/// print(fitted.family)      // .unbounded  (Johnson SU)
/// print(fitted.quantile(0.99))
/// ```
///
/// ## The moments are matched, not approximated
///
/// The Johnson system exists precisely for this: its four parameters are in
/// one-to-one correspondence with the first four moments, so a fit **reproduces
/// them**. That makes the routine self-certifying — ``mean``, ``standardDeviation``,
/// ``skewness`` and ``kurtosis`` are the values asked for, and the moments of a large
/// sample must agree with them.
///
/// This is why the Johnson system is used here rather than a Cornish–Fisher expansion
/// of the quantile, which is simpler and much more common. Cornish–Fisher matches the
/// requested moments only asymptotically, so a routine built on it would return a
/// distribution whose moments are *not* the ones requested while being named after
/// them — a plausible-but-wrong answer of exactly the kind this package refuses.
///
/// ## Which family, and why the choice is forced
///
/// The four moments select the member; nothing is chosen by preference. Writing
/// `β₁ = skewness²` and `β₂ = kurtosis`, the **lognormal line** divides the plane. Its
/// position for a given skewness comes from solving `(ω + 2)²(ω − 1) = β₁`, after
/// which the line sits at `ω⁴ + 2ω³ + 3ω² − 3`:
///
/// - above it, the tails are too heavy for a bounded family → **Johnson SU**;
/// - below it, they are too light for an unbounded one → **Johnson SB**;
/// - on it → **lognormal**;
/// - and `β₁ = 0, β₂ = 3` is the normal.
///
/// Below `β₂ = β₁ + 1` there is nothing at all: that inequality follows from
/// `Var[(X − μ)²] ≥ 0` and holds for every distribution that has four moments. A
/// request there throws ``MomentFitError/impossibleMoments(skewness:kurtosis:)``
/// rather than returning the nearest feasible thing, because the nearest feasible
/// thing is an answer to a question nobody asked.
///
/// ## Kurtosis is not excess kurtosis
///
/// `kurtosis` here is `E[(X − μ)⁴]/σ⁴`, which is **3** for a normal. Many tools report
/// excess kurtosis, which is that minus three. Passing an excess value of 3.0 asks for
/// something far more peaked than intended, and passing 0.0 asks for the impossible.
public struct DistributionMomentFit: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The mean that was requested and is reproduced.
	public let mean: Double

	/// The standard deviation that was requested and is reproduced.
	public let standardDeviation: Double

	/// The skewness that was requested and is reproduced.
	public let skewness: Double

	/// The kurtosis that was requested and is reproduced. Three for a normal.
	public let kurtosis: Double

	/// Which member of the system the moments selected.
	public let family: JohnsonFamily

	/// The fitted shape parameters, `γ` then `δ`, of the standardised member.
	public let shape: (gamma: Double, delta: Double)

	/// Whether the fit was performed on the mirrored variate.
	///
	/// The system is fitted for non-negative skewness and reflected afterwards, which
	/// halves the search space and costs nothing: reflection negates odd moments and
	/// leaves even ones alone.
	private let reflected: Bool

	/// `X = location + scale · W`, the affine map putting the standardised member on
	/// the requested mean and standard deviation.
	private let location: Double
	private let scale: Double

	// MARK: - Construction

	/// Fits a distribution to four moments.
	///
	/// - Parameters:
	///   - mean: The first moment.
	///   - standardDeviation: The second, strictly positive.
	///   - skewness: The standardised third moment. Zero is symmetric.
	///   - kurtosis: The standardised fourth moment, **not** excess: three for a
	///     normal.
	/// - Throws: ``MomentFitError`` naming which argument was rejected, or
	///   ``MomentFitError/didNotConverge`` if the shape solve failed.
	public init(mean: Double,
				standardDeviation: Double,
				skewness: Double = 0,
				kurtosis: Double = 3) throws {
		guard standardDeviation > 0, standardDeviation.isFinite else {
			throw MomentFitError.nonPositiveStandardDeviation
		}
		guard mean.isFinite, skewness.isFinite, kurtosis.isFinite else {
			throw MomentFitError.nonFiniteMoment
		}

		let beta1: Double = skewness * skewness
		// The theorem, not a family limitation. Equality is the two-point
		// distribution, which has no density to sample from.
		guard kurtosis > beta1 + 1 else {
			throw MomentFitError.impossibleMoments(skewness: skewness, kurtosis: kurtosis)
		}

		self.mean = mean
		self.standardDeviation = standardDeviation
		self.skewness = skewness
		self.kurtosis = kurtosis

		let mirrored = skewness < 0
		self.reflected = mirrored
		let targetSkew: Double = mirrored ? -skewness : skewness

		let selected = Self.selectFamily(skewness: targetSkew, kurtosis: kurtosis)
		self.family = selected

		let solved = try Self.solveShape(family: selected, skewness: targetSkew, kurtosis: kurtosis)
		self.shape = solved

		// The standardised member has whatever mean and spread it has; the affine map
		// is what makes the first two moments the requested ones. Skewness and
		// kurtosis are invariant under a positive affine map, so fixing them first and
		// the location and scale second is exact rather than iterative.
		let moments = Self.standardisedMoments(family: selected, gamma: solved.gamma, delta: solved.delta)
		guard moments.variance > 0, moments.variance.isFinite else {
			throw MomentFitError.didNotConverge
		}
		let spread: Double = moments.variance.squareRoot()
		let mappedScale: Double = standardDeviation / spread
		self.scale = mappedScale

		// The variate the quantile actually evaluates is `±W`, and reflection negates
		// its mean while leaving its variance alone. Centring on the unreflected mean
		// puts every left-skewed fit off by `2·scale·E[W]` — which is invisible in the
		// skewness and kurtosis, since those are what the shape solve fixed, and shows
		// up only in the first moment the routine is named for.
		let effectiveMean: Double = mirrored ? -moments.mean : moments.mean
		self.location = mean - mappedScale * effectiveMean
	}

	// MARK: - The distribution

	/// The value below which a draw falls with probability `p`.
	///
	/// - Parameter p: A probability in the open interval (0, 1).
	/// - Returns: The quantile.
	public func quantile(_ p: Double) -> Double {
		guard p > 0, p < 1 else { return p <= 0 ? -.infinity : .infinity }
		// Reflection swaps the tails, so the mirrored fit is read from the opposite
		// end of the probability scale.
		let effective: Double = reflected ? 1 - p : p
		let z: Double = inverseNormalCDF(p: effective, mean: 0, stdDev: 1)
		let w: Double = Self.transform(family: family, z: z, gamma: shape.gamma, delta: shape.delta)
		let signed: Double = reflected ? -w : w
		return location + scale * signed
	}

	/// The probability that a draw falls at or below `x`.
	///
	/// - Parameter x: Any value.
	/// - Returns: A probability in [0, 1].
	public func cdf(_ x: Double) -> Double {
		guard x.isFinite else { return x > 0 ? 1 : 0 }
		guard scale > 0 else { return 0 }
		let standardised: Double = (x - location) / scale
		let w: Double = reflected ? -standardised : standardised
		guard let z = Self.inverseTransform(family: family, w: w, gamma: shape.gamma, delta: shape.delta) else {
			// Outside the support of a bounded member.
			let belowSupport: Bool = w <= 0
			let answer: Double = belowSupport ? 0 : 1
			return reflected ? 1 - answer : answer
		}
		let probability: Double = normalCDF(x: z, mean: 0, stdDev: 1)
		return reflected ? 1 - probability : probability
	}

	// MARK: - Family selection

	/// The kurtosis of the lognormal with the given skewness — the dividing line.
	static func lognormalLineKurtosis(skewness: Double) -> Double {
		guard skewness > 0 else { return 3 }
		let beta1: Double = skewness * skewness
		// `(ω + 2)²(ω − 1)` increases strictly on ω > 1, so bisection is exact enough
		// and cannot pick the wrong root.
		var low = 1.0
		var high = 2.0
		while Self.lognormalBeta1(high) < beta1 && high < 1e6 { high *= 2 }
		for _ in 0..<200 {
			let middle: Double = (low + high) / 2
			if Self.lognormalBeta1(middle) < beta1 { low = middle } else { high = middle }
		}
		let omega: Double = (low + high) / 2
		let squared: Double = omega * omega
		let cubed: Double = squared * omega
		let fourth: Double = squared * squared
		return fourth + 2 * cubed + 3 * squared - 3
	}

	static func lognormalBeta1(_ omega: Double) -> Double {
		let offset: Double = omega + 2
		return offset * offset * (omega - 1)
	}

	static func selectFamily(skewness: Double, kurtosis: Double) -> JohnsonFamily {
		if skewness == 0 && abs(kurtosis - 3) < 1e-12 { return .normal }
		let line = lognormalLineKurtosis(skewness: skewness)
		if abs(kurtosis - line) < 1e-9 { return .lognormal }
		return kurtosis > line ? .unbounded : .bounded
	}

	// MARK: - The standardised members

	/// `W = f((z − γ)/δ)` for the selected member.
	static func transform(family: JohnsonFamily, z: Double, gamma: Double, delta: Double) -> Double {
		let inner: Double = (z - gamma) / delta
		switch family {
		case .normal: return z
		case .unbounded: return Foundation.sinh(inner)
		case .lognormal: return Foundation.exp(inner)
		case .bounded: return 1 / (1 + Foundation.exp(-inner))
		}
	}

	/// The inverse, or `nil` where `w` is outside the member's support.
	static func inverseTransform(family: JohnsonFamily, w: Double, gamma: Double, delta: Double) -> Double? {
		switch family {
		case .normal:
			return w
		case .unbounded:
			return gamma + delta * Foundation.asinh(w)
		case .lognormal:
			guard w > 0 else { return nil }
			return gamma + delta * Foundation.log(w)
		case .bounded:
			guard w > 0, w < 1 else { return nil }
			return gamma + delta * Foundation.log(w / (1 - w))
		}
	}

	/// The first four moments of the standardised member.
	///
	/// Closed form where one exists, quadrature only for the bounded member — whose
	/// transform is confined to (0, 1), so the integrand is a bounded function times a
	/// normal density and Simpson converges quickly and safely.
	static func standardisedMoments(family: JohnsonFamily, gamma: Double, delta: Double)
	-> (mean: Double, variance: Double, skewness: Double, kurtosis: Double) {
		var raw = [Double](repeating: 0, count: 5)
		raw[0] = 1

		switch family {
		case .normal:
			return (mean: 0, variance: 1, skewness: 0, kurtosis: 3)

		case .unbounded, .lognormal:
			// Both are exponentials of a normal, so every raw moment is a finite sum
			// of `E[e^{t(a + bZ)}] = e^{ta + t²b²/2}`. Exact, and much better
			// conditioned than integrating sinh⁴ against a density.
			let a: Double = -gamma / delta
			let b: Double = 1 / delta
			func exponentialMoment(_ t: Double) -> Double {
				let linear: Double = t * a
				let quadratic: Double = t * t * b * b / 2
				return Foundation.exp(linear + quadratic)
			}
			if family == .lognormal {
				for order in 1...4 { raw[order] = exponentialMoment(Double(order)) }
			} else {
				// sinh(x)^n = 2^-n Σ_j C(n,j)(−1)^j e^{(n−2j)x}
				for order in 1...4 {
					var total = 0.0
					for j in 0...order {
						let coefficient: Double = Double(Self.binomial(order, j))
						let sign: Double = j % 2 == 0 ? 1 : -1
						let power: Double = Double(order - 2 * j)
						total += sign * coefficient * exponentialMoment(power)
					}
					let scaling: Double = Foundation.pow(2.0, Double(order))
                    raw[order] = total / scaling
				}
			}

		case .bounded:
			// Simpson over z, weighted by the normal density. The transform is a
			// logistic, so every power of it lies in (0, 1) and the integrand is
			// dominated by the density — no cancellation, no growth.
			let lower: Double = -12
			let upper: Double = 12
			let steps = 4_000
			let h: Double = (upper - lower) / Double(steps)
			let normaliser: Double = (2 * Double.pi).squareRoot()
			var sums = [Double](repeating: 0, count: 5)
			for step in 0...steps {
				let z: Double = lower + Double(step) * h
				let density: Double = Foundation.exp(-z * z / 2) / normaliser
				let weight: Double
				if step == 0 || step == steps { weight = 1 }
				else if step % 2 == 1 { weight = 4 }
				else { weight = 2 }
				let w: Double = transform(family: .bounded, z: z, gamma: gamma, delta: delta)
				var powered = 1.0
				for order in 1...4 {
					powered *= w
					sums[order] += weight * density * powered
				}
			}
			for order in 1...4 { raw[order] = sums[order] * h / 3 }
		}

		return centralise(raw)
	}

	/// Central moments from raw ones, then standardised.
	static func centralise(_ raw: [Double]) -> (mean: Double, variance: Double, skewness: Double, kurtosis: Double) {
		let m1 = raw[1], m2 = raw[2], m3 = raw[3], m4 = raw[4]
		let variance: Double = m2 - m1 * m1
		guard variance > 0 else { return (m1, 0, 0, 3) }

		let thirdA: Double = m3 - 3 * m1 * m2
		let thirdB: Double = 2 * m1 * m1 * m1
		let third: Double = thirdA + thirdB

		let fourthA: Double = m4 - 4 * m1 * m3
		let fourthB: Double = 6 * m1 * m1 * m2
		let fourthC: Double = 3 * m1 * m1 * m1 * m1
		let fourth: Double = fourthA + fourthB - fourthC

		let sigma: Double = variance.squareRoot()
		let cubedSigma: Double = variance * sigma
		let fourthSigma: Double = variance * variance
		return (mean: m1, variance: variance,
				skewness: third / cubedSigma, kurtosis: fourth / fourthSigma)
	}

	static func binomial(_ n: Int, _ k: Int) -> Int {
		guard k >= 0, k <= n else { return 0 }
		var result = 1
		for step in 0..<Swift.min(k, n - k) {
			result = result * (n - step) / (step + 1)
		}
		return result
	}

	// MARK: - The shape solve

	/// Solves `(γ, δ)` so the standardised member has the requested skewness and
	/// kurtosis.
	///
	/// Two equations in two unknowns, by Newton with a numerical Jacobian. `δ` is
	/// carried as `log δ` so it cannot step to zero or below, which is where the
	/// transforms lose their meaning.
	static func solveShape(family: JohnsonFamily, skewness: Double, kurtosis: Double) throws
	-> (gamma: Double, delta: Double) {
		if family == .normal { return (gamma: 0, delta: 1) }

		if family == .lognormal {
			// One free shape parameter, and skewness alone fixes it — there is nothing
			// to iterate on.
			var low = 1.0 + 1e-12
			var high = 2.0
			let beta1: Double = skewness * skewness
			while lognormalBeta1(high) < beta1 && high < 1e6 { high *= 2 }
			for _ in 0..<200 {
                let middle: Double = (low + high) / 2
                if lognormalBeta1(middle) < beta1 { low = middle } else { high = middle }
			}
			let omega: Double = (low + high) / 2
			let logOmega: Double = Foundation.log(omega)
			guard logOmega > 0 else { throw MomentFitError.didNotConverge }
			let delta: Double = 1 / logOmega.squareRoot()
			return (gamma: 0, delta: delta)
		}

		func residual(_ gamma: Double, _ logDelta: Double) -> (Double, Double)? {
			let delta: Double = Foundation.exp(logDelta)
			guard delta.isFinite, delta > 0 else { return nil }
			let moments = standardisedMoments(family: family, gamma: gamma, delta: delta)
			guard moments.skewness.isFinite, moments.kurtosis.isFinite else { return nil }
			return (moments.skewness - skewness, moments.kurtosis - kurtosis)
		}

		// Several starting points rather than one clever one. The residual surface is
		// smooth but not globally convex, and a fixed start fails on perfectly ordinary
		// moment sets; trying a spread of them is cheaper than a globalisation strategy
		// and easier to reason about.
		let gammaStarts: [Double] = [0, -0.5, 0.5, -1.5, 1.5, -3, 3]
        let deltaStarts: [Double] = [0.5, 1.0, 2.0, 4.0, 0.25]

		for gammaStart in gammaStarts {
			for deltaStart in deltaStarts {
				var gamma = gammaStart
				var logDelta = Foundation.log(deltaStart)
				var converged = false

				for _ in 0..<200 {
					guard let (f1, f2) = residual(gamma, logDelta) else { break }
					if abs(f1) < 1e-10 && abs(f2) < 1e-10 { converged = true; break }

					let step = 1e-6
					guard let (g1, g2) = residual(gamma + step, logDelta),
						  let (h1, h2) = residual(gamma, logDelta + step) else { break }
					let j11: Double = (g1 - f1) / step
					let j12: Double = (h1 - f1) / step
					let j21: Double = (g2 - f2) / step
					let j22: Double = (h2 - f2) / step

					let determinant: Double = j11 * j22 - j12 * j21
					guard abs(determinant) > 1e-14 else { break }
					let deltaGamma: Double = (f1 * j22 - f2 * j12) / determinant
					let deltaLog: Double = (f2 * j11 - f1 * j21) / determinant

					// Damped: an undamped Newton step from a poor start routinely
					// throws `logDelta` far enough that the moments overflow.
					var damping = 1.0
					var accepted = false
					for _ in 0..<20 {
						let trialGamma: Double = gamma - damping * deltaGamma
						let trialLog: Double = logDelta - damping * deltaLog
						if let (t1, t2) = residual(trialGamma, trialLog),
						   abs(t1) + abs(t2) < abs(f1) + abs(f2) {
							gamma = trialGamma
							logDelta = trialLog
							accepted = true
							break
						}
						damping /= 2
					}
					guard accepted else { break }
				}

				if converged {
					let delta: Double = Foundation.exp(logDelta)
					if delta.isFinite, delta > 0 { return (gamma: gamma, delta: delta) }
				}
			}
		}
		throw MomentFitError.didNotConverge
	}
}

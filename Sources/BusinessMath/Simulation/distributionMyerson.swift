//
//  distributionMyerson.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A Myerson distribution: a three-point elicitation turned into a continuous one.
///
/// Someone who knows a business well can rarely name a distribution, but can usually
/// name three numbers — a low case, a most-likely case and a high case — and say how
/// confident they are in the outer two. The Myerson distribution is the standard way
/// to turn that into something you can sample.
///
/// Binds Risk Solver's `PsiMyerson(low, mode, high, probability)`.
///
/// ```swift
/// // A revenue forecast: 5th percentile 80, median 100, 95th percentile 150.
/// if let revenue = DistributionMyerson(low: 80, mode: 100, high: 150) {
///     print(revenue.quantile(0.5))    // 100.0 — the mode is the median
///     print(revenue.quantile(0.05))   // 80.0
///     print(revenue.quantile(0.95))   // 150.0
/// }
/// ```
///
/// ## What it is underneath
///
/// A shifted lognormal, chosen so the three elicited points land exactly where they
/// were elicited. Writing `z` for the standard normal quantile at the confidence
/// level and `b = (high − mode)/(mode − low)` for the asymmetry:
///
/// ```
/// Q(p) = mode + (high − mode) · (b^(Φ⁻¹(p)/z) − 1) / (b − 1)      b ≠ 1
/// Q(p) = mode + (high − low)/(2z) · Φ⁻¹(p)                        b = 1
/// ```
///
/// The `b = 1` branch is not a special case bolted on: when the two arms are equal
/// the general form is `0/0`, and its limit is exactly the normal distribution above.
/// A symmetric elicitation gives a symmetric distribution, which is the answer anyone
/// would expect and is worth having fall out of the algebra rather than being
/// asserted.
///
/// ## Why the three points come back exactly
///
/// This is the whole point of the family, and it is checkable without reference to
/// any other implementation — §2.2 of the coverage proposal. At `p = 0.5`,
/// `Φ⁻¹(p) = 0`, so `b⁰ = 1` and the numerator vanishes: `Q(0.5) = mode`. At the
/// upper confidence point `Φ⁻¹(p) = z`, so `b¹ = b` and the fraction is 1:
/// `Q = mode + (high − mode) = high`. At the lower point the same algebra gives
/// `mode − (mode − low) = low`.
///
/// So the elicited numbers are not fitted, they are reproduced. `DistributionMyerson`
/// is exact where a moment-matched alternative would be approximate.
///
/// ## Support
///
/// Unbounded on the long side and bounded on the short one, which is what makes it
/// suitable for quantities that cannot go below zero but have no ceiling — revenue,
/// duration, cost. For a right-skewed elicitation (`b > 1`) the lower bound is
/// `mode − (high − mode)/(b − 1)`; for a left-skewed one the bound is above. A
/// symmetric elicitation is unbounded both ways, being a normal.
public struct DistributionMyerson: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The low case, returned exactly by `quantile((1 − probability)/2)`.
	public let low: Double

	/// The most likely case, which is also the median.
	public let mode: Double

	/// The high case, returned exactly by `quantile(1 − (1 − probability)/2)`.
	public let high: Double

	/// The confidence that a draw falls between `low` and `high`.
	public let probability: Double

	/// `Φ⁻¹` at the upper confidence point — the `z` in the formulas above.
	private let z: Double

	/// `(high − mode)/(mode − low)`, the asymmetry of the elicitation.
	///
	/// Greater than one means the upper arm is longer, which is the usual shape for a
	/// quantity with a floor and no ceiling.
	public let asymmetry: Double

	/// Whether the two arms are equal to working precision, in which case the
	/// distribution is normal and the general formula is `0/0`.
	private let isSymmetric: Bool

	/// `high − mode`, and `1/(b − 1)` and `1/log(b)` for the asymmetric branch —
	/// formed once here, beside the guards that prove each divisor non-zero.
	private let upperArm: Double
	private let inverseAsymmetryLessOne: Double
	private let inverseLogAsymmetry: Double
	/// `b − 1`, kept alongside its reciprocal so the CDF can use `log1p` on it.
	private let asymmetryLessOne: Double
	/// `log b`, computed as `log1p(b − 1)` so it stays exact as `b` approaches 1.
	private let logAsymmetry: Double

	/// The standard deviation of the normal branch, `(high − low)/(2z)`.
	private let symmetricScale: Double

	/// `1/z`, `1/symmetricScale` and `1/upperArm`, formed once in the initialiser
	/// where the guards proving each divisor non-zero sit on the adjacent lines. The
	/// hot paths then multiply, keeping each division beside the invariant that makes
	/// it safe instead of leaving a bare divide far from its proof.
	private let inverseZ: Double
	private let inverseSymmetricScale: Double
	private let inverseUpperArm: Double

	/// Creates a Myerson distribution from a three-point elicitation.
	///
	/// - Parameters:
	///   - low: The low case. Must be strictly below `mode`.
	///   - mode: The most likely case, which becomes the median.
	///   - high: The high case. Must be strictly above `mode`.
	///   - probability: The confidence that a draw lies between `low` and `high`,
	///     in the open interval (0, 1). Defaults to 0.9, so `low` and `high` are the
	///     5th and 95th percentiles — the convention Risk Solver uses and the one
	///     most elicitation protocols are written around.
	/// - Returns: `nil` unless `low < mode < high` and every value is finite, or if
	///   `probability` is outside (0, 1). A collapsed arm is refused rather than
	///   nudged: `mode == low` means the elicitation says the median is also the
	///   lower confidence bound, which is not a statement this family can represent,
	///   and inventing a small positive width would answer a question nobody asked.
	public init?(low: Double, mode: Double, high: Double, probability: Double = 0.9) {
		guard low.isFinite, mode.isFinite, high.isFinite else { return nil }
		guard low < mode, mode < high else { return nil }
		guard probability > 0, probability < 1 else { return nil }

		self.low = low
		self.mode = mode
		self.high = high
		self.probability = probability

		// The upper confidence point. For probability 0.9 this is Φ⁻¹(0.95) ≈ 1.6449.
		let upperTail: Double = (1 - probability) / 2
		let quantilePoint: Double = 1 - upperTail
		let zValue: Double = inverseNormalCDF(p: quantilePoint, mean: 0, stdDev: 1)
		guard zValue.isFinite, zValue > 0 else { return nil }
		self.z = zValue

		let lowerArm: Double = mode - low
		let upper: Double = high - mode
		guard lowerArm > 0, upper > 0 else { return nil }
		self.upperArm = upper

		let ratio: Double = upper / lowerArm
		guard ratio.isFinite, ratio > 0 else { return nil }
		self.asymmetry = ratio

		// Only where `b − 1` is not a normal number: zero, subnormal, or non-finite. Those
		// are exactly the offsets whose reciprocal overflows, and they are the only ones the
		// general form cannot handle.
		//
		// The window used to be `1e-9`, on the reasoning that the general formula lost more
		// to cancellation in `b − 1` than the limit lost by being a limit. That was true of
		// the formula as written — `pow(b, r) − 1` discards the information the answer is
		// made of when `b` is near 1 — and it made the branch *least* accurate exactly where
		// it handed over. Measured at `b − 1 = 1e-9`, the quantile sat 4.89e-6 from the
		// limit where the perturbation justifies 5e-8: about a hundred times too far.
		//
		// `expm1(r · log1p(b − 1))` never forms `bʳ` and never subtracts 1 from something
		// near 1, so it is exact to rounding at any `b`, and the window can close to nothing.
		let symmetric = !(ratio - 1).isNormal
		self.isSymmetric = symmetric

		let span: Double = high - low
		let twiceZ: Double = 2 * zValue
		guard twiceZ > 0 else { return nil }
		let scale: Double = span / twiceZ
		guard scale > 0 else { return nil }
		self.symmetricScale = scale
		self.inverseZ = 1 / zValue
		self.inverseSymmetricScale = 1 / scale
		self.inverseUpperArm = 1 / upper

		if symmetric {
			self.inverseAsymmetryLessOne = 0
			self.inverseLogAsymmetry = 0
			self.asymmetryLessOne = 0
			self.logAsymmetry = 0
		} else {
			let offset: Double = ratio - 1
			// `log1p(b − 1)` rather than `log(b)`: the two agree away from 1, and only the
			// first keeps its significant digits as `b` approaches it.
			let logRatio: Double = Foundation.log1p(offset)
			guard offset != 0, logRatio != 0, logRatio.isFinite else { return nil }
			self.inverseAsymmetryLessOne = 1 / offset
			self.inverseLogAsymmetry = 1 / logRatio
			self.asymmetryLessOne = offset
			self.logAsymmetry = logRatio
		}
	}

	/// The value below which a draw falls with probability `p`.
	///
	/// - Parameter p: A probability in the open interval (0, 1).
	/// - Returns: The quantile. Exactly `low`, `mode` and `high` at the three
	///   elicited probabilities.
	public func quantile(_ p: Double) -> Double {
		guard p > 0, p < 1 else { return p <= 0 ? -Double.infinity : Double.infinity }
		let standard: Double = inverseNormalCDF(p: p, mean: 0, stdDev: 1)
		guard standard.isFinite else { return standard > 0 ? Double.infinity : -Double.infinity }

		if isSymmetric {
			return mode + symmetricScale * standard
		}
		let exponent: Double = standard * inverseZ
		// `bʳ − 1` written so the subtraction never happens. `pow(b, r) - 1` loses every
		// significant digit when `bʳ` is near 1, which is the whole near-symmetric regime.
		let scaled: Double = exponent * logAsymmetry
		let shifted: Double = Foundation.expm1(scaled)
		return mode + upperArm * shifted * inverseAsymmetryLessOne
	}

	/// The probability that a draw falls at or below `x`.
	///
	/// - Parameter x: Any finite value. Outside the support this returns 0 or 1
	///   rather than failing.
	/// - Returns: A probability in [0, 1].
	public func cdf(_ x: Double) -> Double {
		guard x.isFinite else { return x > 0 ? 1 : 0 }

		if isSymmetric {
			let deviation: Double = x - mode
			let standardised: Double = deviation * inverseSymmetricScale
			return normalCDF(x: standardised, mean: 0, stdDev: 1)
		}

		// Invert the quantile: b^(Φ⁻¹(p)/z) = 1 + (x − mode)(b − 1)/(high − mode).
		let deviation: Double = x - mode
		let scaled: Double = deviation * inverseUpperArm
		let displacement: Double = scaled * asymmetryLessOne
		let inner: Double = 1 + displacement

		// Off the bounded end of the support. The bound is where `inner` reaches zero,
		// and beyond it there is no `p` to solve for — the distribution simply does not
		// reach. Answering 0 or 1 is the protocol's requirement and is also the truth.
		guard inner > 0 else { return asymmetry > 1 ? 0 : 1 }

		// `log1p` on the displacement, matching `expm1` in the quantile: the two are
		// inverses of each other and both avoid forming a value near 1 only to take its
		// logarithm.
		let logInner: Double = Foundation.log1p(displacement)
		let standard: Double = z * logInner * inverseLogAsymmetry
		return normalCDF(x: standard, mean: 0, stdDev: 1)
	}
}

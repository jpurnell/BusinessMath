//
//  distributionHypSecant.swift
//  BusinessMath
//

import Foundation
import Numerics

/// `π/2`, which needs no division by a variable.
private let piOverTwo: Double = Double.pi / 2

/// `2/π`, formed once at file scope.
///
/// The guard is not ceremony even though `Double.pi` is a constant: it is the one place
/// the invariant behind every use of this value is stated, and it makes the division
/// total rather than resting on a fact stated only in a comment. Naming the ratio here
/// also keeps it out of the hot paths, which multiply by it.
private let twoOverPi: Double = {
	let halfTurn = Double.pi
	guard halfTurn > 0 else { return 0 }
	return 2 / halfTurn
}()

/// A hyperbolic secant distribution: symmetric, bell-shaped, and heavier in the tails
/// than a normal.
///
/// Binds Risk Solver's `PsiHypSecant(loc, scale)`.
///
/// ```swift
/// if let error = DistributionHypSecant(loc: 0, scale: 1) {
///     print(error.cdf(0))   // 0.5 — symmetric about loc
/// }
/// ```
///
/// ## `scale` is the standard deviation here, and is not in SciPy
///
/// This is the parameterisation trap the coverage proposal warns about in §2.1, and it
/// is worth stating plainly because both conventions look identical from the outside.
///
/// The *standard* hyperbolic secant has density `1/(π·cosh x)` and quantile
/// `ln(tan(πu/2))`. `scipy.stats.hypsecant(loc, scale)` shifts and stretches that
/// directly, so its `scale` is a plain scale factor. Frontline's quantile instead reads
///
/// ```
/// Q(u) = loc + scale·(2/π)·ln(tan(πu/2))
/// ```
///
/// and that extra `2/π` is not decoration. The standard form has variance `π²/4`, so
/// dividing by `π/2` normalises it to variance one — which makes **Frontline's `scale`
/// the standard deviation**.
///
/// Binding Frontline's argument straight to SciPy's would produce a distribution too
/// wide by a factor of `π/2 ≈ 1.571`. Worse, a test that converted both sides the same
/// wrong way would agree perfectly and prove nothing, which is exactly the failure §2.1
/// describes. `hypSecantScaleIsStandardDeviation` measures the sample standard
/// deviation against the argument to pin the convention down.
///
/// ## The formulas
///
/// ```
/// Q(u) = loc + (2·scale/π)·ln(tan(πu/2))
/// F(x) = (2/π)·arctan(exp(π·(x − loc)/(2·scale)))
/// ```
///
/// The second is the first rearranged, and the pair round-trips by construction.
public struct DistributionHypSecant: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The centre of the distribution, which is also its mean and median.
	public let loc: Double

	/// The standard deviation — see the note on the type. Positive.
	public let scale: Double

	/// Creates a hyperbolic secant distribution.
	///
	/// - Parameters:
	///   - loc: The centre. Any finite value.
	///   - scale: The **standard deviation**, positive and finite. Not SciPy's scale
	///     parameter; the two differ by `π/2`.
	/// - Returns: `nil` if `scale` is not positive and finite, or if `loc` is not
	///   finite.
	public init?(loc: Double, scale: Double) {
		guard loc.isFinite, scale > 0, scale.isFinite else { return nil }
		self.loc = loc
		self.scale = scale

		// `spread` is the 2·scale/π of the quantile formula, which is just
		// `scale · (2/π)`. Formed here, on the line after the guard proving `scale`
		// positive, so `cdf` and `quantile` multiply rather than divide.
		let widened: Double = scale * twoOverPi
		guard widened > 0 else { return nil }
		self.spread = widened
		self.inverseSpread = 1 / widened
	}

	/// `2·scale/π`, the multiplier in the quantile formula.
	private let spread: Double

	/// `1/spread`, used by ``cdf(_:)``.
	private let inverseSpread: Double

	/// P(X ≤ x).
	public func cdf(_ x: Double) -> Double {
		let exponent: Double = (x - loc) * inverseSpread
		// `exp` overflows to infinity for an exponent past about 710, where `atan(∞)`
		// is π/2 and the CDF is 1 — the correct limit, reached without a NaN.
		let scaled: Double = Foundation.atan(Foundation.exp(exponent))
		return scaled * twoOverPi
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability in the open interval (0, 1). The support is
	///   unbounded, so the endpoints are infinite; they return ∓`Double.infinity`
	///   rather than a NaN, which is the honest answer to `quantile(0)`.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return -.infinity }
		guard p < 1 else { return .infinity }
		let angle: Double = p * piOverTwo
		let tangent: Double = Foundation.tan(angle)
		let standardised: Double = Foundation.log(tangent)
		return loc + spread * standardised
	}
}

//
//  besselI.swift
//  BusinessMath
//
//  The modified first kind. Excel calls it BESSELI.
//

import Foundation
import Numerics

/// The modified Bessel function of the first kind, Iₙ(x).
///
/// Iₙ solves the modified equation
///
/// ```
/// x²y″ + xy′ − (x² + n²)y = 0
/// ```
///
/// and is what Jₙ becomes on the imaginary axis: Iₙ(x) = i^(−n)Jₙ(ix). It does not
/// oscillate. It is positive and increasing for x > 0, growing like e^x/√(2πx), so
/// it leaves `Double`'s range a little past x = 713.
///
/// ```swift
/// let i2: Double = besselI(x: 1.5, order: 2)   // 0.3378346183…
/// let i0: Double = besselI(x: 0.0, order: 0)   // exactly 1
/// ```
///
/// ## Method
///
/// One method at every argument and order: the ascending series
///
/// ```
/// Iₙ(x) = Σₖ (x/2)^(n+2k) / (k!·(n+k)!)
/// ```
///
/// Every term is positive, so unlike its alternating counterpart in
/// ``besselJ(x:order:)`` there is no cancellation to escape, at any argument. That
/// removes the whole reason J needs three regimes — and with it the single most
/// likely defect in this family, a Miller normalisation that is off by a constant
/// factor, because there is no normalisation at all.
///
/// The sum is carried relative to its own leading term with the scale kept in
/// logarithms, so neither (x/2)ⁿ/n! nor the running sum needs to be representable.
/// Only the answer does. The cost is one exp/log round trip, worth about ε·|ln Iₙ|
/// — under 2e-13 even at the top of the range, and nearer 1e-16 for ordinary
/// arguments.
///
/// ### Negative x, and overflow
///
/// Iₙ(−x) = (−1)ⁿIₙ(x); Excel agrees, returning `-0.981666428` for
/// `BESSELI(-1.5, 1)` where an absolute-value reading would give `+0.981666429`.
///
/// An overflowing result returns `T.infinity` rather than `T.nan`. That is the true
/// limit, correctly signed, and it stays distinguishable from the invalid-input
/// case.
///
/// ## Accuracy
///
/// Better than 1.8e-13 relative, measured against a 30-digit `mpmath` reference
/// over 15,000 argument-order pairs spanning 1e-6 to 3000 and orders 0 to 200 —
/// see `BesselFunctionsTests`. Results in the subnormal range carry fewer than 53
/// significant bits by construction and are not held to that figure.
///
/// - Parameters:
///   - x: The argument. Any finite value.
///   - n: The order. Must be non-negative.
/// - Returns: Iₙ(x), `T.infinity` on overflow, or `T.nan` if `n` is negative or `x`
///   is NaN or infinite.
///
/// ## See Also
/// - ``besselK(x:order:)``
/// - ``besselJ(x:order:)``
public func besselI<T: Real>(x: T, order n: Int) -> T {
	guard n >= 0 else { return T.nan }
	guard !x.isNaN, x.isFinite else { return T.nan }

	if x < T.zero {
		let magnitude: T = besselI(x: -x, order: n)
		return n % 2 == 0 ? magnitude : -magnitude
	}
	if x == T.zero { return n == 0 ? T(1) : T.zero }

	return besselAscendingSeries(x: x, order: n, alternating: false)
}

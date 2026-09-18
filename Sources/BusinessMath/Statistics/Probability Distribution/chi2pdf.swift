//
//  chi2pdf.swift
//  
//
//  Created by Justin Purnell on 6/11/22.
//

import Foundation
import Numerics

/// Deprecated. This function does not compute a density.
///
/// Its body summed the density at 0.001, 0.002, … up to `x` and multiplied by the step: a
/// left-hand Riemann sum of the integral, which is the **cumulative** function. Measured:
///
/// | call | answered | the density there |
/// |---|---|---|
/// | `chi2pdf(x: 0.5, dF: 1)` | 0.5023 | 0.4394 |
/// | `chi2pdf(x: 10, dF: 3)` | 0.9814 | 0.0085 |
/// | `chi2pdf(x: 100, dF: 3)` | 0.99999 | ~1e-21 |
///
/// The last row is the clearest: where a CDF saturates, a density vanishes.
///
/// It was also O(x) — `chi2pdf(x: 1000, dF: 3)` ran a million iterations — and derived that
/// iteration count by rendering a `Double` to a string and parsing it back as an integer.
///
/// ## This was found once before and fixed in the wrong direction
///
/// `chi2cdf` used to be `1 - chi2pdf(x:dF:)`. That was recognised as nonsense, `chi2cdf` was
/// deleted and ``chiSquaredCDF(x:df:)`` written to replace it — and `chi2pdf` was left
/// exported and wrong. A module holding a correct CDF and a misnamed one is worse than one
/// holding neither, because the pair looks deliberate.
///
/// ## What to call instead
///
/// - A **density**: ``chiSquaredPDF(x:df:)``, or `DistributionChiSquared.pdf(_:)`.
/// - The **cumulative** function, which is what this actually approximated:
///   ``chiSquaredCDF(x:df:)`` — exact, and not a Riemann sum.
///
/// - Parameters:
///   - x: The value at which to evaluate.
///   - dF: The degrees of freedom.
/// - Returns: The density, by way of ``chiSquaredPDF(x:df:)``. **This is a different number
///   from the one previous versions returned**, because the previous number was wrong.
@available(*, deprecated, message: "chi2pdf computed a cumulative sum, not a density. Use chiSquaredPDF(x:df:) for the density, or chiSquaredCDF(x:df:) for what this actually approximated.")
public func chi2pdf<T: Real>(x: T, dF: Int) -> T {
	// Delegates rather than keeping the old body, so a caller who does not read the warning
	// still gets a correct answer. The unbounded point at zero becomes infinity here, where
	// the free function throws, because this signature has no way to report it.
	guard let density = try? chiSquaredPDF(x: x, df: dF) else {
		guard x == T.zero, dF < 2, dF > 0 else { return T.zero }
		return T.infinity
	}
	return density
}

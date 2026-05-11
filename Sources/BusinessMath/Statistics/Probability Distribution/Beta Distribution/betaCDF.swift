import Foundation
import Numerics

/// Cumulative distribution function of the Beta distribution.
///
/// Computes P(X <= x | alpha, beta) = I_x(alpha, beta) where I_x is the regularized
/// incomplete beta function.
///
/// - Parameters:
///   - x: Value at which to evaluate the CDF, in [0, 1].
///   - alpha: First shape parameter (> 0).
///   - beta: Second shape parameter (> 0).
/// - Returns: Probability P(X <= x) in [0, 1].
/// - Throws: ``BusinessMathError/invalidInput(message:value:expectedRange:)``
///   if `x` is outside [0, 1] or `alpha`/`beta` <= 0.
public func betaCDF<T: Real>(x: T, alpha: T, beta: T) throws -> T {
	return try regularizedIncompleteBeta(x: x, a: alpha, b: beta)
}

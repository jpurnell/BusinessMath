import Foundation
import Numerics

/// Natural logarithm of the Beta function.
///
/// Computed as `ln(B(a, b)) = ln(Γ(a)) + ln(Γ(b)) - ln(Γ(a+b))`,
/// using the log-gamma function for numerical stability with large parameters.
///
/// - Parameters:
///   - a: First shape parameter (a > 0).
///   - b: Second shape parameter (b > 0).
/// - Returns: ln(B(a, b))
public func logBeta<T: Real>(_ a: T, _ b: T) -> T {
	return T.logGamma(a) + T.logGamma(b) - T.logGamma(a + b)
}

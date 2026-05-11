import Foundation
import Numerics

/// A variance component estimated from a generalizability study (G-study).
///
/// Each component represents the estimated variance attributable to a specific
/// source of variation (e.g., persons, raters, person-by-rater interaction).
///
/// - Note: Negative raw estimates are truncated to zero, following standard
///   G-theory convention.
///
/// Example:
/// ```swift
/// // A person variance component explaining 60% of total variance
/// let personVar = VarianceComponent<Double>(
///     source: "p",
///     variance: 4.5,
///     percentOfTotal: 60.0,
///     df: 29,
///     meanSquare: 15.0
/// )
/// ```
public struct VarianceComponent<T: Real>: Sendable, Equatable {
	/// The source of variation (e.g., "p", "raters", "p x raters").
	public let source: String

	/// The estimated variance for this component (non-negative).
	public let variance: T

	/// The percentage of total variance attributable to this component.
	public let percentOfTotal: T

	/// Degrees of freedom associated with this component.
	public let df: Int

	/// Mean square from the ANOVA table for this component.
	public let meanSquare: T
}

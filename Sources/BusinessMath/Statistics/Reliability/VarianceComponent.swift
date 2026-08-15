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
/// // Components are produced by a G-study rather than constructed directly:
/// // the memberwise initialiser is internal, as the values must agree with
/// // the ANOVA they came from.
/// let ratings = [[4.0, 5.0, 4.0], [3.0, 3.0, 4.0], [5.0, 5.0, 5.0], [2.0, 3.0, 2.0]]
/// let result = try gStudy(ratings, facetLabel: "raters")
///
/// for component in result.components {
///     print("\(component.source): \(component.percentOfTotal)% of total")
/// }
/// ```
public struct VarianceComponent<T: Real & Sendable>: Sendable, Equatable {
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

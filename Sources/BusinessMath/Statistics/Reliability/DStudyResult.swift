import Foundation
import Numerics

/// Result of a decision study (D-study).
///
/// A D-study uses variance components from a G-study to project the
/// reliability of measurements under alternative designs (different numbers
/// of raters, items, occasions, etc.).
///
/// Two reliability coefficients are provided:
/// - ``generalizabilityCoefficient`` (rho-squared): for relative decisions
///   (ranking persons against each other).
/// - ``dependabilityCoefficient`` (Phi): for absolute decisions
///   (comparing persons to a fixed standard).
///
/// Example:
/// ```swift
/// let gResult = try gStudy(ratings)
/// let dResult = try dStudy(gResult, design: ["raters": 5])
/// print("Generalizability: \(dResult.generalizabilityCoefficient)")
/// print("Dependability: \(dResult.dependabilityCoefficient)")
/// print("SEM: \(dResult.standardErrorOfMeasurement)")
/// ```
public struct DStudyResult<T: Real>: Sendable, Equatable {
	/// Generalizability coefficient (rho-squared) for relative decisions.
	///
	/// Analogous to ICC consistency; reflects reliability when ranking persons.
	public let generalizabilityCoefficient: T

	/// Dependability coefficient (Phi) for absolute decisions.
	///
	/// Analogous to ICC absolute agreement; reflects reliability when comparing
	/// persons to a fixed standard.
	public let dependabilityCoefficient: T

	/// Relative error variance (sigma-delta-squared).
	///
	/// Reflects error variance relevant to relative decisions only.
	public let relativeErrorVariance: T

	/// Absolute error variance (sigma-Delta-squared).
	///
	/// Reflects error variance relevant to absolute decisions.
	public let absoluteErrorVariance: T

	/// Standard error of measurement, computed as the square root of the
	/// absolute error variance.
	public let standardErrorOfMeasurement: T

	/// The facet sample sizes used in this D-study design.
	public let designFacets: [String: Int]
}

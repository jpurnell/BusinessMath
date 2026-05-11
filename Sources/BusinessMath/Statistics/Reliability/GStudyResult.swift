import Foundation
import Numerics

/// Result of a generalizability study (G-study).
///
/// Contains the estimated variance components and facet information
/// from decomposing observed score variance into its constituent sources.
///
/// The G-study identifies how much variation is attributable to each
/// source (persons, facets, interactions, and residual error), informing
/// the design of subsequent decision studies (D-studies).
///
/// Example:
/// ```swift
/// let result = try gStudy(ratings, facetLabel: "raters")
/// print("Person variance: \(result.variancePersons)")
/// print("Total variance: \(result.totalVariance)")
/// for comp in result.components {
///     print("\(comp.source): \(comp.variance) (\(comp.percentOfTotal)%)")
/// }
/// ```
public struct GStudyResult<T: Real & Sendable>: Sendable, Equatable {
	/// The estimated variance components, one per source of variation.
	public let components: [VarianceComponent<T>]

	/// The facets included in this G-study design.
	public let facets: [GFacet]

	/// The total variance (sum of all component variances).
	public let totalVariance: T

	/// The variance attributable to persons (the object of measurement).
	public let variancePersons: T

	/// The number of persons (objects of measurement) in the study.
	public let personCount: Int
}

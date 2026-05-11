import Foundation

/// A facet in a generalizability study.
///
/// A facet represents a source of measurement variation (e.g., raters, items,
/// occasions) that is sampled from a larger universe.
///
/// Example:
/// ```swift
/// let raterFacet = GFacet(label: "raters", levels: 3)
/// let itemFacet = GFacet(label: "items", levels: 10)
/// ```
public struct GFacet: Sendable, Hashable {
	/// The descriptive label for this facet (e.g., "raters", "items").
	public let label: String

	/// The number of levels observed for this facet.
	public let levels: Int

	/// Creates a facet for a generalizability study.
	///
	/// - Parameters:
	///   - label: Descriptive label for this facet (e.g., "raters", "items").
	///   - levels: The number of observed levels for this facet.
	public init(label: String, levels: Int) {
		self.label = label
		self.levels = levels
	}
}

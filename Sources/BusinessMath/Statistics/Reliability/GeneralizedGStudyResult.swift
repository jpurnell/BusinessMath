import Numerics

/// Result of a generalized G-study supporting arbitrary numbers of facets.
///
/// Extends the traditional two-facet G-study to handle three or more facets
/// using Brennan's algorithmic Expected Mean Squares (EMS) rules for
/// variance component extraction.
///
/// Each variance component is keyed by the set of facet names that constitute
/// the effect (e.g., `{"p"}` for persons, `{"p", "raters"}` for the
/// person-by-rater interaction).
///
/// Example:
/// ```swift
/// let data = try CrossedDesignData<Double>(
///     values: myValues,
///     facetNames: ["p", "raters", "items"],
///     dimensions: [4, 3, 2]
/// )
/// let result = try generalizedGStudy(data, objectOfMeasurement: "p")
/// let personVariance = result.varianceObject // sigma^2_p
/// ```
public struct GeneralizedGStudyResult<T: Real & Sendable>: Sendable, Equatable {

    /// Estimated variance components, keyed by effect (set of facet names).
    public let varianceComponents: [Set<String>: T]

    /// Percentage of total variance for each component.
    public let percentOfTotal: [Set<String>: T]

    /// The EMS table used for variance extraction.
    public let emsTable: [Set<String>: [EMSEntry<T>]]

    /// Mean squares from the multi-way ANOVA, keyed by effect.
    public let meanSquares: [Set<String>: T]

    /// Degrees of freedom from the multi-way ANOVA, keyed by effect.
    public let degreesOfFreedom: [Set<String>: Int]

    /// The facets included in this study.
    public let facets: [GFacet]

    /// The facet designated as the object of measurement (typically "p" for persons).
    public let objectOfMeasurement: String

    /// The total variance (sum of all variance components).
    public let totalVariance: T

    /// The variance attributable to the object of measurement.
    public var varianceObject: T {
        varianceComponents[Set([objectOfMeasurement])] ?? T.zero
    }

    /// Converts this generalized result to a ``GStudyResult`` for backward
    /// compatibility with existing one-facet and two-facet D-study functions.
    ///
    /// The object of measurement is mapped to the "p" component. Other effects
    /// are converted using the standard `"x"` notation for interactions.
    ///
    /// - Returns: A ``GStudyResult`` equivalent to this generalized result.
    public func asGStudyResult() -> GStudyResult<T> {
        let obj = objectOfMeasurement
        let nonObjFacets = facets.filter { $0.label != obj }
        let personCount = facets.first { $0.label == obj }?.levels ?? 0

        // Build VarianceComponent array from the variance components
        var components: [VarianceComponent<T>] = []

        // Sort effects by size then alphabetically for deterministic ordering
        let sortedEffects = varianceComponents.keys.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count < rhs.count }
            return lhs.sorted().joined() < rhs.sorted().joined()
        }

        for effect in sortedEffects {
            let variance = varianceComponents[effect] ?? T.zero
            let pct = percentOfTotal[effect] ?? T.zero
            let df = degreesOfFreedom[effect] ?? 0
            let ms = meanSquares[effect] ?? T.zero

            // Build source label: use "p" for object, facet labels for others,
            // "x" separator for interactions
            let sortedLabels = effect.sorted()
            let source = sortedLabels.joined(separator: " x ")

            components.append(VarianceComponent(
                source: source,
                variance: variance,
                percentOfTotal: pct,
                df: df,
                meanSquare: ms
            ))
        }

        return GStudyResult(
            components: components,
            facets: nonObjFacets,
            totalVariance: totalVariance,
            variancePersons: varianceObject,
            personCount: personCount
        )
    }
}

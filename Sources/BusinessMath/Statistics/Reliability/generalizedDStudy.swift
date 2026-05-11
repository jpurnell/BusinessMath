import Numerics

/// Performs a generalized D-study based on a generalized G-study result.
///
/// Projects the reliability of measurements under alternative designs by
/// specifying new sample sizes for each non-object facet. Computes both
/// relative and absolute reliability indices for designs with arbitrary
/// numbers of facets.
///
/// **Relative error variance** (for ranking decisions):
/// ```
/// sigma^2_delta = sum over E containing p, E != {p}:
///     sigma^2_E / product(n'_f for f in E \ {p})
/// ```
///
/// **Absolute error variance** (for absolute decisions):
/// ```
/// sigma^2_Delta = sum over E where E != {p}:
///     sigma^2_E / product(n'_f for f in E, excluding p if present)
/// ```
///
/// - Parameters:
///   - gResult: The generalized G-study result.
///   - designSizes: A dictionary mapping non-object facet labels to their
///     projected sample sizes.
/// - Returns: A ``DStudyResult`` with reliability coefficients and error variances.
/// - Throws: `BusinessMathError.invalidInput` if design sizes don't match
///   the non-object facets or any size is less than 1.
public func generalizedDStudy<T: Real>(
    _ gResult: GeneralizedGStudyResult<T>,
    designSizes: [String: Int]
) throws -> DStudyResult<T> {
    let obj = gResult.objectOfMeasurement
    let nonObjFacetLabels = Set(gResult.facets.map { $0.label }.filter { $0 != obj })
    let designLabels = Set(designSizes.keys)

    guard nonObjFacetLabels == designLabels else {
        throw BusinessMathError.invalidInput(
            message: "Design sizes must match non-object facets",
            value: "\(designLabels.sorted())",
            expectedRange: "\(nonObjFacetLabels.sorted())")
    }

    for (label, size) in designSizes {
        guard size >= 1 else {
            throw BusinessMathError.invalidInput(
                message: "Design size must be at least 1",
                value: "\(label): \(size)",
                expectedRange: ">= 1")
        }
    }

    let sigmaP = gResult.varianceObject
    let objectSet: Set<String> = [obj]

    var relativeError = T.zero
    var absoluteError = T.zero

    for (effect, variance) in gResult.varianceComponents {
        // Skip the object-of-measurement component itself
        guard effect != objectSet else { continue }

        let containsObject = effect.contains(obj)

        // Compute divisor: product of n'_f for facets in E that are not the object
        let nonObjFacetsInEffect = effect.filter { $0 != obj }
        var divisor = T(1)
        for facet in nonObjFacetsInEffect {
            guard let size = designSizes[facet] else { continue }
            divisor = divisor * T(size)
        }

        guard divisor > T.zero else { continue }

        // Absolute error: all components except {p}
        absoluteError += variance / divisor

        // Relative error: only components containing p (excluding {p} itself)
        if containsObject {
            relativeError += variance / divisor
        }
    }

    // Generalizability coefficient (rho^2)
    let rhoSquared: T
    let relDenom = sigmaP + relativeError
    if relDenom > T.zero {
        rhoSquared = sigmaP / relDenom
    } else {
        rhoSquared = T.zero
    }

    // Dependability coefficient (Phi)
    let phi: T
    let absDenom = sigmaP + absoluteError
    if absDenom > T.zero {
        phi = sigmaP / absDenom
    } else {
        phi = T.zero
    }

    let sem = T.sqrt(absoluteError)

    return DStudyResult(
        generalizabilityCoefficient: rhoSquared,
        dependabilityCoefficient: phi,
        relativeErrorVariance: relativeError,
        absoluteErrorVariance: absoluteError,
        standardErrorOfMeasurement: sem,
        designFacets: designSizes
    )
}

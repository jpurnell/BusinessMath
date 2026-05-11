import Numerics

/// Performs a generalized G-study on fully crossed design data with arbitrary
/// numbers of facets.
///
/// Uses Brennan's algorithmic EMS rules to extract variance components from
/// a multi-way ANOVA. The algorithm:
/// 1. Performs a multi-way ANOVA to obtain mean squares for each effect.
/// 2. Generates an EMS table using Brennan's rules.
/// 3. Solves for variance components bottom-up (largest effects first).
/// 4. Truncates negative estimates to zero.
///
/// - Parameters:
///   - data: A ``CrossedDesignData`` instance containing the observations.
///   - objectOfMeasurement: The facet label representing the object of
///     measurement (e.g., `"p"` for persons).
/// - Returns: A ``GeneralizedGStudyResult`` with variance components and
///   diagnostics.
/// - Throws: `BusinessMathError.invalidInput` if `objectOfMeasurement` is
///   not among the facet names.
///   `BusinessMathError.insufficientData` if any dimension is less than 2.
public func generalizedGStudy<T: Real>(
    _ data: CrossedDesignData<T>,
    objectOfMeasurement: String
) throws -> GeneralizedGStudyResult<T> {
    guard data.facetNames.contains(objectOfMeasurement) else {
        throw BusinessMathError.invalidInput(
            message: "Object of measurement '\(objectOfMeasurement)' not found in facet names",
            value: objectOfMeasurement,
            expectedRange: "one of \(data.facetNames)")
    }

    // Step 1: Multi-way ANOVA
    let anova = try multiWayANOVA(data)

    // Step 2: Generate EMS table
    var sampleSizes: [String: Int] = [:]
    for i in 0..<data.facetNames.count {
        sampleSizes[data.facetNames[i]] = data.dimensions[i]
    }

    let emsTable: [Set<String>: [EMSEntry<T>]] = try generateEMSTable(
        facetNames: data.facetNames,
        sampleSizes: sampleSizes
    )

    // Step 3: Bottom-up variance component extraction
    // Sort effects by |E| descending, so we solve from largest (residual) first
    let effects = Array(anova.meanSquares.keys)
    let sortedEffects = effects.sorted { $0.count > $1.count }

    var variances: [Set<String>: T] = [:]

    for effect in sortedEffects {
        guard let ms = anova.meanSquares[effect] else { continue }
        guard let emsEntries = emsTable[effect] else { continue }

        // Find the coefficient for sigma^2_E itself (c(E, E) = product of n_f for f not in E)
        guard let selfEntry = emsEntries.first(where: { $0.component == effect }) else { continue }
        let selfCoeff = selfEntry.coefficient

        guard selfCoeff > T.zero else { continue }

        // MS(E) = c(E,E) * sigma^2_E + sum over strict supersets S: c(S,E) * sigma^2_S
        // => sigma^2_E = (MS(E) - sum over strict supersets S: c(S,E) * sigma^2_S) / c(E,E)
        var supersetContribution = T.zero

        for entry in emsEntries {
            guard entry.component != effect else { continue }
            // entry.component is a strict superset of effect
            let supersetVar = variances[entry.component] ?? T.zero
            supersetContribution += entry.coefficient * supersetVar
        }

        let rawVariance = (ms - supersetContribution) / selfCoeff

        // Truncate negative to zero (standard G-theory convention)
        variances[effect] = rawVariance < T.zero ? T.zero : rawVariance
    }

    // Step 4: Compute total variance and percentages
    let total = variances.values.reduce(T.zero, +)
    let hundred = T(100)

    var percentages: [Set<String>: T] = [:]
    for (effect, variance) in variances {
        if total > T.zero {
            percentages[effect] = variance / total * hundred
        } else {
            percentages[effect] = T.zero
        }
    }

    // Build facets
    let facets = data.facetNames.enumerated().map { index, name in
        GFacet(label: name, levels: data.dimensions[index])
    }

    return GeneralizedGStudyResult(
        varianceComponents: variances,
        percentOfTotal: percentages,
        emsTable: emsTable,
        meanSquares: anova.meanSquares,
        degreesOfFreedom: anova.degreesOfFreedom,
        facets: facets,
        objectOfMeasurement: objectOfMeasurement,
        totalVariance: total
    )
}

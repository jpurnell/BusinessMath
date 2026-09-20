import Numerics

/// Result of a multi-way analysis of variance for a fully crossed design.
///
/// Contains the sum of squares, degrees of freedom, and mean squares for
/// every effect (non-empty subset of facets) in a fully crossed ANOVA.
///
/// Example:
/// ```swift
/// let myValues = (0..<24).map { Double($0) + 1.0 }
/// let data = try CrossedDesignData<Double>(
///     values: myValues,
///     facetNames: ["p", "raters", "items"],
///     dimensions: [4, 3, 2]
/// )
/// let result = try multiWayANOVA(data)
/// // Access SS for the person × rater interaction
/// let ssPR = result.sumOfSquares[Set(["p", "raters"])]
/// ```
public struct MultiWayANOVAResult<T: Real & Sendable>: Sendable, Equatable {

    /// Sum of squares for each effect, keyed by the set of facet names.
    public let sumOfSquares: [Set<String>: T]

    /// Degrees of freedom for each effect, keyed by the set of facet names.
    public let degreesOfFreedom: [Set<String>: Int]

    /// Mean squares for each effect (SS / df), keyed by the set of facet names.
    public let meanSquares: [Set<String>: T]
}

/// Performs a multi-way ANOVA on fully crossed design data.
///
/// Computes sums of squares, degrees of freedom, and mean squares for every
/// effect in a fully crossed design using the marginal means and inclusion-exclusion
/// algorithm.
///
/// For each effect `E`, the adjusted effect is computed via inclusion-exclusion:
/// ```
/// adjustedMean(E, levels) = sum over subsets S of E (incl. empty):
///     (-1)^(|E| - |S|) * marginalMean[S][levels restricted to S]
/// SS(E) = nComplement(E) * sum over level combos: adjustedMean^2
/// df(E) = product of (n_f - 1) for f in E
/// MS(E) = SS(E) / df(E)
/// ```
///
/// - Parameter data: A ``CrossedDesignData`` instance containing the observations.
/// - Returns: A ``MultiWayANOVAResult`` with SS, df, and MS for each effect.
/// - Throws: `BusinessMathError.insufficientData` if any dimension is less than 2.
public func multiWayANOVA<T: Real>(
    _ data: CrossedDesignData<T>
) throws -> MultiWayANOVAResult<T> {
    let facetNames = data.facetNames
    let dimensions = data.dimensions

    // Validate: all dimensions >= 2
    for (index, dim) in dimensions.enumerated() {
        guard dim >= 2 else {
            throw BusinessMathError.insufficientData(
                required: 2, actual: dim,
                context: "Multi-way ANOVA requires at least 2 levels for facet '\(facetNames[index])'")
        }
    }

    let f = facetNames.count

    // Build index map: facetName -> position in dimensions array
    var facetIndex: [String: Int] = [:]
    for i in 0..<f {
        facetIndex[facetNames[i]] = i
    }

    // Compute all non-empty subsets (effects)
    let effects = allNonEmptySubsets(of: facetNames)

    // Precompute marginal mean tables for every subset of facets (including empty set)
    // A marginal mean table for a subset S is indexed by the levels of facets in S,
    // and averages over all facets not in S.

    // For the empty set, the marginal mean is just the grand mean (a single value).
    // For a subset S, the table has product(dimensions[i] for i in S) entries.

    // We represent marginal means as flat arrays keyed by subset, with row-major ordering
    // based on the sorted facet indices within the subset.

    let marginalMeans = marginalMeanTables(data, facetNames: facetNames, dimensions: dimensions)

    // Step 2: Compute SS for each effect via inclusion-exclusion.
    var ssDict: [Set<String>: T] = [:]
    var dfDict: [Set<String>: Int] = [:]
    var msDict: [Set<String>: T] = [:]

    for effect in effects {
        let effectIndices = (0..<f).filter { effect.contains(facetNames[$0]) }
        let effectDims = effectIndices.map { dimensions[$0] }

        let ssEffect = effectSumOfSquares(
            effect, facetNames: facetNames, dimensions: dimensions,
            effectIndices: effectIndices, effectDims: effectDims,
            marginalMeans: marginalMeans)

        // df(E) = product of (n_f - 1) for f in E
        let df = effectDims.map { $0 - 1 }.reduce(1, *)

        // MS(E) = SS(E) / df(E)
        let ms: T
        if df > 0 {
            ms = ssEffect / T(df)
        } else {
            ms = T.zero
        }

        ssDict[effect] = ssEffect
        dfDict[effect] = df
        msDict[effect] = ms
    }

    return MultiWayANOVAResult(
        sumOfSquares: ssDict,
        degreesOfFreedom: dfDict,
        meanSquares: msDict
    )
}

/// The marginal mean table for every subset of the facets, including the empty one.
///
/// A table for subset `S` is indexed by the levels of the facets in `S` and averages over
/// every facet not in `S`; the empty subset gives the grand mean as a single value. Stored
/// flat, row-major over the subset's facets in their natural order.
///
/// - Parameters:
///   - data: The crossed design.
///   - facetNames: Labels for each facet, in the design's own order.
///   - dimensions: Levels per facet, in the same order.
/// - Returns: One flat table per subset.
private func marginalMeanTables<T: Real>(
    _ data: CrossedDesignData<T>, facetNames: [String], dimensions: [Int]
) -> [Set<String>: [T]] {
    let f = facetNames.count
    let allSubsets = allSubsetsIncludingEmpty(of: facetNames)
    var marginalMeans: [Set<String>: [T]] = [:]
    let totalCount = data.values.count
    let strides = computeStrides(dimensions)

    for subset in allSubsets {
        // Determine the facet indices in this subset, in natural order
        let subsetIndices = (0..<f).filter { subset.contains(facetNames[$0]) }
        let subsetDims = subsetIndices.map { dimensions[$0] }
        let tableSize = subsetDims.isEmpty ? 1 : subsetDims.reduce(1, *)

        // Number of elements averaged over = totalCount / tableSize
        let avgCount = totalCount / tableSize
        guard avgCount > 0 else { continue }

        var sums = [T](repeating: T.zero, count: tableSize)

        for flatIdx in 0..<totalCount {
            let multiIdx = flatToMultiIndex(flatIdx, dimensions: dimensions, strides: strides)

            // Compute the flat index within the marginal table
            var marginalFlat = 0
            var marginalStride = 1
            for si in stride(from: subsetIndices.count - 1, through: 0, by: -1) {
                let facetIdx = subsetIndices[si]
                marginalFlat += multiIdx[facetIdx] * marginalStride
                marginalStride *= subsetDims[si]
            }

            sums[marginalFlat] += data.values[flatIdx]
        }

        let divisor = T(avgCount)
        marginalMeans[subset] = sums.map { $0 / divisor }
    }
    return marginalMeans
}

/// One effect's sum of squares, by inclusion-exclusion over its own subsets.
///
///     adjustedMean(E, levels) = SUM over subsets S of E, including the empty one:
///         (-1)^(|E| - |S|) * marginalMean[S][levels restricted to S]
///     SS(E) = nComplement(E) * SUM over level combinations: adjustedMean^2
///
/// The alternating sign is what removes the lower-order effects already accounted for
/// elsewhere, and `nComplement` — the product of the dimensions *not* in `E` — is how many
/// observations each adjusted cell stands for. Taking that product from the wrong side is
/// the error a design with two equal dimensions cannot detect, which is why
/// `MultiWayANOVAOracleTests` uses three distinct ones.
///
/// - Returns: The effect's sum of squares.
private func effectSumOfSquares<T: Real>(
    _ effect: Set<String>,
    facetNames: [String],
    dimensions: [Int],
    effectIndices: [Int],
    effectDims: [Int],
    marginalMeans: [Set<String>: [T]]
) -> T {
    let f = facetNames.count
    let effectTableSize = effectDims.reduce(1, *)

    // Complement facets: those NOT in effect
    let complementIndices = (0..<f).filter { !effect.contains(facetNames[$0]) }
    let nComplement: T
    if complementIndices.isEmpty {
        nComplement = T(1)
    } else {
        nComplement = T(complementIndices.map { dimensions[$0] }.reduce(1, *))
    }

    let subsetsOfEffect = allSubsetsIncludingEmpty(of: Array(effect))
    var ssEffect = T.zero

    for cellFlat in 0..<effectTableSize {
        // The level of each facet in the effect, for this cell.
        var effectLevels = [Int](repeating: 0, count: effectIndices.count)
        var remainder = cellFlat
        for si in stride(from: effectIndices.count - 1, through: 0, by: -1) {
            effectLevels[si] = remainder % effectDims[si]
            remainder /= effectDims[si]
        }

        var adjustedMean = T.zero
        for subsetOfEffect in subsetsOfEffect {
            guard let means = marginalMeans[subsetOfEffect] else { continue }
            let sign: T = (effect.count - subsetOfEffect.count) % 2 == 0 ? T(1) : T(-1)

            let subsetIndices = (0..<f).filter { subsetOfEffect.contains(facetNames[$0]) }
            if subsetIndices.isEmpty {
                adjustedMean += sign * means[0]
                continue
            }

            let subsetDims = subsetIndices.map { dimensions[$0] }
            var marginalFlat = 0
            var marginalStride = 1
            for si in stride(from: subsetIndices.count - 1, through: 0, by: -1) {
                let facetIdx = subsetIndices[si]
                guard let positionInEffect = effectIndices.firstIndex(of: facetIdx) else { continue }
                marginalFlat += effectLevels[positionInEffect] * marginalStride
                marginalStride *= subsetDims[si]
            }
            adjustedMean += sign * means[marginalFlat]
        }

        ssEffect += adjustedMean * adjustedMean
    }

    return nComplement * ssEffect
}

// MARK: - Multi-Way ANOVA Helpers

/// Computes strides for a row-major flat indexing scheme.
private func computeStrides(_ dimensions: [Int]) -> [Int] {
    guard !dimensions.isEmpty else { return [] }
    var strides = [Int](repeating: 1, count: dimensions.count)
    for i in stride(from: dimensions.count - 2, through: 0, by: -1) {
        strides[i] = strides[i + 1] * dimensions[i + 1]
    }
    return strides
}

/// Converts a flat index to a multi-dimensional index.
private func flatToMultiIndex(_ flatIndex: Int, dimensions: [Int], strides: [Int]) -> [Int] {
    var result = [Int](repeating: 0, count: dimensions.count)
    var remaining = flatIndex
    for i in 0..<dimensions.count {
        result[i] = remaining / strides[i]
        remaining = remaining % strides[i]
    }
    return result
}

/// Generates all non-empty subsets of the given elements.
private func allNonEmptySubsets(of elements: [String]) -> [Set<String>] {
    let count = elements.count
    let total = 1 << count
    var subsets: [Set<String>] = []
    for mask in 1..<total {
        var subset = Set<String>()
        for bit in 0..<count {
            if mask & (1 << bit) != 0 {
                subset.insert(elements[bit])
            }
        }
        subsets.append(subset)
    }
    return subsets
}

/// Generates all subsets (including the empty set) of the given elements.
private func allSubsetsIncludingEmpty(of elements: [String]) -> [Set<String>] {
    let count = elements.count
    let total = 1 << count
    var subsets: [Set<String>] = []
    for mask in 0..<total {
        var subset = Set<String>()
        for bit in 0..<count {
            if mask & (1 << bit) != 0 {
                subset.insert(elements[bit])
            }
        }
        subsets.append(subset)
    }
    return subsets
}

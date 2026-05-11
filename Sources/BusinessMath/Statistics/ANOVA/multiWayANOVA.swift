import Numerics

/// Result of a multi-way analysis of variance for a fully crossed design.
///
/// Contains the sum of squares, degrees of freedom, and mean squares for
/// every effect (non-empty subset of facets) in a fully crossed ANOVA.
///
/// Example:
/// ```swift
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

    // Step 1: Compute marginal sums, then divide by count of averaged elements.
    let allSubsets = allSubsetsIncludingEmpty(of: facetNames)

    // For each subset, store a flat array of marginal means.
    // The ordering within each flat array uses the natural facet order (by index in facetNames).
    var marginalMeans: [Set<String>: [T]] = [:]

    let totalCount = data.values.count

    for subset in allSubsets {
        // Determine the facet indices in this subset, in natural order
        let subsetIndices = (0..<f).filter { subset.contains(facetNames[$0]) }
        let subsetDims = subsetIndices.map { dimensions[$0] }
        let tableSize = subsetDims.isEmpty ? 1 : subsetDims.reduce(1, *)

        // Number of elements averaged over = totalCount / tableSize
        let avgCount = totalCount / tableSize

        guard avgCount > 0 else { continue }

        // Accumulate sums
        var sums = [T](repeating: T.zero, count: tableSize)

        // Iterate over all observations
        let strides = computeStrides(dimensions)

        for flatIdx in 0..<totalCount {
            // Determine the multi-index for this flat index
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

        // Divide by count to get means
        let divisor = T(avgCount)
        marginalMeans[subset] = sums.map { $0 / divisor }
    }

    // Step 2: Compute SS for each effect via inclusion-exclusion.
    var ssDict: [Set<String>: T] = [:]
    var dfDict: [Set<String>: Int] = [:]
    var msDict: [Set<String>: T] = [:]

    for effect in effects {
        let effectIndices = (0..<f).filter { effect.contains(facetNames[$0]) }
        let effectDims = effectIndices.map { dimensions[$0] }
        let effectTableSize = effectDims.reduce(1, *)

        // Complement facets: those NOT in effect
        let complementIndices = (0..<f).filter { !effect.contains(facetNames[$0]) }
        let nComplement: T
        if complementIndices.isEmpty {
            nComplement = T(1)
        } else {
            nComplement = T(complementIndices.map { dimensions[$0] }.reduce(1, *))
        }

        // All subsets of effect (including empty set)
        let effectFacets = effectIndices.map { facetNames[$0] }
        let subsetsOfEffect = allSubsetsIncludingEmpty(of: effectFacets)

        // For each level combination of effect, compute adjusted mean
        var ssEffect = T.zero

        for levelFlat in 0..<effectTableSize {
            // Determine the multi-index within effect dimensions
            let levelMulti = flatToMultiIndex(levelFlat, dimensions: effectDims,
                                              strides: computeStrides(effectDims))

            // Compute adjusted mean via inclusion-exclusion
            var adjustedMean = T.zero

            for subsetOfEffect in subsetsOfEffect {
                let subsetFacets = effectIndices.filter { subsetOfEffect.contains(facetNames[$0]) }
                let sign: T = (effect.count - subsetOfEffect.count) % 2 == 0 ? T(1) : T(-1)

                // Look up the marginal mean for this subset at the restricted indices
                guard let means = marginalMeans[subsetOfEffect] else { continue }

                if subsetOfEffect.isEmpty {
                    // Grand mean is a single value
                    adjustedMean += sign * means[0]
                } else {
                    // Compute flat index within marginalMeans[subsetOfEffect]
                    let subsetIndicesInOrder = (0..<f).filter { subsetOfEffect.contains(facetNames[$0]) }
                    let subsetDims = subsetIndicesInOrder.map { dimensions[$0] }

                    var marginalFlat = 0
                    var marginalStride = 1
                    for si in stride(from: subsetIndicesInOrder.count - 1, through: 0, by: -1) {
                        let facetIdx = subsetIndicesInOrder[si]
                        // Find this facet's level from the effect level combination
                        guard let posInEffect = effectIndices.firstIndex(of: facetIdx) else { continue }
                        marginalFlat += levelMulti[posInEffect] * marginalStride
                        marginalStride *= subsetDims[si]
                    }

                    adjustedMean += sign * means[marginalFlat]
                }
            }

            ssEffect += adjustedMean * adjustedMean
        }

        ssEffect = nComplement * ssEffect

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

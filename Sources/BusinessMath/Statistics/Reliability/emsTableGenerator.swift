import Numerics

/// Generates an Expected Mean Squares (EMS) table for a fully crossed design
/// using Brennan's algorithmic EMS rules.
///
/// For each effect `E` (non-empty subset of facets), the EMS equation is:
/// ```
/// EMS(E) = sum over supersets S of E:
///     c(S, E) * sigma^2_S
/// ```
/// where `c(S, E) = product of n_f` for each facet `f` not in `S`.
///
/// - Parameters:
///   - facetNames: The labels of all facets in the design.
///   - sampleSizes: A dictionary mapping each facet name to its sample size.
/// - Returns: A dictionary mapping each effect (set of facet names) to its EMS entries.
/// - Throws: `BusinessMathError.insufficientData` if `facetNames` is empty.
///   `BusinessMathError.invalidInput` if `sampleSizes` is missing a facet.
public func generateEMSTable<T: Real>(
    facetNames: [String],
    sampleSizes: [String: Int]
) throws -> [Set<String>: [EMSEntry<T>]] {
    guard !facetNames.isEmpty else {
        throw BusinessMathError.insufficientData(
            required: 1, actual: 0,
            context: "EMS table generation requires at least one facet")
    }

    for name in facetNames {
        guard sampleSizes[name] != nil else {
            throw BusinessMathError.invalidInput(
                message: "Missing sample size for facet '\(name)'",
                value: nil,
                expectedRange: "a positive integer")
        }
    }

    let allFacets = Set(facetNames)

    // Generate all non-empty subsets (effects)
    let effects = nonEmptySubsets(of: facetNames)

    var table: [Set<String>: [EMSEntry<T>]] = [:]

    for effect in effects {
        var entries: [EMSEntry<T>] = []

        // Find all supersets of effect among the effects
        for superset in effects {
            guard effect.isSubset(of: superset) else { continue }

            // Coefficient = product of n_f for f in (allFacets \ superset)
            let complement = allFacets.subtracting(superset)
            var coefficient = T(1)
            for facet in complement {
                guard let size = sampleSizes[facet] else { continue }
                coefficient = coefficient * T(size)
            }

            entries.append(EMSEntry(component: superset, coefficient: coefficient))
        }

        table[effect] = entries
    }

    return table
}

/// Generates all non-empty subsets of the given array of strings.
///
/// - Parameter elements: The elements to generate subsets from.
/// - Returns: An array of sets, each representing a non-empty subset.
private func nonEmptySubsets(of elements: [String]) -> [Set<String>] {
    let count = elements.count
    let total = 1 << count // 2^count
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

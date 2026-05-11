# Proposal: Generalized G-Theory (3+ Facets)

**Date:** 2026-05-10
**Status:** Draft
**Scope:** Algorithmic EMS rule generation and multi-facet G/D-studies in `BusinessMath/Statistics/Reliability/`
**Depends on:** `PROPOSAL_advanced_reliability.md` Phase 6 (must land first -- provides the two-facet G-study base case, `GStudyResult`, `DStudyResult`, `VarianceComponent`, `GFacet`)

## Problem

The existing Phase 6 in `PROPOSAL_advanced_reliability.md` implements G-theory for one-facet (p x r) and two-facet (p x r x i) fully crossed designs. The EMS tables and variance component extraction formulas in that implementation are hard-coded for these two specific designs.

This is insufficient for real-world measurement studies that commonly involve three or more facets:

| Domain | Design | Facets |
|--------|--------|--------|
| Medical imaging | patients (p) x readers (r) x regions (i) x occasions (o) | 4 |
| Educational testing | students (p) x raters (r) x items (i) x occasions (o) | 4 |
| Industrial quality control | products (p) x operators (r) x instruments (i) | 3 |
| Performance assessment | examinees (p) x raters (r) x tasks (i) x rubric dimensions (d) | 4 |
| Behavioral observation | children (p) x observers (r) x activities (i) x time periods (o) | 4 |

For f facets in a fully crossed random-effects design, the number of variance components is 2^f - 1. A two-facet design has 7 components; a three-facet design has 15; a four-facet design has 31. Deriving and hard-coding the EMS table for each becomes impractical beyond two facets. An algorithmic EMS rule generator is needed.

### What Already Exists (After Phase 6 Lands)

| Component | Status | Location |
|-----------|--------|----------|
| `GFacet` | Phase 6 | `Reliability/GFacet.swift` |
| `VarianceComponent<T>` | Phase 6 | `Reliability/VarianceComponent.swift` |
| `GStudyResult<T>` | Phase 6 | `Reliability/GStudyResult.swift` |
| `DStudyResult<T>` | Phase 6 | `Reliability/DStudyResult.swift` |
| `gStudy(_:facetLabel:)` (one-facet) | Phase 6 | `Reliability/gStudy.swift` |
| `gStudy(_:facetLabels:)` (two-facet) | Phase 6 | `Reliability/gStudy.swift` |
| `dStudy(_:design:)` | Phase 6 | `Reliability/dStudy.swift` |
| `twoWayANOVA(_:)` | Exists | `ANOVA/twoWayANOVA.swift` |
| `oneWayANOVA(_:)` | Exists | `ANOVA/oneWayANOVA.swift` |
| Multi-way ANOVA (3+ factors) | Missing | -- |
| Algorithmic EMS rule generator | Missing | -- |
| Generalized variance component extraction | Missing | -- |
| Generalized D-study (3+ facets) | Missing | -- |

## Theory: Brennan's EMS Rules

### Setup

Consider a fully crossed random-effects design with a set of facets F = {f_1, f_2, ..., f_k} and corresponding sample sizes n_{f_1}, n_{f_2}, ..., n_{f_k}. The object of measurement is one distinguished facet, typically denoted p.

In a fully crossed design, every level of every facet is observed in combination with every level of every other facet. The total number of observations is the product of all sample sizes.

Each non-empty subset E of F corresponds to a source of variation (an "effect") and has an associated variance component sigma^2_E. There are 2^k - 1 such components. For example, with F = {p, r, i}:

- Main effects: sigma^2_p, sigma^2_r, sigma^2_i
- Two-way interactions: sigma^2_{pr}, sigma^2_{pi}, sigma^2_{ri}
- Three-way interaction (residual): sigma^2_{pri}

### The EMS Rule

For any effect E (a non-empty subset of F), the expected mean square is:

```
EMS(E) = sum over all S where S is a superset of E (including E itself):
             c(S, E) * sigma^2_S
```

where the coefficient c(S, E) is:

```
c(S, E) = product of n_f for all f in (F \ S)
```

That is, the coefficient of sigma^2_S in EMS(E) is the product of sample sizes of all facets that are NOT in S.

Key observations:
- When S = F (the full set of all facets), c(F, E) = product over an empty set = 1. So sigma^2_F always appears with coefficient 1 in every EMS equation.
- When S = E, c(E, E) = product of n_f for all f not in E. This is the coefficient of sigma^2_E in its own EMS equation -- and it is always the largest coefficient in that equation.

### Worked Example: Three Facets (p x r x i)

F = {p, r, i} with sample sizes n_p, n_r, n_i. There are 2^3 - 1 = 7 variance components.

**EMS Table:**

| Effect E | EMS(E) |
|----------|--------|
| {p} | n_r * n_i * sigma^2_p + n_i * sigma^2_{pr} + n_r * sigma^2_{pi} + 1 * sigma^2_{pri} |
| {r} | n_p * n_i * sigma^2_r + n_i * sigma^2_{pr} + n_p * sigma^2_{ri} + 1 * sigma^2_{pri} |
| {i} | n_p * n_r * sigma^2_i + n_r * sigma^2_{pi} + n_p * sigma^2_{ri} + 1 * sigma^2_{pri} |
| {p, r} | n_i * sigma^2_{pr} + 1 * sigma^2_{pri} |
| {p, i} | n_r * sigma^2_{pi} + 1 * sigma^2_{pri} |
| {r, i} | n_p * sigma^2_{ri} + 1 * sigma^2_{pri} |
| {p, r, i} | 1 * sigma^2_{pri} |

Derivation of each coefficient:
- In EMS({p}), the coefficient of sigma^2_{pr} is the product of n_f for f in F \ {p,r} = {i}, so c = n_i.
- In EMS({p}), the coefficient of sigma^2_{pi} is the product of n_f for f in F \ {p,i} = {r}, so c = n_r.
- In EMS({p}), the coefficient of sigma^2_p is the product of n_f for f in F \ {p} = {r,i}, so c = n_r * n_i.
- In EMS({p}), the coefficient of sigma^2_{pri} is the product of n_f for f in F \ {p,r,i} = {}, so c = 1.

### Variance Component Extraction (Bottom-Up Solver)

Given the EMS equations and the observed mean squares MS(E) for each effect, solve for the variance components starting from the largest subset (the residual) and working down:

```
For each effect E, sorted by |E| descending:
    sigma^2_E = (MS(E) - sum over all strict supersets S of E: c(S, E) * sigma^2_S) / c(E, E)
    sigma^2_E = max(0, sigma^2_E)   // truncate negatives
```

The largest subset E = F (the residual) is solved first:

```
sigma^2_{pri} = MS({p,r,i}) / 1 = MS({p,r,i})
```

Then two-way interactions:

```
sigma^2_{pr} = (MS({p,r}) - 1 * sigma^2_{pri}) / n_i
sigma^2_{pi} = (MS({p,i}) - 1 * sigma^2_{pri}) / n_r
sigma^2_{ri} = (MS({r,i}) - 1 * sigma^2_{pri}) / n_p
```

Then main effects:

```
sigma^2_p = (MS({p}) - n_i * sigma^2_{pr} - n_r * sigma^2_{pi} - sigma^2_{pri}) / (n_r * n_i)
sigma^2_r = (MS({r}) - n_i * sigma^2_{pr} - n_p * sigma^2_{ri} - sigma^2_{pri}) / (n_p * n_i)
sigma^2_i = (MS({i}) - n_r * sigma^2_{pi} - n_p * sigma^2_{ri} - sigma^2_{pri}) / (n_p * n_r)
```

Negative estimates are truncated to zero, which is standard practice in G-theory (Shavelson and Webb 1991). This truncation introduces a small positive bias but prevents nonsensical negative variance estimates.

### Worked Example: Four Facets (p x r x i x o)

F = {p, r, i, o} with sample sizes n_p, n_r, n_i, n_o. There are 2^4 - 1 = 15 variance components.

The same algorithm generates the full EMS table. For instance:

```
EMS({p}) = n_r*n_i*n_o * sigma^2_p
         + n_i*n_o    * sigma^2_{pr}
         + n_r*n_o    * sigma^2_{pi}
         + n_r*n_i    * sigma^2_{po}
         + n_o        * sigma^2_{pri}
         + n_i        * sigma^2_{pro}
         + n_r        * sigma^2_{pio}
         + 1          * sigma^2_{prio}
```

The solver extracts all 15 components in one pass from largest subset to smallest.

## Generalized D-Study Formulas

Given variance components from a G-study with object of measurement p and the remaining facets as the "universe of admissible observations," a D-study predicts reliability for hypothetical facet sizes.

Let n'_f denote the D-study sample size for facet f (replacing the G-study sample size n_f for all facets except p).

### Relative Error Variance (for Generalizability Coefficient)

The relative error variance includes only variance components that contain p (excluding sigma^2_p itself):

```
sigma^2_delta = sum over all E where p is in E and E != {p}:
                    sigma^2_E / (product of n'_f for f in E \ {p})
```

The generalizability coefficient (relative/consistency) is:

```
E(rho^2) = sigma^2_p / (sigma^2_p + sigma^2_delta)
```

### Absolute Error Variance (for Dependability Coefficient)

The absolute error variance includes ALL variance components except sigma^2_p:

```
sigma^2_Delta = sum over all E where E != {p}:
                    sigma^2_E / (product of n'_f for f in E \ {p})
```

Note: when p is not in E, the denominator is the product of n'_f for ALL facets in E. When p is in E (but E != {p}), the denominator is the product of n'_f for the non-p facets in E.

The dependability coefficient (absolute) is:

```
Phi = sigma^2_p / (sigma^2_p + sigma^2_Delta)
```

### Example: Three-Facet D-Study

Given G-study components {sigma^2_p, sigma^2_r, sigma^2_i, sigma^2_{pr}, sigma^2_{pi}, sigma^2_{ri}, sigma^2_{pri}} and D-study sizes n'_r, n'_i:

```
sigma^2_delta = sigma^2_{pr}/n'_r + sigma^2_{pi}/n'_i + sigma^2_{pri}/(n'_r * n'_i)

sigma^2_Delta = sigma^2_r/n'_r + sigma^2_i/n'_i + sigma^2_{pr}/n'_r
              + sigma^2_{pi}/n'_i + sigma^2_{ri}/(n'_r * n'_i)
              + sigma^2_{pri}/(n'_r * n'_i)
```

This generalizes the two-facet D-study formulas from Phase 6 and extends them to arbitrary facet counts.

## Multi-Way ANOVA: The Computational Engine

### Problem

For a fully crossed design with f facets, we need to compute mean squares for each of the 2^f - 1 effects. The existing `twoWayANOVA` handles only 2 facets. A generalized multi-way ANOVA is required.

### Theory

For a balanced, fully crossed design, the sum of squares for each effect E is computed using the inclusion-exclusion principle on marginal means.

Define the marginal mean for effect E at a particular combination of levels (l_{f1}, l_{f2}, ...) for the facets in E:

```
Y_bar_E(levels) = mean of all observations where the facets in E are fixed at the given levels
                  (averaging over all facets NOT in E)
```

The sum of squares for effect E is then:

```
SS(E) = n_complement(E) * sum over all level combinations of E:
            (adjusted_mean(E, levels))^2
```

where `n_complement(E)` is the product of sample sizes for facets not in E.

The "adjusted mean" uses inclusion-exclusion to remove lower-order effects:

```
adjusted_mean(E, levels) = sum over all subsets S of E (including E and empty set):
                               (-1)^(|E| - |S|) * Y_bar_S(levels restricted to S)
```

For the empty set, Y_bar_{} is the grand mean.

For implementation, this reduces to:

1. Compute all marginal mean tables (one for each non-empty subset of F, plus the grand mean)
2. For each effect E, compute SS(E) via inclusion-exclusion on these marginal means

### Degrees of Freedom

For effect E in a fully crossed design:

```
df(E) = product of (n_f - 1) for all f in E
```

And the mean square is:

```
MS(E) = SS(E) / df(E)
```

### Computational Cost

For f facets with maximum sample size n:
- Number of effects: 2^f - 1
- Marginal mean tables: 2^f tables, each of size at most n^f
- Total work: O(2^f * n^f)

For typical G-theory studies (f <= 5, n <= 50), this is negligible. For f = 4 and n = 20, the total work is about 15 * 160,000 = 2.4M operations.

## Proposed API

### Data Input

The multi-dimensional data input is the most delicate API design question. Hard-coded array nesting (`[[T]]`, `[[[T]]]`, `[[[[T]]]]`) does not generalize. Instead, use a flat array with explicit dimensions:

```swift
/// Multi-dimensional data for a fully crossed design.
///
/// Stores observations in a flat array with row-major ordering.
/// For facets with sizes [n1, n2, n3], the element at indices [i, j, k]
/// is stored at flat index i * n2 * n3 + j * n3 + k.
public struct CrossedDesignData<T: Real>: Sendable, Equatable {
    /// Flat array of all observations in row-major order.
    public let values: [T]

    /// Ordered list of facet names matching the dimension order.
    public let facetNames: [String]

    /// Size of each dimension (number of levels per facet).
    public let dimensions: [Int]

    /// Total number of observations (product of all dimensions).
    public var count: Int { values.count }

    /// Accesses the observation at the given multi-dimensional index.
    ///
    /// - Parameter indices: Array of indices, one per facet.
    /// - Returns: The observation value at that position.
    /// - Precondition: `indices.count == dimensions.count` and each
    ///   index is within bounds.
    public func value(at indices: [Int]) -> T

    /// Creates a crossed design data container.
    ///
    /// - Parameters:
    ///   - values: Flat array of observations in row-major order.
    ///   - facetNames: Names for each dimension.
    ///   - dimensions: Number of levels per dimension.
    /// - Throws: `BusinessMathError.mismatchedDimensions` if
    ///   `values.count != product of dimensions` or if
    ///   `facetNames.count != dimensions.count`.
    public init(values: [T], facetNames: [String], dimensions: [Int]) throws
}
```

### EMS Rule Generator

```swift
/// An entry in the EMS table: a variance component and its coefficient.
public struct EMSEntry<T: Real>: Sendable, Equatable {
    /// The set of facet names identifying this variance component.
    public let component: Set<String>

    /// The coefficient (product of sample sizes for facets not in the component).
    public let coefficient: T
}

/// Generates the Expected Mean Squares (EMS) table for a fully crossed
/// random-effects design using Brennan's rules.
///
/// For each effect E (non-empty subset of facets), the EMS is:
/// ```
/// EMS(E) = sum over S where S is a superset of E:
///              c(S, E) * sigma^2_S
/// ```
/// where c(S, E) = product of n_f for f in (allFacets \ S).
///
/// - Parameters:
///   - facetNames: Ordered list of facet names.
///   - sampleSizes: Number of levels for each facet, keyed by name.
/// - Returns: Dictionary mapping each effect (as a `Set<String>`) to its
///   list of ``EMSEntry`` values (component, coefficient pairs).
/// - Throws: `BusinessMathError.invalidInput` if facetNames is empty or
///   sampleSizes does not contain all facet names.
public func generateEMSTable<T: Real>(
    facetNames: [String],
    sampleSizes: [String: Int]
) throws -> [Set<String>: [EMSEntry<T>]]
```

### Generalized G-Study

```swift
/// Result of a generalized G-study for arbitrary facet count.
///
/// Extends ``GStudyResult`` with the full EMS table and set-based
/// variance component indexing for designs with three or more facets.
public struct GeneralizedGStudyResult<T: Real>: Sendable, Equatable {
    /// All variance components indexed by their facet combination.
    /// Keys are sets of facet names (e.g., {"p", "r"} for the p x r interaction).
    public let varianceComponents: [Set<String>: T]

    /// Percentage of total variance for each component.
    public let percentOfTotal: [Set<String>: T]

    /// The EMS table used for extraction (for diagnostics and verification).
    public let emsTable: [Set<String>: [EMSEntry<T>]]

    /// The mean squares from the multi-way ANOVA.
    public let meanSquares: [Set<String>: T]

    /// Degrees of freedom for each effect.
    public let degreesOfFreedom: [Set<String>: Int]

    /// Facet definitions (name and sample size).
    public let facets: [GFacet]

    /// The name of the object-of-measurement facet.
    public let objectOfMeasurement: String

    /// Total variance (sum of all components).
    public let totalVariance: T

    /// Convenience: variance of the object of measurement.
    public var varianceObject: T {
        varianceComponents[Set([objectOfMeasurement])] ?? T.zero
    }
}

/// Generalized G-study for a fully crossed design with any number of facets.
///
/// Automatically generates the EMS table using Brennan's rules, computes
/// mean squares via multi-way ANOVA, and extracts variance components by
/// solving the EMS equations bottom-up (largest subsets first).
///
/// For one-facet and two-facet designs, this produces results consistent
/// with the specialized ``gStudy(_:facetLabel:)`` and
/// ``gStudy(_:facetLabels:)`` functions from Phase 6.
///
/// - Parameters:
///   - data: Multi-dimensional observation data in a ``CrossedDesignData``.
///     The first facet name in `data.facetNames` should be the object of
///     measurement (e.g., "persons").
///   - objectOfMeasurement: Name of the facet that is the object of
///     measurement. Must match one of `data.facetNames`.
/// - Returns: A ``GeneralizedGStudyResult`` with all 2^f - 1 variance
///   components, EMS table, and mean squares.
/// - Throws: `BusinessMathError.insufficientData` if any dimension has
///   fewer than 2 levels. `BusinessMathError.invalidInput` if
///   `objectOfMeasurement` is not found in the facet names.
public func generalizedGStudy<T: Real>(
    _ data: CrossedDesignData<T>,
    objectOfMeasurement: String
) throws -> GeneralizedGStudyResult<T>
```

### Generalized D-Study

```swift
/// Generalized D-study for a fully crossed design with any number of facets.
///
/// Predicts reliability under different study designs by substituting
/// D-study sample sizes into the G-study variance component formulas.
///
/// Relative error variance:
/// ```
/// sigma^2_delta = sum over E containing p (E != {p}):
///     sigma^2_E / product(n'_f for f in E \ {p})
/// ```
///
/// Absolute error variance:
/// ```
/// sigma^2_Delta = sum over E where E != {p}:
///     sigma^2_E / product(n'_f for f in E, excluding p if present)
/// ```
///
/// - Parameters:
///   - gResult: Result from ``generalizedGStudy``.
///   - designSizes: D-study sample sizes for each non-object facet.
///     Keys must match the non-object facet names from the G-study.
/// - Returns: A ``DStudyResult`` with generalizability coefficient,
///   dependability coefficient, and error variances.
/// - Throws: `BusinessMathError.invalidInput` if `designSizes` keys
///   do not match the non-object facets, or if any size is less than 1.
public func generalizedDStudy<T: Real>(
    _ gResult: GeneralizedGStudyResult<T>,
    designSizes: [String: Int]
) throws -> DStudyResult<T>
```

### Backward Compatibility

The existing Phase 6 `gStudy` overloads for one-facet and two-facet designs remain unchanged. The generalized functions are new, separate entry points. A convenience bridge allows users to convert between result types:

```swift
extension GeneralizedGStudyResult {
    /// Converts this result to a ``GStudyResult`` for compatibility
    /// with the ``dStudy(_:design:)`` function from Phase 6.
    ///
    /// Useful when a generalized G-study was run on a one-facet or
    /// two-facet design and the caller wants to use the simpler D-study API.
    public func asGStudyResult() -> GStudyResult<T>
}
```

## Algorithms

### Algorithm 1: Powerset Generation

```
function powerset(facets: [String]) -> [Set<String>]:
    if facets is empty:
        return [{}]
    let first = facets[0]
    let rest = powerset(facets[1...])
    return rest + rest.map { $0 union {first} }
```

Filter out the empty set to get all non-empty subsets (the 2^f - 1 effects).

### Algorithm 2: EMS Table Generation

```
function generateEMS(facetNames: [String], sampleSizes: [String: Int]):
    let allEffects = nonEmptyPowerset(facetNames)

    var emsTable: [Set<String>: [(component: Set<String>, coefficient: Int)]] = [:]

    for each effect E in allEffects:
        emsTable[E] = []
        for each component S in allEffects where E is a subset of S:
            let complementFacets = facetNames.filter { f in !S.contains(f) }
            let coefficient = complementFacets.isEmpty
                ? 1
                : complementFacets.map { sampleSizes[$0]! }.reduce(1, *)
            emsTable[E].append((component: S, coefficient: coefficient))

    return emsTable
```

### Algorithm 3: Multi-Way ANOVA (Marginal Means Approach)

```
function multiWayANOVA(data: CrossedDesignData, facetNames: [String], sampleSizes: [String: Int]):
    let allEffects = nonEmptyPowerset(facetNames)

    // Step 1: Compute marginal mean tables for every subset of facets
    var marginalMeans: [Set<String>: [IndexTuple: T]] = [:]
    marginalMeans[{}] = [(): grandMean(data)]

    for each subset S of facetNames (including non-empty subsets):
        for each combination of levels in S:
            marginalMeans[S][levels] = mean of all observations where
                the facets in S are fixed at the given levels

    // Step 2: Compute SS for each effect via inclusion-exclusion
    var SS: [Set<String>: T] = [:]
    var df: [Set<String>: Int] = [:]
    var MS: [Set<String>: T] = [:]

    for each effect E in allEffects:
        df[E] = product of (sampleSizes[f] - 1) for f in E
        let nComplement = product of sampleSizes[f] for f not in E

        var ssE = 0
        for each combination of levels in E:
            var adjustedMean = 0
            for each subset S of E (including empty set and E itself):
                let sign = (-1)^(|E| - |S|)
                let marginalAtLevels = marginalMeans[S][levels restricted to S]
                adjustedMean += sign * marginalAtLevels
            ssE += adjustedMean^2

        SS[E] = nComplement * ssE
        MS[E] = SS[E] / df[E]

    return MS, df
```

### Algorithm 4: Variance Component Extraction

```
function extractVarianceComponents(MS: [Set: T], emsTable: table):
    var sigma: [Set<String>: T] = [:]

    // Sort effects by size descending (largest first = residual)
    let effects = allEffects.sorted(by: { $0.count > $1.count })

    for E in effects:
        // Find the self-coefficient c(E, E)
        let selfCoeff = emsTable[E].first(where: { $0.component == E })!.coefficient

        // Subtract contributions from already-solved supersets
        var numerator = MS[E]
        for (S, coeff) in emsTable[E] where S != E:
            numerator -= T(coeff) * sigma[S]!

        sigma[E] = max(T.zero, numerator / T(selfCoeff))

    return sigma
```

### Verification Property

The extraction is correct if and only if for every effect E:

```
MS(E) == sum over S where S is a superset of E: c(S, E) * sigma^2_S
```

(up to the truncation of negative components to zero). This property should be tested.

## File Organization

```
Sources/BusinessMath/Statistics/
  ANOVA/
    oneWayANOVA.swift                                    -- EXISTS
    twoWayANOVA.swift                                    -- EXISTS
    multiWayANOVA.swift                                  -- NEW
  Reliability/
    gStudy.swift                                         -- EXISTS (Phase 6)
    dStudy.swift                                         -- EXISTS (Phase 6)
    GStudyResult.swift                                   -- EXISTS (Phase 6)
    DStudyResult.swift                                   -- EXISTS (Phase 6)
    VarianceComponent.swift                              -- EXISTS (Phase 6)
    GFacet.swift                                         -- EXISTS (Phase 6)
    CrossedDesignData.swift                              -- NEW
    EMSEntry.swift                                       -- NEW
    emsTableGenerator.swift                              -- NEW
    GeneralizedGStudyResult.swift                        -- NEW
    generalizedGStudy.swift                              -- NEW
    generalizedDStudy.swift                              -- NEW

Tests/BusinessMathTests/Statistics Tests/
  ANOVA Tests/
    MultiWayANOVATests.swift                             -- NEW
  Reliability Tests/
    GStudyTests.swift                                    -- EXISTS (Phase 6)
    DStudyTests.swift                                    -- EXISTS (Phase 6)
    EMSTableGeneratorTests.swift                         -- NEW
    GeneralizedGStudyTests.swift                         -- NEW
    GeneralizedDStudyTests.swift                         -- NEW
    CrossedDesignDataTests.swift                         -- NEW
```

## Implementation Plan

### Phase 1: CrossedDesignData and Powerset Utilities (~40 lines)

**RED:**
1. `CrossedDesignData` with 3 facets [2, 3, 4]: `value(at: [1, 2, 3])` returns the correct element
2. Row-major index for [i, j, k] matches `i * n2 * n3 + j * n3 + k`
3. Mismatched `values.count` vs product of `dimensions`: throws `mismatchedDimensions`
4. Mismatched `facetNames.count` vs `dimensions.count`: throws `mismatchedDimensions`
5. Empty facet names or dimensions: throws `insufficientData`
6. Marginal mean computation: mean over one facet matches manual calculation

**GREEN:** Implement `CrossedDesignData`, flat-to-multi index conversion, and marginal mean extraction.

### Phase 2: EMS Table Generator (~60 lines)

**RED:**
7. Two-facet EMS table matches the known Phase 6 table (p x r): three effects, three components
8. Three-facet EMS table matches the hand-derived table in the Theory section above: seven effects, verify all 7 EMS equations
9. Four-facet EMS table: verify EMS({p}) has 8 terms (one for each superset of {p}), all coefficients correct
10. Coefficient of sigma^2_F (residual) is always 1 in every EMS equation
11. Coefficient of sigma^2_E in its own EMS(E) equals product of n_f for f not in E
12. Number of entries in EMS table equals 2^f - 1
13. Single facet (degenerate): throws or produces trivial table
14. Empty facet list: throws `invalidInput`

**GREEN:** Implement powerset enumeration and Brennan's coefficient rule.

### Phase 3: Multi-Way ANOVA for Crossed Designs (~120 lines)

**RED:**
15. Two-facet design: MS values match `twoWayANOVA` results (cross-validate)
16. Three-facet balanced design with known textbook SS values (Brennan 2001, Chapter 4)
17. Degrees of freedom for each effect: df(E) = product of (n_f - 1) for f in E
18. Sum of all SS equals SS_total
19. Sum of all df equals N - 1
20. All observations identical: all SS = 0, all MS = 0
21. Only one facet varies: only that main effect and interactions involving it have nonzero SS
22. Any dimension with fewer than 2 levels: throws `insufficientData`

**GREEN:** Implement marginal means computation and inclusion-exclusion SS decomposition.

### Phase 4: Variance Component Extraction (~40 lines)

**RED:**
23. Three-facet design with known variance components (Shavelson and Webb 1991, Table 5.1)
24. Two-facet extraction matches Phase 6 results
25. Negative raw estimate is truncated to zero (construct data where this occurs)
26. All components sum to a reasonable total (percentages sum to 100%)
27. Perfectly uniform data: all components are zero
28. Only person variance: sigma^2_p dominates, all others near zero

**GREEN:** Implement bottom-up solver using the EMS table from Phase 2.

### Phase 5: Generalized G-Study (Orchestration) (~30 lines)

**RED:**
29. Three-facet G-study end-to-end: data in, `GeneralizedGStudyResult` out, all components match textbook
30. Two-facet G-study via generalized function matches Phase 6 `gStudy(_:facetLabels:)` results
31. Four-facet G-study: 15 components extracted, all non-negative
32. Object of measurement not in facet names: throws `invalidInput`
33. `asGStudyResult()` conversion produces valid `GStudyResult` for two-facet case

**GREEN:** Wire together CrossedDesignData -> Multi-Way ANOVA -> EMS Table -> Extraction -> Result.

### Phase 6: Generalized D-Study (~40 lines)

**RED:**
34. Three-facet D-study: relative error variance matches hand computation
35. Three-facet D-study: absolute error variance matches hand computation
36. Two-facet D-study via generalized function matches Phase 6 `dStudy` results
37. Doubling any facet size reduces both error variances
38. D-study with all facet sizes = 1: maximum error variance
39. D-study with very large facet sizes: coefficients approach 1.0 (perfect reliability)
40. Design sizes don't match non-object facets: throws `invalidInput`
41. Design size < 1: throws `invalidInput`
42. Four-facet D-study: verify generalizability and dependability coefficients against EduG software output

**GREEN:** Implement relative and absolute error variance formulas using the generalized rules.

## Effort Estimates

| Phase | New Files | Estimated Lines | Test Cases | Dependencies |
|-------|-----------|----------------|------------|--------------|
| 1: CrossedDesignData | 1 source + 1 test | ~40 | 6 | None |
| 2: EMS Table Generator | 2 source + 1 test | ~60 | 8 | Phase 1 |
| 3: Multi-Way ANOVA | 1 source + 1 test | ~120 | 8 | Phase 1 |
| 4: Variance Component Extraction | internal (in generalizedGStudy) | ~40 | 6 | Phases 2, 3 |
| 5: Generalized G-Study | 2 source + 1 test | ~30 | 5 | Phases 2, 3, 4 |
| 6: Generalized D-Study | 1 source + 1 test | ~40 | 9 | Phase 5 |
| **Total** | **7 source + 5 test** | **~330** | **~42** | |

Estimated effort: 2-3 sessions (assuming Phase 6 from `PROPOSAL_advanced_reliability.md` has landed).

## Phase Dependencies

```
Phase 6 from PROPOSAL_advanced_reliability.md (two-facet G-theory)
              |
              v
    Phase 1: CrossedDesignData
         |           |
         v           v
    Phase 2:     Phase 3:
    EMS Table    Multi-Way ANOVA
         |           |
         v           v
    Phase 4: Variance Component Extraction
              |
              v
    Phase 5: Generalized G-Study
              |
              v
    Phase 6: Generalized D-Study
```

Phases 2 and 3 are independent of each other and can be developed in parallel once Phase 1 lands.

## References

- Brennan, R.L. (2001). *Generalizability Theory*. Springer-Verlag. Chapter 4: Multi-facet designs; Appendix B: EMS rules for crossed designs.
- Cardinet, J., Johnson, S., & Pini, G. (2010). *Applying Generalizability Theory Using EduG*. Routledge. (Practical computation guide with worked examples for 3+ facets.)
- Shavelson, R.J. & Webb, N.M. (1991). *Generalizability Theory: A Primer*. Sage Publications. Chapter 5: Multi-facet designs. Table 5.1 provides reference variance components for a three-facet design.
- Cronbach, L.J., Gleser, G.C., Nanda, H., & Rajaratnam, N. (1972). *The Dependability of Behavioral Measurements*. Wiley. (Original theoretical foundation for multi-facet G-theory.)
- Webb, N.M., Shavelson, R.J., & Haertel, E.H. (2006). "Reliability coefficients and generalizability theory." In C.R. Rao & S. Sinharay (Eds.), *Handbook of Statistics*, Vol. 26, pp. 81-124. (Modern overview of EMS-based variance component estimation.)

## Not In Scope

- **Unbalanced multi-facet designs** -- Require Henderson's Method III or REML for variance component estimation. The method-of-moments approach via EMS rules assumes balanced (rectangular) data.
- **Nested facets within a generalized design** -- Mixed crossed/nested designs (e.g., raters nested within schools, crossed with items) require modified EMS rules where nested facets do not appear in certain interactions. This is a substantial extension requiring Cornfield-Tukey rules for nested designs.
- **Multivariate G-theory** -- Simultaneous analysis of multiple dependent measures (e.g., multiple subscales) requires matrix-valued variance components and a different mathematical framework.
- **Fixed facets** -- The EMS rules presented here assume all facets are random. When some facets are fixed (mixed-model G-theory), the EMS rules change: terms involving fixed facets are removed from certain EMS equations, and the D-study formulas are modified. Supporting mixed models would require an additional `isRandom` property on `GFacet` and modified EMS generation logic.
- **Confidence intervals on variance components** -- Bootstrap or jackknife intervals for estimated variance components. Useful but orthogonal to the core EMS machinery.
- **Negative variance component handling beyond truncation** -- Alternative approaches such as constrained REML or Bayesian estimation that avoid the bias introduced by truncation. These belong in a future REML-based G-theory extension.

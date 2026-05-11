import Testing
import Foundation
@testable import BusinessMath

@Suite("Generalized G-Study — Multi-Facet Generalizability Study")
struct GeneralizedGStudyTests {

    // MARK: - Helpers

    /// Creates a three-facet test dataset: 4 persons × 3 raters × 2 items.
    ///
    /// Constructed from additive effects plus deterministic residuals:
    /// - Person effects: [10, 20, 15, 25]
    /// - Rater effects: [0, 2, -2]
    /// - Item effects: [0, 3]
    /// - Small deterministic residuals for non-trivial interactions.
    private func threeFacetData() throws -> CrossedDesignData<Double> {
        let personEffects: [Double] = [10, 20, 15, 25]
        let raterEffects: [Double] = [0, 2, -2]
        let itemEffects: [Double] = [0, 3]

        // Small deterministic perturbations for interactions
        // pr interaction: alternating +/- pattern
        let prResidual: [[Double]] = [
            [0.5, -0.3, 0.1],
            [-0.4, 0.2, -0.1],
            [0.3, -0.5, 0.2],
            [-0.2, 0.4, -0.3]
        ]
        // pi interaction: small
        let piResidual: [[Double]] = [
            [0.1, -0.1],
            [-0.2, 0.2],
            [0.15, -0.15],
            [-0.05, 0.05]
        ]
        // ri interaction: small
        let riResidual: [[Double]] = [
            [0.2, -0.2],
            [-0.1, 0.1],
            [0.3, -0.3]
        ]
        // pri residual: very small
        let priResidual: [[[Double]]] = [
            [[0.05, -0.05], [0.1, -0.1], [-0.15, 0.15]],
            [[-0.08, 0.08], [0.12, -0.12], [-0.04, 0.04]],
            [[0.03, -0.03], [-0.07, 0.07], [0.04, -0.04]],
            [[-0.02, 0.02], [0.06, -0.06], [0.11, -0.11]]
        ]

        // 4 persons × 3 raters × 2 items = 24 values (row-major: [p][r][i])
        var values: [Double] = []
        for p in 0..<4 {
            for r in 0..<3 {
                for i in 0..<2 {
                    let val = personEffects[p] + raterEffects[r] + itemEffects[i]
                        + prResidual[p][r] + piResidual[p][i]
                        + riResidual[r][i] + priResidual[p][r][i]
                    values.append(val)
                }
            }
        }

        return try CrossedDesignData<Double>(
            values: values,
            facetNames: ["p", "raters", "items"],
            dimensions: [4, 3, 2]
        )
    }

    // MARK: - Three-Facet End-to-End

    @Test("Three-facet G-study produces 7 variance components, all non-negative")
    func testThreeFacetEndToEnd() throws {
        let data = try threeFacetData()
        let result = try generalizedGStudy(data, objectOfMeasurement: "p")

        // 2^3 - 1 = 7 effects
        #expect(result.varianceComponents.count == 7)

        // All variance components must be non-negative
        for (effect, variance) in result.varianceComponents {
            #expect(variance >= 0.0, "Variance for \(effect) should be >= 0")
        }

        // Person variance should be the dominant component
        // (person effects span 10-25, other effects are much smaller)
        let personVar = result.varianceComponents[Set(["p"])]
        #expect(personVar != nil)
        #expect(personVar! > 0.0)

        // varianceObject should match person variance
        #expect(result.varianceObject == personVar!)

        // Total variance should equal sum of all components
        let sumVar = result.varianceComponents.values.reduce(0.0, +)
        #expect(abs(result.totalVariance - sumVar) < 1e-10)
    }

    @Test("Three-facet: percentages sum to 100%")
    func testThreeFacetPercentages() throws {
        let data = try threeFacetData()
        let result = try generalizedGStudy(data, objectOfMeasurement: "p")

        let totalPct = result.percentOfTotal.values.reduce(0.0, +)
        #expect(abs(totalPct - 100.0) < 1e-8)
    }

    @Test("Three-facet: person variance dominates for person-driven data")
    func testPersonVarianceDominates() throws {
        let data = try threeFacetData()
        let result = try generalizedGStudy(data, objectOfMeasurement: "p")

        let personPct = result.percentOfTotal[Set(["p"])] ?? 0.0
        // Person effects span 15 units; other effects are < 5 units
        #expect(personPct > 50.0, "Person variance should be > 50% of total")
    }

    @Test("Three-facet: EMS table has 7 effects")
    func testThreeFacetEMSTable() throws {
        let data = try threeFacetData()
        let result = try generalizedGStudy(data, objectOfMeasurement: "p")

        #expect(result.emsTable.count == 7)
    }

    // MARK: - Two-Facet Backward Compatibility

    @Test("Two-facet generalized G-study matches existing gStudy results")
    func testTwoFacetMatchesExisting() throws {
        // 4 subjects × 3 raters — same data as existing tests
        let ratings: [[Double]] = [
            [4.0, 5.0, 6.0],
            [2.0, 3.0, 4.0],
            [8.0, 9.0, 10.0],
            [6.0, 7.0, 8.0]
        ]

        // Run existing one-facet gStudy
        let existingResult = try gStudy(ratings, facetLabel: "r")

        // Run generalized gStudy on same data
        let values = ratings.flatMap { $0 }
        let data = try CrossedDesignData<Double>(
            values: values,
            facetNames: ["p", "r"],
            dimensions: [4, 3]
        )
        let generalizedResult = try generalizedGStudy(data, objectOfMeasurement: "p")

        // Compare variance components
        let genPersonVar = generalizedResult.varianceComponents[Set(["p"])] ?? 0.0
        let genRaterVar = generalizedResult.varianceComponents[Set(["r"])] ?? 0.0
        let genResidualVar = generalizedResult.varianceComponents[Set(["p", "r"])] ?? 0.0

        let existPersonVar = existingResult.variancePersons
        let existRaterVar = existingResult.components.first { $0.source == "r" }?.variance ?? 0.0
        let existResidualVar = existingResult.components.first { $0.source == "p x r" }?.variance ?? 0.0

        #expect(abs(genPersonVar - existPersonVar) < 1e-10)
        #expect(abs(genRaterVar - existRaterVar) < 1e-10)
        #expect(abs(genResidualVar - existResidualVar) < 1e-10)
    }

    // MARK: - Four-Facet

    @Test("Four-facet: 15 components, all non-negative")
    func testFourFacet15Components() throws {
        // 3 × 2 × 2 × 2 = 24 values
        let values: [Double] = [
            10, 12, 11, 13, 14, 16, 15, 17,
            20, 22, 21, 23, 24, 26, 25, 27,
            15, 17, 16, 18, 19, 21, 20, 22
        ]
        let data = try CrossedDesignData<Double>(
            values: values,
            facetNames: ["p", "a", "b", "c"],
            dimensions: [3, 2, 2, 2]
        )

        let result = try generalizedGStudy(data, objectOfMeasurement: "p")

        // 2^4 - 1 = 15
        #expect(result.varianceComponents.count == 15)

        for (effect, variance) in result.varianceComponents {
            #expect(variance >= 0.0, "Variance for \(effect) should be >= 0")
        }
    }

    // MARK: - Error Cases

    @Test("objectOfMeasurement not in facets throws invalidInput")
    func testInvalidObjectOfMeasurement() throws {
        let data = try CrossedDesignData<Double>(
            values: (0..<12).map { Double($0) },
            facetNames: ["p", "r"],
            dimensions: [4, 3]
        )

        #expect(throws: BusinessMathError.self) {
            let _ = try generalizedGStudy(data, objectOfMeasurement: "unknown")
        }
    }

    // MARK: - asGStudyResult Conversion

    @Test("asGStudyResult conversion produces correct GStudyResult")
    func testAsGStudyResultConversion() throws {
        let data = try threeFacetData()
        let genResult = try generalizedGStudy(data, objectOfMeasurement: "p")
        let gResult = genResult.asGStudyResult()

        // Person variance should match
        #expect(abs(gResult.variancePersons - genResult.varianceObject) < 1e-10)

        // Total variance should match
        #expect(abs(gResult.totalVariance - genResult.totalVariance) < 1e-10)

        // Should have 7 components for 3-facet study
        #expect(gResult.components.count == 7)

        // personCount should be 4
        #expect(gResult.personCount == 4)

        // Non-object facets should be raters and items (2 facets)
        #expect(gResult.facets.count == 2)
        let facetLabels = Set(gResult.facets.map { $0.label })
        #expect(facetLabels.contains("raters"))
        #expect(facetLabels.contains("items"))
    }

    // MARK: - Uniform Data

    @Test("Uniform data: all variance components zero")
    func testUniformDataAllZero() throws {
        let values = [Double](repeating: 7.0, count: 12)
        let data = try CrossedDesignData<Double>(
            values: values,
            facetNames: ["p", "r"],
            dimensions: [4, 3]
        )

        let result = try generalizedGStudy(data, objectOfMeasurement: "p")

        for (effect, variance) in result.varianceComponents {
            #expect(abs(variance) < 1e-10, "Variance for \(effect) should be 0")
        }
    }
}

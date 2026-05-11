import Testing
import Foundation
@testable import BusinessMath

@Suite("Multi-Way ANOVA — Fully Crossed Design")
struct MultiWayANOVATests {

    // MARK: - Cross-Validation with Two-Way ANOVA

    @Test("Two-facet multiWayANOVA matches twoWayANOVA results")
    func testTwoFacetMatchesTwoWayANOVA() throws {
        // 4 subjects × 3 raters — same data as twoWayANOVA tests
        let ratings: [[Double]] = [
            [4.0, 5.0, 6.0],
            [2.0, 3.0, 4.0],
            [8.0, 9.0, 10.0],
            [6.0, 7.0, 8.0]
        ]

        let twoWay = try twoWayANOVA(ratings)

        // Flatten into CrossedDesignData
        let values = ratings.flatMap { $0 }
        let data = try CrossedDesignData<Double>(
            values: values,
            facetNames: ["p", "r"],
            dimensions: [4, 3]
        )

        let multi = try multiWayANOVA(data)

        // Compare SS values
        let ssP = multi.sumOfSquares[Set(["p"])]
        let ssR = multi.sumOfSquares[Set(["r"])]
        let ssPR = multi.sumOfSquares[Set(["p", "r"])]

        #expect(ssP != nil)
        #expect(ssR != nil)
        #expect(ssPR != nil)

        #expect(abs(ssP! - twoWay.ssSubjects) < 1e-10)
        #expect(abs(ssR! - twoWay.ssRaters) < 1e-10)
        #expect(abs(ssPR! - twoWay.ssError) < 1e-10)

        // Compare df
        #expect(multi.degreesOfFreedom[Set(["p"])] == twoWay.dfSubjects)
        #expect(multi.degreesOfFreedom[Set(["r"])] == twoWay.dfRaters)
        #expect(multi.degreesOfFreedom[Set(["p", "r"])] == twoWay.dfError)

        // Compare MS
        #expect(abs(multi.meanSquares[Set(["p"])]! - twoWay.msSubjects) < 1e-10)
        #expect(abs(multi.meanSquares[Set(["r"])]! - twoWay.msRaters) < 1e-10)
        #expect(abs(multi.meanSquares[Set(["p", "r"])]! - twoWay.msError) < 1e-10)
    }

    // MARK: - Degrees of Freedom

    @Test("Degrees of freedom match product-of-(n_f - 1) formula")
    func testDegreesOfFreedom() throws {
        // 3 × 4 × 2
        let values = (0..<24).map { Double($0) }
        let data = try CrossedDesignData<Double>(
            values: values,
            facetNames: ["a", "b", "c"],
            dimensions: [3, 4, 2]
        )

        let result = try multiWayANOVA(data)

        // df({a}) = 3-1 = 2
        #expect(result.degreesOfFreedom[Set(["a"])] == 2)

        // df({b}) = 4-1 = 3
        #expect(result.degreesOfFreedom[Set(["b"])] == 3)

        // df({c}) = 2-1 = 1
        #expect(result.degreesOfFreedom[Set(["c"])] == 1)

        // df({a,b}) = 2*3 = 6
        #expect(result.degreesOfFreedom[Set(["a", "b"])] == 6)

        // df({a,c}) = 2*1 = 2
        #expect(result.degreesOfFreedom[Set(["a", "c"])] == 2)

        // df({b,c}) = 3*1 = 3
        #expect(result.degreesOfFreedom[Set(["b", "c"])] == 3)

        // df({a,b,c}) = 2*3*1 = 6
        #expect(result.degreesOfFreedom[Set(["a", "b", "c"])] == 6)
    }

    @Test("Sum of all df equals N - 1")
    func testDfSumEqualsNMinus1() throws {
        let values = (0..<24).map { Double($0) }
        let data = try CrossedDesignData<Double>(
            values: values,
            facetNames: ["a", "b", "c"],
            dimensions: [3, 4, 2]
        )

        let result = try multiWayANOVA(data)

        let totalDf = result.degreesOfFreedom.values.reduce(0, +)
        #expect(totalDf == 24 - 1)
    }

    // MARK: - SS Properties

    @Test("Sum of all SS equals SS_total for three-facet data")
    func testSSPartition() throws {
        // Use data with non-trivial variance
        let values: [Double] = [
            3, 5, 7, 2,
            8, 6, 4, 9,
            1, 2, 3, 5,
            6, 7, 8, 4,
            2, 3, 5, 1,
            9, 1, 4, 6
        ]
        let data = try CrossedDesignData<Double>(
            values: values,
            facetNames: ["a", "b", "c"],
            dimensions: [2, 3, 4]
        )

        let result = try multiWayANOVA(data)

        // Compute SS_total manually
        let n = Double(values.count)
        let grandMean = values.reduce(0.0, +) / n
        var ssTotal = 0.0
        for v in values {
            let diff = v - grandMean
            ssTotal += diff * diff
        }

        let sumSS = result.sumOfSquares.values.reduce(0.0, +)
        #expect(abs(sumSS - ssTotal) < 1e-8)
    }

    // MARK: - Uniform Data

    @Test("All identical observations: all SS = 0")
    func testAllIdenticalObservations() throws {
        let values = [Double](repeating: 5.0, count: 24)
        let data = try CrossedDesignData<Double>(
            values: values,
            facetNames: ["p", "r", "i"],
            dimensions: [2, 3, 4]
        )

        let result = try multiWayANOVA(data)

        for (effect, ss) in result.sumOfSquares {
            #expect(abs(ss) < 1e-10, "SS for \(effect) should be 0 for uniform data")
        }
    }

    // MARK: - Error Cases

    @Test("Any dimension < 2 throws insufficientData")
    func testDimensionLessThan2Throws() throws {
        // Second dimension is 1
        let data = try CrossedDesignData<Double>(
            values: [1.0, 2.0],
            facetNames: ["a", "b"],
            dimensions: [2, 1]
        )

        #expect(throws: BusinessMathError.self) {
            let _ = try multiWayANOVA(data)
        }
    }

    // MARK: - Three-Facet Verification

    @Test("Three-facet ANOVA produces 7 effects")
    func testThreeFacetEffectCount() throws {
        let values = (0..<24).map { Double($0) }
        let data = try CrossedDesignData<Double>(
            values: values,
            facetNames: ["p", "r", "i"],
            dimensions: [2, 3, 4]
        )

        let result = try multiWayANOVA(data)

        #expect(result.sumOfSquares.count == 7)
        #expect(result.degreesOfFreedom.count == 7)
        #expect(result.meanSquares.count == 7)
    }

    @Test("MS = SS / df for all effects")
    func testMSEqualsSSDividedByDf() throws {
        let values: [Double] = [
            3, 5, 7, 2,
            8, 6, 4, 9,
            1, 2, 3, 5,
            6, 7, 8, 4,
            2, 3, 5, 1,
            9, 1, 4, 6
        ]
        let data = try CrossedDesignData<Double>(
            values: values,
            facetNames: ["a", "b", "c"],
            dimensions: [2, 3, 4]
        )

        let result = try multiWayANOVA(data)

        for (effect, ms) in result.meanSquares {
            let ss = result.sumOfSquares[effect] ?? 0.0
            let df = result.degreesOfFreedom[effect] ?? 0
            guard df > 0 else { continue }
            let expected = ss / Double(df)
            #expect(abs(ms - expected) < 1e-10,
                    "MS should equal SS/df for effect \(effect)")
        }
    }
}

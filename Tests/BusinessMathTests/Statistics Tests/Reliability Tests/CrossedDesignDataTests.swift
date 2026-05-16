import Testing
import Foundation
@testable import BusinessMath

@Suite("CrossedDesignData — Multi-Dimensional Crossed Design Storage")
struct CrossedDesignDataTests {

    @Test("Value access with 3 facets [2, 3, 4] uses row-major indexing")
    func testValueAccessThreeFacets() throws {
        // 2 × 3 × 4 = 24 values
        let values: [Double] = (0..<24).map { Double($0) }
        let data = try CrossedDesignData<Double>(
            values: values,
            facetNames: ["p", "raters", "items"],
            dimensions: [2, 3, 4]
        )

        #expect(data.count == 24)

        // value at [0, 0, 0] = index 0
        #expect(abs(data.value(at: [0, 0, 0]) - 0.0) < 1e-6)

        // value at [0, 0, 1] = index 1
        #expect(abs(data.value(at: [0, 0, 1]) - 1.0) < 1e-6)

        // value at [0, 1, 0] = index 4
        #expect(abs(data.value(at: [0, 1, 0]) - 4.0) < 1e-6)

        // value at [1, 0, 0] = index 12 (1 * 3 * 4)
        #expect(abs(data.value(at: [1, 0, 0]) - 12.0) < 1e-6)

        // value at [1, 2, 3] = 1*12 + 2*4 + 3 = 23
        #expect(abs(data.value(at: [1, 2, 3]) - 23.0) < 1e-6)
    }

    @Test("Row-major index verification: i*n2*n3 + j*n3 + k")
    func testRowMajorIndexFormula() throws {
        let dims = [2, 3, 4]
        let values: [Double] = (0..<24).map { Double($0) }
        let data = try CrossedDesignData<Double>(
            values: values,
            facetNames: ["a", "b", "c"],
            dimensions: dims
        )

        // Verify every possible index combination
        for i in 0..<dims[0] {
            for j in 0..<dims[1] {
                for k in 0..<dims[2] {
                    let expectedFlat = i * dims[1] * dims[2] + j * dims[2] + k
                    #expect(data.value(at: [i, j, k]) == Double(expectedFlat))
                }
            }
        }
    }

    @Test("Mismatched value count throws mismatchedDimensions")
    func testMismatchedValueCountThrows() throws {
        #expect(throws: BusinessMathError.self) {
            let _ = try CrossedDesignData<Double>(
                values: [1.0, 2.0, 3.0],
                facetNames: ["p", "raters"],
                dimensions: [2, 3]
            )
        }
    }

    @Test("Mismatched facet names count throws mismatchedDimensions")
    func testMismatchedFacetNamesThrows() throws {
        #expect(throws: BusinessMathError.self) {
            let _ = try CrossedDesignData<Double>(
                values: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
                facetNames: ["p", "raters", "items"],
                dimensions: [2, 3]
            )
        }
    }

    @Test("Empty facet names throws insufficientData")
    func testEmptyFacetNamesThrows() throws {
        #expect(throws: BusinessMathError.self) {
            let _ = try CrossedDesignData<Double>(
                values: [],
                facetNames: [],
                dimensions: []
            )
        }
    }

    @Test("Dimension of zero throws mismatchedDimensions")
    func testZeroDimensionThrows() throws {
        #expect(throws: BusinessMathError.self) {
            let _ = try CrossedDesignData<Double>(
                values: [],
                facetNames: ["p"],
                dimensions: [0]
            )
        }
    }

    @Test("Single facet works correctly")
    func testSingleFacet() throws {
        let data = try CrossedDesignData<Double>(
            values: [10.0, 20.0, 30.0],
            facetNames: ["items"],
            dimensions: [3]
        )

        #expect(data.count == 3)
        #expect(abs(data.value(at: [0]) - 10.0) < 1e-6)
        #expect(abs(data.value(at: [1]) - 20.0) < 1e-6)
        #expect(abs(data.value(at: [2]) - 30.0) < 1e-6)
    }

    @Test("Two facets: 2×3 matrix")
    func testTwoFacets() throws {
        let data = try CrossedDesignData<Double>(
            values: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
            facetNames: ["p", "raters"],
            dimensions: [2, 3]
        )

        #expect(abs(data.value(at: [0, 0]) - 1.0) < 1e-6)
        #expect(abs(data.value(at: [0, 2]) - 3.0) < 1e-6)
        #expect(abs(data.value(at: [1, 0]) - 4.0) < 1e-6)
        #expect(abs(data.value(at: [1, 2]) - 6.0) < 1e-6)
    }

    @Test("Equatable conformance")
    func testEquatable() throws {
        let data1 = try CrossedDesignData<Double>(
            values: [1.0, 2.0, 3.0, 4.0],
            facetNames: ["a", "b"],
            dimensions: [2, 2]
        )
        let data2 = try CrossedDesignData<Double>(
            values: [1.0, 2.0, 3.0, 4.0],
            facetNames: ["a", "b"],
            dimensions: [2, 2]
        )
        let data3 = try CrossedDesignData<Double>(
            values: [1.0, 2.0, 3.0, 5.0],
            facetNames: ["a", "b"],
            dimensions: [2, 2]
        )

        #expect(data1 == data2)
        #expect(data1 != data3)
    }
}

import Numerics

/// Multi-dimensional data for a fully crossed design.
///
/// Stores observations in a flat array with row-major ordering.
/// For facets with sizes `[n1, n2, n3]`, the element at indices `[i, j, k]`
/// is at flat index `i * n2 * n3 + j * n3 + k`.
///
/// Example:
/// ```swift
/// // 2 persons × 3 raters × 4 items
/// let data = try CrossedDesignData<Double>(
///     values: (0..<24).map { Double($0) },
///     facetNames: ["p", "raters", "items"],
///     dimensions: [2, 3, 4]
/// )
/// let v = data.value(at: [1, 2, 3]) // flat index: 1*12 + 2*4 + 3 = 23
/// ```
public struct CrossedDesignData<T: Real & Sendable>: Sendable, Equatable {

    /// The observation values stored in row-major order.
    public let values: [T]

    /// The labels for each facet dimension (e.g., `["p", "raters", "items"]`).
    public let facetNames: [String]

    /// The number of levels for each facet (e.g., `[4, 3, 2]`).
    public let dimensions: [Int]

    /// The total number of observations.
    public var count: Int { values.count }

    /// Creates a crossed design data container.
    ///
    /// - Parameters:
    ///   - values: Flat array of observations in row-major order.
    ///   - facetNames: Labels for each facet dimension.
    ///   - dimensions: Number of levels for each facet.
    /// - Throws: `BusinessMathError.insufficientData` if inputs are empty.
    ///   `BusinessMathError.mismatchedDimensions` if counts are inconsistent,
    ///   names don't match dimensions, or any dimension is less than 1.
    public init(values: [T], facetNames: [String], dimensions: [Int]) throws {
        guard !facetNames.isEmpty else {
            throw BusinessMathError.insufficientData(
                required: 1, actual: 0,
                context: "CrossedDesignData requires at least one facet")
        }

        guard !dimensions.isEmpty else {
            throw BusinessMathError.insufficientData(
                required: 1, actual: 0,
                context: "CrossedDesignData requires at least one dimension")
        }

        guard facetNames.count == dimensions.count else {
            throw BusinessMathError.mismatchedDimensions(
                message: "Number of facet names must equal number of dimensions",
                expected: "\(dimensions.count)",
                actual: "\(facetNames.count)")
        }

        for (index, dim) in dimensions.enumerated() {
            guard dim >= 1 else {
                throw BusinessMathError.mismatchedDimensions(
                    message: "Dimension for '\(facetNames[index])' must be at least 1",
                    expected: ">= 1",
                    actual: "\(dim)")
            }
        }

        let expectedCount = dimensions.reduce(1, *)

        guard values.count == expectedCount else {
            throw BusinessMathError.mismatchedDimensions(
                message: "Value count must equal the product of dimensions",
                expected: "\(expectedCount)",
                actual: "\(values.count)")
        }

        self.values = values
        self.facetNames = facetNames
        self.dimensions = dimensions
    }

    /// Retrieves the value at the given multi-dimensional indices.
    ///
    /// - Parameter indices: An array of indices, one per facet dimension.
    /// - Returns: The observation at the specified position.
    /// - Precondition: `indices.count` must equal `dimensions.count`,
    ///   and each index must be within range for its dimension.
    public func value(at indices: [Int]) -> T {
        var flatIndex = 0
        var currentStride = 1
        for i in Swift.stride(from: dimensions.count - 1, through: 0, by: -1) {
            flatIndex += indices[i] * currentStride
            currentStride *= dimensions[i]
        }
        return values[flatIndex]
    }
}

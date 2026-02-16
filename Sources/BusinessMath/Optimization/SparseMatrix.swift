//
//  SparseMatrix.swift
//  BusinessMath
//
//  Created by Claude Code on 12/11/25.
//  Phase 8.1: Sparse Matrix Infrastructure with CSR format
//

import Foundation

/// Sparse matrix stored in Compressed Sparse Row (CSR) format
///
/// CSR format uses three arrays:
/// - values: Non-zero elements (length = nnz)
/// - columnIndices: Column index for each non-zero (length = nnz)
/// - rowPointers: Start index in values array for each row (length = rows + 1)
///
/// This provides O(nnz) storage and O(nnz) matrix-vector multiplication,
/// dramatically more efficient than O(n²) dense storage for sparse matrices.
///
/// Example:
/// ```swift
/// let dense = [
///     [1.0, 0.0, 2.0],
///     [0.0, 3.0, 0.0],
///     [4.0, 0.0, 5.0]
/// ]
/// let sparse = SparseMatrix(dense: dense)
/// let result = sparse.multiply(vector: [1, 2, 3])
/// ```
public struct SparseMatrix {
    /// Number of rows in the matrix
    public let rows: Int

    /// Number of columns in the matrix
    public let columns: Int

    /// Non-zero values stored in row-major order
    private let values: [Double]

    /// Column index for each non-zero value
    private let columnIndices: [Int]

    /// Start index in values array for each row (length = rows + 1)
    /// rowPointers[i] = start index for row i
    /// rowPointers[i+1] = end index for row i (exclusive)
    private let rowPointers: [Int]

    /// Number of non-zero elements
    public var nonZeroCount: Int {
        return values.count
    }

    /// Sparsity ratio (fraction of zeros)
    /// 0.0 = fully dense, 1.0 = all zeros
    public var sparsity: Double {
        let totalElements = rows * columns
        guard totalElements > 0 else { return 1.0 }
        return 1.0 - Double(nonZeroCount) / Double(totalElements)
    }

    // MARK: - Initialization

    /// Create sparse matrix from dense 2D array
    ///
    /// - Parameters:
    ///   - dense: 2D array of values
    ///   - zeroThreshold: Values with absolute value < threshold are treated as zero
    public init(dense: [[Double]], zeroThreshold: Double = 1e-15) {
        guard !dense.isEmpty, !dense[0].isEmpty else {
            self.rows = 0
            self.columns = 0
            self.values = []
            self.columnIndices = []
            self.rowPointers = [0]
            return
        }

        self.rows = dense.count
        self.columns = dense[0].count

        var values: [Double] = []
        var columnIndices: [Int] = []
        var rowPointers: [Int] = [0]

        for row in 0..<rows {
            for col in 0..<columns {
                let value = dense[row][col]
                if abs(value) > zeroThreshold {
                    values.append(value)
                    columnIndices.append(col)
                }
            }
            rowPointers.append(values.count)
        }

        self.values = values
        self.columnIndices = columnIndices
        self.rowPointers = rowPointers
    }

    /// Create sparse matrix from triplet format [(row, col, value), ...]
    ///
    /// Triplets are automatically sorted by (row, col) for efficient CSR construction.
    ///
    /// - Parameters:
    ///   - rows: Number of rows
    ///   - columns: Number of columns
    ///   - triplets: Array of (row, column, value) tuples
    public init(rows: Int, columns: Int, triplets: [(Int, Int, Double)]) {
        self.rows = rows
        self.columns = columns

        // Sort triplets by (row, col) for CSR format
        let sortedTriplets = triplets.sorted { lhs, rhs in
            if lhs.0 != rhs.0 {
                return lhs.0 < rhs.0
            }
            return lhs.1 < rhs.1
        }

        var values: [Double] = []
        var columnIndices: [Int] = []
        var rowPointers: [Int] = [0]

        var currentRow = 0

        for (row, col, value) in sortedTriplets {
            // Fill in empty rows
            while currentRow < row {
                rowPointers.append(values.count)
                currentRow += 1
            }

            values.append(value)
            columnIndices.append(col)
        }

        // Fill remaining row pointers
        while currentRow < rows {
            rowPointers.append(values.count)
            currentRow += 1
        }

        self.values = values
        self.columnIndices = columnIndices
        self.rowPointers = rowPointers
    }

    // MARK: - Matrix Operations

    /// Multiply sparse matrix by dense vector: result = A × x
    ///
    /// Complexity: O(nnz) where nnz = number of non-zeros
    ///
    /// - Parameter vector: Dense vector (length must equal columns)
    /// - Returns: Result vector (length = rows)
    public func multiply(vector: [Double]) -> [Double] {
        precondition(vector.count == columns, "Vector length must equal number of columns")

        var result = [Double](repeating: 0.0, count: rows)

        for row in 0..<rows {
            let startIdx = rowPointers[row]
            let endIdx = rowPointers[row + 1]

            var sum = 0.0
            for idx in startIdx..<endIdx {
                let col = columnIndices[idx]
                let value = values[idx]
                sum += value * vector[col]
            }

            result[row] = sum
        }

        return result
    }

    /// Transpose the sparse matrix
    ///
    /// Converts CSR format to CSC (Compressed Sparse Column) format
    /// which is equivalent to CSR of the transpose.
    ///
    /// - Returns: Transposed sparse matrix
    public func transposed() -> SparseMatrix {
        var triplets: [(Int, Int, Double)] = []

        for row in 0..<rows {
            let startIdx = rowPointers[row]
            let endIdx = rowPointers[row + 1]

            for idx in startIdx..<endIdx {
                let col = columnIndices[idx]
                let value = values[idx]
                // Transpose: (row, col) → (col, row)
                triplets.append((col, row, value))
            }
        }

        return SparseMatrix(rows: columns, columns: rows, triplets: triplets)
    }

    /// Extract a submatrix
    ///
    /// - Parameters:
	///   - rowRange: Range of rows to extract
	///   - colRange: Range of columns to extract
    /// - Returns: Submatrix as a new sparse matrix
    public func submatrix(rows rowRange: Range<Int>, columns colRange: Range<Int>) -> SparseMatrix {
        var triplets: [(Int, Int, Double)] = []

        for row in rowRange {
            guard row < rows else { continue }

            let startIdx = rowPointers[row]
            let endIdx = rowPointers[row + 1]

            for idx in startIdx..<endIdx {
                let col = columnIndices[idx]
                if colRange.contains(col) {
                    let value = values[idx]
                    // Map to submatrix coordinates
                    triplets.append((row - rowRange.lowerBound, col - colRange.lowerBound, value))
                }
            }
        }

        return SparseMatrix(
            rows: rowRange.count,
            columns: colRange.count,
            triplets: triplets
        )
    }

    /// Get value at specific position (slow - for testing/debugging only)
    ///
    /// This operation is O(log(nnz_row)) due to binary search.
    /// For performance-critical code, use matrix-vector multiplication instead.
    ///
    /// - Parameters:
    ///   - row: Row index
    ///   - column: Column index
    /// - Returns: Value at (row, column), or 0.0 if not stored
    public subscript(row: Int, column: Int) -> Double {
        precondition(row >= 0 && row < rows, "Row index out of bounds")
        precondition(column >= 0 && column < columns, "Column index out of bounds")

        let startIdx = rowPointers[row]
        let endIdx = rowPointers[row + 1]

        // Binary search for column in this row
        var left = startIdx
        var right = endIdx

        while left < right {
            let mid = (left + right) / 2
            let midCol = columnIndices[mid]

            if midCol == column {
                return values[mid]
            } else if midCol < column {
                left = mid + 1
            } else {
                right = mid
            }
        }

        return 0.0  // Not found = zero
    }
}

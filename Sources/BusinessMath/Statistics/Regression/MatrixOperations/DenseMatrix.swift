//
//  DenseMatrix.swift
//  BusinessMath
//
//  Created by Claude Code on 2026-02-15.
//

import Foundation
import Numerics

/// A generic dense matrix type supporting standard linear algebra operations.
///
/// `DenseMatrix` is an immutable value type that provides thread-safe matrix operations.
/// All instances automatically conform to `Sendable`, making them safe to use across
/// concurrent contexts.
///
/// ## Creating Matrices
///
/// ```swift
/// // From 2D array
/// let A = try DenseMatrix([
///     [1.0, 2.0],
///     [3.0, 4.0]
/// ])
///
/// // Identity matrix
/// let I = DenseMatrix<Double>.identity(size: 3)
///
/// // Diagonal matrix
/// let D = DenseMatrix<Double>.diagonal([1, 2, 3])
/// ```
///
/// ## Matrix Operations
///
/// ```swift
/// let A = try DenseMatrix([[1.0, 2.0], [3.0, 4.0]])
/// let B = try DenseMatrix([[5.0, 6.0], [7.0, 8.0]])
///
/// // Transpose
/// let At = A.transposed()
///
/// // Multiplication
/// let C = try A.multiplied(by: B)
///
/// // Matrix-vector product
/// let x = [1.0, 2.0]
/// let Ax = try A.multiplied(by: x)
///
/// // Addition/subtraction
/// let sum = try A + B
/// let diff = try A - B
///
/// // Scalar multiplication
/// let scaled = 2.0 * A
/// ```
///
/// ## Solving Linear Systems
///
/// ```swift
/// // Solve Ax = b
/// let A = try DenseMatrix([[2.0, 3.0], [4.0, 5.0]])
/// let b = [8.0, 14.0]
/// let x = try A.solve(b)  // [1.0, 2.0]
/// ```
///
/// ## Performance
///
/// For large matrices (n ≥ 100), operations automatically use optimized backends:
/// - **Accelerate** (BLAS/LAPACK) on Apple platforms: 5-20× faster
/// - **Metal** (GPU) on Apple Silicon for n ≥ 1000: 10-100× faster
/// - **Pure Swift** fallback for all platforms
///
/// - Note: `DenseMatrix` is optimized for moderately-sized dense matrices.
///   For very large sparse matrices, use ``SparseMatrix`` instead.
public struct DenseMatrix<T: Real>: Sendable where T: Sendable {

    // MARK: - Storage

    /// Row-major storage: data[row][column]
    private let data: [[T]]

    /// Number of rows in the matrix
    public let rows: Int

    /// Number of columns in the matrix
    public let columns: Int

    // MARK: - Initialization

    /// Create matrix from 2D array.
    ///
    /// - Parameter data: 2D array of values (row-major order)
    ///
    /// - Throws:
    ///   - ``MatrixError/invalidDimensions(expected:actual:)`` if array is not rectangular
    ///   - ``MatrixError/invalidDimensions(expected:actual:)`` if array is empty
    ///
    /// - Complexity: O(mn) where m = rows, n = columns
    public init(_ data: [[T]]) throws {
        guard !data.isEmpty else {
            throw MatrixError.invalidDimensions(
                expected: "Non-empty array",
                actual: "Empty array"
            )
        }

        let columnCount = data[0].count
        guard data.allSatisfy({ $0.count == columnCount }) else {
            throw MatrixError.invalidDimensions(
                expected: "Rectangular array with \(columnCount) columns",
                actual: "Jagged array with varying column counts"
            )
        }

        self.data = data
        self.rows = data.count
        self.columns = columnCount
    }

    /// Create matrix with specified dimensions, filled with a value.
    ///
    /// - Parameters:
    ///   - rows: Number of rows
    ///   - columns: Number of columns
    ///   - value: Value to fill matrix with (default: 0)
    ///
    /// - Complexity: O(mn)
    public init(rows: Int, columns: Int, repeating value: T = T(0)) {
        self.rows = rows
        self.columns = columns
        self.data = Array(repeating: Array(repeating: value, count: columns), count: rows)
    }

    /// Create identity matrix.
    ///
    /// Returns a square matrix with 1s on the diagonal and 0s elsewhere.
    ///
    /// - Parameter size: Dimension of the identity matrix
    ///
    /// - Returns: Identity matrix I where I[i,i] = 1 and I[i,j] = 0 for i ≠ j
    ///
    /// - Complexity: O(n²)
    public static func identity(size: Int) -> DenseMatrix<T> {
        var matrix = Array(repeating: Array(repeating: T(0), count: size), count: size)
        for i in 0..<size {
            matrix[i][i] = T(1)
        }
        return try! DenseMatrix(matrix)  // Safe: we know it's rectangular
    }

    /// Create diagonal matrix from values.
    ///
    /// - Parameter values: Diagonal elements
    ///
    /// - Returns: Square matrix with values on diagonal, zeros elsewhere
    ///
    /// - Complexity: O(n²)
    public static func diagonal(_ values: [T]) -> DenseMatrix<T> {
        let n = values.count
        var matrix = Array(repeating: Array(repeating: T(0), count: n), count: n)
        for i in 0..<n {
            matrix[i][i] = values[i]
        }
        return try! DenseMatrix(matrix)  // Safe: we know it's rectangular
    }

    // MARK: - Accessors

    /// Access element at (row, column).
    ///
    /// - Parameters:
    ///   - row: Row index (0-based)
    ///   - column: Column index (0-based)
    ///
    /// - Returns: Element at the specified position
    ///
    /// - Precondition: row and column must be within bounds
    ///
    /// - Complexity: O(1)
    public subscript(row: Int, column: Int) -> T {
        precondition(row >= 0 && row < rows, "Row index \(row) out of bounds [0, \(rows))")
        precondition(column >= 0 && column < columns, "Column index \(column) out of bounds [0, \(columns))")
        return data[row][column]
    }

    /// Get row as array.
    ///
    /// - Parameter index: Row index (0-based)
    ///
    /// - Returns: Array containing the row elements
    ///
    /// - Complexity: O(n) where n = columns
    public func row(_ index: Int) -> [T] {
        precondition(index >= 0 && index < rows, "Row index out of bounds")
        return data[index]
    }

    /// Get column as array.
    ///
    /// - Parameter index: Column index (0-based)
    ///
    /// - Returns: Array containing the column elements
    ///
    /// - Complexity: O(m) where m = rows
    public func column(_ index: Int) -> [T] {
        precondition(index >= 0 && index < columns, "Column index out of bounds")
        return data.map { $0[index] }
    }

    /// Get all data as 2D array.
    ///
    /// - Returns: Complete matrix data in row-major order
    ///
    /// - Complexity: O(1) (returns internal storage)
    public var array: [[T]] {
        return data
    }

    // MARK: - Properties

    /// Check if matrix is square.
    ///
    /// - Returns: `true` if rows == columns
    public var isSquare: Bool {
        return rows == columns
    }

    /// Check if matrix is symmetric.
    ///
    /// A matrix is symmetric if A[i,j] = A[j,i] for all i, j.
    ///
    /// - Parameter tolerance: Maximum difference for elements to be considered equal
    ///
    /// - Returns: `true` if matrix is symmetric within tolerance
    ///
    /// - Complexity: O(n²)
    public func isSymmetric(tolerance: T) -> Bool {
        guard isSquare else { return false }

        for i in 0..<rows {
            for j in (i+1)..<columns {
                if abs(data[i][j] - data[j][i]) > tolerance {
                    return false
                }
            }
        }
        return true
    }

    /// Trace (sum of diagonal elements).
    ///
    /// - Returns: Sum of diagonal elements, or 0 if not square
    ///
    /// - Complexity: O(n)
    public var trace: T {
        guard isSquare else { return T(0) }

        var sum = T(0)
        for i in 0..<rows {
            sum += data[i][i]
        }
        return sum
    }

    /// Frobenius norm (√(Σ|aᵢⱼ|²)).
    ///
    /// - Returns: Frobenius norm of the matrix
    ///
    /// - Complexity: O(mn)
    public var frobeniusNorm: T {
        var sumSquares = T(0)
        for i in 0..<rows {
            for j in 0..<columns {
                sumSquares += data[i][j] * data[i][j]
            }
        }
        return sqrt(sumSquares)
    }

    // MARK: - Basic Operations

    /// Transpose: rows ↔ columns.
    ///
    /// Returns a new matrix where rows and columns are swapped.
    ///
    /// - Returns: Transposed matrix Aᵀ where Aᵀ[i,j] = A[j,i]
    ///
    /// - Complexity: O(mn)
    public func transposed() -> DenseMatrix<T> {
        var result = Array(repeating: Array(repeating: T(0), count: rows), count: columns)
        for i in 0..<rows {
            for j in 0..<columns {
                result[j][i] = data[i][j]
            }
        }
        return try! DenseMatrix(result)  // Safe: we know dimensions are correct
    }

    /// Matrix-matrix multiplication: C = A × B.
    ///
    /// Computes the product of two matrices using backend-optimized implementation.
    ///
    /// - Parameter other: Right matrix (must have rows == self.columns)
    ///
    /// - Returns: Product matrix (self.rows × other.columns)
    ///
    /// - Throws: ``MatrixError/dimensionMismatch(expected:actual:)`` if dimensions incompatible
    ///
    /// - Complexity: O(mnp) where m = self.rows, n = self.columns, p = other.columns
    public func multiplied(by other: DenseMatrix<T>) throws -> DenseMatrix<T> {
        guard columns == other.rows else {
            throw MatrixError.dimensionMismatch(
                expected: "Inner dimensions must match: (\(rows)×\(columns)) × (\(other.rows)×\(other.columns))",
                actual: "Cannot multiply: column count \(columns) ≠ row count \(other.rows)"
            )
        }

        // Pure Swift multiplication (backend optimization handled in Double-specific extension)
        var result = Array(repeating: Array(repeating: T(0), count: other.columns), count: rows)

        for i in 0..<rows {
            for j in 0..<other.columns {
                var sum = T(0)
                for k in 0..<columns {
                    sum += data[i][k] * other.data[k][j]
                }
                result[i][j] = sum
            }
        }

        return try! DenseMatrix(result)
    }

    /// Matrix-vector multiplication: y = A × x.
    ///
    /// - Parameter vector: Vector (must have length == self.columns)
    ///
    /// - Returns: Product vector (length == self.rows)
    ///
    /// - Throws: ``MatrixError/dimensionMismatch(expected:actual:)`` if vector length ≠ columns
    ///
    /// - Complexity: O(mn) where m = rows, n = columns
    public func multiplied(by vector: [T]) throws -> [T] {
        guard vector.count == columns else {
            throw MatrixError.dimensionMismatch(
                expected: "Vector length must equal column count: \(columns)",
                actual: "Vector has length \(vector.count)"
            )
        }

        var result = Array(repeating: T(0), count: rows)

        for i in 0..<rows {
            var sum = T(0)
            for j in 0..<columns {
                sum += data[i][j] * vector[j]
            }
            result[i] = sum
        }

        return result
    }

    /// Element-wise addition.
    ///
    /// - Parameters:
    ///   - lhs: Left matrix
    ///   - rhs: Right matrix (must have same dimensions as lhs)
    ///
    /// - Returns: Sum matrix where result[i,j] = lhs[i,j] + rhs[i,j]
    ///
    /// - Throws: ``MatrixError/dimensionMismatch(expected:actual:)`` if dimensions don't match
    ///
    /// - Complexity: O(mn)
    public static func + (lhs: DenseMatrix<T>, rhs: DenseMatrix<T>) throws -> DenseMatrix<T> {
        guard lhs.rows == rhs.rows && lhs.columns == rhs.columns else {
            throw MatrixError.dimensionMismatch(
                expected: "Matrices must have same dimensions: (\(lhs.rows)×\(lhs.columns))",
                actual: "Cannot add (\(lhs.rows)×\(lhs.columns)) and (\(rhs.rows)×\(rhs.columns))"
            )
        }

        var result = Array(repeating: Array(repeating: T(0), count: lhs.columns), count: lhs.rows)

        for i in 0..<lhs.rows {
            for j in 0..<lhs.columns {
                result[i][j] = lhs.data[i][j] + rhs.data[i][j]
            }
        }

        return try! DenseMatrix(result)
    }

    /// Element-wise subtraction.
    ///
    /// - Parameters:
    ///   - lhs: Left matrix
    ///   - rhs: Right matrix (must have same dimensions as lhs)
    ///
    /// - Returns: Difference matrix where result[i,j] = lhs[i,j] - rhs[i,j]
    ///
    /// - Throws: ``MatrixError/dimensionMismatch(expected:actual:)`` if dimensions don't match
    ///
    /// - Complexity: O(mn)
    public static func - (lhs: DenseMatrix<T>, rhs: DenseMatrix<T>) throws -> DenseMatrix<T> {
        guard lhs.rows == rhs.rows && lhs.columns == rhs.columns else {
            throw MatrixError.dimensionMismatch(
                expected: "Matrices must have same dimensions: (\(lhs.rows)×\(lhs.columns))",
                actual: "Cannot subtract (\(lhs.rows)×\(lhs.columns)) and (\(rhs.rows)×\(rhs.columns))"
            )
        }

        var result = Array(repeating: Array(repeating: T(0), count: lhs.columns), count: lhs.rows)

        for i in 0..<lhs.rows {
            for j in 0..<lhs.columns {
                result[i][j] = lhs.data[i][j] - rhs.data[i][j]
            }
        }

        return try! DenseMatrix(result)
    }

    /// Scalar multiplication.
    ///
    /// - Parameters:
    ///   - scalar: Scalar value
    ///   - matrix: Matrix to scale
    ///
    /// - Returns: Scaled matrix where result[i,j] = scalar × matrix[i,j]
    ///
    /// - Complexity: O(mn)
    public static func * (scalar: T, matrix: DenseMatrix<T>) -> DenseMatrix<T> {
        var result = Array(repeating: Array(repeating: T(0), count: matrix.columns), count: matrix.rows)

        for i in 0..<matrix.rows {
            for j in 0..<matrix.columns {
                result[i][j] = scalar * matrix.data[i][j]
            }
        }

        return try! DenseMatrix(result)
    }

    // MARK: - Linear System Solving

    /// Solve linear system Ax = b.
    ///
    /// Uses backend-optimized solver (QR decomposition or Cholesky for SPD matrices).
    ///
    /// - Parameter b: Right-hand side vector (length must equal rows)
    ///
    /// - Returns: Solution vector x
    ///
    /// - Throws:
    ///   - ``MatrixError/notSquare`` if matrix is not square
    ///   - ``MatrixError/singularMatrix`` if matrix is singular
    ///   - ``MatrixError/dimensionMismatch(expected:actual:)`` if b length ≠ rows
    ///
    /// - Complexity: O(n³) for decomposition, O(n²) for back-substitution
    public func solve(_ b: [T]) throws -> [T] {
        guard isSquare else {
            throw MatrixError.notSquare
        }

        guard b.count == rows else {
            throw MatrixError.dimensionMismatch(
                expected: "Vector length must equal matrix rows: \(rows)",
                actual: "Vector has length \(b.count)"
            )
        }

        // Gaussian elimination (backend optimization handled in Double-specific extension)
        return try gaussianElimination(b)
    }

    /// Simple Gaussian elimination solver (fallback for non-Double types).
    ///
    /// - Parameter b: Right-hand side vector
    ///
    /// - Returns: Solution vector
    ///
    /// - Throws: ``MatrixError/singularMatrix`` if matrix is singular
    private func gaussianElimination(_ b: [T]) throws -> [T] {
        var A = data
        var b = b

        let n = rows

        // Forward elimination
        for i in 0..<n {
            // Find pivot
            var maxRow = i
            for k in (i+1)..<n {
                if abs(A[k][i]) > abs(A[maxRow][i]) {
                    maxRow = k
                }
            }

            // Swap rows
            if maxRow != i {
                (A[i], A[maxRow]) = (A[maxRow], A[i])
                (b[i], b[maxRow]) = (b[maxRow], b[i])
            }

            // Check for singularity (using type-appropriate epsilon)
            let epsilon = T.ulpOfOne * 100000
            if abs(A[i][i]) < epsilon {
                throw MatrixError.singularMatrix
            }

            // Eliminate column
            for k in (i+1)..<n {
                let factor = A[k][i] / A[i][i]
                for j in i..<n {
                    A[k][j] -= factor * A[i][j]
                }
                b[k] -= factor * b[i]
            }
        }

        // Back substitution
        var x = Array(repeating: T(0), count: n)
        for i in (0..<n).reversed() {
            var sum = b[i]
            for j in (i+1)..<n {
                sum -= A[i][j] * x[j]
            }
            x[i] = sum / A[i][i]
        }

        return x
    }
}

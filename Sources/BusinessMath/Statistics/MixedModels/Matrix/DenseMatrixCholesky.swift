import Foundation
import Numerics

extension DenseMatrix {

	/// Cholesky decomposition: A = L * L' where L is lower triangular.
	///
	/// The matrix must be symmetric and positive definite. The Cholesky
	/// decomposition is unique for positive definite matrices and provides
	/// efficient solving of linear systems, determinant computation, and
	/// matrix inversion.
	///
	/// Uses the Cholesky-Banachiewicz algorithm.
	///
	/// - Returns: Lower triangular matrix L such that A = L * L'
	/// - Throws: ``MatrixError/notSquare`` if the matrix is not square.
	///   ``MatrixError/notPositiveDefinite`` if the matrix is not positive definite.
	/// - Complexity: O(n³ / 3)
	public func cholesky() throws -> DenseMatrix<T> {
		guard isSquare else { throw MatrixError.notSquare }
		let n = rows
		guard n > 0 else { throw MatrixError.notPositiveDefinite }

		var L = Array(repeating: Array(repeating: T.zero, count: n), count: n)

		for j in 0..<n {
			var sumDiag = T.zero
			for k in 0..<j {
				sumDiag += L[j][k] * L[j][k]
			}
			let diagVal = self[j, j] - sumDiag
			guard diagVal > T.zero else {
				throw MatrixError.notPositiveDefinite
			}
			L[j][j] = T.sqrt(diagVal)

			for i in (j + 1)..<n {
				var sumOffDiag = T.zero
				for k in 0..<j {
					sumOffDiag += L[i][k] * L[j][k]
				}
				L[i][j] = (self[i, j] - sumOffDiag) / L[j][j]
			}
		}

		return try DenseMatrix(L)
	}

	/// Solve A * x = b using the Cholesky decomposition.
	///
	/// For symmetric positive definite A, this is more efficient and numerically
	/// stable than general Gaussian elimination:
	/// 1. Compute L = cholesky(A)
	/// 2. Forward substitution: solve L * z = b
	/// 3. Back substitution: solve L' * x = z
	///
	/// - Parameter b: Right-hand side vector (length must equal rows).
	/// - Returns: Solution vector x.
	/// - Throws: ``MatrixError/notSquare``, ``MatrixError/notPositiveDefinite``,
	///   ``MatrixError/dimensionMismatch(expected:actual:)``.
	/// - Complexity: O(n³ / 3) for decomposition + O(n²) for solve.
	public func choleskySolve(_ b: [T]) throws -> [T] {
		guard b.count == rows else {
			throw MatrixError.dimensionMismatch(
				expected: "Vector length must equal matrix rows: \(rows)",
				actual: "Vector has length \(b.count)")
		}
		let L = try cholesky()
		let z = try forwardSubstitution(L, b)
		return try backSubstitutionTranspose(L, z)
	}

	/// Solve A * X = B for multiple right-hand sides using Cholesky.
	///
	/// Computes the Cholesky decomposition once and solves for each column of B.
	///
	/// - Parameter B: Right-hand side matrix (rows must equal self.rows).
	/// - Returns: Solution matrix X.
	/// - Throws: Same as ``choleskySolve(_:)-3slhv``.
	/// - Complexity: O(n³ / 3) + O(n² * k) where k = B.columns.
	public func choleskySolve(_ B: DenseMatrix<T>) throws -> DenseMatrix<T> {
		guard B.rows == rows else {
			throw MatrixError.dimensionMismatch(
				expected: "B.rows must equal matrix rows: \(rows)",
				actual: "B has \(B.rows) rows")
		}
		let L = try cholesky()
		var resultCols = [[T]]()

		for col in 0..<B.columns {
			let bCol = (0..<B.rows).map { B[$0, col] }
			let z = try forwardSubstitution(L, bCol)
			let x = try backSubstitutionTranspose(L, z)
			resultCols.append(x)
		}

		var result = Array(repeating: Array(repeating: T.zero, count: B.columns), count: rows)
		for col in 0..<B.columns {
			for row in 0..<rows {
				result[row][col] = resultCols[col][row]
			}
		}
		return try DenseMatrix(result)
	}

	/// Log-determinant computed via Cholesky decomposition.
	///
	/// For a symmetric positive definite matrix A with Cholesky factor L:
	/// ```
	/// log|A| = 2 * sum(log(L[i][i]))
	/// ```
	///
	/// This avoids overflow from computing large determinants directly.
	///
	/// - Returns: log(|A|) = log(determinant of A).
	/// - Throws: ``MatrixError/notSquare``, ``MatrixError/notPositiveDefinite``.
	/// - Complexity: O(n³ / 3) for decomposition, O(n) for the sum.
	public func logDeterminant() throws -> T {
		let L = try cholesky()
		var logDet = T.zero
		for i in 0..<rows {
			logDet += T.log(L[i, i])
		}
		return T(2) * logDet
	}

	/// Matrix inverse via Cholesky decomposition.
	///
	/// Computes A⁻¹ by solving A * X = I column by column using the Cholesky factor.
	///
	/// - Note: Prefer ``choleskySolve(_:)-3slhv`` over forming the explicit inverse
	///   whenever possible.
	///
	/// - Returns: The inverse matrix A⁻¹.
	/// - Throws: ``MatrixError/notSquare``, ``MatrixError/notPositiveDefinite``.
	/// - Complexity: O(n³).
	public func choleskyInverse() throws -> DenseMatrix<T> {
		let identity = DenseMatrix.identity(size: rows)
		return try choleskySolve(identity)
	}
}

// MARK: - Triangular Solve Helpers

/// Forward substitution: solve L * z = b where L is lower triangular.
private func forwardSubstitution<T: Real>(_ L: DenseMatrix<T>, _ b: [T]) throws -> [T] {
	let n = b.count
	var z = Array(repeating: T.zero, count: n)

	for i in 0..<n {
		guard L[i, i] != T.zero else {
			throw MatrixError.singularMatrix
		}
		var sum = b[i]
		for k in 0..<i {
			sum -= L[i, k] * z[k]
		}
		z[i] = sum / L[i, i]
	}
	return z
}

/// Back substitution: solve L' * x = z where L is lower triangular (L' is upper).
private func backSubstitutionTranspose<T: Real>(_ L: DenseMatrix<T>, _ z: [T]) throws -> [T] {
	let n = z.count
	var x = Array(repeating: T.zero, count: n)

	for i in stride(from: n - 1, through: 0, by: -1) {
		guard L[i, i] != T.zero else {
			throw MatrixError.singularMatrix
		}
		var sum = z[i]
		for k in (i + 1)..<n {
			sum -= L[k, i] * x[k]
		}
		x[i] = sum / L[i, i]
	}
	return x
}

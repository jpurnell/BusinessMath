//
//  CorrelationMatrix.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation

/// Validates whether a matrix is a valid correlation matrix.
///
/// A valid correlation matrix must satisfy several properties:
/// - Square matrix (n×n)
/// - Symmetric: matrix[i][j] == matrix[j][i]
/// - Unit diagonal: matrix[i][i] == 1.0 for all i
/// - Bounded values: -1.0 ≤ matrix[i][j] ≤ 1.0 for all i,j
/// - Positive semi-definite: all eigenvalues ≥ 0
///
/// ## Example
///
/// ```swift
/// let validMatrix = [
///     [1.0, 0.5],
///     [0.5, 1.0]
/// ]
/// print(isValidCorrelationMatrix(validMatrix))  // true
///
/// let invalidMatrix = [
///     [1.0, 1.5],  // correlation > 1.0
///     [1.5, 1.0]
/// ]
/// print(isValidCorrelationMatrix(invalidMatrix))  // false
/// ```
///
/// - Parameter matrix: A 2D array representing the correlation matrix
/// - Returns: `true` if the matrix is a valid correlation matrix, `false` otherwise
public func isValidCorrelationMatrix(_ matrix: [[Double]]) -> Bool {
	// Check if matrix is empty
	guard !matrix.isEmpty else { return false }

	let n = matrix.count

	// Check if matrix is square
	guard matrix.allSatisfy({ $0.count == n }) else { return false }

	// Check if matrix is symmetric and has correct diagonal
	for i in 0..<n {
		// Check diagonal
		guard abs(matrix[i][i] - 1.0) < 1e-10 else { return false }

		for j in 0..<n {
			// Check bounds [-1, 1]
			guard matrix[i][j] >= -1.0 && matrix[i][j] <= 1.0 else { return false }

			// Check symmetry
			guard abs(matrix[i][j] - matrix[j][i]) < 1e-10 else { return false }
		}
	}

	// Check positive semi-definite via Cholesky decomposition
	return isPositiveSemiDefinite(matrix)
}

/// Checks if a matrix is symmetric.
///
/// A matrix is symmetric if matrix[i][j] == matrix[j][i] for all i, j.
///
/// - Parameter matrix: A 2D array representing the matrix
/// - Returns: `true` if the matrix is symmetric, `false` otherwise
public func isSymmetric(_ matrix: [[Double]]) -> Bool {
	guard !matrix.isEmpty else { return false }

	let n = matrix.count

	// Check if matrix is square
	guard matrix.allSatisfy({ $0.count == n }) else { return false }

	// Check symmetry
	for i in 0..<n {
		for j in 0..<n {
			if abs(matrix[i][j] - matrix[j][i]) > 1e-10 {
				return false
			}
		}
	}

	return true
}

/// Checks if a matrix is positive semi-definite.
///
/// A matrix is positive semi-definite if all its eigenvalues are non-negative.
/// This is verified using Cholesky decomposition - if the decomposition succeeds,
/// the matrix is positive definite (and thus positive semi-definite).
///
/// - Parameter matrix: A 2D array representing the matrix
/// - Returns: `true` if the matrix is positive semi-definite, `false` otherwise
public func isPositiveSemiDefinite(_ matrix: [[Double]]) -> Bool {
	guard !matrix.isEmpty else { return false }

	let n = matrix.count

	// Check if matrix is square
	guard matrix.allSatisfy({ $0.count == n }) else { return false }

	// Attempt Cholesky decomposition
	// If successful, matrix is positive definite
	do {
		_ = try choleskyDecomposition(matrix)
		return true
	} catch {
		return false
	}
}

/// Error types for matrix operations.
public enum MatrixError: Error {
	case notPositiveDefinite
	case notSquare
	case invalidDimensions
}

/// Performs Cholesky decomposition on a symmetric positive definite matrix.
///
/// The Cholesky decomposition factors a matrix A into L × L^T, where L is a
/// lower triangular matrix. This is used for generating correlated random variables.
///
/// ## Algorithm
///
/// For a matrix A, computes L such that A = L × L^T:
/// - L[i][j] = 0 for j > i (lower triangular)
/// - L[i][i] = sqrt(A[i][i] - sum(L[i][k]^2 for k < i))
/// - L[i][j] = (A[i][j] - sum(L[i][k] × L[j][k] for k < j)) / L[j][j]
///
/// ## Example
///
/// ```swift
/// let matrix = [
///     [4.0, 2.0],
///     [2.0, 3.0]
/// ]
/// let L = try choleskyDecomposition(matrix)
/// // L = [[2.0, 0.0], [1.0, 1.414...]]
/// ```
///
/// - Parameter matrix: A symmetric positive definite matrix
/// - Returns: The lower triangular Cholesky factor L
/// - Throws: `MatrixError.notPositiveDefinite` if the matrix is not positive definite
public func choleskyDecomposition(_ matrix: [[Double]]) throws -> [[Double]] {
	guard !matrix.isEmpty else {
		throw MatrixError.invalidDimensions
	}

	let n = matrix.count

	// Check if matrix is square
	guard matrix.allSatisfy({ $0.count == n }) else {
		throw MatrixError.notSquare
	}

	// Initialize result matrix with zeros
	var L = Array(repeating: Array(repeating: 0.0, count: n), count: n)

	// Perform Cholesky decomposition
	for i in 0..<n {
		for j in 0...i {
			var sum = 0.0

			if i == j {
				// Diagonal element
				for k in 0..<j {
					sum += L[j][k] * L[j][k]
				}

				let value = matrix[j][j] - sum

				// Check for positive definiteness
				guard value > 1e-10 else {
					throw MatrixError.notPositiveDefinite
				}

				L[j][j] = sqrt(value)
			} else {
				// Off-diagonal element
				for k in 0..<j {
					sum += L[i][k] * L[j][k]
				}

				L[i][j] = (matrix[i][j] - sum) / L[j][j]
			}
		}
	}

	return L
}

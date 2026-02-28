//
//  SparseMatrixTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/11/25.
//  TDD: Tests written FIRST, implementation comes after
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Sparse Matrix Tests")
struct SparseMatrixTests {

	// MARK: - Construction Tests

	/// Test creating sparse matrix from dense matrix
	@Test("Create sparse matrix from dense")
	func testCreateFromDense() throws {
		// Dense matrix with many zeros
		let dense: [[Double]] = [
			[1.0, 0.0, 0.0, 2.0],
			[0.0, 3.0, 0.0, 0.0],
			[0.0, 0.0, 4.0, 0.0],
			[5.0, 0.0, 0.0, 6.0]
		]

		let sparse = SparseMatrix(dense: dense)

		#expect(sparse.rows == 4)
		#expect(sparse.columns == 4)
		#expect(sparse.nonZeroCount == 6)  // Only 6 non-zero entries
		#expect(sparse.sparsity > 0.6)     // 62.5% sparse (10/16 are zeros)
	}

	/// Test creating sparse matrix from triplet format
	@Test("Create sparse matrix from triplets")
	func testCreateFromTriplets() throws {
		// Triplet format: [(row, col, value), ...]
		let triplets: [(Int, Int, Double)] = [
			(0, 0, 1.0),
			(0, 3, 2.0),
			(1, 1, 3.0),
			(2, 2, 4.0),
			(3, 0, 5.0),
			(3, 3, 6.0)
		]

		let sparse = SparseMatrix(rows: 4, columns: 4, triplets: triplets)

		#expect(sparse.rows == 4)
		#expect(sparse.columns == 4)
		#expect(sparse.nonZeroCount == 6)
	}

	/// Test empty sparse matrix
	@Test("Create empty sparse matrix")
	func testEmptyMatrix() throws {
		let sparse = SparseMatrix(rows: 10, columns: 10, triplets: [])

		#expect(sparse.rows == 10)
		#expect(sparse.columns == 10)
		#expect(sparse.nonZeroCount == 0)
		#expect(sparse.sparsity == 1.0)  // 100% sparse (all zeros)
	}

	// MARK: - Matrix-Vector Multiplication Tests

	/// Test sparse matrix-vector multiplication matches dense
	@Test("Sparse matrix-vector multiply matches dense")
	func testMatrixVectorMultiply() throws {
		let dense: [[Double]] = [
			[1.0, 0.0, 0.0, 2.0],
			[0.0, 3.0, 0.0, 0.0],
			[0.0, 0.0, 4.0, 0.0],
			[5.0, 0.0, 0.0, 6.0]
		]

		let sparse = SparseMatrix(dense: dense)
		let vector = [1.0, 2.0, 3.0, 4.0]

		// Sparse multiply
		let result = sparse.multiply(vector: vector)

		// Expected: [1*1 + 2*4, 3*2, 4*3, 5*1 + 6*4]
		//         = [9, 6, 12, 29]
		#expect(result.count == 4)
		#expect(abs(result[0] - 9.0) < 1e-10)
		#expect(abs(result[1] - 6.0) < 1e-10)
		#expect(abs(result[2] - 12.0) < 1e-10)
		#expect(abs(result[3] - 29.0) < 1e-10)
	}

	/// Test matrix-vector multiply with identity matrix
	@Test("Identity matrix multiply returns same vector")
	func testIdentityMultiply() throws {
		let triplets: [(Int, Int, Double)] = [
			(0, 0, 1.0),
			(1, 1, 1.0),
			(2, 2, 1.0),
			(3, 3, 1.0)
		]

		let identity = SparseMatrix(rows: 4, columns: 4, triplets: triplets)
		let vector = [5.0, 7.0, 3.0, 9.0]

		let result = identity.multiply(vector: vector)

		for i in 0..<4 {
			#expect(abs(result[i] - vector[i]) < 1e-10)
		}
	}

	// MARK: - Transpose Tests

	/// Test transpose operation
	@Test("Transpose preserves structure")
	func testTranspose() throws {
		let dense: [[Double]] = [
			[1.0, 0.0, 2.0],
			[0.0, 3.0, 0.0],
			[4.0, 0.0, 5.0],
			[0.0, 6.0, 0.0]
		]

		let sparse = SparseMatrix(dense: dense)
		let transposed = sparse.transposed()

		#expect(transposed.rows == 3)
		#expect(transposed.columns == 4)
		#expect(transposed.nonZeroCount == 6)  // Same number of non-zeros

		// Verify transpose: A^T[i][j] = A[j][i]
		// A[0][0] = 1.0 → A^T[0][0] = 1.0
		// A[0][2] = 2.0 → A^T[2][0] = 2.0
		// A[1][1] = 3.0 → A^T[1][1] = 3.0

		let v1 = transposed.multiply(vector: [1.0, 0.0, 0.0, 0.0])
		#expect(abs(v1[0] - 1.0) < 1e-10)  // A^T[0][0] = 1.0
		#expect(abs(v1[1] - 0.0) < 1e-10)
		#expect(abs(v1[2] - 2.0) < 1e-10)  // A^T[2][0] = 2.0
	}

	// MARK: - Submatrix Tests

	/// Test extracting submatrix
	@Test("Extract submatrix")
	func testSubmatrix() throws {
		let dense: [[Double]] = [
			[1.0, 0.0, 0.0, 2.0],
			[0.0, 3.0, 0.0, 0.0],
			[0.0, 0.0, 4.0, 0.0],
			[5.0, 0.0, 0.0, 6.0]
		]

		let sparse = SparseMatrix(dense: dense)

		// Extract 2×2 submatrix from top-left
		let sub = sparse.submatrix(rows: 0..<2, columns: 0..<2)

		#expect(sub.rows == 2)
		#expect(sub.columns == 2)
		#expect(sub.nonZeroCount == 2)  // Only (0,0)=1 and (1,1)=3
	}

	// MARK: - Sparsity Tests

	/// Test sparsity calculation
	@Test("Sparsity correctly calculated")
	func testSparsityCalculation() throws {
		// 10×10 matrix with only 10 non-zeros
		let triplets = (0..<10).map { i in (i, i, 1.0) }
		let sparse = SparseMatrix(rows: 10, columns: 10, triplets: triplets)

		// Sparsity = 1 - (nonZeros / total)
		//          = 1 - (10 / 100) = 0.9 = 90%
		#expect(abs(sparse.sparsity - 0.9) < 1e-10)
	}

	/// Test very sparse matrix
	@Test("Very sparse matrix (0.1% density)")
	func testVerySparseMatrix() throws {
		// 1000×1000 matrix with only 1000 non-zeros (0.1% density)
		let triplets = (0..<1000).map { i in (i, i, Double(i + 1)) }
		let sparse = SparseMatrix(rows: 1000, columns: 1000, triplets: triplets)

		#expect(sparse.nonZeroCount == 1000)
		#expect(sparse.sparsity >= 0.999)  // 99.9% sparse (exactly 0.999)

		// Verify diagonal matrix property
//		let e1 = sparse.multiply(vector: Array(repeating: 0.0, count: 1000).enumerated().map { $0.offset == 0 ? 1.0 : 0.0 })
		var e0 = Array(repeating: 0.0, count: 1000)
		e0[0] = 1.0
		let e1 = sparse.multiply(vector: e0)
		#expect(abs(e1[0] - 1.0) < 1e-10)
		#expect(abs(e1[1] - 0.0) < 1e-10)
	}

	// MARK: - Sparse Solver Tests (Conjugate Gradient)

	/// Test CG solver on simple SPD system
	@Test("Conjugate Gradient solver for SPD system")
	func testConjugateGradient() throws {
		// Solve Ax = b where A is symmetric positive definite
		// A = [4  1]    b = [1]
		//     [1  3]        [2]
		// Solution: x = [1/11, 7/11]

		let A = SparseMatrix(dense: [
			[4.0, 1.0],
			[1.0, 3.0]
		])

		let b = [1.0, 2.0]

		let solver = SparseSolver()
		let x = try solver.solve(A: A, b: b, method: .conjugateGradient, tolerance: 1e-8)

		// Verify solution: should be [1/11, 7/11]
		#expect(abs(x[0] - 1.0/11.0) < 1e-6)
		#expect(abs(x[1] - 7.0/11.0) < 1e-6)

		// Verify Ax = b
		let Ax = A.multiply(vector: x)
		#expect(abs(Ax[0] - b[0]) < 1e-6)
		#expect(abs(Ax[1] - b[1]) < 1e-6)
	}

	/// Test CG on larger SPD system
	@Test("CG solver on 10×10 diagonal system")
	func testConjugateGradientLarge() throws {
		// Diagonal matrix: A[i][i] = i+1
		// b[i] = i+1
		// Solution: x[i] = 1 for all i

		let triplets = (0..<10).map { i in (i, i, Double(i + 1)) }
		let A = SparseMatrix(rows: 10, columns: 10, triplets: triplets)
		let b = (1...10).map { Double($0) }

		let solver = SparseSolver()
		let x = try solver.solve(A: A, b: b, method: .conjugateGradient)

		// Solution should be all ones
		for i in 0..<10 {
			#expect(abs(x[i] - 1.0) < 1e-6)
		}
	}

	// MARK: - Sparse Solver Tests (BiConjugate Gradient)

	/// Test BiCG solver on general (non-symmetric) system
	@Test("BiConjugate Gradient for general system")
	func testBiconjugateGradient() throws {
		// Non-symmetric matrix
		let A = SparseMatrix(dense: [
			[3.0, 1.0],
			[0.0, 2.0]
		])

		let b = [4.0, 6.0]

		let solver = SparseSolver()
		let x = try solver.solve(A: A, b: b, method: .biconjugateGradient, tolerance: 1e-8)

		// Verify Ax = b
		let Ax = A.multiply(vector: x)
		#expect(abs(Ax[0] - b[0]) < 1e-6)
		#expect(abs(Ax[1] - b[1]) < 1e-6)
	}

	// MARK: - Performance Tests

	// MARK: - Large Scale Tests

	/// Test very large sparse matrix (10,000×10,000)
	@Test("Large sparse matrix (10,000×10,000 with 0.1% density)")
	func testLargeSparseMatrix() throws {
		let n = 10_000

		// Create sparse tridiagonal matrix
		var triplets: [(Int, Int, Double)] = []
		for i in 0..<n {
			triplets.append((i, i, 2.0))  // Diagonal
			if i > 0 {
				triplets.append((i, i-1, -1.0))  // Sub-diagonal
			}
			if i < n-1 {
				triplets.append((i, i+1, -1.0))  // Super-diagonal
			}
		}

		let sparse = SparseMatrix(rows: n, columns: n, triplets: triplets)

		#expect(sparse.rows == n)
		#expect(sparse.columns == n)
		#expect(sparse.nonZeroCount < 30_000)  // Approximately 3*n non-zeros
		#expect(sparse.sparsity > 0.999)  // > 99.9% sparse

		// Test matrix-vector multiply completes
		let vector = Array(repeating: 1.0, count: n)
		let result = sparse.multiply(vector: vector)

		#expect(result.count == n)
		// For tridiagonal with [2, -1, -1], interior elements should be 0
		#expect(abs(result[1] - 0.0) < 1e-10)
	}

	// MARK: - Edge Cases

	/// Test matrix with single element
	@Test("Single element sparse matrix")
	func testSingleElement() throws {
		let sparse = SparseMatrix(rows: 1, columns: 1, triplets: [(0, 0, 5.0)])

		#expect(sparse.nonZeroCount == 1)
		#expect(sparse.sparsity == 0.0)  // 0% sparse (fully dense)

		let result = sparse.multiply(vector: [3.0])
		#expect(abs(result[0] - 15.0) < 1e-10)
	}

	/// Test zero threshold in dense conversion
	@Test("Zero threshold filters small values")
	func testZeroThreshold() throws {
		let dense: [[Double]] = [
			[1.0, 1e-15, 0.0],
			[0.0, 2.0, 1e-14],
			[1e-13, 0.0, 3.0]
		]

		// Default threshold should filter out very small values
		let sparse = SparseMatrix(dense: dense, zeroThreshold: 1e-12)

		#expect(sparse.nonZeroCount == 3)  // Only 1.0, 2.0, 3.0 survive
	}
}

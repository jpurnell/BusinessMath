//
//  DenseMatrixTests.swift
//  BusinessMath
//
//  Created by Claude Code on 2026-02-15.
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Dense Matrix Operations")
struct DenseMatrixTests {

    // MARK: - Test Data Helpers

    /// Create a deterministic test matrix with known properties
    private func testMatrix2x2() -> [[Double]] {
        [
            [1.0, 2.0],
            [3.0, 4.0]
        ]
    }

    private func testMatrix3x3() -> [[Double]] {
        [
            [1.0, 2.0, 3.0],
            [4.0, 5.0, 6.0],
            [7.0, 8.0, 9.0]
        ]
    }

    private func identityMatrix(_ size: Int) -> [[Double]] {
        var matrix = Array(repeating: Array(repeating: 0.0, count: size), count: size)
        for i in 0..<size {
            matrix[i][i] = 1.0
        }
        return matrix
    }

    // MARK: - 1️⃣ Golden Path Tests

    @Test("Create matrix from 2D array")
    func createMatrixFrom2DArray() throws {
        let data = testMatrix2x2()
        let matrix = try DenseMatrix(data)

        #expect(matrix.rows == 2)
        #expect(matrix.columns == 2)
        #expect(matrix[0, 0] == 1.0)
        #expect(matrix[0, 1] == 2.0)
        #expect(matrix[1, 0] == 3.0)
        #expect(matrix[1, 1] == 4.0)
    }

    @Test("Create identity matrix")
    func createIdentityMatrix() {
        let matrix = DenseMatrix<Double>.identity(size: 3)

        #expect(matrix.rows == 3)
        #expect(matrix.columns == 3)
        #expect(matrix.isSquare)

        // Verify diagonal elements are 1
        for i in 0..<3 {
            #expect(matrix[i, i] == 1.0)
        }

        // Verify off-diagonal elements are 0
        #expect(matrix[0, 1] == 0.0)
        #expect(matrix[0, 2] == 0.0)
        #expect(matrix[1, 0] == 0.0)
        #expect(matrix[1, 2] == 0.0)
        #expect(matrix[2, 0] == 0.0)
        #expect(matrix[2, 1] == 0.0)
    }

    @Test("Matrix transpose")
    func matrixTranspose() throws {
        let data = [[1.0, 2.0, 3.0],
                    [4.0, 5.0, 6.0]]
        let matrix = try DenseMatrix(data)
        let transposed = matrix.transposed()

        #expect(transposed.rows == 3)
        #expect(transposed.columns == 2)
        #expect(transposed[0, 0] == 1.0)
        #expect(transposed[0, 1] == 4.0)
        #expect(transposed[1, 0] == 2.0)
        #expect(transposed[1, 1] == 5.0)
        #expect(transposed[2, 0] == 3.0)
        #expect(transposed[2, 1] == 6.0)
    }

    @Test("Matrix-vector multiplication")
    func matrixVectorMultiplication() throws {
        let A = try DenseMatrix([[1.0, 2.0],
                                  [3.0, 4.0]])
        let x = [5.0, 6.0]

        let result = try A.multiplied(by: x)

        // [1 2] × [5] = [1×5 + 2×6] = [17]
        // [3 4]   [6]   [3×5 + 4×6]   [39]
        #expect(result.count == 2)
        #expect(abs(result[0] - 17.0) < 1e-10)
        #expect(abs(result[1] - 39.0) < 1e-10)
    }

    @Test("Matrix-matrix multiplication")
    func matrixMatrixMultiplication() throws {
        let A = try DenseMatrix([[1.0, 2.0],
                                  [3.0, 4.0]])
        let B = try DenseMatrix([[5.0, 6.0],
                                  [7.0, 8.0]])

        let C = try A.multiplied(by: B)

        // [1 2] × [5 6] = [1×5+2×7  1×6+2×8] = [19 22]
        // [3 4]   [7 8]   [3×5+4×7  3×6+4×8]   [43 50]
        #expect(C.rows == 2)
        #expect(C.columns == 2)
        #expect(abs(C[0, 0] - 19.0) < 1e-10)
        #expect(abs(C[0, 1] - 22.0) < 1e-10)
        #expect(abs(C[1, 0] - 43.0) < 1e-10)
        #expect(abs(C[1, 1] - 50.0) < 1e-10)
    }

    @Test("Solve simple linear system")
    func solveSimpleLinearSystem() throws {
        // 2x + 3y = 8
        // 4x + 5y = 14
        // Solution: x = 1, y = 2

        let A = try DenseMatrix([[2.0, 3.0],
                                  [4.0, 5.0]])
        let b = [8.0, 14.0]

        let x = try A.solve(b)

        #expect(x.count == 2)
        #expect(abs(x[0] - 1.0) < 1e-10)
        #expect(abs(x[1] - 2.0) < 1e-10)
    }

    // MARK: - 2️⃣ Edge Case Tests

    @Test("Empty matrix")
    func emptyMatrix() throws {
        let data: [[Double]] = []

        #expect(throws: MatrixError.self) {
            _ = try DenseMatrix(data)
        }
    }

    @Test("Single element matrix (1×1)")
    func singleElementMatrix() throws {
        let matrix = try DenseMatrix([[5.0]])

        #expect(matrix.rows == 1)
        #expect(matrix.columns == 1)
        #expect(matrix.isSquare)
        #expect(matrix[0, 0] == 5.0)

        // Transpose of 1×1 is itself
        let transposed = matrix.transposed()
        #expect(transposed[0, 0] == 5.0)
    }

    @Test("Transpose of transpose returns original")
    func transposeOfTranspose() throws {
        let matrix = try DenseMatrix(testMatrix2x2())
        let twice = matrix.transposed().transposed()

        #expect(twice.rows == matrix.rows)
        #expect(twice.columns == matrix.columns)

        for i in 0..<matrix.rows {
            for j in 0..<matrix.columns {
                #expect(abs(twice[i, j] - matrix[i, j]) < 1e-10)
            }
        }
    }

    @Test("Identity matrix multiplication")
    func identityMatrixMultiplication() throws {
        let A = try DenseMatrix(testMatrix2x2())
        let I = DenseMatrix<Double>.identity(size: 2)

        // A × I = A
        let result = try A.multiplied(by: I)

        for i in 0..<A.rows {
            for j in 0..<A.columns {
                #expect(abs(result[i, j] - A[i, j]) < 1e-10)
            }
        }
    }

    @Test("Matrix with zeros")
    func matrixWithZeros() throws {
        let data = [[1.0, 0.0],
                    [0.0, 1.0]]
        let matrix = try DenseMatrix(data)

        #expect(matrix[0, 1] == 0.0)
        #expect(matrix[1, 0] == 0.0)
    }

    // MARK: - 3️⃣ Invalid Input Tests

    @Test("Non-rectangular matrix (jagged array)")
    func nonRectangularMatrix() throws {
        let data = [[1.0, 2.0],
                    [3.0, 4.0, 5.0]]  // Different row lengths

        #expect(throws: MatrixError.self) {
            _ = try DenseMatrix(data)
        }
    }

    @Test("Dimension mismatch in matrix multiplication")
    func dimensionMismatchMultiplication() throws {
        let A = try DenseMatrix([[1.0, 2.0]])  // 1×2
        let B = try DenseMatrix([[1.0], [2.0], [3.0]])  // 3×1

        // Cannot multiply 1×2 by 3×1 (inner dimensions don't match)
        #expect(throws: MatrixError.self) {
            _ = try A.multiplied(by: B)
        }
    }

    @Test("Dimension mismatch in matrix-vector multiplication")
    func dimensionMismatchVectorMultiplication() throws {
        let A = try DenseMatrix([[1.0, 2.0],
                                  [3.0, 4.0]])  // 2×2
        let x = [1.0, 2.0, 3.0]  // Length 3

        #expect(throws: MatrixError.self) {
            _ = try A.multiplied(by: x)
        }
    }

    @Test("Solve system with non-square matrix")
    func solveNonSquareSystem() throws {
        let A = try DenseMatrix([[1.0, 2.0, 3.0],
                                  [4.0, 5.0, 6.0]])  // 2×3 (not square)
        let b = [1.0, 2.0]

        #expect(throws: MatrixError.notSquare.self) {
            _ = try A.solve(b)
        }
    }

    @Test("Solve system with singular matrix")
    func solveSingularSystem() throws {
        // Rows are linearly dependent
        let A = try DenseMatrix([[1.0, 2.0],
                                  [2.0, 4.0]])  // Row 2 = 2 × Row 1
        let b = [3.0, 6.0]

        #expect(throws: MatrixError.singularMatrix.self) {
            _ = try A.solve(b)
        }
    }

    // MARK: - 4️⃣ Property-Based Tests

    @Test("Transpose property: (Aᵀ)ᵀ = A")
    func transposeProperty() throws {
        let A = try DenseMatrix(testMatrix3x3())
        let ATransposedTwice = A.transposed().transposed()

        #expect(ATransposedTwice.rows == A.rows)
        #expect(ATransposedTwice.columns == A.columns)

        for i in 0..<A.rows {
            for j in 0..<A.columns {
                #expect(abs(ATransposedTwice[i, j] - A[i, j]) < 1e-10)
            }
        }
    }

    @Test("Matrix multiplication associativity: (AB)C = A(BC)")
    func multiplicationAssociativity() throws {
        let A = try DenseMatrix([[1.0, 2.0], [3.0, 4.0]])
        let B = try DenseMatrix([[5.0, 6.0], [7.0, 8.0]])
        let C = try DenseMatrix([[9.0, 10.0], [11.0, 12.0]])

        let AB_C = try (try A.multiplied(by: B)).multiplied(by: C)
        let A_BC = try A.multiplied(by: (try B.multiplied(by: C)))

        for i in 0..<AB_C.rows {
            for j in 0..<AB_C.columns {
                #expect(abs(AB_C[i, j] - A_BC[i, j]) < 1e-8)
            }
        }
    }

    @Test("Transpose of product: (AB)ᵀ = BᵀAᵀ")
    func transposeOfProduct() throws {
        let A = try DenseMatrix([[1.0, 2.0], [3.0, 4.0]])
        let B = try DenseMatrix([[5.0, 6.0], [7.0, 8.0]])

        let AB_transposed = try A.multiplied(by: B).transposed()
        let BtAt = try B.transposed().multiplied(by: A.transposed())

        #expect(AB_transposed.rows == BtAt.rows)
        #expect(AB_transposed.columns == BtAt.columns)

        for i in 0..<AB_transposed.rows {
            for j in 0..<AB_transposed.columns {
                #expect(abs(AB_transposed[i, j] - BtAt[i, j]) < 1e-10)
            }
        }
    }

    @Test("Symmetric matrix remains symmetric after transpose")
    func symmetricMatrixProperty() throws {
        let symmetric = [[1.0, 2.0, 3.0],
                        [2.0, 4.0, 5.0],
                        [3.0, 5.0, 6.0]]
        let A = try DenseMatrix(symmetric)

        #expect(A.isSymmetric(tolerance: 1e-10))

        let At = A.transposed()
        #expect(At.isSymmetric(tolerance: 1e-10))

        // A = Aᵀ for symmetric matrices
        for i in 0..<A.rows {
            for j in 0..<A.columns {
                #expect(abs(A[i, j] - At[i, j]) < 1e-10)
            }
        }
    }

    // MARK: - 5️⃣ Numerical Stability Tests

    @Test("Matrix operations with very small numbers")
    func verySmallNumbers() throws {
        let small = 1e-12
        let data = [[small, small * 2],
                    [small * 3, small * 4]]
        let matrix = try DenseMatrix(data)

        #expect(matrix[0, 0] == small)
        #expect(matrix[1, 1] == small * 4)

        // Operations should preserve magnitude
        let transposed = matrix.transposed()
        #expect(abs(transposed[0, 0] - small) < 1e-20)
    }

    @Test("Matrix operations with very large numbers")
    func veryLargeNumbers() throws {
        let large = 1e12
        let data = [[large, large * 2],
                    [large * 3, large * 4]]
        let matrix = try DenseMatrix(data)

        #expect(matrix[0, 0] == large)

        // Should not overflow
        let transposed = matrix.transposed()
        #expect(transposed[0, 0].isFinite)
        #expect(transposed[1, 1].isFinite)
    }

    @Test("Well-conditioned system solution stability")
    func wellConditionedSystem() throws {
        // Well-conditioned matrix (far from singular)
        let A = try DenseMatrix([[10.0, 1.0],
                                  [1.0, 10.0]])
        let b = [11.0, 11.0]

        let x = try A.solve(b)

        // Solution should be x = [1, 1]
        #expect(abs(x[0] - 1.0) < 1e-10)
        #expect(abs(x[1] - 1.0) < 1e-10)

        // Verify: A × x ≈ b
        let Ax = try A.multiplied(by: x)
        #expect(abs(Ax[0] - b[0]) < 1e-10)
        #expect(abs(Ax[1] - b[1]) < 1e-10)
    }

    @Test("Mixed magnitude numbers")
    func mixedMagnitudes() throws {
        let data = [[1e-6, 1e6],
                    [1e3, 1e-3]]
        let matrix = try DenseMatrix(data)

        #expect(matrix[0, 0].isFinite)
        #expect(matrix[0, 1].isFinite)
        #expect(matrix[1, 0].isFinite)
        #expect(matrix[1, 1].isFinite)
    }

    // MARK: - 6️⃣ Stress Tests

    @Test("Large matrix creation", .timeLimit(.minutes(1)))
    func largeMatrixCreation() throws {
        let size = 1000
        var data: [[Double]] = []
        for i in 0..<size {
            var row: [Double] = []
            for j in 0..<size {
                row.append(Double(i * size + j))
            }
            data.append(row)
        }

        let matrix = try DenseMatrix(data)

        #expect(matrix.rows == size)
        #expect(matrix.columns == size)
    }

    @Test("Large matrix transpose", .timeLimit(.minutes(1)))
    func largeMatrixTranspose() throws {
        let size = 500
        let data = (0..<size).map { i in
            (0..<size).map { j in Double(i * size + j) }
        }

        let matrix = try DenseMatrix(data)
        let transposed = matrix.transposed()

        #expect(transposed.rows == size)
        #expect(transposed.columns == size)

        // Verify a few elements
        #expect(transposed[0, 0] == matrix[0, 0])
        #expect(transposed[10, 20] == matrix[20, 10])
    }

    @Test("Large matrix-vector multiplication", .timeLimit(.minutes(1)))
    func largeMatrixVectorMultiplication() throws {
        // Seeded RNG for deterministic test
        struct SeededRNG {
            var state: UInt64
            mutating func next() -> Double {
                state = state &* 6364136223846793005 &+ 1
                let upper = Double((state >> 32) & 0xFFFFFFFF)
                return (upper / Double(UInt32.max)) * 2.0 - 1.0  // Map to [-1, 1]
            }
        }

        var rng = SeededRNG(state: 12345)
        let size = 1000
        let data = (0..<size).map { _ in
            (0..<size).map { _ in rng.next() }
        }

        let matrix = try DenseMatrix(data)
        let vector = (0..<size).map { _ in rng.next() }

        let result = try matrix.multiplied(by: vector)

        #expect(result.count == size)
        #expect(result.allSatisfy { $0.isFinite })
    }

    // MARK: - Parameterized Tests

    @Test("Identity matrices of various sizes",
          arguments: [1, 2, 3, 5, 10, 50, 100])
    func identityMatricesSizes(size: Int) {
        let I = DenseMatrix<Double>.identity(size: size)

        #expect(I.rows == size)
        #expect(I.columns == size)
        #expect(I.isSquare)

        // Verify diagonal
        for i in 0..<size {
            #expect(I[i, i] == 1.0)
        }

        // Verify trace equals size
        #expect(abs(I.trace - Double(size)) < 1e-10)
    }

    @Test("Matrix addition commutativity",
          arguments: [
            ([[1.0, 2.0], [3.0, 4.0]], [[5.0, 6.0], [7.0, 8.0]]),
            ([[1.0]], [[2.0]]),
            ([[1.0, 2.0, 3.0]], [[4.0, 5.0, 6.0]])
          ])
    func matrixAdditionCommutativity(A_data: [[Double]], B_data: [[Double]]) throws {
        let A = try DenseMatrix(A_data)
        let B = try DenseMatrix(B_data)

        let AplusB = try A + B
        let BplusA = try B + A

        for i in 0..<A.rows {
            for j in 0..<A.columns {
                #expect(abs(AplusB[i, j] - BplusA[i, j]) < 1e-10)
            }
        }
    }
}

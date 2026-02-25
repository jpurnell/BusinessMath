//
//  SparsePerformanceBenchmark.swift
//  BusinessMath
//
//  Created by Claude Code on 12/11/25.
//  Phase 8.1: Performance benchmarks demonstrating sparse matrix advantages
//

import Foundation
import TestSupport  // Cross-platform math functions
import Testing
@testable import BusinessMath

@Suite("Sparse Matrix Performance Benchmarks", .serialized)
struct SparsePerformanceBenchmark {

    // MARK: - Matrix-Vector Multiply Benchmarks

    /// Benchmark: Sparse vs Dense matrix-vector multiplication (0.1% density)
    @Test("Sparse vs Dense: 500×500 matrix (0.1% density)")
    func benchmarkSparseVsDense500() throws {
        let n = 500
        let density = 0.001  // 0.1% density

        // Create random sparse matrix with specified density
        let sparse = createRandomSparseMatrix(rows: n, columns: n, density: density)
        let vector = (0..<n).map { _ in Double.random(in: -1.0...1.0) }

        // Sparse benchmark
        let startSparse = Date()
        let iterations = 1000
        for _ in 0..<iterations {
            _ = sparse.multiply(vector: vector)
        }
        let sparseDuration = Date().timeIntervalSince(startSparse)

        // Dense benchmark (using naive implementation)
        let dense = densifyMatrix(sparse, rows: n, columns: n)
        let startDense = Date()
        for _ in 0..<iterations {
            _ = denseMultiply(dense, vector)
        }
        let denseDuration = Date().timeIntervalSince(startDense)

        let speedup = denseDuration / sparseDuration

        // Results
        print("")
        print("═══════════════════════════════════════════════════════")
        print("  Sparse vs Dense Benchmark (500×500, 0.1% density)")
        print("═══════════════════════════════════════════════════════")
		print("  Sparse time: \((sparseDuration * 1000).number(3))ms")
		print("  Dense time:  \((denseDuration * 1000).number(3))ms")
		print("  Speedup:     \(speedup.number(1))×")
        print("  Non-zeros:   \(sparse.nonZeroCount)")
		print("  Sparsity:    \(sparse.sparsity.percent(1))")
        print("═══════════════════════════════════════════════════════")

        // Sparse should be significantly faster
        #expect(speedup > 5.0, "Expected >5× speedup for sparse matrix")
    }

    /// Benchmark: Large sparse matrix (5,000×5,000)
	@Test("Large sparse matrix: 5,000×5,000 (0.06% density)")
    func benchmarkLargeSparse() throws {
        let n = 5_000
        let density = 0.0006  // 0.06% density

        // Create random sparse matrix with specified density
        let sparse = createRandomSparseMatrix(rows: n, columns: n, density: density)
        let vector = (0..<n).map { _ in Double.random(in: -1.0...1.0) }

        // Benchmark sparse multiply
        let start = Date()
        let iterations = 100
        for _ in 0..<iterations {
            _ = sparse.multiply(vector: vector)
        }
        let duration = Date().timeIntervalSince(start)
        let avgTime = duration / Double(iterations)

        print("")
        print("═══════════════════════════════════════════════════════")
        print("  Large Sparse Matrix Benchmark (5,000×5,000)")
        print("═══════════════════════════════════════════════════════")
        print("  Matrix size:     \(n)×\(n)")
        print("  Non-zeros:       \(sparse.nonZeroCount)")
		print("  Sparsity:        \(sparse.sparsity.percent(2))")
		print("  Avg multiply:    \((avgTime * 1000).number(3))ms")
		print("  Throughput:      \((1.0 / avgTime).number(1)) mult/sec")
        print("═══════════════════════════════════════════════════════")

        // Should complete reasonably fast
        #expect(avgTime < 0.02, "Average multiply should be < 20ms")
    }

    // MARK: - Solver Benchmarks

    /// Benchmark: Conjugate Gradient solver convergence
    @Test("CG Solver: 100×100 SPD system")
    func benchmarkCGSolver() throws {
        let n = 100
        let density = 0.03  // 3% density (similar to tridiagonal)

        // Create SPD sparse matrix suitable for CG
        let A = createSPDSparseMatrix(size: n, density: density, diagonalStrength: 2.0)
        let b = [Double](repeating: 1.0, count: n)

        let solver = SparseSolver()

        // Benchmark CG solve
        let start = Date()
        let x = try solver.solve(A: A, b: b, method: .conjugateGradient, tolerance: 1e-8)
        let duration = Date().timeIntervalSince(start)

        // Verify solution quality
        let Ax = A.multiply(vector: x)
        let residual = sqrt(zip(Ax, b).reduce(0.0) { $0 + pow($1.0 - $1.1, 2) })

        print("")
        print("═══════════════════════════════════════════════════════")
        print("  Conjugate Gradient Solver Benchmark (100×100)")
        print("═══════════════════════════════════════════════════════")
        print("  System size:     \(n)×\(n)")
		print("  Solve time:      \((duration * 1000).number(3))ms")
		print("  Final residual:  \(residual.number(2))")
        print("  Converged:       \(residual < 1e-6 ? "✓" : "✗")")
        print("═══════════════════════════════════════════════════════")

        #expect(residual < 1e-6, "Solution should be accurate")
        #expect(duration < 0.1, "Should solve in < 100ms")
    }

    /// Benchmark: BiCG solver for non-symmetric system
    @Test("BiCG Solver: 50×50 non-symmetric system")
    func benchmarkBiCGSolver() throws {
        let n = 50
        let density = 0.06  // 6% density (similar to tridiagonal)

        // Create diagonal dominant non-symmetric sparse matrix suitable for BiCG
        let A = createDiagonalDominantSparseMatrix(size: n, density: density, asymmetryFactor: 0.2, diagonalStrength: 2.0)
        let b = [Double](repeating: 1.0, count: n)

        let solver = SparseSolver(maxIterations: 1000)

        // Benchmark BiCG solve
        let start = Date()
        let x = try solver.solve(A: A, b: b, method: .biconjugateGradient, tolerance: 1e-6)
        let duration = Date().timeIntervalSince(start)

        // Verify solution quality
        let Ax = A.multiply(vector: x)
        let residual = sqrt(zip(Ax, b).reduce(0.0) { $0 + pow($1.0 - $1.1, 2) })

        print("")
        print("═══════════════════════════════════════════════════════")
        print("  Biconjugate Gradient Benchmark (50×50)")
        print("═══════════════════════════════════════════════════════")
        print("  System size:     \(n)×\(n)")
		print("  Solve time:      \((duration * 1000).number(3))ms")
		print("  Final residual:  \(residual.number(2))")
        print("  Converged:       \(residual < 1e-4 ? "✓" : "✗")")
        print("═══════════════════════════════════════════════════════")

        #expect(residual < 1e-4, "Solution should be reasonably accurate")
        #expect(duration < 0.2, "Should solve in < 200ms")
    }

    // MARK: - Memory Efficiency Benchmarks

    /// Benchmark: Memory savings of sparse representation
    @Test("Memory efficiency: 1,000×1,000 sparse matrix")
    func benchmarkMemoryEfficiency() throws {
        let n = 1_000
        let density = 0.003  // 0.3% density

        // Create random sparse matrix with specified density
        let sparse = createRandomSparseMatrix(rows: n, columns: n, density: density)

        // Calculate memory usage
        let sparseMemory = sparse.nonZeroCount * (MemoryLayout<Double>.size + MemoryLayout<Int>.size)
            + (n + 1) * MemoryLayout<Int>.size  // Row pointers

        let denseMemory = n * n * MemoryLayout<Double>.size

        let memorySavings = Double(denseMemory - sparseMemory) / Double(denseMemory)

        print("")
        print("═══════════════════════════════════════════════════════")
        print("  Memory Efficiency (1,000×1,000, 0.3% density)")
        print("═══════════════════════════════════════════════════════")
        print("  Dense memory:    \(denseMemory / 1024 / 1024)MB")
        print("  Sparse memory:   \(sparseMemory / 1024 / 1024)MB")
		print("  Memory saved:    \(memorySavings.percent(1))")
        print("  Non-zeros:       \(sparse.nonZeroCount)")
		print("  Compression:     \((Double(denseMemory) / Double(sparseMemory)).number(1))×")
        print("═══════════════════════════════════════════════════════")

        #expect(memorySavings > 0.95, "Should save >95% memory for sparse matrices")
    }

    // MARK: - Helper Functions

    /// Create a random sparse matrix with specified density
    /// - Parameters:
    ///   - rows: Number of rows
    ///   - columns: Number of columns
    ///   - density: Desired density (fraction of non-zero elements, e.g., 0.001 for 0.1%)
    /// - Returns: A sparse matrix with approximately the specified density
    private func createRandomSparseMatrix(rows: Int, columns: Int, density: Double) -> SparseMatrix {
        let totalElements = rows * columns
        let targetNonZeros = Int(Double(totalElements) * density)

        var triplets: [(Int, Int, Double)] = []
        var usedPositions = Set<Int>()

        // Generate random non-zero entries
        while triplets.count < targetNonZeros {
            let row = Int.random(in: 0..<rows)
            let col = Int.random(in: 0..<columns)
            let position = row * columns + col

            // Avoid duplicate positions
            if !usedPositions.contains(position) {
                let value = Double.random(in: -10.0...10.0)
                if abs(value) > 0.01 {  // Avoid near-zero values
                    triplets.append((row, col, value))
                    usedPositions.insert(position)
                }
            }
        }

        return SparseMatrix(rows: rows, columns: columns, triplets: triplets)
    }

    /// Create a symmetric positive definite (SPD) sparse matrix suitable for CG solver
    /// - Parameters:
    ///   - size: Matrix size (n×n)
    ///   - density: Desired density (fraction of non-zero elements)
    ///   - diagonalStrength: How dominant the diagonal should be (default: 2.0)
    /// - Returns: An SPD sparse matrix that will converge with CG
    private func createSPDSparseMatrix(size: Int, density: Double, diagonalStrength: Double = 2.0) -> SparseMatrix {
        let totalElements = size * size
        let targetNonZeros = Int(Double(totalElements) * density)

        // We'll use half the budget for off-diagonal pairs (symmetric), rest for diagonal enhancement
        let offDiagonalPairs = (targetNonZeros - size) / 2  // Reserve size entries for diagonal

        var triplets: [(Int, Int, Double)] = []
        var usedPairs = Set<String>()

        // Start with positive diagonal (required for SPD)
        var diagonalValues = [Double](repeating: diagonalStrength, count: size)

        // Add symmetric off-diagonal entries
        var pairsAdded = 0
        while pairsAdded < offDiagonalPairs {
            let row = Int.random(in: 0..<size)
            let col = Int.random(in: 0..<size)

            // Only off-diagonal
            guard row != col else { continue }

            // Ensure we haven't used this pair (treat (i,j) same as (j,i))
            let pairKey = row < col ? "\(row),\(col)" : "\(col),\(row)"
            guard !usedPairs.contains(pairKey) else { continue }

            let value = Double.random(in: -1.0...1.0)
            guard abs(value) > 0.01 else { continue }

            // Add both (i,j) and (j,i) for symmetry
            triplets.append((row, col, value))
            triplets.append((col, row, value))
            usedPairs.insert(pairKey)

            // Accumulate for diagonal dominance
            diagonalValues[row] += abs(value)
            diagonalValues[col] += abs(value)

            pairsAdded += 1
        }

        // Add diagonal with accumulated dominance
        for i in 0..<size {
            triplets.append((i, i, diagonalValues[i]))
        }

        return SparseMatrix(rows: size, columns: size, triplets: triplets)
    }

    /// Create a diagonal dominant sparse matrix suitable for BiCG solver
    /// - Parameters:
    ///   - size: Matrix size (n×n)
    ///   - density: Desired density (fraction of non-zero elements)
    ///   - asymmetryFactor: How asymmetric to make the matrix (0.0 = symmetric, 1.0 = fully asymmetric, default: 0.2)
    ///   - diagonalStrength: How dominant the diagonal should be (default: 2.0)
    /// - Returns: A well-conditioned diagonal dominant sparse matrix
    private func createDiagonalDominantSparseMatrix(size: Int, density: Double, asymmetryFactor: Double = 0.2, diagonalStrength: Double = 2.0) -> SparseMatrix {
        let totalElements = size * size
        let targetNonZeros = Int(Double(totalElements) * density)
        let offDiagonalCount = targetNonZeros - size  // Reserve size entries for diagonal

        var triplets: [(Int, Int, Double)] = []
        var usedPositions = Set<Int>()
        var diagonalAccumulation = [Double](repeating: diagonalStrength, count: size)

        // Add off-diagonal entries
        var added = 0
        while added < offDiagonalCount {
            let row = Int.random(in: 0..<size)
            let col = Int.random(in: 0..<size)

            guard row != col else { continue }

            let position = row * size + col
            guard !usedPositions.contains(position) else { continue }

            // Create mild asymmetry by varying the range
            let baseValue = Double.random(in: -1.0...1.0)
            let value: Double
            if Double.random(in: 0...1) < asymmetryFactor {
                // Make this entry more asymmetric
                value = baseValue * Double.random(in: 0.5...1.5)
            } else {
                value = baseValue
            }

            guard abs(value) > 0.01 else { continue }

            triplets.append((row, col, value))
            usedPositions.insert(position)

            // Accumulate absolute value for diagonal dominance
            diagonalAccumulation[row] += abs(value)

            added += 1
        }

        // Add diagonal with accumulated dominance
        for i in 0..<size {
            triplets.append((i, i, diagonalAccumulation[i]))
        }

        return SparseMatrix(rows: size, columns: size, triplets: triplets)
    }

    /// Convert sparse matrix to dense 2D array (for benchmarking only)
    private func densifyMatrix(_ sparse: SparseMatrix, rows: Int, columns: Int) -> [[Double]] {
        var dense = [[Double]](repeating: [Double](repeating: 0.0, count: columns), count: rows)
        for row in 0..<rows {
            for col in 0..<columns {
                dense[row][col] = sparse[row, col]
            }
        }
        return dense
    }

    /// Dense matrix-vector multiplication (for benchmarking comparison)
    private func denseMultiply(_ matrix: [[Double]], _ vector: [Double]) -> [Double] {
        let n = matrix.count
        var result = [Double](repeating: 0.0, count: n)
        for i in 0..<n {
            var sum = 0.0
            for j in 0..<vector.count {
                sum += matrix[i][j] * vector[j]
            }
            result[i] = sum
        }
        return result
    }
}

//
//  SparsePerformanceBenchmark.swift
//  BusinessMath
//
//  Created by Claude Code on 12/11/25.
//  Phase 8.1: Performance benchmarks demonstrating sparse matrix advantages
//

import Foundation
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

        // Create sparse tridiagonal matrix (0.6% density)
        var triplets: [(Int, Int, Double)] = []
        for i in 0..<n {
            triplets.append((i, i, 2.0))  // Diagonal
            if i > 0 { triplets.append((i, i-1, -1.0)) }  // Sub-diagonal
            if i < n-1 { triplets.append((i, i+1, -1.0)) }  // Super-diagonal
        }

        let sparse = SparseMatrix(rows: n, columns: n, triplets: triplets)
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
        print("  Sparse vs Dense Benchmark (500×500, 0.6% density)")
        print("═══════════════════════════════════════════════════════")
        print("  Sparse time: \(String(format: "%.3f", sparseDuration * 1000))ms")
        print("  Dense time:  \(String(format: "%.3f", denseDuration * 1000))ms")
        print("  Speedup:     \(String(format: "%.1f", speedup))×")
        print("  Non-zeros:   \(sparse.nonZeroCount)")
        print("  Sparsity:    \(String(format: "%.1f", sparse.sparsity * 100))%")
        print("═══════════════════════════════════════════════════════")

        // Sparse should be significantly faster
        #expect(speedup > 5.0, "Expected >5× speedup for sparse matrix")
    }

    /// Benchmark: Large sparse matrix (5,000×5,000)
	@Test("Large sparse matrix: 5,000×5,000 (0.06% density)")
    func benchmarkLargeSparse() throws {
        let n = 5_000

        // Create sparse tridiagonal matrix
        var triplets: [(Int, Int, Double)] = []
        for i in 0..<n {
            triplets.append((i, i, 2.0))
            if i > 0 { triplets.append((i, i-1, -1.0)) }
            if i < n-1 { triplets.append((i, i+1, -1.0)) }
        }

        let sparse = SparseMatrix(rows: n, columns: n, triplets: triplets)
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
        print("  Sparsity:        \(String(format: "%.2f", sparse.sparsity * 100))%")
        print("  Avg multiply:    \(String(format: "%.3f", avgTime * 1000))ms")
        print("  Throughput:      \(String(format: "%.1f", 1.0 / avgTime)) mult/sec")
        print("═══════════════════════════════════════════════════════")

        // Should complete reasonably fast
        #expect(avgTime < 0.02, "Average multiply should be < 20ms")
    }

    // MARK: - Solver Benchmarks

    /// Benchmark: Conjugate Gradient solver convergence
    @Test("CG Solver: 100×100 SPD system")
    func benchmarkCGSolver() throws {
        let n = 100

        // Create SPD tridiagonal matrix
        var triplets: [(Int, Int, Double)] = []
        for i in 0..<n {
            triplets.append((i, i, 4.0))  // Diagonal (dominant)
            if i > 0 { triplets.append((i, i-1, -1.0)) }
            if i < n-1 { triplets.append((i, i+1, -1.0)) }
        }

        let A = SparseMatrix(rows: n, columns: n, triplets: triplets)
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
        print("  Solve time:      \(String(format: "%.3f", duration * 1000))ms")
        print("  Final residual:  \(String(format: "%.2e", residual))")
        print("  Converged:       \(residual < 1e-6 ? "✓" : "✗")")
        print("═══════════════════════════════════════════════════════")

        #expect(residual < 1e-6, "Solution should be accurate")
        #expect(duration < 0.1, "Should solve in < 100ms")
    }

    /// Benchmark: BiCG solver for non-symmetric system
    @Test("BiCG Solver: 50×50 non-symmetric system")
    func benchmarkBiCGSolver() throws {
        let n = 50

        // Create well-conditioned non-symmetric matrix
        // Diagonal dominant with mild asymmetry
        var triplets: [(Int, Int, Double)] = []
        for i in 0..<n {
            triplets.append((i, i, 5.0))  // Strong diagonal
            if i > 0 { triplets.append((i, i-1, -1.0)) }  // Sub-diagonal
            if i < n-1 { triplets.append((i, i+1, -0.8)) }  // Super-diagonal (slightly weaker)
        }

        let A = SparseMatrix(rows: n, columns: n, triplets: triplets)
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
        print("  Solve time:      \(String(format: "%.3f", duration * 1000))ms")
        print("  Final residual:  \(String(format: "%.2e", residual))")
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

        // Create very sparse matrix (0.3% density)
        var triplets: [(Int, Int, Double)] = []
        for i in 0..<n {
            triplets.append((i, i, 2.0))
            if i > 0 { triplets.append((i, i-1, -1.0)) }
            if i < n-1 { triplets.append((i, i+1, -1.0)) }
        }

        let sparse = SparseMatrix(rows: n, columns: n, triplets: triplets)

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
        print("  Memory saved:    \(String(format: "%.1f", memorySavings * 100))%")
        print("  Non-zeros:       \(sparse.nonZeroCount)")
        print("  Compression:     \(String(format: "%.1f", Double(denseMemory) / Double(sparseMemory)))×")
        print("═══════════════════════════════════════════════════════")

        #expect(memorySavings > 0.95, "Should save >95% memory for sparse matrices")
    }

    // MARK: - Helper Functions

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

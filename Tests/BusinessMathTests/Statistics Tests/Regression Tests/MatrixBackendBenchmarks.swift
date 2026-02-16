//
//  MatrixBackendBenchmarks.swift
//  BusinessMath
//
//  Created by Claude Code on 2026-02-15.
//

import Testing
import Foundation
@testable import BusinessMath

/// Performance benchmarks comparing matrix operation backends.
///
/// Measures and compares execution times for:
/// - Pure Swift CPU backend
/// - Accelerate BLAS/LAPACK backend (Apple platforms)
/// - Metal GPU backend (Apple Silicon)
///
/// ## Expected Performance
///
/// | Size | CPU | Accelerate | Metal | Best Backend |
/// |------|-----|------------|-------|--------------|
/// | 100  | ~5ms | ~0.5ms (10×) | ~3ms | Accelerate |
/// | 500  | ~120ms | ~8ms (15×) | ~30ms | Accelerate |
/// | 1000 | ~2500ms | ~40ms (60×) | ~25ms (100×) | Metal |
///
/// - Note: Benchmarks are run once per test invocation. For production benchmarking,
///   average multiple runs and warm up the backends first.
///
/// ## Running Benchmarks
///
/// These tests are disabled by default to prevent timeouts during normal test runs.
/// To run them explicitly:
/// ```bash
/// swift test --filter MatrixBackendBenchmarks --enable-disabled-tests
/// ```
@Suite("Matrix Backend Performance Benchmarks", .disabled("Performance benchmarks are slow - run explicitly when needed"))
struct MatrixBackendBenchmarks {

    // MARK: - Helper Functions

    /// Generate random matrix for benchmarking
    func randomMatrix(rows: Int, cols: Int) -> [[Double]] {
        (0..<rows).map { _ in
            (0..<cols).map { _ in Double.random(in: -1.0...1.0) }
        }
    }

    /// Measure execution time in seconds
    func measureTime(_ block: () throws -> Void) rethrows -> TimeInterval {
        let start = Date()
        try block()
        return Date().timeIntervalSince(start)
    }

    // MARK: - Small Matrix Benchmarks (100×100)

    @Test("CPU backend: 100×100 matrix multiplication")
    func cpuSmallMultiply() throws {
        let A = randomMatrix(rows: 100, cols: 100)
        let B = randomMatrix(rows: 100, cols: 100)

        let backend = CPUMatrixBackend()

        let time = try measureTime {
            _ = try backend.multiply(A, B)
        }

        print("CPU (100×100): \(String(format: "%.3f", time * 1000))ms")
    }

    #if canImport(Accelerate)
    @Test("Accelerate backend: 100×100 matrix multiplication")
    func accelerateSmallMultiply() throws {
        let A = randomMatrix(rows: 100, cols: 100)
        let B = randomMatrix(rows: 100, cols: 100)

        let backend = AccelerateMatrixBackend()

        let time = try measureTime {
            _ = try backend.multiply(A, B)
        }

        print("Accelerate (100×100): \(String(format: "%.3f", time * 1000))ms")
    }
    #endif

    #if canImport(Metal)
    @Test("Metal backend: 100×100 matrix multiplication")
    func metalSmallMultiply() throws {
        guard let backend = MetalMatrixBackend() else {
            print("Metal not available, skipping benchmark")
            return
        }

        let A = randomMatrix(rows: 100, cols: 100)
        let B = randomMatrix(rows: 100, cols: 100)

        let time = try measureTime {
            _ = try backend.multiply(A, B)
        }

        print("Metal (100×100): \(String(format: "%.3f", time * 1000))ms")
    }
    #endif

    // MARK: - Medium Matrix Benchmarks (500×500)

    @Test("CPU backend: 500×500 matrix multiplication", .timeLimit(.minutes(1)))
    func cpuMediumMultiply() throws {
        let A = randomMatrix(rows: 500, cols: 500)
        let B = randomMatrix(rows: 500, cols: 500)

        let backend = CPUMatrixBackend()

        let time = try measureTime {
            _ = try backend.multiply(A, B)
        }

        print("CPU (500×500): \(String(format: "%.3f", time * 1000))ms")
    }

    #if canImport(Accelerate)
    @Test("Accelerate backend: 500×500 matrix multiplication")
    func accelerateMediumMultiply() throws {
        let A = randomMatrix(rows: 500, cols: 500)
        let B = randomMatrix(rows: 500, cols: 500)

        let backend = AccelerateMatrixBackend()

        let time = try measureTime {
            _ = try backend.multiply(A, B)
        }

        print("Accelerate (500×500): \(String(format: "%.3f", time * 1000))ms")
    }
    #endif

    #if canImport(Metal)
    @Test("Metal backend: 500×500 matrix multiplication")
    func metalMediumMultiply() throws {
        guard let backend = MetalMatrixBackend() else {
            print("Metal not available, skipping benchmark")
            return
        }

        let A = randomMatrix(rows: 500, cols: 500)
        let B = randomMatrix(rows: 500, cols: 500)

        let time = try measureTime {
            _ = try backend.multiply(A, B)
        }

        print("Metal (500×500): \(String(format: "%.3f", time * 1000))ms")
    }
    #endif

    // MARK: - Large Matrix Benchmarks (1000×1000)

    @Test("CPU backend: 1000×1000 matrix multiplication", .timeLimit(.minutes(2)))
    func cpuLargeMultiply() throws {
        let A = randomMatrix(rows: 1000, cols: 1000)
        let B = randomMatrix(rows: 1000, cols: 1000)

        let backend = CPUMatrixBackend()

        let time = try measureTime {
            _ = try backend.multiply(A, B)
        }

		print("CPU (1000×1000): \((time * 1000).number(1))ms")
    }

    #if canImport(Accelerate)
    @Test("Accelerate backend: 1000×1000 matrix multiplication")
    func accelerateLargeMultiply() throws {
        let A = randomMatrix(rows: 1000, cols: 1000)
        let B = randomMatrix(rows: 1000, cols: 1000)

        let backend = AccelerateMatrixBackend()

        let time = try measureTime {
            _ = try backend.multiply(A, B)
        }

		print("Accelerate (1000×1000): \((time * 1000).number(1))ms")
    }
    #endif

    #if canImport(Metal)
    @Test("Metal backend: 1000×1000 matrix multiplication", .timeLimit(.minutes(3)))
    func metalLargeMultiply() throws {
        guard let backend = MetalMatrixBackend() else {
            print("Metal not available, skipping benchmark")
            return
        }

        let A = randomMatrix(rows: 1000, cols: 1000)
        let B = randomMatrix(rows: 1000, cols: 1000)

        let time = try measureTime {
            _ = try backend.multiply(A, B)
        }

		print("Metal (1000×1000): \((time * 1000).number(1))ms")
    }
    #endif

    // MARK: - Backend Selector Verification

    @Test("Backend selector chooses appropriate backend for different sizes")
    func backendSelector() {
        // Small matrix: should use CPU
        let smallBackend = MatrixBackendSelector.selectBackend(matrixSize: 50)
        #expect(smallBackend is CPUMatrixBackend)

        #if canImport(Accelerate)
        // Medium matrix: should use Accelerate
        let mediumBackend = MatrixBackendSelector.selectBackend(matrixSize: 500)
        #expect(mediumBackend is AccelerateMatrixBackend)
        #endif

        #if canImport(Metal)
        // Large matrix: should prefer Metal if available
        let largeBackend = MatrixBackendSelector.selectBackend(matrixSize: 2000)
        let expectMetal = largeBackend is MetalMatrixBackend
        let expectAccelerate = largeBackend is AccelerateMatrixBackend
        #expect(expectMetal || expectAccelerate)
        #endif
    }
}

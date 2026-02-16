//
//  MatrixBackend.swift
//  BusinessMath
//
//  Created by Claude Code on 2026-02-15.
//

import Foundation

/// Backend protocol for matrix computations.
///
/// Implementations provide CPU or GPU execution based on platform capabilities
/// and problem size. All backends must produce mathematically equivalent results
/// within numerical tolerance.
///
/// ## Available Backends
///
/// - ``CPUMatrixBackend``: Pure Swift implementation (all platforms)
/// - ``AccelerateMatrixBackend``: BLAS/LAPACK optimized (Apple platforms)
/// - ``MetalMatrixBackend``: GPU-accelerated (Apple Silicon)
///
/// ## Performance Characteristics
///
/// | Backend | Best For | Speedup |
/// |---------|----------|---------|
/// | CPU | Small matrices (n < 100) | Baseline |
/// | Accelerate | Medium matrices (100 ≤ n < 1000) | 5-20× |
/// | Metal | Large matrices (n ≥ 1000) | 10-100× |
///
/// ## Usage Example
///
/// ```swift
/// // Automatic backend selection
/// let backend = MatrixBackendSelector.selectBackend(matrixSize: 500)
/// let result = backend.multiply(A, B)
///
/// // Explicit backend
/// let cpuBackend = CPUMatrixBackend()
/// let result = cpuBackend.solve(A, b)
/// ```
///
/// - Note: All implementations must be thread-safe and conform to `Sendable`.
public protocol MatrixBackend: Sendable {

    /// Multiply two matrices: C = A × B
    ///
    /// - Parameters:
    ///   - A: Left matrix (m × n)
    ///   - B: Right matrix (n × p)
    ///
    /// - Returns: Product matrix (m × p)
    ///
    /// - Throws: ``MatrixError/dimensionMismatch(expected:actual:)`` if inner dimensions don't match
    ///
    /// - Complexity: O(mnp) for CPU, O(mnp/cores) for GPU
    func multiply(_ A: [[Double]], _ B: [[Double]]) throws -> [[Double]]

    /// Solve linear system: Ax = b
    ///
    /// Uses the most appropriate method based on matrix properties:
    /// - Symmetric positive definite → Cholesky decomposition
    /// - Square non-singular → QR decomposition with back-substitution
    ///
    /// - Parameters:
    ///   - A: Coefficient matrix (n × n)
    ///   - b: Right-hand side vector (length n)
    ///
    /// - Returns: Solution vector x (length n)
    ///
    /// - Throws:
    ///   - ``MatrixError/notSquare`` if A is not square
    ///   - ``MatrixError/singularMatrix`` if A is singular
    ///   - ``MatrixError/dimensionMismatch(expected:actual:)`` if b length doesn't match A rows
    ///
    /// - Complexity: O(n³) for decomposition, O(n²) for back-substitution
    func solve(_ A: [[Double]], _ b: [Double]) throws -> [Double]

    /// QR decomposition: A = QR
    ///
    /// Decomposes matrix A into:
    /// - Q: Orthogonal matrix (QᵀQ = I)
    /// - R: Upper triangular matrix
    ///
    /// Used for solving linear systems and least squares problems.
    ///
    /// - Parameter A: Matrix to decompose (m × n)
    ///
    /// - Returns: Tuple (Q, R) where A = Q × R
    ///
    /// - Throws: ``MatrixError/invalidDecomposition(reason:)`` if decomposition fails
    ///
    /// - Complexity: O(mn²) using Householder reflections
    func qrDecomposition(_ A: [[Double]]) throws -> (q: [[Double]], r: [[Double]])
}

/// Selects optimal matrix backend based on platform and problem size.
///
/// Automatically chooses the fastest available backend:
/// 1. Metal (GPU) for large matrices on Apple Silicon
/// 2. Accelerate (BLAS/LAPACK) for medium matrices on Apple platforms
/// 3. Pure Swift (CPU) as universal fallback
///
/// ## Usage Example
///
/// ```swift
/// let matrixSize = 1000
/// let backend = MatrixBackendSelector.selectBackend(matrixSize: matrixSize)
///
/// // Backend is automatically chosen:
/// // - Metal if size ≥ 1000 and GPU available
/// // - Accelerate if size ≥ 100 and on Apple platform
/// // - CPU otherwise
/// ```
public struct MatrixBackendSelector {

    /// Select optimal backend for given matrix size.
    ///
    /// - Parameter matrixSize: Approximate matrix dimension (max of rows/columns)
    ///
    /// - Returns: Best available backend for this problem size
    public static func selectBackend(matrixSize: Int) -> any MatrixBackend {
        #if canImport(Metal)
        // Use Metal for very large matrices on Apple Silicon
        if matrixSize >= 1000, let metalBackend = MetalMatrixBackend() {
            return metalBackend
        }
        #endif

        #if canImport(Accelerate)
        // Use Accelerate for medium-to-large matrices on Apple platforms
        if matrixSize >= 100 {
            return AccelerateMatrixBackend()
        }
        #endif

        // Fallback to CPU for small matrices or non-Apple platforms
        return CPUMatrixBackend()
    }
}

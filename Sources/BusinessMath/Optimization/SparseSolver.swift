//
//  SparseSolver.swift
//  BusinessMath
//
//  Created by Claude Code on 12/11/25.
//  Phase 8.1: Sparse iterative solvers (CG, BiCG, GMRES)
//

import Foundation

/// Iterative solver for sparse linear systems Ax = b
///
/// Provides efficient iterative methods that leverage sparse matrix structure:
/// - Conjugate Gradient (CG): For symmetric positive definite systems
/// - Biconjugate Gradient (BiCG): For general non-symmetric systems
/// - GMRES: For general systems with better convergence (future)
///
/// These methods require only matrix-vector products, making them ideal
/// for large sparse systems where direct methods would be prohibitively expensive.
///
/// Example:
/// ```swift
/// let A = SparseMatrix(dense: [[4, 1], [1, 3]])
/// let b = [1.0, 2.0]
/// let solver = SparseSolver()
/// let x = try solver.solve(A: A, b: b, method: .conjugateGradient)
/// ```
public struct SparseSolver {

    /// Solver method selection
    public enum Method {
        /// Conjugate Gradient - for symmetric positive definite matrices
        case conjugateGradient

        /// Biconjugate Gradient - for general non-symmetric matrices
        case biconjugateGradient

        /// GMRES - Generalized Minimal Residual (future implementation)
        // case gmres
    }

    /// Solver errors
    public enum SolverError: Error, LocalizedError {
        case notConverged(iterations: Int, residual: Double)
        case singularMatrix
        case invalidDimensions

        public var errorDescription: String? {
            switch self {
            case .notConverged(let iterations, let residual):
                return "Solver did not converge after \(iterations) iterations (residual: \(residual))"
            case .singularMatrix:
                return "Matrix is singular or nearly singular"
            case .invalidDimensions:
                return "Matrix and vector dimensions are incompatible"
            }
        }
    }

    /// Maximum iterations allowed
    public var maxIterations: Int

    /// Default convergence tolerance
    public var defaultTolerance: Double

    public init(maxIterations: Int = 10000, defaultTolerance: Double = 1e-10) {
        self.maxIterations = maxIterations
        self.defaultTolerance = defaultTolerance
    }

    // MARK: - Main Solver Interface

    /// Solve sparse linear system Ax = b
    ///
    /// - Parameters:
    ///   - A: Sparse coefficient matrix
    ///   - b: Right-hand side vector
    ///   - method: Iterative solver method
    ///   - tolerance: Convergence tolerance (default: 1e-10)
    ///   - initialGuess: Initial solution guess (default: zero vector)
    /// - Returns: Solution vector x
    /// - Throws: SolverError if convergence fails
    public func solve(
        A: SparseMatrix,
        b: [Double],
        method: Method,
        tolerance: Double? = nil,
        initialGuess: [Double]? = nil
    ) throws -> [Double] {
        guard A.rows == A.columns else {
            throw SolverError.invalidDimensions
        }
        guard b.count == A.rows else {
            throw SolverError.invalidDimensions
        }

        let tol = tolerance ?? defaultTolerance
        let x0 = initialGuess ?? [Double](repeating: 0.0, count: b.count)

        switch method {
        case .conjugateGradient:
            return try conjugateGradient(A: A, b: b, x0: x0, tolerance: tol)
        case .biconjugateGradient:
            return try biconjugateGradient(A: A, b: b, x0: x0, tolerance: tol)
        }
    }

    // MARK: - Conjugate Gradient (CG)

    /// Conjugate Gradient method for symmetric positive definite systems
    ///
    /// CG is the optimal Krylov subspace method for SPD matrices.
    /// Guaranteed to converge in at most n iterations (in exact arithmetic).
    ///
    /// Algorithm:
    /// 1. r₀ = b - Ax₀
    /// 2. p₀ = r₀
    /// 3. For k = 0, 1, 2, ...
    ///    α = (rₖᵀrₖ) / (pₖᵀApₖ)
    ///    xₖ₊₁ = xₖ + αpₖ
    ///    rₖ₊₁ = rₖ - αApₖ
    ///    β = (rₖ₊₁ᵀrₖ₊₁) / (rₖᵀrₖ)
    ///    pₖ₊₁ = rₖ₊₁ + βpₖ
    private func conjugateGradient(
        A: SparseMatrix,
        b: [Double],
        x0: [Double],
        tolerance: Double
    ) throws -> [Double] {
        let _ = b.count
        var x = x0

        // r = b - Ax
        var r = vectorSubtract(b, A.multiply(vector: x))
        var p = r

        var rsold = dotProduct(r, r)

        for _ in 0..<maxIterations {
            // Check convergence: ||r|| < tolerance
            if sqrt(rsold) < tolerance {
                return x
            }

            // Ap = A × p
            let Ap = A.multiply(vector: p)

            // α = rsold / (pᵀAp)
            let pAp = dotProduct(p, Ap)
            guard abs(pAp) > 1e-30 else {
                throw SolverError.singularMatrix
            }
            let alpha = rsold / pAp

            // x = x + α*p
            x = vectorAdd(x, vectorScale(p, alpha))

            // r = r - α*Ap
            r = vectorSubtract(r, vectorScale(Ap, alpha))

            let rsnew = dotProduct(r, r)

            // Check convergence
            if sqrt(rsnew) < tolerance {
                return x
            }

            // β = rsnew / rsold
            let beta = rsnew / rsold

            // p = r + β*p
            p = vectorAdd(r, vectorScale(p, beta))

            rsold = rsnew
        }

        throw SolverError.notConverged(iterations: maxIterations, residual: sqrt(rsold))
    }

    // MARK: - Biconjugate Gradient (BiCG)

    /// Biconjugate Gradient method for general non-symmetric systems
    ///
    /// BiCG extends CG to non-symmetric matrices by working with both A and Aᵀ.
    /// Less stable than CG but applicable to general systems.
    ///
    /// Algorithm uses shadow residuals with Aᵀ to maintain conjugacy.
    private func biconjugateGradient(
        A: SparseMatrix,
        b: [Double],
        x0: [Double],
        tolerance: Double
    ) throws -> [Double] {
        let _ = b.count
        var x = x0

        // r = b - Ax
        var r = vectorSubtract(b, A.multiply(vector: x))
        // r̃ = r (shadow residual for Aᵀ)
        var rtilde = r

        var rho = dotProduct(r, rtilde)
        guard abs(rho) > 1e-30 else {
            throw SolverError.singularMatrix
        }

        var p = r
        var ptilde = rtilde

        // Precompute Aᵀ for efficiency
        let AT = A.transposed()

        for iteration in 0..<maxIterations {
            // Check convergence: ||r|| < tolerance
            let rnorm = sqrt(dotProduct(r, r))
            if rnorm < tolerance {
                return x
            }

            // Ap = A × p
            let Ap = A.multiply(vector: p)
            // ATp̃ = Aᵀ × p̃
            let ATptilde = AT.multiply(vector: ptilde)

            // α = rho / (p̃ᵀAp)
            let ptildeAp = dotProduct(ptilde, Ap)
            guard abs(ptildeAp) > 1e-30 else {
                throw SolverError.singularMatrix
            }
            let alpha = rho / ptildeAp

            // x = x + α*p
            x = vectorAdd(x, vectorScale(p, alpha))

            // r = r - α*Ap
            r = vectorSubtract(r, vectorScale(Ap, alpha))

            // r̃ = r̃ - α*Aᵀp̃
            rtilde = vectorSubtract(rtilde, vectorScale(ATptilde, alpha))

            let rhoNew = dotProduct(r, rtilde)

            // Check for breakdown
            guard abs(rhoNew) > 1e-30 else {
                // BiCG breakdown - try to return best solution so far
                let finalNorm = sqrt(dotProduct(r, r))
                if finalNorm < tolerance * 10 {
                    return x  // Close enough
                }
                throw SolverError.notConverged(iterations: iteration, residual: finalNorm)
            }

            // β = rhoNew / rho
            let beta = rhoNew / rho

            // p = r + β*p
            p = vectorAdd(r, vectorScale(p, beta))

            // p̃ = r̃ + β*p̃
            ptilde = vectorAdd(rtilde, vectorScale(ptilde, beta))

            rho = rhoNew
        }

        let finalResidual = sqrt(dotProduct(r, r))
        throw SolverError.notConverged(iterations: maxIterations, residual: finalResidual)
    }

    // MARK: - Vector Operations

    private func dotProduct(_ a: [Double], _ b: [Double]) -> Double {
        return zip(a, b).reduce(0.0) { $0 + $1.0 * $1.1 }
    }

    private func vectorAdd(_ a: [Double], _ b: [Double]) -> [Double] {
        return zip(a, b).map { $0 + $1 }
    }

    private func vectorSubtract(_ a: [Double], _ b: [Double]) -> [Double] {
        return zip(a, b).map { $0 - $1 }
    }

    private func vectorScale(_ v: [Double], _ scalar: Double) -> [Double] {
        return v.map { $0 * scalar }
    }
}

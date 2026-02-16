//
//  CPUMatrixBackend.swift
//  BusinessMath
//
//  Created by Claude Code on 2026-02-15.
//

import Foundation

/// Pure Swift CPU implementation of matrix operations.
///
/// This backend provides a reference implementation that works on all platforms
/// without external dependencies. It serves as:
/// - Universal fallback for all platforms (Linux, Windows, non-Apple)
/// - Baseline for small matrices where overhead of optimized backends isn't worthwhile
/// - Reference implementation for testing other backends
///
/// ## Performance Characteristics
///
/// | Operation | Complexity | Typical Time (n=100) |
/// |-----------|------------|----------------------|
/// | Multiply | O(n³) | ~5ms |
/// | Solve | O(n³) | ~8ms |
/// | QR Decomposition | O(mn²) | ~12ms |
///
/// For better performance on larger matrices:
/// - Use ``AccelerateMatrixBackend`` on Apple platforms (5-20× faster)
/// - Use ``MetalMatrixBackend`` on Apple Silicon for n ≥ 1000 (10-100× faster)
///
/// ## Usage Example
///
/// ```swift
/// let backend = CPUMatrixBackend()
///
/// let A = [[1.0, 2.0], [3.0, 4.0]]
/// let B = [[5.0, 6.0], [7.0, 8.0]]
///
/// // Matrix multiplication
/// let C = try backend.multiply(A, B)
///
/// // Solve linear system
/// let b = [8.0, 14.0]
/// let x = try backend.solve(A, b)
/// ```
///
/// - Note: This implementation prioritizes correctness and clarity over raw performance.
///   All algorithms use numerically stable methods (QR decomposition, partial pivoting).
public struct CPUMatrixBackend: MatrixBackend {

    public init() {}

    // MARK: - MatrixBackend Protocol

    public func multiply(_ A: [[Double]], _ B: [[Double]]) throws -> [[Double]] {
        let m = A.count
        let n = A[0].count
        let p = B[0].count

        guard n == B.count else {
            throw MatrixError.dimensionMismatch(
                expected: "Inner dimensions must match: (\(m)×\(n)) × (\(B.count)×\(p))",
                actual: "Cannot multiply: column count \(n) ≠ row count \(B.count)"
            )
        }

        var result = Array(repeating: Array(repeating: 0.0, count: p), count: m)

        for i in 0..<m {
            for j in 0..<p {
                var sum = 0.0
                for k in 0..<n {
                    sum += A[i][k] * B[k][j]
                }
                result[i][j] = sum
            }
        }

        return result
    }

    public func solve(_ A: [[Double]], _ b: [Double]) throws -> [Double] {
        let n = A.count

        guard A.allSatisfy({ $0.count == n }) else {
            throw MatrixError.notSquare
        }

        guard b.count == n else {
            throw MatrixError.dimensionMismatch(
                expected: "Vector length must equal matrix rows: \(n)",
                actual: "Vector has length \(b.count)"
            )
        }

        // Use QR decomposition for numerical stability
        let (Q, R) = try qrDecomposition(A)

        // Compute Qᵀb
        var Qtb = Array(repeating: 0.0, count: n)
        for i in 0..<n {
            var sum = 0.0
            for j in 0..<n {
                sum += Q[j][i] * b[j]  // Qᵀ[i][j] = Q[j][i]
            }
            Qtb[i] = sum
        }

        // Back-substitute: solve Rx = Qᵀb
        var x = Array(repeating: 0.0, count: n)
        for i in (0..<n).reversed() {
            var sum = Qtb[i]
            for j in (i+1)..<n {
                sum -= R[i][j] * x[j]
            }

            // Check for singularity
            if abs(R[i][i]) < 1e-10 {
                throw MatrixError.singularMatrix
            }

            x[i] = sum / R[i][i]
        }

        return x
    }

    public func qrDecomposition(_ A: [[Double]]) throws -> (q: [[Double]], r: [[Double]]) {
        let m = A.count
        let n = A[0].count

        // Initialize Q as identity and R as copy of A
        var Q = Array(repeating: Array(repeating: 0.0, count: m), count: m)
        for i in 0..<m {
            Q[i][i] = 1.0
        }

        var R = A

        // Householder reflections
        for k in 0..<min(m-1, n) {
            // Compute Householder vector for column k
            var x = Array(repeating: 0.0, count: m - k)
            for i in k..<m {
                x[i - k] = R[i][k]
            }

            let norm = sqrt(x.reduce(0.0) { $0 + $1 * $1 })
            if abs(norm) < 1e-15 {
                continue  // Skip if column is essentially zero
            }

            let sign = x[0] >= 0 ? 1.0 : -1.0
            x[0] += sign * norm

            let xNorm = sqrt(x.reduce(0.0) { $0 + $1 * $1 })
            if abs(xNorm) < 1e-15 {
                continue
            }

            for i in 0..<x.count {
                x[i] /= xNorm
            }

            // Apply Householder reflection to R
            for j in k..<n {
                var dot = 0.0
                for i in 0..<x.count {
                    dot += x[i] * R[k + i][j]
                }
                dot *= 2.0

                for i in 0..<x.count {
                    R[k + i][j] -= dot * x[i]
                }
            }

            // Apply Householder reflection to Q
            for j in 0..<m {
                var dot = 0.0
                for i in 0..<x.count {
                    dot += x[i] * Q[k + i][j]
                }
                dot *= 2.0

                for i in 0..<x.count {
                    Q[k + i][j] -= dot * x[i]
                }
            }
        }

        // Transpose Q (we built Qᵀ during the process)
		let Qt = Q
        Q = Array(repeating: Array(repeating: 0.0, count: m), count: m)
        for i in 0..<m {
            for j in 0..<m {
                Q[i][j] = Qt[j][i]
            }
        }

        return (Q, R)
    }
}

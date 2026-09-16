//
//  GaussianElimination.swift
//  BusinessMath
//
//  One dense linear solve, shared by the callers that were each carrying a copy of it.
//

import Foundation
import Numerics

/// Solves `A x = b` by Gaussian elimination with partial pivoting.
///
/// This is the package's shared dense solve for small systems. It was extracted from two
/// call sites — `TransitionMatrix.solve` and `LogisticRegression.solveSymmetric` — that were
/// carrying implementations identical in every respect but the function name: the same
/// scale-relative singularity criterion, the same pivot search, the same elimination, the
/// same back substitution, the same finiteness guards. Nothing in either was specialised to
/// Markov chains or to a design matrix.
///
/// ## Singularity is judged relative to the matrix, not against a constant
///
/// The threshold is `scale · .ulpOfOne · n²`, where `scale` is the largest magnitude anywhere
/// in the matrix. This matters more than it looks. A fixed cutoff — `1e-9`, say — is really a
/// statement about the *units* the caller happened to choose: the same system expressed in
/// dollars rather than millions of dollars is a billion times larger, and a constant
/// threshold calls one of those singular and the other fine. A scale-relative threshold is
/// dimensionless, so it gives the same verdict for the same system however it is written
/// down.
///
/// The `n²` factor is the standard allowance for error growth through elimination: each of
/// the `n` elimination steps can amplify rounding by roughly `n`, so a pivot that has fallen
/// below that much of the matrix's own scale carries no reliable information.
///
/// ## Other solves in this package, and why they are still separate
///
/// Three more dense solves exist, and they do not all agree with this one:
///
/// - ``solveLinearSystem(matrix:vector:)`` uses a fixed `1e-9` and **throws** a
///   ``OptimizationError`` that distinguishes an exactly singular matrix from a merely
///   ill-conditioned one. That taxonomy is public API with tests pinning it, so its
///   threshold is deliberate rather than incidental and is left alone here.
/// - `PercentileParameterisable.solveLinear` uses a fixed `1e-12` and argues its own case:
///   its systems are at most 4×4 and are rebuilt at every Newton step, so it is avoiding
///   allocation rather than duplicating carelessly.
/// - `SimplexSolver` carries a private solve wound into its own pivoting rules.
///
/// The consequence is worth stating plainly, because it is not obvious from any one call
/// site: **the same matrix can be called singular by one of these and solved by another.**
/// On `[[1e-10, 0], [0, 1]]`, whose exact solution is `[1, 1]`, this function and
/// `solveLinear` both solve it and `solveLinearSystem` refuses it.
///
/// - Parameters:
///   - matrix: The coefficient matrix `A`, which must be square and match `rhs` in size.
///   - rhs: The right-hand side `b`.
///
/// - Returns: The solution `x`, or `nil` when the system is singular to working precision,
///   the dimensions disagree, or any component of the result is not finite. `nil` rather
///   than a throw because every caller treats "no solution" as an ordinary branch — an
///   absorbing chain with no transient states, a design matrix with collinear columns —
///   rather than as an error to propagate.
///
/// - Complexity: O(n³).
internal func gaussianSolve<T: Real>(_ matrix: [[T]], _ rhs: [T]) -> [T]? {
	let n = rhs.count
	guard n > 0, matrix.count == n else { return nil }
	var a = matrix
	var b = rhs

	// The largest magnitude present, which the singularity threshold is measured against.
	var scale: T = T.zero
	for row in a {
		for value in row {
			let size: T = value < T.zero ? -value : value
			if size > scale { scale = size }
		}
	}
	guard scale > T.zero else { return nil }
	let threshold: T = scale * T.ulpOfOne * T(n * n)

	for column in 0..<n {
		// Partial pivoting: take the largest available pivot in this column, which keeps
		// the multipliers below 1 and stops elimination amplifying rounding error.
		var pivotRow = column
		var best: T = T.zero
		for row in column..<n {
			let size: T = a[row][column] < T.zero ? -a[row][column] : a[row][column]
			if size > best { best = size; pivotRow = row }
		}
		guard best > threshold else { return nil }
		if pivotRow != column {
			a.swapAt(pivotRow, column)
			b.swapAt(pivotRow, column)
		}

		let pivot: T = a[column][column]
		for row in (column + 1)..<n {
			let factor: T = a[row][column] / pivot
			guard factor.isFinite else { return nil }
			for k in column..<n {
				let adjustment: T = factor * a[column][k]
				a[row][k] -= adjustment
			}
			let scaled: T = factor * b[column]
			b[row] -= scaled
		}
	}

	var solution = [T](repeating: T.zero, count: n)
	for row in stride(from: n - 1, through: 0, by: -1) {
		var total: T = b[row]
		for k in (row + 1)..<n {
			let term: T = a[row][k] * solution[k]
			total -= term
		}
		let pivot: T = a[row][row]
		guard pivot != T.zero else { return nil }
		solution[row] = total / pivot
	}

	// A finite matrix can still produce a non-finite solution when the system is close
	// enough to singular that the back substitution overflows. The caller asked for a
	// solution, not for an infinity dressed as one.
	return solution.allSatisfy { $0.isFinite } ? solution : nil
}

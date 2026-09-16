//
//  GaussianElimination.swift
//  BusinessMath
//
//  One dense linear solve, shared by the five callers that each carried a copy of it.
//

import Foundation
import Numerics

// MARK: - Configuration

/// How a solve decides a pivot is too small to divide by.
///
/// The package had three of these in circulation and no single call site made that visible.
/// Naming the choice is what lets one implementation serve every caller.
internal enum SingularityCriterion<T: Real> {
	/// `scale · .ulpOfOne · n²`, where `scale` is the largest magnitude in the matrix.
	///
	/// The defensible default, because it is **dimensionless**. A fixed cutoff is really a
	/// statement about the units the caller happened to choose: the same system written in
	/// dollars rather than millions of dollars is a billion times larger, and a constant
	/// threshold calls one of those singular and the other fine. Measuring the pivot against
	/// the matrix's own scale gives the same verdict for the same system however it is
	/// written down.
	///
	/// The `n²` factor is the standard allowance for error growth: each of the `n`
	/// elimination steps can amplify rounding by roughly `n`, so a pivot below that much of
	/// the matrix's scale carries no reliable information.
	case scaleRelative

	/// A fixed cutoff, independent of the matrix.
	///
	/// Correct when the caller knows the scale of its own systems — `ParameterSolve` fits
	/// at most four parameters on a known range — and a deliberate choice rather than an
	/// oversight wherever it appears.
	case absolute(T)
}

/// Why a solve declined to answer.
///
/// Richer than the `nil` most callers want, because ``solveLinearSystem(matrix:vector:)``
/// publishes a taxonomy that separates an exactly singular matrix from a merely
/// ill-conditioned one — a distinction a caller can act on, since the first is not fixable
/// by rescaling and the second often is.
internal enum GaussianSolveFailure<T: Real> {
	/// The matrix had no rows.
	case emptyMatrix

	/// The matrix was not square. Carries the distinct row widths found, sorted.
	case notSquare(rows: Int, widths: [Int])

	/// The right-hand side did not match the matrix.
	case rightHandSideMismatch(expected: Int, actual: Int)

	/// Every entry was zero, so there is no scale to measure a pivot against.
	case noScale

	/// The best available pivot in this column was exactly zero.
	case singular(column: Int)

	/// The best available pivot was non-zero but below the criterion.
	case illConditioned(column: Int, pivot: T, threshold: T)

	/// Elimination succeeded and produced a non-finite component.
	case nonFiniteResult
}

/// The outcome of a solve: an answer, or the reason there is none.
///
/// Deliberately not `Result`. `Result`'s failure type must conform to `Error`, and under
/// Swift 6 `Error` inherits `Sendable` — which would force every caller's generic parameter
/// from `T: Real` to `T: Real & Sendable`. Tightening a constraint on a *public* generic
/// signature like ``solveLinearSystem(matrix:vector:)`` is source-breaking, and a
/// two-case enum costs nothing.
internal enum GaussianSolveOutcome<T: Real> {
	case solved([T])
	case failed(GaussianSolveFailure<T>)
}

/// What a solve is allowed to do and what it must refuse.
internal struct GaussianSolveOptions<T: Real> {
	/// How small a pivot has to be before the solve declines.
	var criterion: SingularityCriterion<T> = .scaleRelative

	/// Whether a non-finite component in the answer is a failure.
	///
	/// True for callers that treat "no solution" as an ordinary branch and would otherwise
	/// propagate an infinity into a probability or a chain. False for
	/// ``solveLinearSystem(matrix:vector:)``, which has never checked and whose published
	/// behaviour is not being changed here.
	var requireFiniteSolution: Bool = true

	init(criterion: SingularityCriterion<T> = .scaleRelative, requireFiniteSolution: Bool = true) {
		self.criterion = criterion
		self.requireFiniteSolution = requireFiniteSolution
	}
}

// `Real` does not imply `Sendable`, so these carry the guarantee only when the scalar
// does. Every concrete scalar in this package (`Double`, `Float`) is `Sendable`, so the
// conformance is available wherever it is actually wanted.
extension SingularityCriterion: Sendable where T: Sendable {}
extension GaussianSolveFailure: Sendable where T: Sendable {}
extension GaussianSolveOptions: Sendable where T: Sendable {}
extension GaussianSolveOutcome: Sendable where T: Sendable {}

// MARK: - The solve

/// Solves `A x = b` by Gaussian elimination with partial pivoting.
///
/// The package's single dense solve for small systems. Five call sites each carried their
/// own copy before this existed — `TransitionMatrix.solve` and
/// `LogisticRegression.solveSymmetric` identical to each other character for character,
/// `PercentileParameterisable.solveLinear` and `SimplexSolver`'s private helper at a fixed
/// `1e-12`, and ``solveLinearSystem(matrix:vector:)`` at a fixed `1e-9` — and nothing
/// compared them. **The same matrix could be called singular by one and solved by another:**
/// on `[[1e-10, 0], [0, 1]]`, whose exact solution is `[1, 1]`, four of the five solved it
/// and the fifth refused.
///
/// They still disagree, because three of those thresholds are defensible for their own
/// callers. What has changed is that the disagreement is now a parameter with a name
/// instead of a constant buried in five bodies.
///
/// - Parameters:
///   - matrix: The coefficient matrix `A`, square and matching `rhs`.
///   - rhs: The right-hand side `b`.
///   - options: The singularity criterion and finiteness policy. Defaults to the
///     scale-relative criterion and refusing non-finite answers.
///
/// - Returns: ``GaussianSolveOutcome/solved(_:)`` with `x`, or
///   ``GaussianSolveOutcome/failed(_:)`` with the reason none was produced.
///
/// - Complexity: O(n³).
internal func gaussianSolveDetailed<T: Real>(
	_ matrix: [[T]],
	_ rhs: [T],
	options: GaussianSolveOptions<T> = GaussianSolveOptions()
) -> GaussianSolveOutcome<T> {
	let n = matrix.count
	guard n > 0 else { return .failed(.emptyMatrix) }
	guard matrix.allSatisfy({ $0.count == n }) else {
		let widths = Set(matrix.map(\.count)).sorted()
		return .failed(.notSquare(rows: n, widths: widths))
	}
	guard rhs.count == n else {
		return .failed(.rightHandSideMismatch(expected: n, actual: rhs.count))
	}

	var a = matrix
	var b = rhs

	// The threshold, resolved once. The scale-relative form needs the largest magnitude
	// present, which is also how an all-zero matrix is detected.
	let threshold: T
	switch options.criterion {
	case .scaleRelative:
		var scale: T = T.zero
		for row in a {
			for value in row {
				let size: T = value < T.zero ? -value : value
				if size > scale { scale = size }
			}
		}
		guard scale > T.zero else { return .failed(.noScale) }
		threshold = scale * T.ulpOfOne * T(n * n)
	case .absolute(let fixed):
		threshold = fixed
	}

	for column in 0..<n {
		// Partial pivoting: take the largest available pivot in this column, which keeps
		// the multipliers at or below 1 and stops elimination amplifying rounding error.
		var pivotRow = column
		var best: T = T.zero
		for row in column..<n {
			let size: T = a[row][column] < T.zero ? -a[row][column] : a[row][column]
			if size > best { best = size; pivotRow = row }
		}

		// Exactly zero and merely small are different failures. A zero column is singular
		// in exact arithmetic and no rescaling helps; a tiny pivot is invertible in exact
		// arithmetic and fails only in floating point, so reformulating may succeed.
		guard best > T.zero else { return .failed(.singular(column: column)) }
		guard best > threshold else {
			return .failed(.illConditioned(column: column, pivot: best, threshold: threshold))
		}

		if pivotRow != column {
			a.swapAt(pivotRow, column)
			b.swapAt(pivotRow, column)
		}

		let pivot: T = a[column][column]
		for row in (column + 1)..<n {
			let factor: T = a[row][column] / pivot
			guard factor.isFinite else { return .failed(.nonFiniteResult) }
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
		guard pivot != T.zero else { return .failed(.singular(column: row)) }
		solution[row] = total / pivot
	}

	// A finite matrix can still produce a non-finite solution when the system is close
	// enough to singular that back substitution overflows. Callers that treat "no solution"
	// as an ordinary branch asked for a solution, not an infinity dressed as one.
	if options.requireFiniteSolution, !solution.allSatisfy({ $0.isFinite }) {
		return .failed(.nonFiniteResult)
	}
	return .solved(solution)
}

/// Solves `A x = b`, reporting failure as `nil`.
///
/// The form four of the five callers want: an absorbing chain with no transient states and
/// a design matrix with collinear columns are ordinary branches, not errors to propagate.
/// See ``gaussianSolveDetailed(_:_:options:)`` for why a solve declines and for the
/// criterion this uses.
///
/// - Complexity: O(n³).
internal func gaussianSolve<T: Real>(
	_ matrix: [[T]],
	_ rhs: [T],
	options: GaussianSolveOptions<T> = GaussianSolveOptions()
) -> [T]? {
	switch gaussianSolveDetailed(matrix, rhs, options: options) {
	case .solved(let solution): return solution
	case .failed: return nil
	}
}

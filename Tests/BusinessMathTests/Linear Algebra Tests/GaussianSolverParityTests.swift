//
//  GaussianSolverParityTests.swift
//  BusinessMathTests
//
//  The package carries five Gaussian-elimination solvers. Two of them were byte-for-byte
//  identical in logic and are being consolidated; this file pins what they do first, so
//  the consolidation is provably behaviour-preserving rather than assumed to be.
//

import Testing
import Numerics
@testable import BusinessMath

/// The two solvers that differed only in name, measured against each other.
///
/// `TransitionMatrix.solve` and `LogisticRegression.solveSymmetric` were separate copies of
/// the same routine — the same scale-relative singularity criterion, the same partial
/// pivoting, the same back substitution, the same finiteness guards. Nothing in either was
/// specialised to Markov chains or to a design matrix.
///
/// These expectations are written to hold for *both*, so they keep holding when both become
/// one call. The interesting cases are the ones where a solver has to decide rather than
/// compute: a singular matrix, a matrix that is near-singular but solvable, and a
/// right-hand side of the wrong length.
@Suite("Gaussian solver parity")
struct GaussianSolverParityTests {

	/// Every case is run through both solvers and their answers compared to each other as
	/// well as to the expected value, so a divergence fails loudly rather than quietly.
	private func bothSolvers(
		_ matrix: [[Double]],
		_ rhs: [Double]
	) -> (markov: [Double]?, logistic: [Double]?) {
		(TransitionMatrix<Double>.solve(matrix, rhs),
		 LogisticRegression<Double>.solveSymmetric(matrix, rhs))
	}

	private func expectAgreement(
		_ matrix: [[Double]],
		_ rhs: [Double],
		_ what: String,
		sourceLocation: SourceLocation = #_sourceLocation
	) -> [Double]? {
		let (markov, logistic) = bothSolvers(matrix, rhs)
		switch (markov, logistic) {
		case (nil, nil):
			return nil
		case let (m?, l?):
			#expect(m.count == l.count, "\(what): \(m.count) against \(l.count)", sourceLocation: sourceLocation)
			for (i, pair) in zip(m, l).enumerated() {
				#expect(pair.0.isEqual(to: pair.1),
						"\(what): component \(i) was \(pair.0) and \(pair.1)",
						sourceLocation: sourceLocation)
			}
			return m
		default:
			Issue.record("\(what): one solver returned nil and the other did not — \(String(describing: markov)) against \(String(describing: logistic))",
						 sourceLocation: sourceLocation)
			return nil
		}
	}

	@Test("A well-conditioned system solves, and both solvers give the same answer")
	func wellConditioned() throws {
		// 2x + y = 5, x + 3y = 10  ->  x = 1, y = 3
		let solution = try #require(expectAgreement([[2, 1], [1, 3]], [5, 10], "2x2"))
		#expect(abs(solution[0] - 1.0) < 1e-12, "x was \(solution[0])")
		#expect(abs(solution[1] - 3.0) < 1e-12, "y was \(solution[1])")
	}

	@Test("Pivoting is required when the leading entry is zero")
	func requiresPivoting() throws {
		// A zero pivot in position (0,0) is what partial pivoting exists for: without the
		// row swap this divides by zero rather than solving.
		let solution = try #require(expectAgreement([[0, 1], [1, 0]], [2, 3], "swap"))
		#expect(solution[0].isEqual(to: 3.0), "x was \(solution[0])")
		#expect(solution[1].isEqual(to: 2.0), "y was \(solution[1])")
	}

	@Test("An exactly singular matrix is refused rather than answered")
	func singularIsRefused() {
		// Row 2 is twice row 1: no unique solution exists.
		let (markov, logistic) = bothSolvers([[1, 2], [2, 4]], [3, 6])
		#expect(markov == nil, "the Markov solver answered a singular system")
		#expect(logistic == nil, "the logistic solver answered a singular system")
	}

	@Test("A near-singular but solvable system is accepted, and this is where the five solvers disagree")
	func nearSingularIsAccepted() throws {
		// The pivot here is 1e-10. Against the scale-relative criterion these two share —
		// `scale * .ulpOfOne * n²`, which is 8.88e-16 for this matrix — that is comfortably
		// solvable, and the exact answer [1, 1] is available.
		//
		// The same matrix is *refused* by `solveLinearSystem`, whose threshold is a fixed
		// 1e-9, and accepted by `ParameterSolve.solveLinear`, whose threshold is a fixed
		// 1e-12. Three criteria, three opinions, one matrix. Pinned here so that
		// consolidating these two does not quietly move the line.
		let solution = try #require(expectAgreement([[1e-10, 0], [0, 1]], [1e-10, 1], "near-singular"))
		#expect(solution[0].isEqual(to: 1.0), "x was \(solution[0])")
		#expect(solution[1].isEqual(to: 1.0), "y was \(solution[1])")
	}

	@Test("A right-hand side of the wrong length is refused")
	func dimensionMismatchIsRefused() {
		let (markov, logistic) = bothSolvers([[1, 2], [3, 4]], [1])
		#expect(markov == nil, "the Markov solver accepted a mismatched right-hand side")
		#expect(logistic == nil, "the logistic solver accepted a mismatched right-hand side")
	}

	@Test("An all-zero matrix has no scale to measure against and is refused")
	func zeroMatrixIsRefused() {
		let (markov, logistic) = bothSolvers([[0, 0], [0, 0]], [0, 0])
		#expect(markov == nil, "the Markov solver answered an all-zero system")
		#expect(logistic == nil, "the logistic solver answered an all-zero system")
	}

	/// The criterion is now a parameter, and the three in use disagree by design.
	///
	/// A pivot of `1e-10` in a matrix whose largest entry is 1. Before this was a parameter,
	/// the same matrix met four different constants buried in five function bodies and got
	/// two different answers depending on which one the caller happened to reach.
	@Test("The three singularity criteria give three verdicts on one matrix")
	func criteriaDisagreeByDesign() throws {
		let matrix: [[Double]] = [[1e-10, 0], [0, 1]]
		let rhs: [Double] = [1e-10, 1]

		// Scale-relative: threshold is 1 × .ulpOfOne × 4 ≈ 8.88e-16, far below the pivot.
		let relative = try #require(gaussianSolve(matrix, rhs), "the default criterion refused")
		#expect(relative[0].isEqual(to: 1.0), "x was \(relative[0])")
		#expect(relative[1].isEqual(to: 1.0), "y was \(relative[1])")

		// A fixed 1e-12, as `ParameterSolve` and `SimplexSolver` use: still below the pivot.
		let lenient = try #require(
			gaussianSolve(matrix, rhs, options: .init(criterion: .absolute(1e-12))),
			"the 1e-12 criterion refused")
		#expect(lenient[0].isEqual(to: 1.0), "x was \(lenient[0])")

		// A fixed 1e-9, as `solveLinearSystem` uses: above the pivot, so it refuses.
		let strict = gaussianSolve(matrix, rhs, options: .init(criterion: .absolute(1e-9)))
		#expect(strict == nil, "the 1e-9 criterion solved a system it should refuse")
	}

	/// The failure says which condition was met, which is what the public taxonomy needs.
	@Test("A refusal names the column and distinguishes zero from merely small")
	func failuresAreDistinguishable() {
		// An exactly zero column is singular however it is measured.
		switch gaussianSolveDetailed([[0.0, 0.0], [0.0, 1.0]], [1.0, 1.0]) {
		case .failed(.singular(let column)):
			#expect(column == 0, "the singular column was reported as \(column)")
		case .failed(let other):
			Issue.record("expected .singular, got \(other)")
		case .solved(let x):
			Issue.record("a singular system was solved: \(x)")
		}

		// A small-but-nonzero pivot is a different condition, and rescaling might fix it.
		let options = GaussianSolveOptions<Double>(criterion: .absolute(1e-9))
		switch gaussianSolveDetailed([[1e-10, 0.0], [0.0, 1.0]], [1e-10, 1.0], options: options) {
		case .failed(.illConditioned(let column, let pivot, let threshold)):
			#expect(column == 0, "the ill-conditioned column was \(column)")
			#expect(pivot.isEqual(to: 1e-10), "the pivot was \(pivot)")
			#expect(threshold.isEqual(to: 1e-9), "the threshold was \(threshold)")
		case .failed(let other):
			Issue.record("expected .illConditioned, got \(other)")
		case .solved(let x):
			Issue.record("an ill-conditioned system was solved: \(x)")
		}

		// Shape failures are separated from numerical ones, because a caller fixes them
		// differently — and `solveLinearSystem` publishes that distinction.
		switch gaussianSolveDetailed([[Double]](), [Double]()) {
		case .failed(.emptyMatrix): break
		default: Issue.record("an empty matrix was not reported as empty")
		}
		switch gaussianSolveDetailed([[1.0, 2.0], [3.0, 4.0]], [1.0]) {
		case .failed(.rightHandSideMismatch(let expected, let actual)):
			#expect(expected == 2 && actual == 1, "reported \(expected) against \(actual)")
		default: Issue.record("a mismatched right-hand side was not reported as one")
		}
	}

	@Test("A larger system still agrees component for component")
	func fourByFour() throws {
		let matrix: [[Double]] = [
			[4, -2, 1, 3],
			[-2, 5, -1, 1],
			[1, -1, 6, -2],
			[3, 1, -2, 7]
		]
		let rhs: [Double] = [6, 3, 4, 9]
		let solution = try #require(expectAgreement(matrix, rhs, "4x4"))

		// Verified by substitution rather than by a stored expected vector: multiplying the
		// matrix back through the solution must reproduce the right-hand side.
		for (row, expected) in zip(matrix, rhs) {
			let got = zip(row, solution).reduce(0.0) { $0 + $1.0 * $1.1 }
			#expect(abs(got - expected) < 1e-10, "row residual was \(got - expected)")
		}
	}
}

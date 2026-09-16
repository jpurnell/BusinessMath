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

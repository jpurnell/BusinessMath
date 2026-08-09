//
//  OptimizationErrorPrecisionTests.swift
//  BusinessMath
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Errors that name the actual condition.
///
/// `invalidInput` covers everything from a zero-length vector to a missing Metal function, which
/// means a caller who catches it learns nothing they can act on. Two conditions in the numerical
/// code are specific enough to deserve their own cases, and both are conditions a caller can
/// respond to differently: a dimension mismatch is a bug in the calling code, whereas numerical
/// instability is a property of the data and may be worth retrying at another scale.
@Suite("OptimizationError precision")
struct OptimizationErrorPrecisionTests {

	// MARK: - dimensionMismatch

	/// Two dimensions that disagree. Distinct from "a dimension is absent or nonsensical",
	/// which remains `invalidInput`.
	@Test("A right-hand side of the wrong length is a dimension mismatch")
	func vectorLengthMismatch() {
		let matrix: [[Double]] = [[2, 1], [1, 3]]
		let tooShort: [Double] = [1]

		#expect(throws: OptimizationError.self) {
			try solveLinearSystem(matrix: matrix, vector: tooShort)
		}
		#expect(isDimensionMismatch(try solveLinearSystem(matrix: matrix, vector: tooShort)))
	}

	@Test("A non-square matrix is a dimension mismatch")
	func nonSquareMatrix() {
		let ragged: [[Double]] = [[1, 2, 3], [4, 5, 6]]

		#expect(isDimensionMismatch(try invertMatrix(ragged)))
	}

	/// A row whose length disagrees with the matrix's own row count — the mismatch is internal
	/// to the argument, not between two arguments.
	@Test("An internally ragged matrix is a dimension mismatch, not merely invalid")
	func raggedRows() {
		let ragged: [[Double]] = [[1, 2], [3]]
		let vector: [Double] = [1, 2]

		#expect(isDimensionMismatch(try solveLinearSystem(matrix: ragged, vector: vector)))
	}

	/// The condition that is *not* a mismatch: nothing disagrees, the input is simply empty.
	@Test("An empty matrix stays invalidInput — nothing disagrees with anything")
	func emptyIsNotAMismatch() {
		let empty: [[Double]] = []
		let noValues: [Double] = []

		#expect(isInvalidInput(try solveLinearSystem(matrix: empty, vector: noValues)))
	}

	// MARK: - numericalInstability

	/// A pivot small enough that elimination would amplify rounding error past the point of
	/// meaning, but not zero. The matrix is invertible in exact arithmetic — its determinant here
	/// is 1.9e-12 — so it is the floating-point solve that cannot be trusted, and calling it
	/// "singular" is false.
	///
	/// Note the whole column must be small. Partial pivoting swaps a large entry into place, so
	/// `[[1e-12, 1], [1, 1]]` solves perfectly well: the guard fires on the largest available
	/// pivot, not on the diagonal entry as written.
	@Test("A near-zero pivot is instability, not singularity")
	func nearlySingularIsInstability() {
		let nearlySingular: [[Double]] = [[1e-12, 1], [1e-13, 2]]
		let vector: [Double] = [1, 2]

		#expect(isNumericalInstability(try solveLinearSystem(matrix: nearlySingular, vector: vector)))
	}

	/// And the genuinely singular case must keep saying so — the split is only worth making if
	/// both sides stay accurate.
	@Test("An exactly singular matrix is still singularMatrix")
	func exactlySingularStaysSingular() {
		let singular: [[Double]] = [[0, 0], [1, 1]]
		let vector: [Double] = [1, 2]

		#expect(isSingularMatrix(try solveLinearSystem(matrix: singular, vector: vector)))
	}

	/// A well-conditioned system must not trip either guard.
	@Test("A well-conditioned system still solves")
	func wellConditionedStillSolves() throws {
		let matrix: [[Double]] = [[2, 1], [1, 3]]
		let vector: [Double] = [5, 10]

		let solution = try solveLinearSystem(matrix: matrix, vector: vector)

		#expect(abs(solution[0] - 1.0) < 1e-9)
		#expect(abs(solution[1] - 3.0) < 1e-9)
	}

	// MARK: - Classification helpers

	private func classify<T>(_ body: @autoclosure () throws -> T) -> OptimizationError? {
		do { _ = try body(); return nil } catch let error as OptimizationError { return error }
		catch { return nil }
	}

	private func isDimensionMismatch<T>(_ body: @autoclosure () throws -> T) -> Bool {
		if case .dimensionMismatch = classify(try body()) { return true }
		return false
	}

	private func isNumericalInstability<T>(_ body: @autoclosure () throws -> T) -> Bool {
		if case .numericalInstability = classify(try body()) { return true }
		return false
	}

	private func isSingularMatrix<T>(_ body: @autoclosure () throws -> T) -> Bool {
		if case .singularMatrix = classify(try body()) { return true }
		return false
	}

	private func isInvalidInput<T>(_ body: @autoclosure () throws -> T) -> Bool {
		if case .invalidInput = classify(try body()) { return true }
		return false
	}
}

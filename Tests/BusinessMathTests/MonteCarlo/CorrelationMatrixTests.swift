//
//  CorrelationMatrixTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
import Numerics
import OSLog

@testable import BusinessMath

@Suite("Correlation Matrix Validation Tests")
struct CorrelationMatrixTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.CorrelationMatrixTests", category: #function)

	@Test("Valid 2x2 correlation matrix")
	func validTwoByTwo() {
		// Perfect correlation matrix
		let matrix = [
			[1.0, 0.5],
			[0.5, 1.0]
		]

		#expect(isValidCorrelationMatrix(matrix), "Valid 2x2 correlation matrix should be accepted")
	}

	@Test("Valid 3x3 correlation matrix")
	func validThreeByThree() {
		// Valid correlation matrix with varying correlations
		let matrix = [
			[1.0, 0.8, 0.3],
			[0.8, 1.0, 0.5],
			[0.3, 0.5, 1.0]
		]

		#expect(isValidCorrelationMatrix(matrix), "Valid 3x3 correlation matrix should be accepted")
	}

	@Test("Identity matrix is valid")
	func identityMatrix() {
		// No correlation (identity matrix)
		let matrix = [
			[1.0, 0.0, 0.0],
			[0.0, 1.0, 0.0],
			[0.0, 0.0, 1.0]
		]

		#expect(isValidCorrelationMatrix(matrix), "Identity matrix should be valid")
	}

	@Test("Reject non-square matrix")
	func nonSquareMatrix() {
		let matrix = [
			[1.0, 0.5],
			[0.5, 1.0],
			[0.3, 0.4]
		]

		#expect(!isValidCorrelationMatrix(matrix), "Non-square matrix should be rejected")
	}

	@Test("Reject asymmetric matrix")
	func asymmetricMatrix() {
		// Not symmetric
		let matrix = [
			[1.0, 0.5],
			[0.3, 1.0]  // Should be 0.5
		]

		#expect(!isValidCorrelationMatrix(matrix), "Asymmetric matrix should be rejected")
	}

	@Test("Reject matrix with wrong diagonal")
	func wrongDiagonal() {
		// Diagonal not all 1.0
		let matrix = [
			[1.0, 0.5],
			[0.5, 0.9]  // Should be 1.0
		]

		#expect(!isValidCorrelationMatrix(matrix), "Matrix with non-1.0 diagonal should be rejected")
	}

	@Test("Reject matrix with out-of-range values")
	func outOfRangeValues() {
		// Correlation > 1.0
		let matrix = [
			[1.0, 1.5],
			[1.5, 1.0]
		]

		#expect(!isValidCorrelationMatrix(matrix), "Matrix with values > 1.0 should be rejected")
	}

	@Test("Reject negative correlation > -1")
	func tooNegativeCorrelation() {
		// Correlation < -1.0
		let matrix = [
			[1.0, -1.5],
			[-1.5, 1.0]
		]

		#expect(!isValidCorrelationMatrix(matrix), "Matrix with values < -1.0 should be rejected")
	}

	@Test("Reject perfect negative correlation (singular matrix)")
	func perfectNegativeCorrelation() {
		// Perfect negative correlation creates a singular matrix (determinant = 0)
		// This is not positive definite, so should be rejected
		let matrix = [
			[1.0, -1.0],
			[-1.0, 1.0]
		]

		#expect(!isValidCorrelationMatrix(matrix), "Perfect negative correlation (singular) should be rejected")
	}

	@Test("Accept strong negative correlation")
	func strongNegativeCorrelation() {
		// Strong but not perfect negative correlation is valid
		let matrix = [
			[1.0, -0.9],
			[-0.9, 1.0]
		]

		#expect(isValidCorrelationMatrix(matrix), "Strong negative correlation (-0.9) should be valid")
	}

	@Test("Reject non-positive-definite matrix")
	func nonPositiveDefinite() {
		// This matrix is not positive semi-definite
		// It has an impossible correlation structure
		let matrix = [
			[1.0, 0.9, 0.9],
			[0.9, 1.0, -0.9],
			[0.9, -0.9, 1.0]
		]

		#expect(!isValidCorrelationMatrix(matrix), "Non-positive-definite matrix should be rejected")
	}

	@Test("Accept large valid matrix")
	func largeValidMatrix() {
		// 5x5 correlation matrix
		let matrix = [
			[1.0, 0.7, 0.5, 0.3, 0.2],
			[0.7, 1.0, 0.6, 0.4, 0.3],
			[0.5, 0.6, 1.0, 0.5, 0.4],
			[0.3, 0.4, 0.5, 1.0, 0.6],
			[0.2, 0.3, 0.4, 0.6, 1.0]
		]

		#expect(isValidCorrelationMatrix(matrix), "Large valid correlation matrix should be accepted")
	}

	@Test("Reject empty matrix")
	func emptyMatrix() {
		let matrix: [[Double]] = []

		#expect(!isValidCorrelationMatrix(matrix), "Empty matrix should be rejected")
	}

	@Test("Accept 1x1 matrix")
	func singleElementMatrix() {
		let matrix = [[1.0]]

		#expect(isValidCorrelationMatrix(matrix), "1x1 matrix with 1.0 should be valid")
	}

	@Test("Check correlation matrix symmetry")
	func checkSymmetry() {
		let symmetric = [
			[1.0, 0.5, 0.3],
			[0.5, 1.0, 0.7],
			[0.3, 0.7, 1.0]
		]

		#expect(isSymmetric(symmetric), "Symmetric matrix should be detected")

		let asymmetric = [
			[1.0, 0.5, 0.3],
			[0.5, 1.0, 0.7],
			[0.4, 0.7, 1.0]  // 0.4 != 0.3
		]

		#expect(!isSymmetric(asymmetric), "Asymmetric matrix should be detected")
	}

	@Test("Check positive definite property")
	func checkPositiveDefinite() {
		// Valid correlation matrix (positive definite)
		let valid = [
			[1.0, 0.5],
			[0.5, 1.0]
		]

		#expect(isPositiveSemiDefinite(valid), "Valid correlation matrix should be positive definite")

		// Invalid - creates negative eigenvalue
		let invalid = [
			[1.0, 0.9, 0.9],
			[0.9, 1.0, -0.9],
			[0.9, -0.9, 1.0]
		]

		#expect(!isPositiveSemiDefinite(invalid), "Invalid correlation structure should not be positive definite")
	}
}

@Suite("Correlation Matrix Validation – Additional")
struct CorrelationMatrixAdditionalTests {

	@Test("Reject perfect positive correlation (singular matrix)")
	func perfectPositiveCorrelation() {
		let matrix = [
			[1.0, 1.0],
			[1.0, 1.0]
		]
		#expect(!isValidCorrelationMatrix(matrix), "Perfect positive correlation should be rejected if PD required")
	}

	@Test("Reject matrices with NaN or Inf")
	func rejectNonFinite() {
		let withNaN = [
			[1.0, Double.nan],
			[0.5, 1.0]
		]
		let withInf = [
			[1.0, .infinity],
			[0.5, 1.0]
		]

		#expect(!isValidCorrelationMatrix(withNaN), "NaN in matrix should be rejected")
		#expect(!isValidCorrelationMatrix(withInf), "Inf in matrix should be rejected")
	}

	@Test("Reject ragged (jagged) matrices")
	func rejectRagged() {
		let ragged = [
			[1.0, 0.5, 0.1],
			[0.5, 1.0]  // shorter row
		]
		#expect(!isValidCorrelationMatrix(ragged), "Ragged matrix should be rejected")
	}

	@Test("Reject slightly out-of-bounds correlations")
	func outOfBoundsByEpsilon() {
		let tooLarge = [
			[1.0, 1.0000001],
			[1.0000001, 1.0]
		]
		let tooSmall = [
			[1.0, -1.0000001],
			[-1.0000001, 1.0]
		]
		#expect(!isValidCorrelationMatrix(tooLarge), "Values > 1 should be rejected even if slightly")
		#expect(!isValidCorrelationMatrix(tooSmall), "Values < -1 should be rejected even if slightly")
	}
}

//
//  NumericalDifferentiationTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/03/25.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Numerical Differentiation Tests")
struct NumericalDifferentiationTests {

	// MARK: - Gradient Tests

	@Test("Gradient of quadratic function")
	func gradientQuadratic() throws {
		// f(x, y) = x² + y²
		// ∇f = [2x, 2y]
		let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let point = VectorN([3.0, 4.0])
		let gradient = try numericalGradient(quadratic, at: point)

		// Expected: [2*3, 2*4] = [6, 8]
		let expected = VectorN([6.0, 8.0])
		let tolerance = 1e-6

		#expect(abs(gradient[0] - expected[0]) < tolerance, "Gradient x-component should be 6.0")
		#expect(abs(gradient[1] - expected[1]) < tolerance, "Gradient y-component should be 8.0")
	}

	@Test("Gradient at minimum")
	func gradientAtMinimum() throws {
		// f(x, y) = x² + y²
		// At (0, 0), ∇f = [0, 0]
		let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let minimum = VectorN([0.0, 0.0])
		let gradient = try numericalGradient(quadratic, at: minimum)

		let tolerance = 1e-6
		#expect(abs(gradient[0]) < tolerance, "Gradient should be zero at minimum")
		#expect(abs(gradient[1]) < tolerance, "Gradient should be zero at minimum")
	}

	@Test("Gradient of Rosenbrock function")
	func gradientRosenbrock() throws {
		// Rosenbrock: f(x, y) = (1-x)² + 100(y-x²)²
		// ∇f = [-2(1-x) - 400x(y-x²), 200(y-x²)]
		let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			let term1 = (1 - x) * (1 - x)
			let term2 = 100 * (y - x*x) * (y - x*x)
			return term1 + term2
		}

		// At (1, 1), the minimum, gradient should be ~[0, 0]
		let minimum = VectorN([1.0, 1.0])
		let gradient = try numericalGradient(rosenbrock, at: minimum)

		let tolerance = 1e-4
		#expect(abs(gradient[0]) < tolerance, "Gradient x should be near zero at minimum")
		#expect(abs(gradient[1]) < tolerance, "Gradient y should be near zero at minimum")
	}

	@Test("Gradient of 3D function")
	func gradient3D() throws {
		// f(x, y, z) = x² + 2y² + 3z²
		// ∇f = [2x, 4y, 6z]
		let function3D: @Sendable (VectorN<Double>) -> Double = { v in
			v[0]*v[0] + 2*v[1]*v[1] + 3*v[2]*v[2]
		}

		let point = VectorN([1.0, 2.0, 3.0])
		let gradient = try numericalGradient(function3D, at: point)

		// Expected: [2*1, 4*2, 6*3] = [2, 8, 18]
		let tolerance = 1e-5
		#expect(abs(gradient[0] - 2.0) < tolerance)
		#expect(abs(gradient[1] - 8.0) < tolerance)
		#expect(abs(gradient[2] - 18.0) < tolerance)
	}

	@Test("Gradient with Vector2D")
	func gradientVector2D() throws {
		// Test with specialized Vector2D type
		let quadratic: (Vector2D<Double>) -> Double = { v in
			v.x * v.x + v.y * v.y
		}

		let point = Vector2D(x: 5.0, y: 12.0)
		let gradient = try numericalGradient(quadratic, at: point)

		// Expected: [10, 24]
		let tolerance = 1e-5
		#expect(abs(gradient.x - 10.0) < tolerance)
		#expect(abs(gradient.y - 24.0) < tolerance)
	}

	// MARK: - Hessian Tests

	@Test("Hessian of quadratic function")
	func hessianQuadratic() throws {
		// f(x, y) = x² + y²
		// H = [[2, 0], [0, 2]]
		let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let point = VectorN([1.0, 2.0])
		let hessian = try numericalHessian(quadratic, at: point)

		let tolerance = 1e-4
		#expect(abs(hessian[0][0] - 2.0) < tolerance, "H[0,0] should be 2")
		#expect(abs(hessian[0][1] - 0.0) < tolerance, "H[0,1] should be 0")
		#expect(abs(hessian[1][0] - 0.0) < tolerance, "H[1,0] should be 0")
		#expect(abs(hessian[1][1] - 2.0) < tolerance, "H[1,1] should be 2")
	}

	@Test("Hessian with mixed partials")
	func hessianMixedPartials() throws {
		// f(x, y) = xy
		// H = [[0, 1], [1, 0]]
		let bilinear: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] * v[1]
		}

		let point = VectorN([2.0, 3.0])
		let hessian = try numericalHessian(bilinear, at: point)

		let tolerance = 1e-4
		#expect(abs(hessian[0][0] - 0.0) < tolerance, "H[0,0] should be 0")
		#expect(abs(hessian[0][1] - 1.0) < tolerance, "H[0,1] should be 1")
		#expect(abs(hessian[1][0] - 1.0) < tolerance, "H[1,0] should be 1")
		#expect(abs(hessian[1][1] - 0.0) < tolerance, "H[1,1] should be 0")
	}

	@Test("Hessian symmetry")
	func hessianSymmetry() throws {
		// Hessian should always be symmetric
		let function: @Sendable (VectorN<Double>) -> Double = { v in
			v[0]*v[0]*v[1] + v[1]*v[1]*v[2]
		}

		let point = VectorN([1.0, 2.0, 3.0])
		let hessian = try numericalHessian(function, at: point)

		let tolerance = 1e-6
		for i in 0..<3 {
			for j in i+1..<3 {
				#expect(abs(hessian[i][j] - hessian[j][i]) < tolerance,
					   "Hessian should be symmetric: H[\(i),\(j)] = H[\(j),\(i)]")
			}
		}
	}

	@Test("Hessian of 3D quadratic form")
	func hessian3DQuadratic() throws {
		// f(x, y, z) = x² + 2y² + 3z²
		// H = [[2, 0, 0], [0, 4, 0], [0, 0, 6]]
		let function: @Sendable (VectorN<Double>) -> Double = { v in
			v[0]*v[0] + 2*v[1]*v[1] + 3*v[2]*v[2]
		}

		let point = VectorN([0.0, 0.0, 0.0])
		let hessian = try numericalHessian(function, at: point)

		let expected = [[2.0, 0.0, 0.0],
						[0.0, 4.0, 0.0],
						[0.0, 0.0, 6.0]]

		let tolerance = 1e-3
		for i in 0..<3 {
			for j in 0..<3 {
				#expect(abs(hessian[i][j] - expected[i][j]) < tolerance,
					   "H[\(i),\(j)] should be \(expected[i][j])")
			}
		}
	}

	// MARK: - Matrix Utilities Tests

	@Test("Solve 2x2 linear system")
	func solveLinearSystem2x2() throws {
		// Solve: 2x + 3y = 13
		//        4x - y = 5
		// Solution: x = 2, y = 3
		let matrix = [[2.0, 3.0],
					  [4.0, -1.0]]
		let vector = [13.0, 5.0]

		let solution = try solveLinearSystem(matrix: matrix, vector: vector)

		let tolerance = 1e-10
		#expect(abs(solution[0] - 2.0) < tolerance, "x should be 2")
		#expect(abs(solution[1] - 3.0) < tolerance, "y should be 3")
	}

	@Test("Solve 3x3 linear system")
	func solveLinearSystem3x3() throws {
		// Solve: x + 2y + 3z = 14
		//        2x + y + z = 7
		//        3x + y + 2z = 11
		// Solution: x = 1, y = 2, z = 3
		let matrix = [[1.0, 2.0, 3.0],
					  [2.0, 1.0, 1.0],
					  [3.0, 1.0, 2.0]]
		let vector = [14.0, 7.0, 11.0]

		let solution = try solveLinearSystem(matrix: matrix, vector: vector)

		let tolerance = 1e-10
		#expect(abs(solution[0] - 1.0) < tolerance, "x should be 1")
		#expect(abs(solution[1] - 2.0) < tolerance, "y should be 2")
		#expect(abs(solution[2] - 3.0) < tolerance, "z should be 3")
	}

	@Test("Invert 2x2 matrix")
	func invertMatrix2x2() throws {
		// A = [[4, 7], [2, 6]]
		// A⁻¹ = [[0.6, -0.7], [-0.2, 0.4]]
		let matrix = [[4.0, 7.0],
					  [2.0, 6.0]]

		let inverse = try invertMatrix(matrix)

		let expectedInverse = [[0.6, -0.7],
							   [-0.2, 0.4]]

		let tolerance = 1e-10
		for i in 0..<2 {
			for j in 0..<2 {
				#expect(abs(inverse[i][j] - expectedInverse[i][j]) < tolerance,
					   "Inverse[\(i),\(j)] should be \(expectedInverse[i][j])")
			}
		}
	}

	@Test("Invert 3x3 identity matrix")
	func invertIdentity() throws {
		let identity = [[1.0, 0.0, 0.0],
						[0.0, 1.0, 0.0],
						[0.0, 0.0, 1.0]]

		let inverse = try invertMatrix(identity)

		let tolerance = 1e-10
		for i in 0..<3 {
			for j in 0..<3 {
				let expected = i == j ? 1.0 : 0.0
				#expect(abs(inverse[i][j] - expected) < tolerance,
					   "Identity inverse should be identity")
			}
		}
	}

	@Test("Matrix inversion verification")
	func matrixInversionVerification() throws {
		// Verify that A * A⁻¹ = I
		let matrix = [[2.0, 1.0],
					  [5.0, 3.0]]

		let inverse = try invertMatrix(matrix)

		// Multiply A * A⁻¹
		var product = [[0.0, 0.0], [0.0, 0.0]]
		for i in 0..<2 {
			for j in 0..<2 {
				for k in 0..<2 {
					product[i][j] += matrix[i][k] * inverse[k][j]
				}
			}
		}

		let tolerance = 1e-10
		for i in 0..<2 {
			for j in 0..<2 {
				let expected = i == j ? 1.0 : 0.0
				#expect(abs(product[i][j] - expected) < tolerance,
					   "A * A⁻¹ should be identity")
			}
		}
	}

	// MARK: - Error Handling Tests

	@Test("Gradient with non-finite values throws")
	func gradientNonFinite() {
		let badFunction: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] == 0 ? .infinity : v[0]
		}

		let point = VectorN([0.0, 1.0])

		#expect(throws: OptimizationError.self) {
			_ = try numericalGradient(badFunction, at: point)
		}
	}

	@Test("Singular matrix throws")
	func singularMatrix() {
		// Singular matrix (rows are linearly dependent)
		let singular = [[1.0, 2.0],
						[2.0, 4.0]]
		let vector = [1.0, 2.0]

		#expect(throws: OptimizationError.self) {
			_ = try solveLinearSystem(matrix: singular, vector: vector)
		}
	}

	// MARK: - Integration Tests

	@Test("Gradient and Hessian consistency")
	func gradientHessianConsistency() throws {
		// For a quadratic function, the Hessian should be constant
		// and the gradient should increase linearly
		let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
			v[0]*v[0] + v[1]*v[1]
		}

		let point1 = VectorN([1.0, 1.0])
		let point2 = VectorN([2.0, 3.0])

		let hessian1 = try numericalHessian(quadratic, at: point1)
		let hessian2 = try numericalHessian(quadratic, at: point2)

		// Hessian should be the same at both points
		let tolerance = 1e-3
		for i in 0..<2 {
			for j in 0..<2 {
				#expect(abs(hessian1[i][j] - hessian2[i][j]) < tolerance,
					   "Hessian should be constant for quadratic")
			}
		}
	}

	@Test("Numerical gradient for portfolio variance")
	func portfolioVarianceGradient() throws {
		// Portfolio variance: σ² = w'Σw where Σ is covariance matrix
		let covariance = [[0.04, 0.01],
						  [0.01, 0.09]]  // 2x2 covariance matrix

		let portfolioVariance: (VectorN<Double>) -> Double = { weights in
			let w = weights.toArray()
			var variance = 0.0
			for i in 0..<2 {
				for j in 0..<2 {
					variance += w[i] * covariance[i][j] * w[j]
				}
			}
			return variance
		}

		let weights = VectorN([0.6, 0.4])
		let gradient = try numericalGradient(portfolioVariance, at: weights)

		// Gradient of w'Σw is 2Σw (for symmetric Σ)
		let expectedGrad0 = 2 * (covariance[0][0] * 0.6 + covariance[0][1] * 0.4)
		let expectedGrad1 = 2 * (covariance[1][0] * 0.6 + covariance[1][1] * 0.4)

		let tolerance = 1e-5
		#expect(abs(gradient[0] - expectedGrad0) < tolerance)
		#expect(abs(gradient[1] - expectedGrad1) < tolerance)
	}
}

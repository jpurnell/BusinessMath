//
//  NumericalDifferentiation.swift
//  BusinessMath
//
//  Created by Claude Code on 12/03/25.
//

import Foundation
import Numerics

// MARK: - Numerical Differentiation for VectorSpace Types

/// Computes the gradient of a scalar function using central finite differences.
///
/// The gradient ∇f at point x is approximated using:
/// ```
/// ∂f/∂xᵢ ≈ [f(x + εeᵢ) - f(x - εeᵢ)] / (2ε)
/// ```
/// where eᵢ is the i-th unit vector.
///
/// ## Example
/// ```swift
/// // Minimize f(x,y) = x² + y²
/// let rosenbrock: (VectorN<Double>) -> Double = { v in
///     let x = v[0], y = v[1]
///     return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
/// }
///
/// let point = VectorN([1.0, 1.0])
/// let grad = try numericalGradient(rosenbrock, at: point)
/// // grad ≈ [0, 0] at the minimum
/// ```
///
/// - Parameters:
///   - function: The scalar-valued function f: V → ℝ
///   - point: The point at which to compute the gradient
///   - epsilon: Step size for finite differences (default: 1e-6)
/// - Returns: The gradient vector ∇f(point)
/// - Throws: `OptimizationError` if the function is not differentiable or computation fails
public func numericalGradient<V: VectorSpace>(
	_ function: (V) -> V.Scalar,
	at point: V,
	epsilon: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000)
) throws -> V where V.Scalar: Real {
	// Convert point to array for easier manipulation
	let components = point.toArray()
	let dimension = components.count

	guard dimension > 0 else {
		throw OptimizationError.invalidInput(message: "Point has zero dimensions")
	}

	// Compute gradient components
	var gradientComponents: [V.Scalar] = []
	gradientComponents.reserveCapacity(dimension)

	for i in 0..<dimension {
		// Create points x + εeᵢ and x - εeᵢ
		var forwardComponents = components
		var backwardComponents = components

		forwardComponents[i] = forwardComponents[i] + epsilon
		backwardComponents[i] = backwardComponents[i] - epsilon

		guard let forwardPoint = V.fromArray(forwardComponents),
			  let backwardPoint = V.fromArray(backwardComponents) else {
			throw OptimizationError.invalidInput(message: "Failed to construct perturbation points")
		}

		// Central difference: [f(x+ε) - f(x-ε)] / 2ε
		let forwardValue = function(forwardPoint)
		let backwardValue = function(backwardPoint)

		// Check for non-finite values
		guard forwardValue.isFinite && backwardValue.isFinite else {
			throw OptimizationError.nonFiniteValue(message: "Function returned non-finite value at point")
		}

		let derivative = (forwardValue - backwardValue) / (V.Scalar(2) * epsilon)
		gradientComponents.append(derivative)
	}

	guard let gradient = V.fromArray(gradientComponents) else {
		throw OptimizationError.invalidInput(message: "Failed to construct gradient vector")
	}

	return gradient
}

/// Computes the Hessian matrix (second derivatives) of a scalar function using finite differences.
///
/// The Hessian H[i,j] = ∂²f/∂xᵢ∂xⱼ is approximated using:
/// ```
/// ∂²f/∂xᵢ∂xⱼ ≈ [f(x+εeᵢ+εeⱼ) - f(x+εeᵢ-εeⱼ) - f(x-εeᵢ+εeⱼ) + f(x-εeᵢ-εeⱼ)] / (4ε²)
/// ```
///
/// ## Example
/// ```swift
/// // For f(x,y) = x² + y², the Hessian is [[2, 0], [0, 2]]
/// let quadratic: (VectorN<Double>) -> Double = { v in
///     v[0]*v[0] + v[1]*v[1]
/// }
///
/// let point = VectorN([0.0, 0.0])
/// let hessian = try numericalHessian(quadratic, at: point)
/// // hessian ≈ [[2.0, 0.0], [0.0, 2.0]]
/// ```
///
/// - Parameters:
///   - function: The scalar-valued function f: V → ℝ
///   - point: The point at which to compute the Hessian
///   - epsilon: Step size for finite differences (default: 1e-5)
/// - Returns: The Hessian matrix as a 2D array H[i][j]
/// - Throws: `OptimizationError` if computation fails
public func numericalHessian<V: VectorSpace>(
	_ function: (V) -> V.Scalar,
	at point: V,
	epsilon: V.Scalar = V.Scalar(1) / V.Scalar(100_000)
) throws -> [[V.Scalar]] where V.Scalar: Real {
	let components = point.toArray()
	let dimension = components.count

	guard dimension > 0 else {
		throw OptimizationError.invalidInput(message: "Point has zero dimensions")
	}

	// Initialize Hessian matrix
	var hessian: [[V.Scalar]] = Array(repeating: Array(repeating: V.Scalar(0), count: dimension), count: dimension)

	// Compute Hessian elements
	for i in 0..<dimension {
		for j in i..<dimension {  // Symmetric matrix, only compute upper triangle
			if i == j {
				// Diagonal elements: ∂²f/∂xᵢ² ≈ [f(x+2εeᵢ) - 2f(x) + f(x-2εeᵢ)] / (4ε²)
				var forwardComponents = components
				var backwardComponents = components

				forwardComponents[i] = forwardComponents[i] + epsilon
				backwardComponents[i] = backwardComponents[i] - epsilon

				guard let forwardPoint = V.fromArray(forwardComponents),
					  let backwardPoint = V.fromArray(backwardComponents) else {
					throw OptimizationError.invalidInput(message: "Failed to construct perturbation points")
				}

				let forwardValue = function(forwardPoint)
				let centerValue = function(point)
				let backwardValue = function(backwardPoint)

				guard forwardValue.isFinite && centerValue.isFinite && backwardValue.isFinite else {
					throw OptimizationError.nonFiniteValue(message: "Function returned non-finite value")
				}

				let secondDerivative = (forwardValue - V.Scalar(2) * centerValue + backwardValue) / (epsilon * epsilon)
				hessian[i][i] = secondDerivative
			} else {
				// Off-diagonal elements: ∂²f/∂xᵢ∂xⱼ using four-point formula
				var ppComponents = components  // x + εeᵢ + εeⱼ
				var pmComponents = components  // x + εeᵢ - εeⱼ
				var mpComponents = components  // x - εeᵢ + εeⱼ
				var mmComponents = components  // x - εeᵢ - εeⱼ

				ppComponents[i] += epsilon
				ppComponents[j] += epsilon

				pmComponents[i] += epsilon
				pmComponents[j] -= epsilon

				mpComponents[i] -= epsilon
				mpComponents[j] += epsilon

				mmComponents[i] -= epsilon
				mmComponents[j] -= epsilon

				guard let ppPoint = V.fromArray(ppComponents),
					  let pmPoint = V.fromArray(pmComponents),
					  let mpPoint = V.fromArray(mpComponents),
					  let mmPoint = V.fromArray(mmComponents) else {
					throw OptimizationError.invalidInput(message: "Failed to construct perturbation points")
				}

				let fpp = function(ppPoint)
				let fpm = function(pmPoint)
				let fmp = function(mpPoint)
				let fmm = function(mmPoint)

				guard fpp.isFinite && fpm.isFinite && fmp.isFinite && fmm.isFinite else {
					throw OptimizationError.nonFiniteValue(message: "Function returned non-finite value")
				}

				let mixedDerivative = (fpp - fpm - fmp + fmm) / (V.Scalar(4) * epsilon * epsilon)
				hessian[i][j] = mixedDerivative
				hessian[j][i] = mixedDerivative  // Symmetric
			}
		}
	}

	return hessian
}

// MARK: - Matrix Utilities

/// Solves a linear system Ax = b using Gaussian elimination with partial pivoting.
///
/// - Parameters:
///   - matrix: The coefficient matrix A (n×n)
///   - vector: The right-hand side vector b (n×1)
/// - Returns: The solution vector x
/// - Throws: `OptimizationError` if the matrix is singular or computation fails
public func solveLinearSystem<T: Real>(
	matrix: [[T]],
	vector: [T]
) throws -> [T] {
	let n = matrix.count
	guard n > 0, matrix.allSatisfy({ $0.count == n }), vector.count == n else {
		throw OptimizationError.invalidInput(message: "Matrix dimensions inconsistent")
	}

	// Create augmented matrix [A|b]
	var augmented = matrix.map { row in row }
	for i in 0..<n {
		augmented[i].append(vector[i])
	}

	// Forward elimination with partial pivoting
	for col in 0..<n {
		// Find pivot
		var maxRow = col
		var maxVal = abs(augmented[col][col])
		for row in (col+1)..<n {
			let val = abs(augmented[row][col])
			if val > maxVal {
				maxVal = val
				maxRow = row
			}
		}

		// Check for singular matrix
		if maxVal < T(1) / T(1_000_000_000) {  // Essentially zero
			throw OptimizationError.singularMatrix(message: "Matrix is singular or nearly singular")
		}

		// Swap rows if needed
		if maxRow != col {
			augmented.swapAt(col, maxRow)
		}

		// Eliminate below
		for row in (col+1)..<n {
			let factor = augmented[row][col] / augmented[col][col]
			for j in col...n {
				augmented[row][j] = augmented[row][j] - factor * augmented[col][j]
			}
		}
	}

	// Back substitution
	var solution = Array(repeating: T(0), count: n)
	for i in stride(from: n-1, through: 0, by: -1) {
		var sum = augmented[i][n]
		for j in (i+1)..<n {
			sum = sum - augmented[i][j] * solution[j]
		}
		solution[i] = sum / augmented[i][i]
	}

	return solution
}

/// Inverts a matrix using Gaussian elimination.
///
/// - Parameter matrix: The matrix to invert (n×n)
/// - Returns: The inverse matrix
/// - Throws: `OptimizationError` if the matrix is singular
public func invertMatrix<T: Real>(_ matrix: [[T]]) throws -> [[T]] {
	let n = matrix.count
	guard n > 0, matrix.allSatisfy({ $0.count == n }) else {
		throw OptimizationError.invalidInput(message: "Matrix must be square")
	}

	// Create identity matrix
	var identity = Array(repeating: Array(repeating: T(0), count: n), count: n)
	for i in 0..<n {
		identity[i][i] = T(1)
	}

	// Solve for each column of the inverse
	var inverse = Array(repeating: Array(repeating: T(0), count: n), count: n)
	for col in 0..<n {
		let column = try solveLinearSystem(matrix: matrix, vector: identity[col])
		for row in 0..<n {
			inverse[row][col] = column[row]
		}
	}

	return inverse
}

// OptimizationError is defined in Sources/BusinessMath/Valuation/Debt/BondPricing.swift

//
//  NumericalDifferentiation.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/03/25.
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
/// let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
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
		// The step is **relative to the coordinate**, not absolute.
		//
		// A double's spacing at magnitude `m` is about `m · 2⁻⁵²`, so a fixed step smaller than
		// that gap cannot move the value at all: `x + epsilon == x`, both evaluations return the
		// same number, and the derivative comes back as exactly zero. Measured on `f(x) = x²`
		// with the old absolute step, against the exact `2x`: correct to 1e6, 4% low at 1e9, 64%
		// high at 1e10, and **exactly zero from 1e12 upward**.
		//
		// Zero is the worst possible wrong answer here, because every gradient method reads it
		// as a stationary point. `MultivariateGradientDescent` on Rosenbrock reached 6.6e25 in
		// five iterations, took a zero gradient there, and returned an objective of 1e105
		// labelled `.converged`.
		//
		// `max(1, |xᵢ|)` rather than `|xᵢ|` so the step stays finite at the origin, where a
		// purely relative step would be zero.
		let magnitude: V.Scalar = components[i] < V.Scalar(0) ? -components[i] : components[i]
		let scale: V.Scalar = V.Scalar.maximum(V.Scalar(1), magnitude)
		let step: V.Scalar = epsilon * scale

		var forwardComponents = components
		var backwardComponents = components

		forwardComponents[i] = forwardComponents[i] + step
		backwardComponents[i] = backwardComponents[i] - step

		guard let forwardPoint = V.fromArray(forwardComponents),
			  let backwardPoint = V.fromArray(backwardComponents) else {
			throw OptimizationError.invalidInput(message: "Failed to construct perturbation points")
		}

		// Divide by the step the arithmetic actually took, not the one that was asked for.
		//
		// `x + step` is rounded to the nearest representable value, so the realised separation
		// differs from `2 · step` by up to an ulp. Reading it back removes that discrepancy from
		// the quotient exactly, rather than leaving it as an error term that grows with `|x|`.
		let realisedSpan: V.Scalar = forwardComponents[i] - backwardComponents[i]

		// Central difference: [f(x+h) - f(x-h)] / (realised separation)
		let forwardValue = function(forwardPoint)
		let backwardValue = function(backwardPoint)

		// Check for non-finite values
		guard forwardValue.isFinite && backwardValue.isFinite else {
			throw OptimizationError.nonFiniteValue(message: "Function returned non-finite value at point")
		}

		// A zero span means the coordinate could not be perturbed at all, which the relative
		// step makes unreachable for finite input — but an infinite or NaN coordinate arrives
		// here too, and dividing by zero would turn that into a silent infinity.
		guard realisedSpan != V.Scalar(0) else {
			throw OptimizationError.nonFiniteValue(
				message: "Coordinate \(i) could not be perturbed: the point is not finite")
		}

		let derivative = (forwardValue - backwardValue) / realisedSpan
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
/// let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
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
	// The elimination itself lives in `gaussianSolveDetailed(_:_:options:)`, shared with
	// the four other callers that each used to carry a copy. What is specific to this
	// function, and preserved exactly, is the threshold and the error taxonomy.
	//
	// The `1e-9` cutoff is fixed rather than scale-relative. That is a weaker criterion
	// than the default — it calls a system singular or not depending on the units it is
	// written in — but it is this function's published behaviour, with tests pinning the
	// errors it raises, so it is a parameter here rather than a correction.
	//
	// `requireFiniteSolution` is off for the same reason: this function has never checked,
	// and turning the check on would newly throw for callers that get an answer today.
	let options = GaussianSolveOptions<T>(
		criterion: .absolute(T(1) / T(1_000_000_000)),
		requireFiniteSolution: false
	)

	switch gaussianSolveDetailed(matrix, vector, options: options) {
	case .solved(let solution):
		return solution

	// Separated so the error names the actual condition: an empty matrix is not a mismatch,
	// and a caller correcting a mismatch needs both counts.
	case .failed(.emptyMatrix):
		throw OptimizationError.invalidInput(message: "Matrix is empty")

	case .failed(.notSquare(let rows, let widths)):
		throw OptimizationError.dimensionMismatch(
			message: "Matrix has \(rows) rows but row widths \(widths); every row must have \(rows)"
		)

	case .failed(.rightHandSideMismatch(let expected, let actual)):
		throw OptimizationError.dimensionMismatch(
			message: "Matrix is \(expected)×\(expected) but the right-hand side has \(actual) elements"
		)

	// "Singular or nearly singular" conflated two conditions a caller can act on
	// differently. An exactly zero column is singular and no amount of rescaling helps; a
	// tiny-but-nonzero pivot is invertible in exact arithmetic and fails only in floating
	// point, so reformulating or rescaling the problem may well succeed.
	case .failed(.singular(let column)):
		throw OptimizationError.singularMatrix(
			message: "Column \(column) is entirely zero; the matrix is singular"
		)

	case .failed(.noScale):
		// Every entry is zero, so the first column is zero like all the rest. Only the
		// scale-relative criterion can report this and this function does not use it, so
		// the case is unreachable here — handled rather than trapped, because an
		// unreachable branch that crashes is worse than one that answers correctly.
		throw OptimizationError.singularMatrix(
			message: "Column 0 is entirely zero; the matrix is singular"
		)

	case .failed(.illConditioned(let column, _, _)):
		throw OptimizationError.numericalInstability(
			message: "Pivot in column \(column) is below 1e-9; elimination would amplify rounding error past the point of meaning"
		)

	case .failed(.nonFiniteResult):
		throw OptimizationError.numericalInstability(
			message: "Elimination produced a non-finite value; the system is too ill-conditioned to solve"
		)
	}
}

/// Inverts a matrix using Gaussian elimination.
///
/// - Parameter matrix: The matrix to invert (n×n)
/// - Returns: The inverse matrix
/// - Throws: ``OptimizationError/invalidInput(message:)`` if the matrix is empty,
///   ``OptimizationError/dimensionMismatch(message:)`` if it is not square,
///   ``OptimizationError/singularMatrix(message:)`` if it is singular, or
///   ``OptimizationError/numericalInstability(message:)`` if it is too ill-conditioned to invert.
public func invertMatrix<T: Real>(_ matrix: [[T]]) throws -> [[T]] {
	let n = matrix.count
	guard n > 0 else {
		throw OptimizationError.invalidInput(message: "Matrix is empty")
	}
	guard matrix.allSatisfy({ $0.count == n }) else {
		let widths = Set(matrix.map(\.count)).sorted()
		throw OptimizationError.dimensionMismatch(
			message: "Matrix has \(n) rows but row widths \(widths); a square matrix needs every row to have \(n)"
		)
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

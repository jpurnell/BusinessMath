//
//  AdvancedMathTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/3/25.
//

import Testing
import TestSupport  // Cross-platform math functions
@testable import BusinessMath

//struct AdvancedMathTests {
//
//	@Test("Neural network gradient calculation")
//	func neuralNetworkGradientCalculation() {
//	// Simulate neural network layer with 3 inputs, 2 outputs
//	let inputs = VectorN<Double>([0.5, -0.2, 0.8])
//	let weights = [
//	VectorN<Double>([0.1, 0.2, -0.1]),  // First neuron weights
//	VectorN<Double>([-0.2, 0.3, 0.1])   // Second neuron weights
//	]
//
//	// Forward pass: W * x
//	let outputs = inputs.multiply(by: weights)
//	#expect(outputs != nil)
//	#expect(outputs!.count == 2)
//
//	// Calculate output: 0.1*0.5 + 0.2*(-0.2) + (-0.1)*0.8 = -0.07
//	#expect(abs(outputs![0] - (-0.07)) < 1e-10)
//
//	// Backward pass: gradient w.r.t. inputs
//	let outputGradients = VectorN<Double>([1.0, -1.0])  // Example gradients
//	var inputGradients = VectorN<Double>.withDimension(inputs.count)
//
//	for (i, weightVector) in weights.enumerated() {
//	inputGradients = inputGradients + outputGradients[i] * weightVector
//	}
//
//	#expect(inputGradients.count == 3)
//	// Should be: [0.1*1 + (-0.2)*(-1), 0.2*1 + 0.3*(-1), (-0.1)*1 + 0.1*(-1)]
//	#expect(abs(inputGradients[0] - 0.3) < 1e-10)
//	#expect(abs(inputGradients[1] - (-0.1)) < 1e-10)
//	#expect(abs(inputGradients[2] - (-0.2)) < 1e-10)
//	}
//
//	@Test("Physical simulation - projectile motion")
//	func physicalSimulationProjectileMotion() {
//	// Simulate projectile motion with vectors
//	let gravity = VectorN<Double>([0.0, -9.81])  // m/s²
//	let initialVelocity = VectorN<Double>([10.0, 20.0])  // m/s
//	let initialPosition = VectorN<Double>([0.0, 0.0])    // meters
//
//	let timeSteps = 100
//	let dt = 0.1  // seconds
//
//	var position = initialPosition
//	var velocity = initialVelocity
//
//	var trajectory: [VectorN<Double>] = [position]
//
//	for _ in 0..<timeSteps {
//	// Update velocity: v = v + a*dt
//	velocity = velocity + gravity * dt
//
//	// Update position: p = p + v*dt
//	position = position + velocity * dt
//
//	trajectory.append(position)
//	}
//
//	// Verify physics
//	#expect(trajectory.count == timeSteps + 1)
//
//	// Final y-position should be negative (fell below starting point)
//	#expect(trajectory.last![1] < 0)
//
//	// x-position should increase monotonically
//	for i in 1..<trajectory.count {
//	#expect(trajectory[i][0] > trajectory[i-1][0])
//	}
//
//	// Peak height calculation
//	let timeToPeak = -initialVelocity[1] / gravity[1]  // vy = 0 at peak
//	let peakHeight = initialPosition[1] + initialVelocity[1] * timeToPeak + 0.5 * gravity[1] * timeToPeak * timeToPeak
//	#expect(peakHeight > 0)
//	}
//
//	@Test("Data normalization for machine learning")
//	func dataNormalizationForMachineLearning() {
//	// Create dataset with different scales
//	let dataset = [
//	VectorN<Double>([100.0, 0.1, 50000.0]),
//	VectorN<Double>([200.0, 0.2, 60000.0]),
//	VectorN<Double>([150.0, 0.15, 55000.0]),
//	VectorN<Double>([180.0, 0.18, 58000.0])
//	]
//
//	// Calculate mean and standard deviation
//	var mean = VectorN<Double>.withDimension(3)
//	for sample in dataset {
//	mean = mean + sample
//	}
//	mean = (1.0 / Double(dataset.count)) * mean
//
//	var variance = VectorN<Double>.withDimension(3)
//	for sample in dataset {
//	let diff = sample - mean
//	variance = variance + diff.hadamard(diff)
//	}
//	variance = (1.0 / Double(dataset.count - 1)) * variance
//	let stdDev = variance.toArray().map { sqrt($0) }
//
//	// Normalize dataset: (x - mean) / stdDev
//	var normalizedDataset: [VectorN<Double>] = []
//	for sample in dataset {
//	let normalized = (sample - mean).elementwiseDivide(by: VectorN<Double>(stdDev))
//	normalizedDataset.append(normalized)
//
//	// Check properties
//	#expect(abs(normalized.mean) < 0.01)  // Mean near 0
//	#expect(abs(normalized.standardDeviation - 1.0) < 0.01)  // Std dev near 1
//	}
//
//	#expect(normalizedDataset.count == dataset.count)
//	}
//
//	@Test("Image processing - vectorized operations")
//	func imageProcessingVectorizedOperations() {
//	// Simulate image pixel operations (grayscale, 3x3 patch)
//	let patch = VectorN<Double>([
//	0.1, 0.2, 0.3,
//	0.4, 0.5, 0.6,
//	0.7, 0.8, 0.9
//	])
//
//	// Edge detection kernel (simplified Sobel)
//	let sobelX = VectorN<Double>([
//	-1, 0, 1,
//	-2, 0, 2,
//	-1, 0, 1
//	])
//
//	let sobelY = VectorN<Double>([
//	-1, -2, -1,
//	0,  0,  0,
//	1,  2,  1
//	])
//
//	// Convolution as dot product
//	let gradientX = patch.dot(sobelX)
//	let gradientY = patch.dot(sobelY)
//
//	// Gradient magnitude
//	let magnitude = sqrt(gradientX * gradientX + gradientY * gradientY)
//	#expect(magnitude > 0)
//
//	// Gradient direction
//	let direction = atan2(gradientY, gradientX)
//	#expect(direction >= -.pi && direction <= .pi)
//
//	// Test brightness adjustment
//	let brightnessFactor = 1.5
//	let brightened = brightnessFactor * patch
//	#expect(brightened.mean > patch.mean)
//
//	// Test contrast adjustment
//	let meanBrightness = patch.mean
//	let contrastAdjusted = (patch - meanBrightness) * 2.0 + meanBrightness
//	#expect(contrastAdjusted.standardDeviation > patch.standardDeviation)
//	}
//
//	// MARK: - Advanced Mathematical Tests
//
//	@Test("Gram-Schmidt orthogonalization")
//	func gramSchmidtOrthogonalization() {
//	// Create a set of linearly independent vectors
//	let v1 = VectorN<Double>([1.0, 1.0, 0.0])
//	let v2 = VectorN<Double>([1.0, 0.0, 1.0])
//	let v3 = VectorN<Double>([0.0, 1.0, 1.0])
//
//	var orthogonalSet: [VectorN<Double>] = []
//
//	// Gram-Schmidt process
//	for v in [v1, v2, v3] {
//	var u = v
//	for orthoVec in orthogonalSet {
//	let projection = v.project(onto: orthoVec)
//	u = u - projection
//	}
//
//	// Only add if not zero vector (linearly independent)
//	if u.norm > 1e-10 {
//	orthogonalSet.append(u.normalized())
//	}
//	}
//
//	// All vectors should be orthogonal
//	for i in 0..<orthogonalSet.count {
//	for j in 0..<orthogonalSet.count where i != j {
//	let dotProduct = orthogonalSet[i].dot(orthogonalSet[j])
//	#expect(abs(dotProduct) < 1e-10)
//	}
//	// And unit length
//	#expect(abs(orthogonalSet[i].norm - 1.0) < 1e-10)
//	}
//
//	#expect(orthogonalSet.count == 3)  // Should have 3 orthogonal vectors
//	}
//	@Test("Eigenvalue approximation (power iteration)")
//	func eigenvalueApproximation() {
//	// Simple symmetric matrix
//	let matrix = [
//	VectorN<Double>([2.0, 1.0]),
//	VectorN<Double>([1.0, 2.0])
//	]
//
//	// Power iteration for dominant eigenvalue
//	var b = VectorN<Double>([1.0, 1.0]).normalized()
//	var eigenvalue: Double = 0.0
//
//	for _ in 0..<100 {
//	// Multiply by matrix
//	guard let Ab = b.multiply(by: matrix) else { break }
//
//	// Normalize
//	let newB = Ab.normalized()
//
//	// Rayleigh quotient for eigenvalue estimate
//	eigenvalue = b.dot(Ab) / b.dot(b)
//
//	// Check convergence
//	if (newB - b).norm < 1e-10 {
//	break
//	}
//	b = newB
//	}
//
//	// Dominant eigenvalue should be 3 for this matrix
//	#expect(abs(eigenvalue - 3.0) < 1e-8)
//
//	// Eigenvector should be [1, 1] direction (normalized)
//	let expectedEigenvector = VectorN<Double>([1.0, 1.0]).normalized()
//	let angle = b.angle(with: expectedEigenvector)
//	#expect(abs(angle) < 1e-8)  // Should be aligned
//	}
//
//		@Test("Singular Value Decomposition simulation")
//		func singularValueDecompositionSimulation() {
//			// Simple 2x2 matrix for SVD simulation
//			let A = [
//				VectorN<Double>([3.0, 0.0]),
//				VectorN<Double>([0.0, 2.0])
//			]
//			
//			// Compute A^T * A for eigenvalues (squares of singular values)
//			let n = A[0].count
//			var ATA = [[Double]](repeating: [Double](repeating: 0.0, count: n), count: n)
//			
//			for i in 0..<n {
//				for j in 0..<n {
//					var sum: Double = 0.0
//					for row in A {
//						sum += row[i] * row[j]
//					}
//					ATA[i][j] = sum
//				}
//			}
//			
//			// For diagonal matrix, eigenvalues are diagonal entries
//			let singularValues = [sqrt(ATA[0][0]), sqrt(ATA[1][1])]
//			#expect(abs(singularValues[0] - 3.0) < 1e-10)
//			#expect(abs(singularValues[1] - 2.0) < 1e-10)
//			
//			// Test matrix reconstruction using outer products
//			let u1 = VectorN<Double>([1.0, 0.0])
//			let u2 = VectorN<Double>([0.0, 1.0])
//			let v1 = VectorN<Double>([1.0, 0.0])
//			let v2 = VectorN<Double>([0.0, 1.0])
//			
//			// A = σ1 * u1 * v1^T + σ2 * u2 * v2^T
//			let outer1 = u1.outerProduct(with: v1)
//			let outer2 = u2.outerProduct(with: v2)
//			
//			// Reconstruct matrix
//			var reconstructed = [[Double]](repeating: [Double](repeating: 0.0, count: n), count: A.count)
//			for i in 0..<A.count {
//				for j in 0..<n {
//					reconstructed[i][j] = singularValues[0] * outer1[i][j] +
//										  singularValues[1] * outer2[i][j]
//				}
//			}
//			
//			// Should match original matrix
//			#expect(abs(reconstructed[0][0] - 3.0) < 1e-10)
//			#expect(abs(reconstructed[1][1] - 2.0) < 1e-10)
//			#expect(abs(reconstructed[0][1]) < 1e-10)
//			#expect(abs(reconstructed[1][0]) < 1e-10)
//		}
//		
//		@Test("Linear system solving (conjugate gradient)")
//		func linearSystemSolving() {
//			// Solve Ax = b using conjugate gradient method
//			// A = [[4, 1], [1, 3]] (symmetric positive definite)
//			let A = [
//				VectorN<Double>([4.0, 1.0]),
//				VectorN<Double>([1.0, 3.0])
//			]
//			let b = VectorN<Double>([1.0, 2.0])
//			
//			// Initial guess
//			var x = VectorN<Double>([0.0, 0.0])
//			var r = b  // Residual: r = b - A*x
//			var p = r  // Search direction
//			
//			for _ in 0..<10 {
//				// Compute A*p
//				guard let Ap = p.multiply(by: A) else { break }
//				
//				// Compute alpha
//				let alpha = r.dot(r) / p.dot(Ap)
//				
//				// Update solution
//				x = x + alpha * p
//				
//				// Update residual
//				let rNew = r - alpha * Ap
//				
//				// Compute beta
//				let beta = rNew.dot(rNew) / r.dot(r)
//				
//				// Update search direction
//				p = rNew + beta * p
//				
//				r = rNew
//				
//				// Check convergence
//				if r.norm < 1e-10 {
//					break
//				}
//			}
//			
//			// Verify solution: x should satisfy A*x ≈ b
//			guard let Ax = x.multiply(by: A) else {
//				Issue.record("Matrix multiplication failed")
//				return
//			}
//			
//			let residual = b - Ax
//			#expect(residual.norm < 1e-8)
//			
//			// Exact solution is [0.0909..., 0.6363...]
//			#expect(abs(x[0] - 1.0/11.0) < 1e-8)
//			#expect(abs(x[1] - 7.0/11.0) < 1e-8)
//		}
//		
//		@Test("Principal Component Analysis simulation")
//		func principalComponentAnalysisSimulation() {
//			// Create correlated 2D data
//			let data = [
//				VectorN<Double>([1.0, 1.0]),
//				VectorN<Double>([2.0, 2.0]),
//				VectorN<Double>([3.0, 3.0]),
//				VectorN<Double>([4.0, 4.0]),
//				VectorN<Double>([5.0, 5.0])
//			]
//			
//			// Center the data
//			var mean = VectorN<Double>.withDimension(2)
//			for point in data {
//				mean = mean + point
//			}
//			mean = (1.0 / Double(data.count)) * mean
//			
//			let centeredData = data.map { $0 - mean }
//			
//			// Compute covariance matrix
//			var covariance = [[Double]](repeating: [Double](repeating: 0.0, count: 2), count: 2)
//			for point in centeredData {
//				let outer = point.outerProduct(with: point)
//				for i in 0..<2 {
//					for j in 0..<2 {
//						covariance[i][j] += outer[i][j]
//					}
//				}
//			}
//			
//			for i in 0..<2 {
//				for j in 0..<2 {
//					covariance[i][j] /= Double(data.count - 1)
//				}
//			}
//			
//			// For perfectly correlated data, first principal component should be [1, 1] direction
//			let expectedPC = VectorN<Double>([1.0, 1.0]).normalized()
//			
//			// Power iteration to find first principal component
//			var pc = VectorN<Double>([1.0, 0.0])
//			let covMatrix = [
//				VectorN<Double>(covariance[0]),
//				VectorN<Double>(covariance[1])
//			]
//			
//			for _ in 0..<50 {
//				guard let newPC = pc.multiply(by: covMatrix) else { break }
//				pc = newPC.normalized()
//			}
//			
//			// Should align with [1, 1] direction
//			let angle = pc.angle(with: expectedPC)
//			#expect(abs(angle) < 1e-8 || abs(angle - .pi) < 1e-8)  // Direction or opposite
//			
//			// Project data onto first PC
//			let projectedData = centeredData.map { $0.project(onto: pc) }
//			
//			// Variance along PC should be large
//			let varianceAlongPC = projectedData.map { $0.squaredNorm }.reduce(0, +) / Double(data.count - 1)
//			#expect(varianceAlongPC > 0)
//		}
//		
//		@Test("Manifold optimization - gradient on sphere")
//		func manifoldOptimizationOnSphere() {
//			// Optimize a function on the unit sphere (manifold constraint)
//			// Function: f(x) = xᵀ * M * x, where M = diag(1, 2, 3)
//			// Constraint: ||x|| = 1
//			
//			let M = [
//				VectorN<Double>([1.0, 0.0, 0.0]),
//				VectorN<Double>([0.0, 2.0, 0.0]),
//				VectorN<Double>([0.0, 0.0, 3.0])
//			]
//			
//			// Riemannian gradient descent on sphere
//			var x = VectorN<Double>([1.0, 1.0, 1.0]).normalized()
//			let learningRate = 0.1
//			
//			for _ in 0..<100 {
//				// Euclidean gradient: ∇f(x) = 2 * M * x
//				guard let Mx = x.multiply(by: M) else { break }
//				let euclideanGradient = 2.0 * Mx
//				
//				// Riemannian gradient: project onto tangent space
//				let riemannianGradient = euclideanGradient - euclideanGradient.dot(x) * x
//				
//				// Retraction: move along geodesic (simplified)
//				let step = -learningRate * riemannianGradient
//				x = (x + step).normalized()
//			}
//			
//			// Should converge to eigenvector of M with smallest eigenvalue (1)
//			// which is [1, 0, 0] direction
//			let expectedMin = VectorN<Double>([1.0, 0.0, 0.0])
//			let angle = x.angle(with: expectedMin)
//			#expect(abs(angle) < 0.1)  // Should be close to x-axis
//			
//			// Verify constraint maintained
//			#expect(abs(x.norm - 1.0) < 1e-10)
//		}
//		
//		@Test("Automatic differentiation simulation")
//		func automaticDifferentiationSimulation() {
//			// Simulate forward-mode automatic differentiation using dual numbers
//			struct DualNumber {
//				let value: Double
//				let derivative: Double
//				
//				static func *(lhs: DualNumber, rhs: DualNumber) -> DualNumber {
//					DualNumber(
//						value: lhs.value * rhs.value,
//						derivative: lhs.derivative * rhs.value + lhs.value * rhs.derivative
//					)
//				}
//				
//				static func +(lhs: DualNumber, rhs: DualNumber) -> DualNumber {
//					DualNumber(
//						value: lhs.value + rhs.value,
//						derivative: lhs.derivative + rhs.derivative
//					)
//				}
//			}
//			
//			// Function: f(x,y) = x² + y²
//			// Gradient should be [2x, 2y]
//			let x = DualNumber(value: 3.0, derivative: 1.0)  // Differentiate w.r.t. x
//			let y = DualNumber(value: 4.0, derivative: 0.0)  // Constant w.r.t. x
//			
//			let xSquared = x * x
//			let ySquared = y * y
//			let f = xSquared + ySquared
//			
//			// ∂f/∂x = 2x = 6
//			#expect(abs(f.derivative - 6.0) < 1e-10)
//			#expect(abs(f.value - 25.0) < 1e-10)  // 3² + 4² = 25
//			
//			// Now differentiate w.r.t. y
//			let x2 = DualNumber(value: 3.0, derivative: 0.0)
//			let y2 = DualNumber(value: 4.0, derivative: 1.0)
//			
//			let f2 = (x2 * x2) + (y2 * y2)
//			#expect(abs(f2.derivative - 8.0) < 1e-10)  // 2y = 8
//			
//			// Vector version: compute gradient of vector function
//			let input = VectorN<DualNumber>([
//				DualNumber(value: 1.0, derivative: 1.0),
//				DualNumber(value: 2.0, derivative: 0.0)
//			])
//			
//			// Function: [x², y²]
//			let output = VectorN<DualNumber>([
//				input[0] * input[0],
//				input[1] * input[1]
//			])
//			
//			// Jacobian diagonal should be [2x, 2y] = [2, 4]
//			#expect(abs(output[0].derivative - 2.0) < 1e-10)
//			#expect(abs(output[1].derivative - 0.0) < 1e-10)  // ∂(y²)/∂x = 0
//		}
//		
//		@Test("Fourier analysis simulation")
//		func fourierAnalysisSimulation() {
//			// Discrete Fourier Transform using vector operations
//			let signal = VectorN<Double>([1.0, 0.0, -1.0, 0.0])
//			let N = signal.count
//			
//			// Compute DFT matrix
//			var dftMatrix: [VectorN<Double>] = []
//			for k in 0..<N {
//				var row: [Double] = []
//				for n in 0..<N {
//					let angle = -2.0 * .pi * Double(k) * Double(n) / Double(N)
//					row.append(cos(angle))  // Real part only for simplicity
//				}
//				dftMatrix.append(VectorN<Double>(row))
//			}
//			
//			// Compute DFT
//			guard let dft = signal.multiply(by: dftMatrix) else {
//				Issue.record("DFT computation failed")
//				return
//			}
//			
//			// For signal [1, 0, -1, 0], DFT should have specific pattern
//			// DC component (k=0) should be 0
//			#expect(abs(dft[0]) < 1e-10)
//			
//			// Parseval's theorem: sum(|x[n]|²) = (1/N) * sum(|X[k]|²)
//			let signalEnergy = signal.toArray().map { $0 * $0 }.reduce(0, +)
//			let spectrumEnergy = dft.toArray().map { $0 * $0 }.reduce(0, +) / Double(N)
//			#expect(abs(signalEnergy - spectrumEnergy) < 1e-10)
//			
//			// Test convolution theorem: convolution in time = multiplication in frequency
//			let kernel = VectorN<Double>([1.0, 1.0])
//			
//			// Time-domain convolution (simplified)
//			var convolution = VectorN<Double>.withDimension(N)
//			for i in 0..<N {
//				for j in 0..<kernel.count {
//					if i - j >= 0 {
//						convolution[i] = convolution[i] + signal[i - j] * kernel[j]
//					}
//				}
//			}
//			
//			// Frequency-domain multiplication
//			guard let signalDFT = signal.multiply(by: dftMatrix),
//				  let kernelDFT = kernel.multiply(by: dftMatrix) else {
//				Issue.record("DFT computation failed")
//				return
//			}
//			
//			let productDFT = signalDFT.hadamard(kernelDFT)
//			
//			// Should satisfy convolution theorem (within scaling)
//			let convolutionEnergy = convolution.toArray().map { $0 * $0 }.reduce(0, +)
//			let productEnergy = productDFT.toArray().map { $0 * $0 }.reduce(0, +) / Double(N)
//			#expect(abs(convolutionEnergy - productEnergy) < 1e-10)
//		}
//		
//		@Test("Support Vector Machine margin calculation")
//		func supportVectorMachineMarginCalculation() {
//			// Simple linear SVM with 2D data
//			let positiveExamples = [
//				VectorN<Double>([1.0, 2.0]),
//				VectorN<Double>([2.0, 3.0]),
//				VectorN<Double>([3.0, 3.0])
//			]
//			
//			let negativeExamples = [
//				VectorN<Double>([-1.0, -1.0]),
//				VectorN<Double>([-2.0, -2.0]),
//				VectorN<Double>([-3.0, -2.0])
//			]
//			
//			// Find maximum margin hyperplane (simplified)
//			// For linearly separable data along x=y line, optimal w = [1, -1]
//			let w = VectorN<Double>([1.0, -1.0]).normalized()
//			let b = 0.0
//			
//			// Calculate margins
//			var minPositiveMargin = Double.infinity
//			var minNegativeMargin = Double.infinity
//			
//			for example in positiveExamples {
//				let margin = w.dot(example) + b
//				minPositiveMargin = min(minPositiveMargin, margin)
//			}
//			
//			for example in negativeExamples {
//				let margin = w.dot(example) + b
//				minNegativeMargin = min(minNegativeMargin, -margin)  // Negative class
//			}
//			
//			// Total margin = distance between closest points of each class
//			let totalMargin = minPositiveMargin + minNegativeMargin
//			#expect(totalMargin > 0)
//			
//			// Support vectors should be closest to hyperplane
//			let supportVectors = (positiveExamples + negativeExamples).filter { example in
//				let distance = abs(w.dot(example) + b)
//				return abs(distance - minPositiveMargin) < 1e-10 ||
//					   abs(distance - minNegativeMargin) < 1e-10
//			}
//			
//			#expect(supportVectors.count >= 2)  // At least one from each class
//			
//			// Verify classification
//			for example in positiveExamples {
//				let prediction = w.dot(example) + b
//				#expect(prediction > 0)
//			}
//			
//			for example in negativeExamples {
//				let prediction = w.dot(example) + b
//				#expect(prediction < 0)
//			}
//		}
//		
//		@Test("Kalman filter state update")
//		func kalmanFilterStateUpdate() {
//			// Simple 1D Kalman filter simulation
//			// State: position and velocity
//			var state = VectorN<Double>([0.0, 0.0])  // [position, velocity]
//			let stateTransition = [
//				VectorN<Double>([1.0, 1.0]),  // position_new = position + velocity
//				VectorN<Double>([0.0, 1.0])   // velocity_new = velocity
//			]
//			
//			let processNoiseCovariance = [
//				VectorN<Double>([0.01, 0.0]),
//				VectorN<Double>([0.0, 0.01])
//			]
//			
//			let measurementMatrix = [
//				VectorN<Double>([1.0, 0.0])  // Only measure position
//			]
//			
//			let measurementNoise = 0.1
//			
//			// Simulate measurements
//			let truePosition = 5.0
//			let trueVelocity = 0.5
//			var measurements: [Double] = []
//			var estimatedStates: [VectorN<Double>] = [state]
//			
//			// Kalman filter matrices (simplified)
//			var covariance = [
//				VectorN<Double>([1.0, 0.0]),
//				VectorN<Double>([0.0, 1.0])
//			]
//			
//			for step in 0..<10 {
//				// True state evolution
//				let trueState = VectorN<Double>([
//					truePosition + trueVelocity * Double(step),
//					trueVelocity
//				])
//				
//				// Generate noisy measurement
//				let measurement = trueState[0] + Double.random(in: -0.5...0.5)
//				measurements.append(measurement)
//				
//				// Prediction step
//				guard let predictedState = state.multiply(by: stateTransition),
//					  let predictedCovariance = multiplyMatrices(
//						multiplyMatrices(stateTransition, covariance),
//						transposeMatrix(stateTransition)
//					  ) else {
//					Issue.record("Prediction failed")
//					return
//				}
//				
//				// Add process noise
//				let predictedCovarianceWithNoise = addMatrices(
//					predictedCovariance,
//					processNoiseCovariance
//				)
//				
//				// Update step (Kalman gain)
//				guard let S = multiplyMatrices(
//						multiplyMatrices(measurementMatrix, predictedCovarianceWithNoise),
//						transposeMatrix(measurementMatrix)
//					  ) else {
//					Issue.record("Innovation covariance failed")
//					return
//				}
//				
//				let innovationCovariance = S[0][0] + measurementNoise
//				guard let K = multiplyMatrices(
//						predictedCovarianceWithNoise,
//						transposeMatrix(measurementMatrix)
//					  )?.map({ row in
//						VectorN<Double>(row.map { $0 / innovationCovariance })
//					  }) else {
//					Issue.record("Kalman gain failed")
//					return
//				}
//				
//				// State update
//				let measurementVector = VectorN<Double>([measurement])
//				guard let measurementPrediction = predictedState.multiply(by: measurementMatrix),
//					  let innovation = measurementVector - measurementPrediction,
//					  let correction = K.multiply(by: [innovation]) else {
//					Issue.record("Update failed")
//					return
//				}
//				
//				state = predictedState + correction[0]
//				estimatedStates.append(state)
//				
//				// Covariance update
//				guard let KH = multiplyMatrices(K, measurementMatrix) else {
//					Issue.record("Covariance update failed")
//					return
//				}
//				
//				let identity = createIdentityMatrix(size: 2)
//				let IminusKH = subtractMatrices(identity, KH)
//				covariance = multiplyMatrices(
//					multiplyMatrices(IminusKH, predictedCovarianceWithNoise),
//					transposeMatrix(IminusKH)
//				) ?? covariance
//			}
//			
//			// Verify filter convergence
//			#expect(estimatedStates.count == 11)
//			
//			// Final estimate should be close to true values
//			let finalError = abs(state[0] - (truePosition + trueVelocity * 9.0))
//			#expect(finalError < 1.0)  // Should converge within reasonable error
//			
//			// Velocity estimate should also converge
//			#expect(abs(state[1] - trueVelocity) < 0.5)
//		}
//		
//		// Helper functions for matrix operations
//		private func multiplyMatrices(_ A: [VectorN<Double>], _ B: [VectorN<Double>]) -> [VectorN<Double>]? {
//			guard !A.isEmpty && !B.isEmpty else { return nil }
//			
//			let n = A.count
//			let m = B[0].count
//			let p = B.count
//			
//			var result = [VectorN<Double>]()
//			
//			for i in 0..<n {
//				var row = [Double]()
//				for j in 0..<m {
//					var sum = 0.0
//					for k in 0..<p {
//						sum += A[i][k] * B[k][j]
//					}
//					row.append(sum)
//				}
//				result.append(VectorN<Double>(row))
//			}
//			
//			return result
//		}
//		
//		private func transposeMatrix(_ A: [VectorN<Double>]) -> [VectorN<Double>] {
//			guard !A.isEmpty else { return [] }
//			
//			let n = A.count
//			let m = A[0].count
//			
//			var result = [VectorN<Double>]()
//			
//			for j in 0..<m {
//				var column = [Double]()
//				for i in 0..<n {
//					column.append(A[i][j])
//				}
//				result.append(VectorN<Double>(column))
//			}
//			
//			return result
//		}
//		
//		private func addMatrices(_ A: [VectorN<Double>], _ B: [VectorN<Double>]) -> [VectorN<Double>] {
//			guard A.count == B.count && !A.isEmpty else { return [] }
//			
//			var result = [VectorN<Double>]()
//			for i in 0..<A.count {
//				result.append(A[i] + B[i])
//			}
//			return result
//		}
//		
//		private func subtractMatrices(_ A: [VectorN<Double>], _ B: [VectorN<Double>]) -> [VectorN<Double>] {
//			guard A.count == B.count && !A.isEmpty else { return [] }
//			
//			var result = [VectorN<Double>]()
//			for i in 0..<A.count {
//				result.append(A[i] - B[i])
//			}
//			return result
//		}
//		
//		private func createIdentityMatrix(size: Int) -> [VectorN<Double>] {
//			var result = [VectorN<Double>]()
//			for i in 0..<size {
//				var row = [Double](repeating: 0.0, count: size)
//				row[i] = 1.0
//				result.append(VectorN<Double>(row))
//			}
//			return result
//		}
//		
////			   let temperatureChange = (heating - cooling) * dt
////				
////				processVariable += temperatureChange
////				
////				// Record history
////				timeHistory.append(Double(step) * dt)
////				temperatureHistory.append(processVariable)
////				controlHistory.append(clampedOutput)
////				
////				previousError = error
////			}
////			
////			// Convert histories to vectors for analysis
////			let timeVector = VectorN<Double>(timeHistory)
////			let tempVector = VectorN<Double>(temperatureHistory)
////			let controlVector = VectorN<Double>(controlHistory)
////			
////			// Verify controller performance
////			#expect(timeVector.count == 100)
////			#expect(tempVector.count == 100)
////			#expect(controlVector.count == 100)
////			
////			// Should reach near setpoint
////			let finalError = abs(setpoint - tempVector[tempVector.count - 1])
////			#expect(finalError < 5.0)  // Within 5 degrees
////			
////			// Check for overshoot (common in PID)
////			let maxTemp = tempVector.max
////			#expect(maxTemp > setpoint)  // Should overshoot slightly
////			
////			// Check settling time (time to reach within 2% of setpoint)
////			let targetRange = setpoint * 0.02  // 2% tolerance
////			var settlingTime: Double?
////			
////			for (i, temp) in tempVector.toArray().enumerated() {
////				if abs(temp - setpoint) < targetRange {
////					settlingTime = timeVector[i]
////					break
////				}
////			}
////			
////			#expect(settlingTime != nil)
////			#expect(settlingTime! < 5.0)  // Should settle within 5 seconds
////			
////			// Analyze control effort
////			let avgControl = controlVector.mean
////			#expect(avgControl > 0 && avgControl < 100)
////			
////			// Check for steady-state error (should be near zero with integral term)
////			let steadyStateError = abs(setpoint - tempVector.mean)
////			#expect(steadyStateError < 1.0)
//		
//		@Test("State-space system simulation")
//		func stateSpaceSystemSimulation() {
//			// Mass-spring-damper system: m*x'' + c*x' + k*x = F
//			// State-space representation: x' = A*x + B*u
//			
//			// Parameters
//			let m = 1.0  // mass
//			let c = 0.5  // damping
//			let k = 2.0  // stiffness
//			
//			// State vector: [position, velocity]
//			var x = VectorN<Double>([0.0, 0.0])
//			
//			// State matrix A
//			let A = [
//				VectorN<Double>([0.0, 1.0]),
//				VectorN<Double>([-k/m, -c/m])
//			]
//			
//			// Input matrix B
//			let B = [
//				VectorN<Double>([0.0]),
//				VectorN<Double>([1.0/m])
//			]
//			
//			// Simulation parameters
//			let dt = 0.01
//			let simulationTime = 10.0
//			let steps = Int(simulationTime / dt)
//			
//			// Input force (step input)
//			let F = 1.0
//			
//			var timeHistory: [Double] = []
//			var positionHistory: [Double] = []
//			var velocityHistory: [Double] = []
//			
//			for step in 0..<steps {
//				let time = Double(step) * dt
//				
//				// State derivative: x' = A*x + B*u
//				guard let Ax = x.multiply(by: A),
//					  let Bu = VectorN<Double>([F]).multiply(by: B) else {
//					Issue.record("State-space calculation failed")
//					return
//				}
//				
//				let xdot = Ax + Bu[0]
//				
//				// Euler integration: x = x + x'*dt
//				x = x + xdot * dt
//				
//				// Record history
//				timeHistory.append(time)
//				positionHistory.append(x[0])
//				velocityHistory.append(x[1])
//			}
//			
//			// Convert to vectors
//			let timeVector = VectorN<Double>(timeHistory)
//			let positionVector = VectorN<Double>(positionHistory)
//			let velocityVector = VectorN<Double>(velocityHistory)
//			
//			// Verify system properties
//			#expect(timeVector.count == steps)
//			#expect(positionVector.count == steps)
//			#expect(velocityVector.count == steps)
//			
//			// Check steady-state position (for step input)
//			// Static deflection: x_ss = F/k = 1/2 = 0.5
//			let steadyStatePosition = 1.0 / k  // F/k
//			let finalPosition = positionVector[positionVector.count - 1]
//			#expect(abs(finalPosition - steadyStatePosition) < 0.01)
//			
//			// Check damping (should be underdamped with these parameters)
//			// Natural frequency: ω_n = sqrt(k/m) = sqrt(2)
//			// Damping ratio: ζ = c/(2*sqrt(m*k)) = 0.5/(2*sqrt(2)) ≈ 0.177 < 1 (underdamped)
//			
//			// Find peaks for oscillation analysis
//			var peaks: [Double] = []
//			for i in 1..<(positionVector.count - 1) {
//				if positionVector[i] > positionVector[i-1] && positionVector[i] > positionVector[i+1] {
//					peaks.append(positionVector[i])
//				}
//			}
//			
//			#expect(peaks.count > 2)  // Should oscillate
//			
//			// Calculate damping from peak ratios (logarithmic decrement)
//			if peaks.count >= 3 {
//				let delta = log(peaks[0] / peaks[1])
//				let dampingRatio = delta / sqrt(4 * .pi * .pi + delta * delta)
//				#expect(dampingRatio > 0.1 && dampingRatio < 0.3)  // Should match calculated ~0.177
//			}
//			
//			// Energy conservation check (kinetic + potential)
//			var totalEnergyHistory: [Double] = []
//			for i in 0..<positionVector.count {
//				let kinetic = 0.5 * m * velocityVector[i] * velocityVector[i]
//				let potential = 0.5 * k * positionVector[i] * positionVector[i]
//				totalEnergyHistory.append(kinetic + potential)
//			}
//			
//			let energyVector = VectorN<Double>(totalEnergyHistory)
//			let initialEnergy = energyVector[0]
//			let finalEnergy = energyVector[energyVector.count - 1]
//			
//			// Energy should decrease due to damping
//			#expect(finalEnergy < initialEnergy)
//			
//			// But should approach steady-state energy
//			let steadyStateEnergy = 0.5 * k * steadyStatePosition * steadyStatePosition
//			#expect(abs(finalEnergy - steadyStateEnergy) < 0.01)
//		}
//		
//		@Test("Optimal control - LQR design")
//		func optimalControlLQRDesign() {
//			// Linear Quadratic Regulator design for double integrator
//			// System: x' = A*x + B*u
//			// Cost: J = ∫(xᵀQx + uᵀRu) dt
//			
//			// Double integrator: position and velocity
//			let A = [
//				VectorN<Double>([0.0, 1.0]),
//				VectorN<Double>([0.0, 0.0])
//			]
//			
//			let B = [
//				VectorN<Double>([0.0]),
//				VectorN<Double>([1.0])
//			]
//			
//			// Weight matrices
//			let Q = [
//				VectorN<Double>([1.0, 0.0]),  // Penalize position error
//				VectorN<Double>([0.0, 0.1])   // Penalize velocity
//			]
//			
//			let R = [VectorN<Double>([0.01])]  // Control effort penalty
//			
//			// Solve Algebraic Riccati Equation (simplified for this system)
//			// For double integrator with these weights, solution is known
//			
//			// Optimal feedback gain: K = R⁻¹BᵀP
//			// Where P solves: AᵀP + PA - PBR⁻¹BᵀP + Q = 0
//			
//			// For this simple case, we can compute directly
//			// Let P = [[p11, p12], [p12, p22]]
//			// Solving gives: p11 = sqrt(2R), p12 = R, p22 = sqrt(2R)
//			
//			let R_value = R[0][0]
//			let p11 = sqrt(2.0 * R_value)
//			let p12 = R_value
//			let p22 = sqrt(2.0 * R_value)
//			
//			let P = [
//				VectorN<Double>([p11, p12]),
//				VectorN<Double>([p12, p22])
//			]
//			
//			// Compute optimal gain K = R⁻¹BᵀP
//			guard let B_transpose = transposeMatrix(B),
//				  let BP = multiplyMatrices(B_transpose, P) else {
//				Issue.record("Matrix multiplication failed")
//				return
//			}
//			
//			let K = BP.map { row in
//				VectorN<Double>(row.toArray().map { $0 / R_value })
//			}
//			
//			#expect(K.count == 1)  // Single input
//			#expect(K[0].count == 2)  // Two states
//			
//			// Simulate closed-loop system
//			var x = VectorN<Double>([1.0, 0.0])  // Initial position = 1, velocity = 0
//			let dt = 0.01
//			let steps = 500
//			
//			var positionHistory: [Double] = []
//			var controlHistory: [Double] = []
//			
//			for _ in 0..<steps {
//				// Optimal control: u = -K*x
//				guard let u_vec = x.multiply(by: K) else { break }
//				let u = -u_vec[0]  // Negative feedback
//				
//				// System dynamics: x' = A*x + B*u
//				guard let Ax = x.multiply(by: A),
//					  let Bu = VectorN<Double>([u]).multiply(by: B) else {
//					break
//				}
//				
//				let xdot = Ax + Bu[0]
//				x = x + xdot * dt
//				
//				positionHistory.append(x[0])
//				controlHistory.append(u)
//			}
//			
//			// Verify optimal control properties
//			let finalPosition = positionHistory.last ?? 0.0
//			#expect(abs(finalPosition) < 0.01)  // Should regulate to zero
//			
//			// Control effort should be reasonable
//			let controlEffort = controlHistory.map { $0 * $0 }.reduce(0, +) * dt
//			#expect(controlEffort > 0 && controlEffort < 10.0)
//			
//			// Cost comparison with other gains
//			let otherGains = [
//				VectorN<Double>([0.5, 0.5]),  // Suboptimal
//				VectorN<Double>([2.0, 2.0])   // Aggressive
//			]
//			
//			var costs: [Double] = []
//			
//			for testK in [K[0]] + otherGains {
//				var testX = VectorN<Double>([1.0, 0.0])
//				var testCost = 0.0
//				
//				for _ in 0..<steps {
//					guard let u_vec = testX.multiply(by: [testK]) else { break }
//					let u = -u_vec[0]
//					
//					// State cost: xᵀQx
//					guard let Qx = testX.multiply(by: Q) else { break }
//					let stateCost = testX.dot(Qx)
//					
//					// Control cost: uᵀRu
//					let controlCost = u * R_value * u
//					
//					testCost += (stateCost + controlCost) * dt
//					
//					// Update state
//					guard let Ax = testX.multiply(by: A),
//						  let Bu = VectorN<Double>([u]).multiply(by: B) else {
//						break
//					}
//					
//					let xdot = Ax + Bu[0]
//					testX = testX + xdot * dt
//				}
//				
//				costs.append(testCost)
//			}
//			
//			// LQR should have lowest cost
//			#expect(costs[0] < costs[1])  // Better than suboptimal
//			#expect(costs[0] < costs[2])  // Better than aggressive
//		}
//		
//		@Test("Model Predictive Control simulation")
//		func modelPredictiveControlSimulation() {
//			// Simple MPC for temperature control with constraints
//			
//			// System: first-order thermal system
//			// T' = (T_env - T)/τ + α*u
//			let tau = 5.0  // Time constant (seconds)
//			let alpha = 0.2  // Heating coefficient
//			let T_env = 20.0  // Ambient temperature
//			
//			var T = 20.0  // Current temperature
//			let T_setpoint = 100.0
//			let dt = 0.1
//			
//			// MPC parameters
//			let horizon = 10  // Prediction horizon
//			let controlHorizon = 5  // Control horizon
//			
//			// Constraints
//			let u_min = 0.0
//			let u_max = 100.0
//			let T_min = 0.0
//			let T_max = 150.0
//			
//			var timeHistory: [Double] = []
//			var tempHistory: [Double] = []
//			var controlHistory: [Double] = []
//			
//			// MPC simulation
//			for step in 0..<100 {
//				let time = Double(step) * dt
//				
//				// MPC optimization (simplified - gradient descent)
//				var bestU: [Double] = Array(repeating: 0.0, count: controlHorizon)
//				var bestCost = Double.infinity
//				
//				// Simple grid search for demonstration
//				let u_options = stride(from: u_min, to: u_max, by: 10.0)
//				
//				for u_test in u_options {
//					var T_pred = T
//					var cost = 0.0
//					var u_sequence: [Double] = []
//					
//					for k in 0..<horizon {
//						let u = (k < controlHorizon) ? u_test : 0.0
//						u_sequence.append(u)
//						
//						// Predict temperature
//						let dT = ((T_env - T_pred)/tau + alpha * u) * dt
//						T_pred += dT
//						
//						// Clamp temperature prediction
//						T_pred = max(T_min, min(T_max, T_pred))
//						
//						// Cost: tracking error + control effort
//						let error = T_setpoint - T_pred
//						cost += error * error * dt + 0.01 * u * u * dt
//					}
//					
//					if cost < bestCost {
//						bestCost = cost
//						bestU = u_sequence
//					}
//				}
//				
//				// Apply first control input
//				let u_optimal = bestU[0]
//				
//				// Update system
//				let dT = ((T_env - T)/tau + alpha * u_optimal) * dt
//				T += dT
//				
//				// Record
//				timeHistory.append(time)
//				tempHistory.append(T)
//				controlHistory.append(u_optimal)
//			}
//			
//			// Convert to vectors
//			let timeVector = VectorN<Double>(timeHistory)
//			let tempVector = VectorN<Double>(tempHistory)
//			let controlVector = VectorN<Double>(controlHistory)
//			
//			// Verify MPC performance
//			#expect(timeVector.count == 100)
//			#expect(tempVector.count == 100)
//			#expect(controlVector.count == 100)
//			
//			// Should reach setpoint
//			let finalError = abs(T_setpoint - tempVector[tempVector.count - 1])
//			#expect(finalError < 5.0)
//			
//			// Check constraint satisfaction
//			#expect(controlVector.min >= u_min)
//			#expect(controlVector.max <= u_max)
//			#expect(tempVector.min >= T_min)
//			#expect(tempVector.max <= T_max)
//			
//			// Control should be smooth (no excessive chattering)
//			let controlChanges = (0..<(controlVector.count-1)).map { i in
//				abs(controlVector[i+1] - controlVector[i])
//			}
//			
//			let avgControlChange = VectorN<Double>(controlChanges).mean
//			#expect(avgControlChange < 5.0)  // Smooth control
//			
//			// Compare with PID (from previous test)
//			// MPC should have better constraint handling and preview capability
//		}

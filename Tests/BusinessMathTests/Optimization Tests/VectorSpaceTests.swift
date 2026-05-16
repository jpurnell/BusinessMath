//
//  VectorSpaceTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/3/25.
//

import Foundation
import TestSupport  // Cross-platform math functions
import Testing
import Numerics
@testable import BusinessMath

@Suite("VectorSpace Protocol")
struct VectorSpaceTests {

		// MARK: - Vector1D Tests

	@Test("Vector1D basic operations")
	func vector1DBasicOperations() {
		let v1 = Vector1D<Double>(2.5)
		let v2 = Vector1D<Double>(0.5)

		let sum = v1 + v2
		#expect(abs(sum.value - 3.0) < 1e-6)

		let diff = v1 - v2
		#expect(abs(diff.value - 2.0) < 1e-6)

		let scaled = 2.0 * v1
		#expect(abs(scaled.value - 5.0) < 1e-6)

		let divided = v1 / 5.0
		#expect(abs(divided.value - 0.5) < 1e-6)

		let negated = -v1
		#expect(abs(negated.value - (-2.5)) < 1e-6)
	}

	@Test("Vector1D norm and dot product")
	func vector1DNormAndDot() {
		let v1 = Vector1D<Double>(3.0)
		let v2 = Vector1D<Double>(4.0)
		let vNeg = Vector1D<Double>(-7.5)

		// Norm is the absolute value
		#expect(abs(v1.norm - 3.0) < 1e-6)
		#expect(abs(vNeg.norm - 7.5) < 1e-6)

		// Dot product is just the product of components
		#expect(abs(v1.dot(v2) - 12.0) < 1e-6)
		#expect(abs(v1.dot(v1) - 9.0) < 1e-6)

		// Squared norm via VectorSpace default
		#expect(abs(v1.squaredNorm - 9.0) < 1e-6)
	}

	@Test("Vector1D array conversion")
	func vector1DArrayConversion() {
		let v = Vector1D<Double>(2.5)

		// To array
		#expect(v.toArray().count == 1 && abs(v.toArray()[0] - 2.5) < 1e-6)

		// From array (valid)
		let fromArray = Vector1D<Double>.fromArray([3.5])
		#expect(abs((fromArray?.value ?? .nan) - 3.5) < 1e-6)

		// From array (wrong size — must return nil)
		#expect(Vector1D<Double>.fromArray([]) == nil)
		#expect(Vector1D<Double>.fromArray([1.0, 2.0]) == nil)
	}

	@Test("Vector1D zero, dimension, and isFinite")
	func vector1DConvenienceMembers() {
		let zero = Vector1D<Double>.zero
		#expect(abs(zero.value - 0.0) < 1e-6)

		#expect(Vector1D<Double>.dimension == 1)

		let finite = Vector1D<Double>(2.5)
		#expect(finite.isFinite)

		let infinite = Vector1D<Double>(.infinity)
		#expect(!infinite.isFinite)

		let nan = Vector1D<Double>(.nan)
		#expect(!nan.isFinite)
	}

	@Test("Vector1D distance and lerp")
	func vector1DDistanceAndLerp() {
		let a = Vector1D<Double>(0.0)
		let b = Vector1D<Double>(10.0)

		// distance is the default extension method via VectorSpace
		#expect(abs(a.distance(to: b) - 10.0) < 1e-6)
		#expect(abs(b.distance(to: a) - 10.0) < 1e-6)
		#expect(abs(a.squaredDistance(to: b) - 100.0) < 1e-6)
	}

	@Test("Vector1D Equatable and Hashable")
	func vector1DEquatableAndHashable() {
		let a = Vector1D<Double>(2.5)
		let b = Vector1D<Double>(2.5)
		let c = Vector1D<Double>(2.6)

		#expect(a == b)
		#expect(a != c)

		// Hashable: equal vectors have equal hashes
		#expect(a.hashValue == b.hashValue)
	}

	@Test("Vector1D Codable round-trip")
	func vector1DCodable() throws {
		let original = Vector1D<Double>(2.5)
		let encoder = JSONEncoder()
		let decoder = JSONDecoder()

		let data = try encoder.encode(original)
		let decoded = try decoder.decode(Vector1D<Double>.self, from: data)

		#expect(decoded == original)
		#expect(abs(decoded.value - 2.5) < 1e-6)
	}

	@Test("Vector1D Sendable conformance")
	func vector1DSendable() async {
		let v = Vector1D<Double>(3.14)
		// Compile-time check: passing across actor boundary requires Sendable
		await Task.detached {
			#expect(abs(v.value - 3.14) < 1e-6)
		}.value
	}

		// MARK: - Vector2D Tests
	
	@Test("Vector2D basic operations")
	func vector2DBasicOperations() {
		let v1 = Vector2D<Double>(x: 1.0, y: 2.0)
		let v2 = Vector2D<Double>(x: 3.0, y: 4.0)
		
			// Addition
		let sum = v1 + v2
		#expect(abs(sum.x - 4.0) < 1e-6)
		#expect(abs(sum.y - 6.0) < 1e-6)

			// Scalar multiplication
		let scaled = 2.0 * v1
		#expect(abs(scaled.x - 2.0) < 1e-6)
		#expect(abs(scaled.y - 4.0) < 1e-6)

			// Negation
		let neg = -v1
		#expect(abs(neg.x - (-1.0)) < 1e-6)
		#expect(abs(neg.y - (-2.0)) < 1e-6)

			// Subtraction (default implementation)
		let diff = v1 - v2
		#expect(abs(diff.x - (-2.0)) < 1e-6)
		#expect(abs(diff.y - (-2.0)) < 1e-6)
	}
	
	@Test("Vector2D norm and dot product")
	func vector2DNormAndDot() {
		let v1 = Vector2D<Double>(x: 3.0, y: 4.0)
		let v2 = Vector2D<Double>(x: 1.0, y: 2.0)
		
			// Norm
		#expect(abs(v1.norm - 5.0) < 1e-6)
		#expect(abs(v2.norm - sqrt(5.0)) < 1e-6)

			// Squared norm
		#expect(abs(v1.squaredNorm - 25.0) < 1e-6)
		#expect(abs(v2.squaredNorm - 5.0) < 1e-6)

			// Dot product
		let dot = v1.dot(v2)
		let expectedDot = 3.0 * 1.0 + 4.0 * 2.0
		#expect(abs(dot - expectedDot) < 1e-6)
		
			// Distance
		let distance = v1.distance(to: v2)
		let expectedDistance = sqrt((3.0 - 1.0) * (3.0 - 1.0) + (4.0 - 2.0) * (4.0 - 2.0))
		#expect(abs(distance - expectedDistance) < 1e-10)
	}
	
	@Test("Vector2D array conversion")
	func vector2DArrayConversion() {
		let v = Vector2D<Double>(x: 1.5, y: 2.5)
		
			// To array
		let array = v.toArray()
		#expect(array.count == 2)
		#expect(abs(array[0] - 1.5) < 1e-6)
		#expect(abs(array[1] - 2.5) < 1e-6)

			// From array
		let fromArray = Vector2D<Double>.fromArray([3.0, 4.0])
		#expect(abs((fromArray?.x ?? .nan) - 3.0) < 1e-6)
		#expect(abs((fromArray?.y ?? .nan) - 4.0) < 1e-6)
		
			// Invalid array
		let invalid = Vector2D<Double>.fromArray([1.0])
		#expect(invalid == nil)
	}
	
	@Test("Vector2D convenience methods")
	func vector2DConvenienceMethods() {
			// Zero vector
		let zero = Vector2D<Double>.zero
		#expect(abs(zero.x - 0.0) < 1e-6)
		#expect(abs(zero.y - 0.0) < 1e-6)
		
			// Is finite
		let finite = Vector2D<Double>(x: 1.0, y: 2.0)
		#expect(finite.isFinite == true)
		
		let infinite = Vector2D<Double>(x: .infinity, y: 2.0)
		#expect(infinite.isFinite == false)
		
			// Linear interpolation
		let start = Vector2D<Double>(x: 0.0, y: 0.0)
		let end = Vector2D<Double>(x: 10.0, y: 20.0)
		let lerped = Vector2D<Double>.lerp(from: start, to: end, t: 0.5)
		#expect(abs(lerped.x - 5.0) < 1e-6)
		#expect(abs(lerped.y - 10.0) < 1e-6)
	}
	
		// MARK: - Vector3D Tests
	
	@Test("Vector3D basic operations")
	func vector3DBasicOperations() {
		let v1 = Vector3D<Double>(x: 1.0, y: 2.0, z: 3.0)
		let v2 = Vector3D<Double>(x: 4.0, y: 5.0, z: 6.0)
		
		let sum = v1 + v2
		#expect(abs(sum.x - 5.0) < 1e-6)
		#expect(abs(sum.y - 7.0) < 1e-6)
		#expect(abs(sum.z - 9.0) < 1e-6)

		let scaled = 2.0 * v1
		#expect(abs(scaled.x - 2.0) < 1e-6)
		#expect(abs(scaled.y - 4.0) < 1e-6)
		#expect(abs(scaled.z - 6.0) < 1e-6)
	}
	
	@Test("Vector3D norm calculation")
	func vector3DNormCalculation() {
		let v = Vector3D<Double>(x: 1.0, y: 2.0, z: 2.0)
		#expect(abs(v.norm - 3.0) < 1e-10)  // sqrt(1² + 2² + 2²) = 3
	}
	
		// MARK: - VectorN Tests
	
	@Test("VectorN initialization")
	func vectorNInitialization() {
			// From array
		let v1 = VectorN<Double>([1.0, 2.0, 3.0])
		#expect(v1.count == 3)
		#expect(abs(v1[0] - 1.0) < 1e-6)
		#expect(abs(v1[1] - 2.0) < 1e-6)
		#expect(abs(v1[2] - 3.0) < 1e-6)

			// Repeating
		let v2 = VectorN<Double>(repeating: 5.0, count: 4)
		#expect(v2.count == 4)
		#expect(abs(v2[0] - 5.0) < 1e-6)
		#expect(abs(v2[3] - 5.0) < 1e-6)
		
			// Zero vector
		let zero = VectorN<Double>.zero
		#expect(zero.count == 0)
	}
	
	@Test("VectorN operations with matching dimensions")
	func vectorNOperationsMatchingDimensions() {
		let v1 = VectorN<Double>([1.0, 2.0, 3.0])
		let v2 = VectorN<Double>([4.0, 5.0, 6.0])
		
			// Addition
		let sum = v1 + v2
		#expect(sum.count == 3)
		#expect(abs(sum[0] - 5.0) < 1e-6)
		#expect(abs(sum[1] - 7.0) < 1e-6)
		#expect(abs(sum[2] - 9.0) < 1e-6)

			// Scalar multiplication
		let scaled = 2.0 * v1
		#expect(abs(scaled[0] - 2.0) < 1e-6)
		#expect(abs(scaled[1] - 4.0) < 1e-6)
		#expect(abs(scaled[2] - 6.0) < 1e-6)

			// Dot product
		let dot = v1.dot(v2)
		let expectedDotN = 1.0*4.0 + 2.0*5.0 + 3.0*6.0
		#expect(abs(dot - expectedDotN) < 1e-6)
		
			// Norm
		let norm = v1.norm
		let expectedNorm = sqrt(1.0*1.0 + 2.0*2.0 + 3.0*3.0)
		#expect(abs(norm - expectedNorm) < 1e-10)
	}
	
	@Test("VectorN operations with mismatched dimensions")
	func vectorNOperationsMismatchedDimensions() {
		let v1 = VectorN<Double>([1.0, 2.0])
		let v2 = VectorN<Double>([3.0, 4.0, 5.0])
		
			// Addition with mismatch returns zero vector
		let sum = v1 + v2
		#expect(sum.count == 3)  // Max dimension
		#expect(abs(sum[0] - 0.0) < 1e-6)
		#expect(abs(sum[1] - 0.0) < 1e-6)
		#expect(abs(sum[2] - 0.0) < 1e-6)

			// Dot product with mismatch returns 0
		let dot = v1.dot(v2)
		#expect(abs(dot - 0.0) < 1e-6)
	}
	
	@Test("VectorN subscript access")
	func vectorNSubscriptAccess() {
		var v = VectorN<Double>([1.0, 2.0, 3.0])
		
			// Read access
		#expect(abs(v[0] - 1.0) < 1e-6)
		#expect(abs(v[1] - 2.0) < 1e-6)
		#expect(abs(v[2] - 3.0) < 1e-6)

			// Out of bounds read returns 0
		#expect(abs(v[-1] - 0.0) < 1e-6)
		#expect(abs(v[10] - 0.0) < 1e-6)

			// Write access
		v[1] = 99.0
		#expect(abs(v[1] - 99.0) < 1e-6)
		
			// Out of bounds write does nothing
		v[-1] = 100.0
		v[10] = 100.0
		#expect(v.count == 3)
	}
	
	@Test("VectorN convenience methods")
	func vectorNConvenienceMethods() {
			// Unit vector
		let unit = VectorN<Double>.unitVector(dimension: 3, direction: 1)
		#expect(unit.count == 3)
		#expect(abs(unit[0] - 0.0) < 1e-6)
		#expect(abs(unit[1] - 1.0) < 1e-6)
		#expect(abs(unit[2] - 0.0) < 1e-6)

			// With dimension
		let sized = VectorN<Double>.withDimension(4, initialValue: 7.0)
		#expect(sized.count == 4)
		#expect(abs(sized[0] - 7.0) < 1e-6)
		#expect(abs(sized[3] - 7.0) < 1e-6)
		
			// Is finite
		let finite = VectorN<Double>([1.0, 2.0, 3.0])
		#expect(finite.isFinite == true)
		
		let infinite = VectorN<Double>([1.0, .infinity, 3.0])
		#expect(infinite.isFinite == false)
	}
	
		// MARK: - Vector Operations Tests
	
	@Test("Vector operations - Hadamard product")
	func vectorHadamardProduct() {
		let v1 = VectorN<Double>([1.0, 2.0, 3.0])
		let v2 = VectorN<Double>([4.0, 5.0, 6.0])
		
		let result = v1.hadamard(v2)
		#expect(result.count == 3)
		#expect(abs(result[0] - 4.0) < 1e-6)   // 1*4
		#expect(abs(result[1] - 10.0) < 1e-6)  // 2*5
		#expect(abs(result[2] - 18.0) < 1e-6)  // 3*6

			// Mismatched dimensions returns zero
		let v3 = VectorN<Double>([1.0, 2.0])
		let zeroResult = v1.hadamard(v3)
		#expect(zeroResult.count == 3)
		#expect(abs(zeroResult[0] - 0.0) < 1e-6)
	}
	
	@Test("Vector operations - elementwise division")
	func vectorElementwiseDivision() {
		let v1 = VectorN<Double>([10.0, 20.0, 30.0])
		let v2 = VectorN<Double>([2.0, 4.0, 5.0])
		
		let result = v1.elementwiseDivide(by: v2)
		#expect(result.count == 3)
		#expect(abs(result[0] - 5.0) < 1e-6)   // 10/2
		#expect(abs(result[1] - 5.0) < 1e-6)   // 20/4
		#expect(abs(result[2] - 6.0) < 1e-6)   // 30/5
	}
	
	@Test("Vector operations - statistics")
	func vectorStatistics() {
		let v = VectorN<Double>([1.0, 2.0, 3.0, 4.0, 5.0])
		let stdDev = v.standardDeviation()
		let difference = Double(1.0) / Double(10000000000)
		let value = abs(stdDev - sqrt(2.5))
		#expect(abs(v.sum - 15.0) < 1e-6)
		#expect(abs(v.mean - 3.0) < 1e-6)
		#expect(value < difference)  // Population variance = 2.5
		#expect(abs((v.max ?? .nan) - 5.0) < 1e-6)
		#expect(abs((v.min ?? .nan) - 1.0) < 1e-6)
	}
	
	@Test("Vector operations - normalization")
	func vectorNormalization() {
		let v = VectorN<Double>([3.0, 4.0])
		let normalized = v.normalized()
		
		#expect(abs(normalized.norm - 1.0) < 1e-10)
		#expect(abs(normalized[0] - 0.6) < 1e-10)   // 3/5
		#expect(abs(normalized[1] - 0.8) < 1e-10)   // 4/5
		
			// Zero vector normalization returns itself
		let zero = VectorN<Double>.zero
		let zeroNormalized = zero.normalized()
		#expect(zeroNormalized.count == 0)
	}
	
	@Test("Vector operations - projection")
	func vectorProjection() {
		let v1 = VectorN<Double>([1.0, 2.0, 3.0])
		let v2 = VectorN<Double>([1.0, 0.0, 0.0])
		
		let projection = v1.projection(onto: v2)
		#expect(projection.count == 3)
		#expect(abs(projection[0] - 1.0) < 1e-6)  // Projects onto x-axis
		#expect(abs(projection[1] - 0.0) < 1e-6)
		#expect(abs(projection[2] - 0.0) < 1e-6)

			// Projection onto zero vector returns zero
		let zero = VectorN<Double>.zero
		let zeroProjection = v1.projection(onto: zero)
		#expect(zeroProjection.count == 3)  // Returns zero vector of same dimension
	#expect(abs(zeroProjection[0] - 0.0) < 1e-6)
	#expect(abs(zeroProjection[1] - 0.0) < 1e-6)
	#expect(abs(zeroProjection[2] - 0.0) < 1e-6)
	}
	
	@Test("Vector operations - angle calculation")
	func vectorAngleCalculation() {
		let v1 = VectorN<Double>([1.0, 0.0])
		let v2 = VectorN<Double>([0.0, 1.0])
		
		let angle = v1.angle(with: v2)
		#expect(abs(angle - .pi/2) < 1e-10)  // 90 degrees in radians
		
			// Parallel vectors
		let v3 = VectorN<Double>([2.0, 0.0])
		let parallelAngle = v1.angle(with: v3)
		#expect(abs(parallelAngle) < 1e-10)
		
			// Anti-parallel vectors
		let v4 = VectorN<Double>([-1.0, 0.0])
		let antiParallelAngle = v1.angle(with: v4)
		#expect(abs(antiParallelAngle - .pi) < 1e-10)
	}
	
		// MARK: - Matrix-Vector Operations Tests
	
//	@Test("Matrix-vector multiplication")
//	func matrixVectorMultiplication() {
//		let v = VectorN<Double>([1.0, 2.0])
//		let matrix = [
//			VectorN<Double>([1.0, 0.0]),  // [1 0]
//			VectorN<Double>([0.0, 1.0]),  // [0 1]
//			VectorN<Double>([1.0, 1.0])   // [1 1]
//		]
//		
//		let result = v.multiply(by: matrix)
//		#expect(result != nil)
//		#expect(result!.count == 3)
//		#expect(result![0] == 1.0)  // 1*1 + 2*0
//		#expect(result![1] == 2.0)  // 1*0 + 2*1
//		#expect(result![2] == 3.0)  // 1*1 + 2*1
//		
//			// Invalid dimensions
//		let badMatrix = [VectorN<Double>([1.0])]
//		let badResult = v.multiply(by: badMatrix)
//		#expect(badResult == nil)
//	}
	
	@Test("Outer product")
	func outerProduct() {
		let v1 = VectorN<Double>([1.0, 2.0])
		let v2 = VectorN<Double>([3.0, 4.0, 5.0])
		
		let result = v1.outerProduct(with: v2)
		#expect(result.count == 2)  // v1 dimension
		#expect(result[0].count == 3)  // v2 dimension
		
		#expect(abs(result[0][0] - 3.0) < 1e-6)  // 1*3
		#expect(abs(result[0][1] - 4.0) < 1e-6)  // 1*4
		#expect(abs(result[0][2] - 5.0) < 1e-6)  // 1*5
		#expect(abs(result[1][0] - 6.0) < 1e-6)  // 2*3
		#expect(abs(result[1][1] - 8.0) < 1e-6)  // 2*4
		#expect(abs(result[1][2] - 10.0) < 1e-6) // 2*5
	}
	
		// MARK: - Convenience Extensions Tests
	
//	@Test("Convenience vector creation")
//	func convenienceVectorCreation() {
//			// Variadic arguments
//		let v1 = VectorN<Double>.vector(1.0, 2.0, 3.0)
//		#expect(v1 != nil)
//		#expect(v1!.count == 3)
//		#expect(v1![0] == 1.0)
//		
//			// Filled vector
//		let v2 = VectorN<Double>.filled(with: 7.0, dimension: 4)
//		#expect(v2 != nil)
//		#expect(v2!.count == 4)
//		#expect(v2![0] == 7.0)
//		#expect(v2![3] == 7.0)
//		
//			// Random vector
//		let v3 = VectorN<Double>.random(dimension: 5)
//		#expect(v3 != nil)
//		#expect(v3!.count == 5)
//		#expect(v3!.isFinite == true)
//		
//			// Random vector in range
//		let v4 = VectorN<Double>.random(in: -1.0...1.0, dimension: 3)
//		#expect(v4 != nil)
//		#expect(v4!.count == 3)
//		#expect(v4!.min >= -1.0)
//		#expect(v4!.max <= 1.0)
//	}
	
		// MARK: - Scalar Type Conformance Tests
	
	@Test("Double as VectorSpace")
	func doubleAsVectorSpace() {
		let d1: Double = 3.0
		let d2: Double = 4.0
		
			// Operations
		#expect(abs(d1 + d2 - 7.0) < 1e-6)
		#expect(abs(2.0 * d1 - 6.0) < 1e-6)
		#expect(abs(-d1 - (-3.0)) < 1e-6)

			// Norm
		#expect(abs(d1.norm - 3.0) < 1e-6)

			// Dot product
		#expect(abs(d1.dot(d2) - 12.0) < 1e-6)

			// Array conversion
		#expect(d1.toArray().count == 1 && abs(d1.toArray()[0] - 3.0) < 1e-6)
		#expect(abs((Double.fromArray([5.0]) ?? .nan) - 5.0) < 1e-6)
		#expect(Double.fromArray([1.0, 2.0]) == nil)
		
			// Dimension
		#expect(Double.dimension == 1)
		
			// Is finite
		#expect(d1.isFinite == true)
		#expect(Double.infinity.isFinite == false)
	}
	
	@Test("Float as VectorSpace")
	func floatAsVectorSpace() {
		let f1: Float = 3.0
		let f2: Float = 4.0
		
		#expect(abs(f1 + f2 - 7.0) < 1e-6)
		#expect(abs(2.0 * f1 - 6.0) < 1e-6)
		#expect(abs(f1.norm - 3.0) < 1e-6)
		#expect(abs(f1.dot(f2) - 12.0) < 1e-6)
		#expect(Float.dimension == 1)
	}
	
		// MARK: - Performance Tests
	
//	@Test("VectorN performance", .tags(.performance))
//	func vectorNPerformance() async throws {
//		let size = 1000
//		let v1 = VectorN<Double>(repeating: 1.0, count: size)
//		let v2 = VectorN<Double>(repeating: 2.0, count: size)
//		
//			// Measure addition
//		try await #measure(iterations: 1000) {
//			_ = v1 + v2
//		}
//		
//			// Measure dot product
//		try await #measure(iterations: 1000) {
//			_ = v1.dot(v2)
//		}
//		
//			// Measure norm
//		try await #measure(iterations: 1000) {
//			_ = v1.norm
//		}
//	}
//	
//	@Test("Vector2D vs VectorN performance", .tags(.performance))
//	func vector2DvsVectorNPerformance() async throws {
//		let iterations = 10000
//		
//			// Vector2D
//		let v2d1 = Vector2D<Double>(x: 1.0, y: 2.0)
//		let v2d2 = Vector2D<Double>(x: 3.0, y: 4.0)
//		
//		let v2dTime = try await #measure(iterations: iterations) {
//			_ = v2d1 + v2d2
//			_ = v2d1.dot(v2d2)
//			_ = v2d1.norm
//		}
//		
//			// VectorN with 2 dimensions
//		let vn1 = VectorN<Double>([1.0, 2.0])
//		let vn2 = VectorN<Double>([3.0, 4.0])
//		
//		let vnTime = try await #measure(iterations: iterations) {
//			_ = vn1 + vn2
//			_ = vn1.dot(vn2)
//			_ = vn1.norm
//		}
//		
//			// Vector2D should be faster due to compile-time optimization
//		#expect(v2dTime < vnTime * 1.5)  // Allow some overhead
//	}
	
		// MARK: - Edge Cases Tests
	
//	@Test("Empty vector operations")
//	func emptyVectorOperations() {
//		let empty = VectorN<Double>.zero
//		
//		#expect(empty.count == 0)
//		#expect(empty.norm == 0.0)
//		#expect(empty.sum == 0.0)
//		#expect(empty.mean == 0.0)
//		#expect(empty.standardDeviation == 0.0)
//		
//			// Operations with empty vectors
//		let result = empty + empty
//		#expect(result.count == 0)
//		
//		let dot = empty.dot(empty)
//		#expect(dot == 0.0)
//	}
	
	@Test("Vector with NaN and infinity")
	func vectorWithNaNandInfinity() {
		let v = VectorN<Double>([1.0, .nan, .infinity, 4.0])
		
		#expect(v.isFinite == false)
		#expect(v.norm.isNaN == true)  // Norm with NaN is NaN
		
			// Operations with NaN
		let v2 = VectorN<Double>([2.0, 3.0, 4.0, 5.0])
		let sum = v + v2
		#expect(abs(sum[0] - 3.0) < 1e-6)  // 1 + 2
		#expect(sum[1].isNaN == true)  // NaN + 3
		#expect(sum[2].isInfinite == true)  // ∞ + 4
		#expect(abs(sum[3] - 9.0) < 1e-6)  // 4 + 5
	}
	
//	@Test("Large dimension vectors")
//	func largeDimensionVectors() {
//		let dimension = 10000
//		let v1 = VectorN<Double>(repeating: 1.0, count: dimension)
//		let v2 = VectorN<Double>(repeating: 2.0, count: dimension)
//		
//			// Basic operations should work
//		let sum = v1 + v2
//		#expect(sum.count == dimension)
//		#expect(sum[0] == 3.0)
//		#expect(sum[dimension - 1] == 3.0)
//		
//		let dot = v1.dot(v2)
//		#expect(dot == Double(dimension) * 2.0)  // 1*2 for each component
//		
//		let norm = v1.norm
//		#expect(abs(norm - sqrt(Double(dimension))) < 1e-10)
//		
//			// Statistics
//		#expect(v1.sum == Double(dimension))
//		#expect(v1.mean == 1.0)
//		#expect(v1.standardDeviation == 0.0)
//	}
	
	@Test("Vector equality and hashability")
	func vectorEqualityAndHashability() {
		let v1 = VectorN<Double>([1.0, 2.0, 3.0])
		let v2 = VectorN<Double>([1.0, 2.0, 3.0])
		let v3 = VectorN<Double>([1.0, 2.0, 4.0])
		let v4 = VectorN<Double>([1.0, 2.0])
		
			// Equality
		#expect(v1 == v2)
		#expect(v1 != v3)
		#expect(v1 != v4)
		
			// Hash values should match for equal vectors
		#expect(v1.hashValue == v2.hashValue)
		#expect(v1.hashValue != v3.hashValue)
		
			// Can be used in sets
		var set = Set<VectorN<Double>>()
		set.insert(v1)
		set.insert(v2)  // Should not add duplicate
		set.insert(v3)
		#expect(set.count == 2)
	}
	
	@Test("Vector copy-on-write semantics")
	func vectorCopyOnWrite() {
		var v1 = VectorN<Double>([1.0, 2.0, 3.0])
		var v2 = v1  // Should share storage initially
		
			// Modify v2 - should trigger copy
		v2[0] = 99.0
		
		#expect(abs(v1[0] - 1.0) < 1e-6)  // v1 unchanged
		#expect(abs(v2[0] - 99.0) < 1e-6) // v2 modified

			// Modify v1 - should not affect v2
		v1[1] = 88.0
		#expect(abs(v1[1] - 88.0) < 1e-6)
		#expect(abs(v2[1] - 2.0) < 1e-6)  // v2 unchanged
	}
	
	@Test("Vector serialization (Codable)")
	func vectorSerialization() throws {
		let original = VectorN<Double>([1.0, 2.0, 3.0, 4.0])
		
			// Encode
		let encoder = JSONEncoder()
		let data = try encoder.encode(original)
		
			// Decode
		let decoder = JSONDecoder()
		let decoded = try decoder.decode(VectorN<Double>.self, from: data)
		
		#expect(decoded == original)
		#expect(decoded.count == 4)
		#expect(abs(decoded[0] - 1.0) < 1e-6)
		#expect(abs(decoded[3] - 4.0) < 1e-6)

			// Test Vector2D serialization
		let v2d = Vector2D<Double>(x: 1.5, y: 2.5)
		let v2dData = try encoder.encode(v2d)
		let decodedV2D = try decoder.decode(Vector2D<Double>.self, from: v2dData)

		#expect(abs(decodedV2D.x - 1.5) < 1e-6)
		#expect(abs(decodedV2D.y - 2.5) < 1e-6)
	}
	
//	@Test("Vector description and debug strings")
//	func vectorDescription() {
//		let v = VectorN<Double>([1.0, 2.0, 3.0])
//		let description = v.description
//		let debugDescription = v.debugDescription
//		
//		#expect(description.contains("VectorN"))
//		#expect(description.contains("1.0"))
//		#expect(description.contains("3.0"))
//		#expect(debugDescription.contains("VectorN"))
//		
//			// Vector2D description
//		let v2d = Vector2D<Double>(x: 1.0, y: 2.0)
//		let v2dDescription = v2d.description
//		#expect(v2dDescription.contains("Vector2D"))
//		#expect(v2dDescription.contains("x: 1.0"))
//		#expect(v2dDescription.contains("y: 2.0"))
//	}
	
		// MARK: - Cross Product Tests (3D specific)
	
	@Test("Vector3D cross product")
	func vector3DCrossProduct() {
		let v1 = Vector3D<Double>(x: 1.0, y: 0.0, z: 0.0)
		let v2 = Vector3D<Double>(x: 0.0, y: 1.0, z: 0.0)
		
		let cross = v1.cross(v2)
		#expect(abs(cross.x - 0.0) < 1e-6)
		#expect(abs(cross.y - 0.0) < 1e-6)
		#expect(abs(cross.z - 1.0) < 1e-6)  // Right-hand rule: x × y = z

			// Test anticommutativity: v1 × v2 = -(v2 × v1)
		let crossReverse = v2.cross(v1)
		#expect(abs(crossReverse.x - 0.0) < 1e-6)
		#expect(abs(crossReverse.y - 0.0) < 1e-6)
		#expect(abs(crossReverse.z - (-1.0)) < 1e-6)

			// Parallel vectors have zero cross product
		let v3 = Vector3D<Double>(x: 2.0, y: 0.0, z: 0.0)
		let parallelCross = v1.cross(v3)
		#expect(abs(parallelCross.x - 0.0) < 1e-6)
		#expect(abs(parallelCross.y - 0.0) < 1e-6)
		#expect(abs(parallelCross.z - 0.0) < 1e-6)
	}
	
	@Test("Vector3D triple product")
	func vector3DTripleProduct() {
		let a = Vector3D<Double>(x: 1.0, y: 0.0, z: 0.0)  // i
		let b = Vector3D<Double>(x: 0.0, y: 1.0, z: 0.0)  // j
		let c = Vector3D<Double>(x: 0.0, y: 0.0, z: 1.0)  // k

		// Scalar triple product: a · (b × c)
		let triple = a.tripleProduct(b, c)
		#expect(abs(triple - 1.0) < 1e-6)  // Should be 1 for right-handed basis

		// Vector triple product: a × (b × c)
		// For a=i, b=j, c=k: b×c = i, so a×(b×c) = i×i = 0
		let vectorTriple = a.vectorTripleProduct(b, c)
		#expect(abs(vectorTriple.x - 0.0) < 1e-6)
		#expect(abs(vectorTriple.y - 0.0) < 1e-6)  // a × (b × c) = b(a·c) - c(a·b) = j*0 - k*0 = 0
		#expect(abs(vectorTriple.z - 0.0) < 1e-6)

		// Test with different vectors to get non-zero result
		// For a=i, b=j, c=i: a×(b×c) = a×(j×i) = a×(-k) = j = (0,1,0)
		let c2 = Vector3D<Double>(x: 1.0, y: 0.0, z: 0.0)  // i (same as a)
		let vectorTriple2 = a.vectorTripleProduct(b, c2)
		#expect(abs(vectorTriple2.x - 0.0) < 1e-6)
		#expect(abs(vectorTriple2.y - 1.0) < 1e-6)  // Verified: b(a·c) - c(a·b) = j*1 - i*0 = j
		#expect(abs(vectorTriple2.z - 0.0) < 1e-6)
	}
	
		// MARK: - Linear Interpolation Tests
	
	@Test("Linear interpolation")
	func linearInterpolation() {
		let start = VectorN<Double>([0.0, 0.0])
		let end = VectorN<Double>([10.0, 20.0])
		
			// t = 0
		let lerp0 = VectorN<Double>.lerp(from: start, to: end, t: 0.0)
		#expect(lerp0 == start)
		
			// t = 1
		let lerp1 = VectorN<Double>.lerp(from: start, to: end, t: 1.0)
		#expect(lerp1 == end)
		
			// t = 0.5
		let lerpMid = VectorN<Double>.lerp(from: start, to: end, t: 0.5)
		#expect(abs(lerpMid[0] - 5.0) < 1e-6)
		#expect(abs(lerpMid[1] - 10.0) < 1e-6)

			// t outside [0, 1] - extrapolation
		let extrapolate = VectorN<Double>.lerp(from: start, to: end, t: 2.0)
		#expect(abs(extrapolate[0] - 20.0) < 1e-6)
		#expect(abs(extrapolate[1] - 40.0) < 1e-6)
	}
	
		// MARK: - Distance and Similarity Tests
	
	@Test("Distance metrics")
	func distanceMetrics() {
		let v1 = VectorN<Double>([0.0, 0.0])
		let v2 = VectorN<Double>([3.0, 4.0])
		
			// Euclidean distance
		let euclidean = v1.distance(to: v2)
		#expect(abs(euclidean - 5.0) < 1e-6)  // 3-4-5 triangle

			// Squared distance (faster, avoids sqrt)
		let squared = v1.squaredDistance(to: v2)
		#expect(abs(squared - 25.0) < 1e-6)

			// Manhattan distance
		let manhattan = v1.manhattanDistance(to: v2)
		#expect(abs(manhattan - 7.0) < 1e-6)  // 3 + 4

			// Chebyshev distance
		let chebyshev = v1.chebyshevDistance(to: v2)
		#expect(abs(chebyshev - 4.0) < 1e-6)  // max(3, 4)
	}
	
	@Test("Cosine similarity")
	func cosineSimilarity() {
		let v1 = VectorN<Double>([1.0, 0.0])
		let v2 = VectorN<Double>([0.0, 1.0])
		let v3 = VectorN<Double>([2.0, 0.0])
		
			// Orthogonal vectors
		let simOrtho = v1.cosineSimilarity(with: v2)
		#expect(abs(simOrtho) < 1e-10)  // Should be 0
		
			// Parallel vectors (same direction)
		let simParallel = v1.cosineSimilarity(with: v3)
		#expect(abs(simParallel - 1.0) < 1e-10)  // Should be 1
		
			// Anti-parallel vectors
		let v4 = VectorN<Double>([-1.0, 0.0])
		let simAntiParallel = v1.cosineSimilarity(with: v4)
		#expect(abs(simAntiParallel - (-1.0)) < 1e-10)  // Should be -1
		
			// 45 degree angle
		let v5 = VectorN<Double>([1.0, 1.0]).normalized()
		let sim45 = v1.cosineSimilarity(with: v5)
		#expect(abs(sim45 - cos(.pi/4)) < 1e-10)
	}
	
		// MARK: - Special Vector Types Tests
	
	@Test("Basis vectors")
	func basisVectors() {
			// Standard basis for 3D
		let e1 = VectorN<Double>.unitVector(dimension: 3, direction: 0)
		let e2 = VectorN<Double>.unitVector(dimension: 3, direction: 1)
		let e3 = VectorN<Double>.unitVector(dimension: 3, direction: 2)
		
		#expect(abs(e1[0] - 1.0) < 1e-6)
		#expect(abs(e1[1] - 0.0) < 1e-6)
		#expect(abs(e1[2] - 0.0) < 1e-6)

		#expect(abs(e2[0] - 0.0) < 1e-6)
		#expect(abs(e2[1] - 1.0) < 1e-6)
		#expect(abs(e2[2] - 0.0) < 1e-6)

		#expect(abs(e3[0] - 0.0) < 1e-6)
		#expect(abs(e3[1] - 0.0) < 1e-6)
		#expect(abs(e3[2] - 1.0) < 1e-6)

			// Orthogonality
		#expect(abs(e1.dot(e2) - 0.0) < 1e-6)
		#expect(abs(e1.dot(e3) - 0.0) < 1e-6)
		#expect(abs(e2.dot(e3) - 0.0) < 1e-6)
		
			// Unit length
		#expect(abs(e1.norm - 1.0) < 1e-10)
		#expect(abs(e2.norm - 1.0) < 1e-10)
		#expect(abs(e3.norm - 1.0) < 1e-10)
	}
	
	@Test("Ones and zeros vectors")
	func onesAndZerosVectors() {
		let dimension = 5
		
			// Zero vector
		let zero = VectorN<Double>.zero
		#expect(zero.count == 0)  // Default zero is empty
		
		let sizedZero = VectorN<Double>.withDimension(dimension)
		#expect(sizedZero.count == dimension)
		#expect(abs(sizedZero.sum - 0.0) < 1e-6)
		
			// Ones vector
		let ones = VectorN<Double>.filled(with: 1.0, dimension: dimension)
		#expect(ones != nil)
		#expect(ones!.count == dimension)
		#expect(ones!.sum == Double(dimension))
		
			// Custom filled vector
		let sevens = VectorN<Double>.filled(with: 7.0, dimension: 3)
		#expect(sevens != nil)
		#expect(abs(sevens![0] - 7.0) < 1e-6)
		#expect(abs(sevens![1] - 7.0) < 1e-6)
		#expect(abs(sevens![2] - 7.0) < 1e-6)
	}
	
		// MARK: - Error Handling Tests
	
	@Test("Error conditions and edge cases")
	func errorConditions() {
			// Division by zero in elementwise division
		let v1 = VectorN<Double>([1.0, 2.0])
		let v2 = VectorN<Double>([0.0, 0.0])
		
		let divided = v1.elementwiseDivide(by: v2)
		#expect(divided[0].isInfinite == true)  // 1/0 = ∞
		#expect(divided[1].isInfinite == true)  // 2/0 = ∞
		
			// Normalization of zero vector
		let zero = VectorN<Double>.zero
		let normalizedZero = zero.normalized()
		#expect(normalizedZero.count == 0)  // Returns zero vector of same dimension
	#expect(abs(normalizedZero[0] - 0.0) < 1e-6)
	#expect(abs(normalizedZero[1] - 0.0) < 1e-6)

			// Angle with zero vector
		let angleWithZero = v1.angle(with: zero)
		#expect(abs(angleWithZero - 0.0) < 1e-6)  // Defined as 0

			// Projection onto zero vector
		let projection = v1.projection(onto: zero)
	#expect(projection.count == 2)  // Returns zero vector of same dimension
	#expect(abs(projection[0] - 0.0) < 1e-6)
	#expect(abs(projection[1] - 0.0) < 1e-6)

			// Cosine similarity with zero vector
		let cosineWithZero = v1.cosineSimilarity(with: zero)
		#expect(abs(cosineWithZero - 0.0) < 1e-6)  // Defined as 0
	}
	
		// MARK: - Type Safety Tests
	
	@Test("Type safety and generic constraints")
	func typeSafety() {
			// Should compile with different numeric types
		let doubleVec = VectorN<Double>([1.0, 2.0])
		let floatVec = VectorN<Float>([1.0, 2.0])
//		let cgFloatVec = VectorN<CGFloat>([1.0, 2.0])
		
			// All should support basic operations
//		#expect(doubleVec.norm is Double)
//		#expect(floatVec.norm is Float)
//		#expect(cgFloatVec.norm is CGFloat)
		
			// Mixing types should not compile (type safety)
			// Uncommenting this should cause a compile error:
//			 let mixed = doubleVec + floatVec  // Should not compile
		
			// But conversion should work
		let convertedFloat = VectorN<Float>(doubleVec.toArray().map { Float($0) })
		let convertedDouble = VectorN<Double>(floatVec.toArray().map { Double($0) })
		#expect(convertedFloat.count == 2)
		#expect(convertedDouble.count == 2)
	}
	
	@Test("Sendable conformance")
	func sendableConformance() async {
			// Vector types should be Sendable for concurrency
		let vector = VectorN<Double>([1.0, 2.0, 3.0])
		
			// Can be passed to async task
		let task = Task {
			return vector.norm
		}
		
		let norm = await task.value
		#expect(abs(norm - sqrt(14.0)) < 1e-6)
		
			// Vector2D should also be Sendable
		let v2d = Vector2D<Double>(x: 1.0, y: 2.0)
		let v2dTask = Task {
			return v2d.norm
		}
		
		let v2dNorm = await v2dTask.value
		#expect(abs(v2dNorm - sqrt(5.0)) < 1e-6)
	}
	
	@Test(.disabled("Integration with existing math functions"))
	func integrationWithMathFunctions() {
			// Test that vectors work with existing BusinessMath functions
		let v = VectorN<Double>([1.0, 2.0, 3.0])
		
			// Apply element-wise functions
		let squared = v.hadamard(v)
		#expect(abs(squared[0] - 1.0) < 1e-6)
		#expect(abs(squared[1] - 4.0) < 1e-6)
		#expect(abs(squared[2] - 9.0) < 1e-6)

			// Use in optimization context (placeholder for future tests)
		let gradient = VectorN<Double>([0.1, -0.2, 0.3])
		let step = 0.1 * gradient
		#expect(abs(step[0] - 0.01) < 1e-6)
		#expect(abs(step[1] - (-0.02)) < 1e-6)
		#expect(abs(step[2] - 0.03) < 1e-6)
		
			// Test with statistical functions
		let data = VectorN<Double>([1.0, 2.0, 3.0, 4.0, 5.0])
		let mean = data.mean
		let stdDev = data.standardDeviation()
		let tolerance = 1.0 / 100000000000.0
		let value = abs(stdDev - sqrt(2.5))
		#expect(abs(mean - 3.0) < 1e-6)
		#expect(value < tolerance)
		
			// Test normalization in machine learning context
		let features = VectorN<Double>([100.0, 0.001, 5000.0])
		let normalized = features.normalized()
		#expect(abs(normalized.norm - 1.0) < 1e-10)
		
			// All components should be scaled proportionally
		let ratio = normalized[0] / features[0]
		#expect(abs(normalized[1] / features[1] - ratio) < 1e-10)
		#expect(abs(normalized[2] / features[2] - ratio) < 1e-10)
	}
	
	@Test("Integration with gradient descent simulation")
	func integrationWithGradientDescent() {
			// Simple quadratic function: f(x) = x²
			// Gradient: ∇f(x) = 2x
		let learningRate = 0.1
		
			// Start at x = 5.0
		var x = VectorN<Double>([5.0])
		let _ = VectorN<Double>([0.0])  // Minimum at x = 0
		
			// Perform gradient descent steps
		for _ in 0..<50 {
			let gradient = VectorN<Double>([2.0 * x[0]])  // ∇f(x) = 2x
			x = x - learningRate * gradient
		}
		
			// Should converge near 0
		#expect(abs(x[0]) < 0.01)
		
			// Multi-dimensional test: f(x,y) = x² + y²
			// Gradient: ∇f(x,y) = [2x, 2y]
		var point = VectorN<Double>([3.0, 4.0])
		
		for _ in 0..<50 {
			let gradient = VectorN<Double>([2.0 * point[0], 2.0 * point[1]])
			point = point - learningRate * gradient
		}
		
			// Should converge near origin
		#expect(point.norm < 0.01)
	}
	
	@Test("Integration with linear algebra operations")
	func integrationWithLinearAlgebra() {
			// Test matrix-vector multiplication for linear transformations
		let vector = VectorN<Double>([1.0, 2.0])
		
			// Rotation matrix 90 degrees counterclockwise
		let rotation90 = [
			VectorN<Double>([0.0, -1.0]),
			VectorN<Double>([1.0, 0.0])
		]
		
		let rotated = rotation90.map({ vector.dot($0) })
//		#expect(rotated != nil)
		#expect(abs(rotated[0] - (-2.0)) < 1e-6)  // 0*1 + (-1)*2
		#expect(abs(rotated[1] - 1.0) < 1e-6)   // 1*1 + 0*2
		
			// Scaling matrix
		let scaling = [
			VectorN<Double>([2.0, 0.0]),
			VectorN<Double>([0.0, 3.0])
		]
		
		let scaled = scaling.map({ vector.dot($0) })
//		#expect(scaled != nil)
		#expect(abs(scaled[0] - 2.0) < 1e-6)  // 2*1 + 0*2
		#expect(abs(scaled[1] - 6.0) < 1e-6)  // 0*1 + 3*2
		
			// Test outer product for covariance-like calculation
		let v1 = VectorN<Double>([1.0, 2.0, 3.0])
		let v2 = VectorN<Double>([4.0, 5.0, 6.0])
		let outer = v1.outerProduct(with: v2)
		
			// Should produce 3x3 matrix
		#expect(outer.count == 3)
		#expect(outer[0].count == 3)
		#expect(abs(outer[0][0] - 4.0) < 1e-6)  // 1*4
		#expect(abs(outer[2][2] - 18.0) < 1e-6) // 3*6
	}
	
	@Test("Integration with probability distributions", .disabled("Statistical test with random variation - needs larger sample size or deterministic seeding"))
	func integrationWithProbabilityDistributions() {
			// Generate random vectors for Monte Carlo simulation
		let dimension = 3
		let sampleSize = 1000
		
		var samples: [VectorN<Double>] = []
		var sum = VectorN<Double>.withDimension(dimension)
		
			// Generate samples from uniform distribution
		for _ in 0..<sampleSize {
			if let sample = VectorN<Double>.random(in: 0...1) {
				samples.append(sample)
				sum = sum + sample
			}
		}
		
			// Calculate sample mean
		let sampleMean = (1.0 / Double(sampleSize)) * sum
		
			// Mean should be near 0.5 for uniform [0,1]
		#expect(abs(sampleMean.mean - 0.5) < 0.2)
		
			// Calculate sample covariance (simplified)
		var covariance = VectorN<Double>.withDimension(dimension)
		for sample in samples {
			let centered = sample - sampleMean
			covariance = covariance + centered.hadamard(centered)
		}
		covariance = (1.0 / Double(sampleSize - 1)) * covariance
		
			// Variance of each component should be near 1/12 ≈ 0.0833
		#expect(abs(covariance.mean - 1.0/12.0) < 0.05)
	}
	
		// MARK: - Real-world Use Case Tests
	
	@Test("Portfolio optimization simulation")
	func portfolioOptimizationSimulation() {
			// Simulate portfolio with 3 assets
		let returns = VectorN<Double>([0.08, 0.12, 0.05])  // Expected returns
		let weights = VectorN<Double>([0.4, 0.4, 0.2])     // Portfolio weights
		
			// Expected portfolio return: weighted sum
		let expectedReturn = returns.dot(weights)
		#expect(abs(expectedReturn - 0.090) < 1e-10)  // 0.4*0.08 + 0.4*0.12 + 0.2*0.05 = 0.090
		
			// Simulate covariance matrix using volatilities and correlations
		let volatilities = VectorN<Double>([0.15, 0.20, 0.10])  // Standard deviations

		// Build correlation matrix (symmetric)
		// Asset 0-1: 0.3, Asset 0-2: 0.1, Asset 1-2: 0.2
		let correlationMatrix: [[Double]] = [
			[1.0, 0.3, 0.1],  // Asset 0 correlations
			[0.3, 1.0, 0.2],  // Asset 1 correlations
			[0.1, 0.2, 1.0]   // Asset 2 correlations
		]

		// Build covariance matrix: Cov(i,j) = σ_i * σ_j * ρ_ij
		var covarianceMatrix: [[Double]] = Array(repeating: Array(repeating: 0.0, count: 3), count: 3)
		for i in 0..<3 {
			for j in 0..<3 {
				covarianceMatrix[i][j] = volatilities[i] * volatilities[j] * correlationMatrix[i][j]
			}
		}

		// Calculate portfolio variance: σ²_p = Σᵢ Σⱼ w_i w_j Cov(i,j)
		var variance = 0.0
		for i in 0..<3 {
			for j in 0..<3 {
				variance += weights[i] * weights[j] * covarianceMatrix[i][j]
			}
		}

		#expect(variance > 0)

		// Compare to undiversified case (perfect correlation, ρ = 1.0)
		// Undiversified variance: (Σ w_i * σ_i)² - the square of the sum, not sum of squares!
		let weightedVolSum = weights.dot(volatilities)  // Σ w_i * σ_i
		let undiversifiedVariance = weightedVolSum * weightedVolSum  // (Σ w_i * σ_i)²

		// With imperfect correlations (< 1.0), diversification reduces variance
		#expect(variance < undiversifiedVariance, "Diversification should reduce portfolio variance")
		
		// Weights already sum to 1.0 (0.4 + 0.4 + 0.2 = 1.0)
	#expect(abs(weights.sum - 1.0) < 1e-10)
	}
}

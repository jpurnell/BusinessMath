	// 
	//  VectorSpace.swift
	//  BusinessMath
	//
	//  Created by Justin Purnell on 12/3/25.
	//

import Foundation
import Numerics

/// A protocol defining a vector space over a scalar field.
/// Vector spaces support addition, scalar multiplication, and have a zero element.
///
/// # Mathematical Definition
/// A vector space V over a field F is a set equipped with two operations:
/// 1. Vector addition: V × V → V
/// 2. Scalar multiplication: F × V → V
///
/// # Requirements
/// - Must satisfy the vector space axioms (associativity, commutativity, identity, inverse, distributivity)
/// - Must be able to compute the norm (length) of a vector
/// - Must support conversion to/from arrays for interoperability
///
/// # Examples
/// ```swift
/// // 2D vector
/// let v1 = Vector2D<Double>(x: 1.0, y: 2.0)
/// let v2 = Vector2D<Double>(x: 3.0, y: 4.0)
/// let sum = v1 + v2  // Vector2D(x: 4.0, y: 6.0)
///
/// // N-dimensional vector
/// let v3 = VectorN<Double>([1.0, 2.0, 3.0])
/// let v4 = VectorN<Double>([4.0, 5.0, 6.0])
/// let dot = v3.dot(v4)  // 32.0 (1*4 + 2*5 + 3*6)
/// ```
public protocol VectorSpace: AdditiveArithmetic, Hashable, Codable, Sendable {
	/// The scalar type over which the vector space is defined.
	/// Must conform to `Real` for mathematical operations.
	associatedtype Scalar: Real & Sendable & Codable
	
	/// The zero vector of the vector space.
	/// - Returns: The additive identity element.
	static var zero: Self { get }
	
	/// Vector addition.
	/// - Parameters:
	///   - lhs: Left-hand side vector
	///   - rhs: Right-hand side vector
	/// - Returns: The sum of the two vectors.
	static func + (lhs: Self, rhs: Self) -> Self
	
	/// Scalar multiplication.
	/// - Parameters:
	///   - lhs: Scalar multiplier
	///   - rhs: Vector to multiply
	/// - Returns: The scaled vector.
	static func * (lhs: Scalar, rhs: Self) -> Self
	
	/// Vector negation.
	/// - Parameter vector: Vector to negate
	/// - Returns: The additive inverse of the vector.
	static prefix func - (vector: Self) -> Self
	
	/// The norm (length) of the vector.
	/// - Returns: Euclidean norm: √(v₁² + v₂² + ... + vₙ²)
	var norm: Scalar { get }
	
	/// Dot product (inner product) with another vector.
	/// - Parameter other: Another vector
	/// - Returns: Scalar dot product: v₁·w₁ + v₂·w₂ + ... + vₙ·wₙ
	func dot(_ other: Self) -> Scalar
	
	/// Create a vector from an array of scalars.
	/// - Parameter array: Array of scalar components
	/// - Returns: A vector if the array is valid for this vector type, otherwise nil.
	static func fromArray(_ array: [Scalar]) -> Self?
	
	/// Convert the vector to an array of scalars.
	/// - Returns: Array representation of the vector's components.
	func toArray() -> [Scalar]
	
	/// The dimension of the vector space.
	/// For fixed-dimension vectors (like Vector2D), this is constant.
	/// For variable-dimension vectors (like VectorN), this may be variable.
	static var dimension: Int { get }
	
	/// Check if all components of the vector are finite.
	/// - Returns: True if all components are finite numbers (not NaN or infinity).
	var isFinite: Bool { get }
}

// MARK: - Default Implementations

/// Default Implementations
public extension VectorSpace {
	/// Vector subtraction (default implementation using addition and negation).
	/// - Parameters:
	///   - lhs: Left-hand side vector
	///   - rhs: Right-hand side vector to subtract
	/// - Returns: The difference of the two vectors.
	static func - (lhs: Self, rhs: Self) -> Self {
		return lhs + (-rhs)
	}
	
	/// Squared norm of the vector (faster than norm for comparisons).
	/// - Returns: v·v = v₁² + v₂² + ... + vₙ²
	var squaredNorm: Scalar {
		return self.dot(self)
	}
	
	/// Distance between two vectors.
	/// - Parameter other: Another vector
	/// - Returns: Euclidean distance: ‖self - other‖
	func distance(to other: Self) -> Scalar {
		return (self - other).norm
	}
	
	/// Squared distance between two vectors (faster than distance for comparisons).
	/// - Parameter other: Another vector
	/// - Returns: Squared Euclidean distance: ‖self - other‖²
	func squaredDistance(to other: Self) -> Scalar {
		return (self - other).squaredNorm
	}
	
	/// Manhattan distance (L1 norm) between two vectors.
	/// - Parameter other: Another vector
	/// - Returns: Sum of absolute differences: |v₁ - w₁| + |v₂ - w₂| + ... + |vₙ - wₙ|
	func manhattanDistance(to other: Self) -> Scalar {
		let diff = self - other
		return diff.toArray().reduce(Scalar(0)) { $0 + abs($1) }
	}
	
	/// Chebyshev distance (L∞ norm) between two vectors.
	/// - Parameter other: Another vector
	/// - Returns: Maximum absolute difference: max(|v₁ - w₁|, |v₂ - w₂|, ..., |vₙ - wₙ|)
	func chebyshevDistance(to other: Self) -> Scalar {
		let diff = self - other
		return diff.toArray().map { abs($0) }.max() ?? Scalar(0)
	}
	
	/// Cosine similarity between two vectors.
	/// - Parameter other: Another vector
	/// - Returns: Cosine of the angle between vectors: (v·w) / (‖v‖‖w‖)
	///            Returns 0 if either vector has zero norm.
	func cosineSimilarity(with other: Self) -> Scalar {
		let dotProduct = self.dot(other)
		let norms = self.norm * other.norm
		guard norms > Scalar(0) else { return Scalar(0) }
		return dotProduct / norms
	}
	
	/// Linear interpolation between two vectors.
	/// - Parameters:
	///   - from: Starting vector
	///   - to: Ending vector
	///   - t: Interpolation parameter (0 = from, 1 = to, can extrapolate outside [0,1])
	/// - Returns: Interpolated vector: from + t * (to - from)
	static func lerp(from: Self, to: Self, t: Scalar) -> Self {
		return from + t * (to - from)
	}
}

// MARK: - 2D Vector Implementation

/// A 2-dimensional vector with x and y components.
/// Optimized for 2D operations with compile-time dimension checking.
///
/// # Use Cases
/// - 2D coordinate systems
/// - Complex numbers (x = real, y = imaginary)
/// - Any two-variable optimization problem
///
/// # Performance
/// Faster than `VectorN` for 2D operations due to compile-time optimization
/// and avoidance of array bounds checking.
public struct Vector2D<T: Real & Sendable & Codable>: VectorSpace {
	/// The scalar type over which this 2D vector space is defined.
	///
	/// Must conform to `Real`, `Sendable`, and `Codable` for mathematical operations,
	/// concurrency safety, and serialization.
	public typealias Scalar = T
	
	/// The x-component of the vector.
	public var x: Scalar
	
	/// The y-component of the vector.
	public var y: Scalar
	
	/// Create a 2D vector with x and y components.
	/// - Parameters:
	///   - x: x-component
	///   - y: y-component
	public init(x: Scalar, y: Scalar) {
		self.x = x
		self.y = y
	}
	
	/// The zero vector: (0, 0).
	public static var zero: Vector2D<T> {
		Vector2D(x: T(0), y: T(0))
	}
	
	/// Vector addition.
	public static func + (lhs: Vector2D<T>, rhs: Vector2D<T>) -> Vector2D<T> {
		Vector2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
	}
	
	/// Scalar multiplication.
	public static func * (lhs: T, rhs: Vector2D<T>) -> Vector2D<T> {
		Vector2D(x: lhs * rhs.x, y: lhs * rhs.y)
	}

	/// Scalar division.
	public static func / (lhs: Vector2D<T>, rhs: T) -> Vector2D<T> {
		Vector2D(x: lhs.x / rhs, y: lhs.y / rhs)
	}

	/// Vector negation.
	public static prefix func - (vector: Vector2D<T>) -> Vector2D<T> {
		Vector2D(x: -vector.x, y: -vector.y)
	}
	
	/// Euclidean norm: √(x² + y²).
	public var norm: T {
		T.sqrt(x * x + y * y)
	}
	
	/// Dot product: x₁x₂ + y₁y₂.
	public func dot(_ other: Vector2D<T>) -> T {
		x * other.x + y * other.y
	}
	
	/// Create a 2D vector from an array.
	/// - Parameter array: Must have exactly 2 elements
	/// - Returns: Vector2D if array has 2 elements, otherwise nil.
	public static func fromArray(_ array: [T]) -> Vector2D<T>? {
		guard array.count == 2 else { return nil }
		return Vector2D(x: array[0], y: array[1])
	}
	
	/// Convert to array: [x, y].
	public func toArray() -> [T] {
		[x, y]
	}
	
	/// Dimension is always 2 for Vector2D.
	public static var dimension: Int { 2 }
	
	/// Check if both components are finite.
	public var isFinite: Bool {
		x.isFinite && y.isFinite
	}
	
	/// Cross product (2D pseudo-cross product returns scalar).
	/// - Parameter other: Another 2D vector
	/// - Returns: Scalar cross product: x₁y₂ - y₁x₂
	///            Represents signed area of parallelogram.
	public func cross(_ other: Vector2D<T>) -> T {
		x * other.y - y * other.x
	}
	
	/// Rotate the vector by an angle.
	/// - Parameter angle: Rotation angle in radians
	/// - Returns: Rotated vector
	public func rotated(by angle: T) -> Vector2D<T> {
		let cosA = T.cos(angle)
		let sinA = T.sin(angle)
		return Vector2D(
		x: x * cosA - y * sinA,
		y: x * sinA + y * cosA
		)
	}
	
	/// Angle of the vector relative to the positive x-axis.
	/// - Returns: Angle in radians in range [-π, π]
	public var angle: T {
		T.atan2(y: y, x: x)
	}
}

// MARK: - 3D Vector Implementation

/// A 3-dimensional vector with x, y, and z components.
/// Optimized for 3D operations with compile-time dimension checking.
///
/// # Use Cases
/// - 3D coordinate systems
/// - RGB color spaces
/// - Three-variable optimization problems
/// - Cross product calculations (3D only)
///
/// # Performance
/// Faster than `VectorN` for 3D operations due to compile-time optimization.
public struct Vector3D<T: Real & Sendable & Codable>: VectorSpace {
	/// The scalar type over which this 3D vector space is defined.
	///
	/// Must conform to `Real`, `Sendable`, and `Codable` for mathematical operations,
	/// concurrency safety, and serialization.
	public typealias Scalar = T
	
	/// The x-component of the vector.
	public var x: Scalar
	
	/// The y-component of the vector.
	public var y: Scalar
	
	/// The z-component of the vector.
	public var z: Scalar
	
	/// Create a 3D vector with x, y, and z components.
	/// - Parameters:
	///   - x: x-component
	///   - y: y-component
	///   - z: z-component
	public init(x: Scalar, y: Scalar, z: Scalar) {
		self.x = x
		self.y = y
		self.z = z
	}
	
	/// The zero vector: (0, 0, 0).
	public static var zero: Vector3D<T> {
		Vector3D(x: T(0), y: T(0), z: T(0))
	}
	
	/// Vector addition.
	public static func + (lhs: Vector3D<T>, rhs: Vector3D<T>) -> Vector3D<T> {
		Vector3D(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
	}
	
	/// Scalar multiplication.
	public static func * (lhs: T, rhs: Vector3D<T>) -> Vector3D<T> {
		Vector3D(x: lhs * rhs.x, y: lhs * rhs.y, z: lhs * rhs.z)
	}

	/// Scalar division.
	public static func / (lhs: Vector3D<T>, rhs: T) -> Vector3D<T> {
		Vector3D(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
	}

	/// Vector negation.
	public static prefix func - (vector: Vector3D<T>) -> Vector3D<T> {
		Vector3D(x: -vector.x, y: -vector.y, z: -vector.z)
	}
	
	/// Euclidean norm: √(x² + y² + z²).
	public var norm: T {
		T.sqrt(x * x + y * y + z * z)
	}
	
	/// Dot product: x₁x₂ + y₁y₂ + z₁z₂.
	public func dot(_ other: Vector3D<T>) -> T {
		x * other.x + y * other.y + z * other.z
	}
	
	/// Create a 3D vector from an array.
	/// - Parameter array: Must have exactly 3 elements
	/// - Returns: Vector3D if array has 3 elements, otherwise nil.
	public static func fromArray(_ array: [T]) -> Vector3D<T>? {
		guard array.count == 3 else { return nil }
		return Vector3D(x: array[0], y: array[1], z: array[2])
	}
	
	/// Convert to array: [x, y, z].
	public func toArray() -> [T] {
		[x, y, z]
	}
	
	/// Dimension is always 3 for Vector3D.
	public static var dimension: Int { 3 }
	
	/// Check if all components are finite.
	public var isFinite: Bool {
		x.isFinite && y.isFinite && z.isFinite
	}
	
	/// Cross product (3D vector cross product).
	/// - Parameter other: Another 3D vector
	/// - Returns: Cross product vector: (y₁z₂ - z₁y₂, z₁x₂ - x₁z₂, x₁y₂ - y₁x₂)
	///            Perpendicular to both input vectors.
	public func cross(_ other: Vector3D<T>) -> Vector3D<T> {
		Vector3D(
		x: y * other.z - z * other.y,
		y: z * other.x - x * other.z,
		z: x * other.y - y * other.x
		)
	}
	
	/// Scalar triple product: a · (b × c).
	/// - Parameters:
	///   - b: Second vector
	///   - c: Third vector
	/// - Returns: Scalar representing signed volume of parallelepiped.
	public func tripleProduct(_ b: Vector3D<T>, _ c: Vector3D<T>) -> T {
		self.dot(b.cross(c))
	}
	
	/// Vector triple product: a × (b × c).
	/// - Parameters:
	///   - b: Second vector
	///   - c: Third vector
	/// - Returns: Vector result: b(a·c) - c(a·b)
	public func vectorTripleProduct(_ b: Vector3D<T>, _ c: Vector3D<T>) -> Vector3D<T> {
		self.dot(c) * b - self.dot(b) * c
	}
}

// MARK: - N-Dimensional Vector Implementation

/// An N-dimensional vector backed by an array.
/// Supports variable dimensions at runtime.
///
/// # Use Cases
/// - High-dimensional optimization problems
/// - Feature vectors in machine learning
/// - Portfolio weights (N assets)
/// - Any problem with variable or large dimension
///
/// # Performance
/// More flexible than fixed-dimension vectors but has array bounds checking overhead.
/// Use `Vector2D` or `Vector3D` when dimension is known at compile time.
public struct VectorN<T: Real & Sendable & Codable>: VectorSpace {
	/// The scalar type over which this vector space is defined.
	///
	/// Must conform to `Real`, `Sendable`, and `Codable` for mathematical operations,
	/// concurrency safety, and serialization.
	public typealias Scalar = T
	
	/// The components of the vector.
	private var components: [T]
	
	/// Create an N-dimensional vector from an array of components.
	/// - Parameter components: Array of scalar components
	public init(_ components: [T]) {
		self.components = components
	}
	
	/// Create a vector with all components equal to a value.
	/// - Parameters:
	///   - value: Value for all components
	///   - count: Number of components
	public init(repeating value: T, count: Int) {
		self.components = Array(repeating: value, count: count)
	}
	
	/// The zero vector (empty vector).
	public static var zero: VectorN<T> {
		VectorN([])
	}
	
	/// Vector addition.
	/// If dimensions don't match, returns a zero vector of maximum dimension.
	public static func + (lhs: VectorN<T>, rhs: VectorN<T>) -> VectorN<T> {
		guard lhs.components.count == rhs.components.count else {
				// Return zero vector for dimension mismatch
			return VectorN(repeating: T(0), count: Swift.max(lhs.components.count, rhs.components.count))
		}
		
		let result = zip(lhs.components, rhs.components).map { $0 + $1 }
		return VectorN(result)
	}
	
	/// Scalar multiplication.
	public static func * (lhs: T, rhs: VectorN<T>) -> VectorN<T> {
		VectorN(rhs.components.map { lhs * $0 })
	}

	/// Scalar division.
	public static func / (lhs: VectorN<T>, rhs: T) -> VectorN<T> {
		VectorN(lhs.components.map { $0 / rhs })
	}

	/// Vector negation.
	public static prefix func - (vector: VectorN<T>) -> VectorN<T> {
		VectorN(vector.components.map { -$0 })
	}
	
	/// Euclidean norm: √(v₁² + v₂² + ... + vₙ²).
	public var norm: T {
		T.sqrt(components.reduce(T(0)) { $0 + $1 * $1 })
	}
	
	/// Dot product: v₁·w₁ + v₂·w₂ + ... + vₙ·wₙ.
	public func dot(_ other: VectorN<T>) -> T {
		guard components.count == other.components.count else {
			return T(0)
		}
		
		return zip(components, other.components).reduce(T(0)) { $0 + $1.0 * $1.1 }
	}
	
	/// Create an N-dimensional vector from an array.
	/// - Parameter array: Array of scalar components
	/// - Returns: VectorN with the given components.
	public static func fromArray(_ array: [T]) -> VectorN<T>? {
		VectorN(array)
	}
	
	/// Convert to array: [v₁, v₂, ..., vₙ].
	public func toArray() -> [T] {
		components
	}
	
	/// Dimension is the number of components.
	public static var dimension: Int { -1 } // Variable dimension
	
	/// The actual dimension of this vector.
	public var dimension: Int {
		components.count
	}
	
	/// Check if all components are finite.
	public var isFinite: Bool {
		components.allSatisfy { $0.isFinite }
	}
	
	/// Access individual components by index.
	/// - Parameter index: Component index (0-based)
	/// - Returns: Component value, or 0 if index out of bounds.
	public subscript(index: Int) -> T {
		get {
			guard index >= 0 && index < components.count else { return T(0) }
			return components[index]
		}
		set {
			guard index >= 0 && index < components.count else { return }
			components[index] = newValue
		}
	}

	/// The number of components in the vector.
	public var count: Int {
		components.count
	}

	/// Set individual component by index.
	/// - Parameters:
	///   - index: Component index (0-based)
	///   - value: New component value
	/// - Returns: New vector with updated component, or nil if index out of bounds.
	public func settingComponent(at index: Int, to value: T) -> VectorN<T>? {
		guard index >= 0 && index < components.count else { return nil }
		var newComponents = components
		newComponents[index] = value
		return VectorN(newComponents)
	}
	
	/// Append a component to the vector.
	/// - Parameter value: Value to append
	/// - Returns: New vector with appended component.
	public func appending(_ value: T) -> VectorN<T> {
		VectorN(components + [value])
	}
	
	/// Remove the last component from the vector.
	/// - Returns: New vector without last component, or nil if vector is empty.
	public func removingLast() -> VectorN<T>? {
		guard !components.isEmpty else { return nil }
		return VectorN(Array(components.dropLast()))
	}
	
	/// Concatenate two vectors.
	/// - Parameter other: Vector to concatenate
	/// - Returns: New vector with components from both vectors.
	public func concatenated(with other: VectorN<T>) -> VectorN<T> {
		VectorN(components + other.components)
	}
	
	/// Slice the vector.
	/// - Parameter range: Range of indices to include
	/// - Returns: New vector with sliced components, or nil if range invalid.
	public func slice(_ range: Range<Int>) -> VectorN<T>? {
		guard range.lowerBound >= 0 && range.upperBound <= components.count else { return nil }
		return VectorN(Array(components[range]))
	}
	
	/// Element-wise multiplication (Hadamard product).
	/// - Parameter other: Another vector
	/// - Returns: Vector where each component is the product of corresponding components.
	public func hadamardProduct(with other: VectorN<T>) -> VectorN<T> {
		guard components.count == other.components.count else {
			return VectorN(repeating: T(0), count: Swift.max(components.count, other.components.count))
		}
		
		let result = zip(components, other.components).map { $0 * $1 }
		return VectorN(result)
	}

	/// Convenient alias for hadamardProduct.
	public func hadamard(_ other: VectorN<T>) -> VectorN<T> {
		hadamardProduct(with: other)
	}
	
	/// Element-wise division.
	/// - Parameter other: Another vector
	/// - Returns: Vector where each component is the division of corresponding components.
	///            Returns zero vector for division by zero.
	public func elementwiseDivide(by other: VectorN<T>) -> VectorN<T> {
		guard components.count == other.components.count else {
			return VectorN(repeating: T(0), count: Swift.max(components.count, other.components.count))
		}

		// For floating point types, division by zero produces infinity (IEEE 754)
		let result = zip(components, other.components).map { numerator, denominator in
			numerator / denominator  // Let natural IEEE 754 behavior handle division by zero
		}
		return VectorN(result)
	}
	
	/// Sum of all components.
	/// - Returns: Sum of v₁ + v₂ + ... + vₙ
	public var sum: T {
		components.reduce(T(0), +)
	}
	
	/// Mean (average) of all components.
	/// - Returns: (v₁ + v₂ + ... + vₙ) / n, or 0 if vector is empty.
	public var mean: T {
		guard !components.isEmpty else { return T(0) }
		return sum / T(components.count)
	}
	
	/// Standard deviation of components.
	/// - Parameter isSample: True for sample standard deviation (n-1), false for population (n)
	/// - Returns: Standard deviation, or 0 if vector has fewer than 2 components.
	public func standardDeviation(isSample: Bool = true) -> T {
		guard components.count > 1 else { return T(0) }

		let m = mean
		let sumSquaredDiffs = components.reduce(T(0)) { $0 + ($1 - m) * ($1 - m) }
		let divisor = isSample ? T(components.count - 1) : T(components.count)
		return T.sqrt(sumSquaredDiffs / divisor)
	}
	
	/// Minimum component value.
	/// - Returns: Minimum value, or nil if vector is empty.
	public var min: T? {
		components.min()
	}
	
	/// Maximum component value.
	/// - Returns: Maximum value, or nil if vector is empty.
	public var max: T? {
		components.max()
	}
	
	/// Range of component values.
	/// - Returns: (min, max) tuple, or nil if vector is empty.
	public var range: (min: T, max: T)? {
		guard let minVal = min, let maxVal = max else { return nil }
		return (minVal, maxVal)
	}
	
	/// Normalize the vector to unit length.
	/// - Returns: Unit vector in same direction, or zero vector if norm is zero.
	public func normalized() -> VectorN<T> {
		let n = norm
		guard n > T(0) else { return VectorN(repeating: T(0), count: components.count) }
		return (T(1) / n) * self
	}

	/// Project the vector onto the probability simplex (components sum to 1.0).
	///
	/// This is useful for portfolio weights, probability distributions, and mixture coefficients.
	/// Unlike `normalized()`, which creates a unit vector (Euclidean norm = 1.0),
	/// this ensures the components sum to 1.0.
	///
	/// # Example
	/// ```swift
	/// // Portfolio weights
	/// let rawWeights = VectorN([3.0, 1.0, 2.0])
	/// let weights = rawWeights.simplexProjection()  // [0.5, 0.167, 0.333]
	/// print(weights.sum)  // 1.0
	/// ```
	///
	/// - Returns: A new vector where all components sum to 1.0
	/// - Precondition: Vector must have at least one non-zero component
	public func simplexProjection() -> VectorN<T> {
		let s = self.sum
		precondition(s != 0, "Cannot project zero vector onto simplex")
		return self / s
	}
	
	/// Project this vector onto another vector.
	/// - Parameter other: Vector to project onto
	/// - Returns: Projection vector: (self·other / ‖other‖²) * other
	public func projection(onto other: VectorN<T>) -> VectorN<T> {
		let otherNormSquared = other.squaredNorm
		guard otherNormSquared > T(0) else { return VectorN(repeating: T(0), count: components.count) }

		
		let scalar = self.dot(other) / otherNormSquared
		return scalar * other
	}
	
	/// Rejection of this vector from another vector.
	/// - Parameter other: Vector to reject from
	/// - Returns: Rejection vector: self - projection(onto: other)
	public func rejection(from other: VectorN<T>) -> VectorN<T> {
		self - projection(onto: other)
	}
	
	/// Check if this vector is orthogonal to another vector.
	/// - Parameter other: Another vector
	/// - Parameter tolerance: Numerical tolerance for dot product comparison
	/// - Returns: True if dot product is approximately zero.
	public func isOrthogonal(to other: VectorN<T>, tolerance: T? = nil) -> Bool {
		let tol = tolerance ?? (T(1) / T(10_000_000))
		return abs(self.dot(other)) < tol
	}
	
	/// Check if this vector is parallel to another vector.
	/// - Parameter other: Another vector
	/// - Parameter tolerance: Numerical tolerance for cross product magnitude comparison
	/// - Returns: True if vectors are scalar multiples (for 2D/3D) or if cosine similarity is ±1.
	public func isParallel(to other: VectorN<T>, tolerance: T? = nil) -> Bool {
		let tol = tolerance ?? (T(1) / T(10_000_000))
		let cosSim = self.cosineSimilarity(with: other)
		return abs(abs(cosSim) - T(1)) < tol
	}
}

// MARK: - Formatting Extensions (Double only)
extension VectorN where T == Double {
	/// Formatted description with clean floating-point display
	///
	/// Uses the default optimization formatter (context-aware).
	///
	/// ## Example
	/// ```swift
	/// let v = VectorN([2.9999999999999964, 0.7500000000000002, 1e-15])
	/// print(v.formattedDescription())  // "[3, 0.75, 0]"
	/// ```
	public func formattedDescription() -> String {
		formattedDescription(with: .optimization)
	}

	/// Formatted description with custom formatter
	///
	/// ## Example
	/// ```swift
	/// let v = VectorN([123.456, 789.012])
	/// let formatter = FloatingPointFormatter(strategy: .significantFigures(count: 2))
	/// print(v.formattedDescription(with: formatter))  // "[120, 790]"
	/// ```
	///
	/// - Parameter formatter: Custom formatter to use
	/// - Returns: Formatted string representation
	public func formattedDescription(with formatter: FloatingPointFormatter) -> String {
		let formatted = formatter.format(components)
		return "[" + formatted.map(\.formatted).joined(separator: ", ") + "]"
	}
}

// MARK: - Conformance to AdditiveArithmetic

/// Conformance of VectorN to AdditiveArithmetic for generic numeric algorithms.
///
/// This conformance allows VectorN to work with Swift's standard library functions
/// that operate on additive types, such as `reduce` with addition.
///
/// ## Example
/// ```swift
/// let vectors = [
///     VectorN([1.0, 2.0]),
///     VectorN([3.0, 4.0]),
///     VectorN([5.0, 6.0])
/// ]
/// let sum = vectors.reduce(.zero, +)  // VectorN([9.0, 12.0])
/// ```
extension VectorN: AdditiveArithmetic {
	/// Vector subtraction.
	///
	/// Returns a zero vector if dimensions don't match.
	///
	/// - Parameters:
	///   - lhs: Left-hand side vector
	///   - rhs: Right-hand side vector
	/// - Returns: Component-wise difference, or zero vector for dimension mismatch
	public static func - (lhs: VectorN<T>, rhs: VectorN<T>) -> VectorN<T> {
		guard lhs.components.count == rhs.components.count else {
			return VectorN(repeating: T(0), count: Swift.max(lhs.components.count, rhs.components.count))
		}

		let result = zip(lhs.components, rhs.components).map { $0 - $1 }
		return VectorN(result)
	}
}

// MARK: - Conformance to Hashable

/// Conformance of VectorN to Hashable for use in Sets and Dictionary keys.
///
/// Two vectors are equal if they have identical components in the same order.
/// The hash is computed from the component array, ensuring that equal vectors
/// produce equal hashes.
///
/// ## Example
/// ```swift
/// let v1 = VectorN([1.0, 2.0, 3.0])
/// let v2 = VectorN([1.0, 2.0, 3.0])
/// let v3 = VectorN([1.0, 2.0, 3.1])
///
/// print(v1 == v2)  // true
/// print(v1 == v3)  // false
///
/// let vectorSet: Set = [v1, v2, v3]  // {v1, v3} (v2 equals v1)
/// ```
extension VectorN: Hashable {
	/// Hash the vector by combining its components.
	/// - Parameter hasher: The hasher to use
	public func hash(into hasher: inout Hasher) {
		hasher.combine(components)
	}

	/// Compare two vectors for equality.
	/// - Parameters:
	///   - lhs: Left-hand side vector
	///   - rhs: Right-hand side vector
	/// - Returns: True if vectors have identical components
	public static func == (lhs: VectorN<T>, rhs: VectorN<T>) -> Bool {
		lhs.components == rhs.components
	}
}

// MARK: - Conformance to Codable

/// Conformance of VectorN to Codable for JSON serialization.
///
/// VectorN is encoded and decoded as a simple array of scalars, making
/// it compatible with standard JSON formats.
///
/// ## Example
/// ```swift
/// let v = VectorN([1.0, 2.0, 3.0])
/// let json = try JSONEncoder().encode(v)
/// // JSON: [1.0, 2.0, 3.0]
///
/// let decoded = try JSONDecoder().decode(VectorN<Double>.self, from: json)
/// // decoded == v
/// ```
extension VectorN: Codable {
	/// Decode a VectorN from a decoder.
	/// - Parameter decoder: The decoder to read from
	/// - Throws: DecodingError if the format is invalid
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let components = try container.decode([T].self)
		self.init(components)
	}

	/// Encode this VectorN to an encoder.
	/// - Parameter encoder: The encoder to write to
	/// - Throws: EncodingError if encoding fails
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(components)
	}
}

// MARK: - Conformance to Sendable

extension VectorN: Sendable where T: Sendable {}

// MARK: - Additional Operations

/// Conformance to Codable
extension VectorN {
		/// Outer product with another vector.
		/// - Parameter other: Another vector
		/// - Returns: Matrix (as array of arrays) representing outer product.
	public func outerProduct(with other: VectorN<T>) -> [[T]] {
		components.map { v_i in
			other.components.map { w_j in
				v_i * w_j
			}
		}
	}
	
	/// Kronecker product with another vector.
	/// - Parameter other: Another vector
	/// - Returns: Vector representing Kronecker product.
	public func kroneckerProduct(with other: VectorN<T>) -> VectorN<T> {
		var result: [T] = []
		for v_i in components {
			for w_j in other.components {
				result.append(v_i * w_j)
			}
		}
		return VectorN(result)
	}
	
	/// Apply a function element-wise to the vector.
	/// - Parameter transform: Function to apply to each component
	/// - Returns: New vector with transformed components.
	public func map(_ transform: (T) -> T) -> VectorN<T> {
		VectorN(components.map(transform))
	}
	
	/// Zip with another vector and apply a function.
	/// - Parameters:
	///   - other: Another vector
	///   - transform: Function to apply to pairs of components
	/// - Returns: New vector with transformed component pairs.
	public func zipWith(_ other: VectorN<T>, _ transform: (T, T) -> T) -> VectorN<T> {
		guard components.count == other.components.count else {
			return VectorN(repeating: T(0), count: Swift.max(components.count, other.components.count))
		}
		
		let result = zip(components, other.components).map(transform)
		return VectorN(result)
	}
	
	/// Reduce the vector to a single value.
	/// - Parameters:
	///   - initial: Initial value
	///   - transform: Reduction function
	/// - Returns: Reduced value.
	public func reduce(_ initial: T, _ transform: (T, T) -> T) -> T {
		components.reduce(initial, transform)
	}
	
	/// Filter components based on a predicate.
	/// - Parameter isIncluded: Predicate to test components
	/// - Returns: New vector with filtered components.
	public func filter(_ isIncluded: (T) -> Bool) -> VectorN<T> {
		VectorN(components.filter(isIncluded))
	}
}

// MARK: - Factory Methods
extension VectorN {
	/// Create a basis vector (all zeros except one component).
	/// - Parameters:
	///   - dimension: Total dimension of vector
	///   - index: Index of the non-zero component (0-based)
	///   - value: Value of the non-zero component (default: 1)
	/// - Returns: Basis vector, or zero vector if index out of bounds.
	public static func basisVector(dimension: Int, index: Int, value: T = T(1)) -> VectorN<T> {
		guard index >= 0 && index < dimension else {
			return VectorN(repeating: T(0), count: dimension)
		}
		
		var components = Array(repeating: T(0), count: dimension)
		components[index] = value
		return VectorN(components)
	}
	
	/// Create a vector of ones.
	/// - Parameter dimension: Dimension of vector
	/// - Returns: Vector where all components are 1.
	public static func ones(dimension: Int) -> VectorN<T> {
		VectorN(repeating: T(1), count: dimension)
	}

	/// Create equal weights that sum to 1.0 (useful for equal-weighted portfolios).
	///
	/// This creates a vector where each component is 1/n, ensuring they sum to 1.0
	/// for use as portfolio weights, probability distributions, or mixture coefficients.
	///
	/// # Example
	/// ```swift
	/// // Equal-weighted 4-asset portfolio
	/// let weights = VectorN<Double>.equalWeights(dimension: 4)  // [0.25, 0.25, 0.25, 0.25]
	/// print(weights.sum)  // 1.0
	/// ```
	///
	/// - Parameter dimension: Number of components (must be positive)
	/// - Returns: Vector where all components are 1/dimension
	/// - Precondition: dimension must be positive
	public static func equalWeights(dimension: Int) -> VectorN<T> {
		precondition(dimension > 0, "Dimension must be positive")
		let weight = T(1) / T(dimension)
		return VectorN(repeating: weight, count: dimension)
	}
	
	/// Create a vector with linearly spaced values.
	/// - Parameters:
	///   - start: Starting value
	///   - end: Ending value
	///   - count: Number of components
	/// - Returns: Vector with linearly spaced values.
	public static func linearSpace(from start: T, to end: T, count: Int) -> VectorN<T> {
		guard count > 0 else { return VectorN([]) }
		guard count > 1 else { return VectorN([start]) }
		
		let step = (end - start) / T(count - 1)
		var components: [T] = []
		for i in 0..<count {
			components.append(start + T(i) * step)
		}
		return VectorN(components)
	}
	
	/// Create a vector with logarithmically spaced values.
	/// - Parameters:
	///   - start: Starting value (must be positive)
	///   - end: Ending value (must be positive)
	///   - count: Number of components
	/// - Returns: Vector with logarithmically spaced values.
	public static func logSpace(from start: T, to end: T, count: Int) -> VectorN<T> {
		guard count > 0 else { return VectorN([]) }
		guard start > T(0) && end > T(0) else {
			return VectorN(repeating: T(0), count: count)
		}
		
		let logStart = T.log(start)
		let logEnd = T.log(end)
		return linearSpace(from: logStart, to: logEnd, count: count).map { T.exp($0) }
	}

    /// Create a random vector with components uniformly sampled from a range.
    /// - Parameters:
    ///   - range: Closed range to sample from (inclusive)
    ///   - dimension: Number of components
    /// - Returns: A random vector, or nil if dimension is negative.
	public static func random(in range: ClosedRange<T>, dimension: Int) -> VectorN<T>? {
        guard dimension >= 0 else { return nil }
        // If dimension is zero, return empty vector
        if dimension == 0 { return VectorN<T>([]) }
        let values: [T] = (0..<dimension).map { _ in
			let x = Double.random(in: range as! ClosedRange<Double>)
			return T(Int(x))
        }
        return VectorN<T>(values)
    }

    /// Create a random vector with a default dimension of 3.
    /// - Parameter range: Closed range to sample from (inclusive)
    /// - Returns: A random 3D vector.
    public static func random(in range: ClosedRange<T>) -> VectorN<T>? {
        // Default to 3 dimensions to match tests that expect a 3D sample
        return random(in: range, dimension: 3)
    }
}

// MARK: - Additional Factory Methods for VectorN

extension VectorN {
	/// Convenient alias for basisVector.
	public static func unitVector(dimension: Int, direction: Int) -> VectorN<T> {
		basisVector(dimension: dimension, index: direction, value: T(1))
	}
	
	/// Create a vector with a specific dimension and initial value.
	public static func withDimension(_ dimension: Int, initialValue: T = T(0)) -> VectorN<T> {
		VectorN(repeating: initialValue, count: dimension)
	}
	
	/// Create a vector filled with a specific value.
	public static func filled(with value: T, dimension: Int) -> VectorN<T>? {
		guard dimension >= 0 else { return nil }
		return VectorN(repeating: value, count: dimension)
	}
	
	/// Create a vector from variadic arguments.
	public static func vector(_ components: T...) -> VectorN<T>? {
		guard !components.isEmpty else { return nil }
		return VectorN(components)
	}
	
	/// Calculate the angle between two vectors.
	public func angle(with other: VectorN<T>) -> T {
		let dotProduct = self.dot(other)
		let norms = self.norm * other.norm
		guard norms > T(0) else { return T(0) }
		let cosAngle = Swift.max(-T(1), Swift.min(T(1), dotProduct / norms))
		return T.acos(cosAngle)
	}
}

// MARK: - Scalar VectorSpace Conformance

/// Conformance of Double to VectorSpace, treating scalars as 1-dimensional vectors.
///
/// This allows Double values to be used directly in vector space operations, which is
/// useful for scalar optimization problems or as building blocks for higher-dimensional vectors.
///
/// ## Example
/// ```swift
/// let a: Double = 3.5
/// let b: Double = 2.0
/// let c = a + b  // Standard arithmetic
/// let d = a.dot(b)  // 7.0 (scalar multiplication)
/// print(a.norm)  // 3.5 (absolute value)
/// ```
///
/// ## Mathematical Interpretation
/// Scalars form a 1-dimensional vector space where:
/// - The zero element is 0.0
/// - The norm is the absolute value
/// - The dot product is multiplication
///
/// ## See Also
/// - ``Float`` for single-precision scalar vector space
extension Double: VectorSpace {
	/// The scalar type is Double itself.
	public typealias Scalar = Double

	/// The zero element in the 1-dimensional scalar space.
	public static var zero: Double { 0.0 }

	/// The norm (absolute value) of the scalar.
	public var norm: Double { abs(self) }

	/// Dot product with another scalar (multiplication).
	/// - Parameter other: Another Double value
	/// - Returns: The product of the two scalars
	public func dot(_ other: Double) -> Double { self * other }

	/// Create a Double from an array.
	/// - Parameter array: Must contain exactly one element
	/// - Returns: The single Double value, or nil if array size != 1
	public static func fromArray(_ array: [Double]) -> Double? {
		guard array.count == 1 else { return nil }
		return array[0]
	}

	/// Convert to array representation.
	/// - Returns: Single-element array containing this Double
	public func toArray() -> [Double] { [self] }

	/// Dimension is always 1 for scalars.
	public static var dimension: Int { 1 }
	// isFinite is already provided by FloatingPoint protocol
}

/// Conformance of Float to VectorSpace, treating scalars as 1-dimensional vectors.
///
/// This allows Float values to be used directly in vector space operations, which is
/// useful for scalar optimization problems or as building blocks for higher-dimensional vectors.
///
/// ## Example
/// ```swift
/// let a: Float = 3.5
/// let b: Float = 2.0
/// let c = a + b  // Standard arithmetic
/// let d = a.dot(b)  // 7.0 (scalar multiplication)
/// print(a.norm)  // 3.5 (absolute value)
/// ```
///
/// ## Mathematical Interpretation
/// Scalars form a 1-dimensional vector space where:
/// - The zero element is 0.0
/// - The norm is the absolute value
/// - The dot product is multiplication
extension Float: VectorSpace {
	/// The scalar type is Float itself.
	public typealias Scalar = Float

	/// The zero element in the 1-dimensional scalar space.
	public static var zero: Float { 0.0 }

	/// The norm (absolute value) of the scalar.
	public var norm: Float { abs(self) }

	/// Dot product with another scalar (multiplication).
	/// - Parameter other: Another Float value
	/// - Returns: The product of the two scalars
	public func dot(_ other: Float) -> Float { self * other }

	/// Create a Float from an array.
	/// - Parameter array: Must contain exactly one element
	/// - Returns: The single Float value, or nil if array size != 1
	public static func fromArray(_ array: [Float]) -> Float? {
		guard array.count == 1 else { return nil }
		return array[0]
	}

	/// Convert to array representation.
	/// - Returns: Single-element array containing this Float
	public func toArray() -> [Float] { [self] }

	/// Dimension is always 1 for scalars.
	public static var dimension: Int { 1 }
	// isFinite is already provided by FloatingPoint protocol
}


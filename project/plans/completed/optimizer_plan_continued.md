# Comprehensive Optimizer Enhancement Implementation Plan (Continued)

## Phase 2: VectorSpace Foundation (Multi-Dimensional Optimization) - Continued

### Step 2.1: VectorSpace Protocol Implementation (Continued)

**File:** `Sources/BusinessMath/Optimization/Vector/VectorSpace.swift` (Continued)

```swift
    /// N-dimensional vector (array-backed).
    public struct VectorN<T: Real & Sendable & Codable>: VectorSpace {
        public typealias Scalar = T
        
        private var components: [T]
        
        public init(_ components: [T]) {
            self.components = components
        }
        
        public init(repeating value: T, count: Int) {
            self.components = Array(repeating: value, count: count)
        }
        
        public static var zero: VectorN<T> {
            VectorN([])
        }
        
        public static func + (lhs: VectorN<T>, rhs: VectorN<T>) -> VectorN<T> {
            guard lhs.components.count == rhs.components.count else {
                // Return zero vector for dimension mismatch
                return VectorN(repeating: T(0), count: max(lhs.components.count, rhs.components.count))
            }
            
            let result = zip(lhs.components, rhs.components).map { $0 + $1 }
            return VectorN(result)
        }
        
        public static func * (lhs: T, rhs: VectorN<T>) -> VectorN<T> {
            let result = rhs.components.map { lhs * $0 }
            return VectorN(result)
        }
        
        public static prefix func - (vector: VectorN<T>) -> VectorN<T> {
            let result = vector.components.map { -$0 }
            return VectorN(result)
        }
        
        public var norm: T {
            T.sqrt(components.reduce(T(0)) { $0 + $1 * $1 })
        }
        
        public func dot(_ other: VectorN<T>) -> T {
            guard components.count == other.components.count else {
                return T(0)
            }
            
            return zip(components, other.components)
                .map { $0 * $1 }
                .reduce(T(0), +)
        }
        
        public static func fromArray(_ array: [T]) -> VectorN<T>? {
            VectorN(array)
        }
        
        public func toArray() -> [T] {
            components
        }
        
        public static var dimension: Int {
            fatalError("VectorN dimension is variable. Use count property instead.")
        }
        
        public var count: Int {
            components.count
        }
        
        public var isFinite: Bool {
            components.allSatisfy { $0.isFinite }
        }
        
        /// Access individual component.
        public subscript(index: Int) -> T {
            get {
                guard index >= 0 && index < components.count else {
                    return T(0)
                }
                return components[index]
            }
            set {
                guard index >= 0 && index < components.count else { return }
                components[index] = newValue
            }
        }
        
        /// Create a vector with specific dimension.
        public static func withDimension(_ dimension: Int, initialValue: T = T(0)) -> VectorN<T> {
            VectorN(repeating: initialValue, count: dimension)
        }
        
        /// Create a unit vector in the specified direction.
        public static func unitVector(dimension: Int, direction: Int) -> VectorN<T> {
            var components = Array(repeating: T(0), count: dimension)
            if direction >= 0 && direction < dimension {
                components[direction] = T(1)
            }
            return VectorN(components)
        }
    }
}

// MARK: - Convenience Extensions

public extension VectorSpace {
    /// Create a vector from variadic arguments.
    static func vector(_ components: Scalar...) -> Self? {
        fromArray(components)
    }
    
    /// Create a vector with all components equal.
    static func filled(with value: Scalar, dimension: Int) -> Self? {
        fromArray(Array(repeating: value, count: dimension))
    }
    
    /// Create a random vector with components in [0, 1].
    static func random(dimension: Int) -> Self? {
        let components = (0..<dimension).map { _ in
            Scalar.random(in: 0...1)
        }
        return fromArray(components)
    }
    
    /// Create a random vector with components in specified range.
    static func random(in range: ClosedRange<Scalar>, dimension: Int) -> Self? {
        let components = (0..<dimension).map { _ in
            Scalar.random(in: range)
        }
        return fromArray(components)
    }
}

// MARK: - Vector Operations

public extension VectorSpace {
    /// Element-wise multiplication (Hadamard product).
    func hadamard(_ other: Self) -> Self {
        let lhsArray = self.toArray()
        let rhsArray = other.toArray()
        guard lhsArray.count == rhsArray.count else {
            return Self.zero
        }
        
        let result = zip(lhsArray, rhsArray).map { $0 * $1 }
        return Self.fromArray(result) ?? Self.zero
    }
    
    /// Element-wise division.
    func elementwiseDivide(by other: Self) -> Self {
        let lhsArray = self.toArray()
        let rhsArray = other.toArray()
        guard lhsArray.count == rhsArray.count else {
            return Self.zero
        }
        
        let result = zip(lhsArray, rhsArray).map { $0 / $1 }
        return Self.fromArray(result) ?? Self.zero
    }
    
    /// Sum of all components.
    var sum: Scalar {
        toArray().reduce(Scalar(0), +)
    }
    
    /// Mean of all components.
    var mean: Scalar {
        let array = toArray()
        guard !array.isEmpty else { return Scalar(0) }
        return sum / Scalar(array.count)
    }
    
    /// Standard deviation of components.
    var standardDeviation: Scalar {
        let array = toArray()
        guard array.count > 1 else { return Scalar(0) }
        
        let m = mean
        let variance = array.reduce(Scalar(0)) { $0 + ($1 - m) * ($1 - m) } / Scalar(array.count - 1)
        return Scalar.sqrt(variance)
    }
    
    /// Maximum component value.
    var max: Scalar {
        toArray().max() ?? Scalar(0)
    }
    
    /// Minimum component value.
    var min: Scalar {
        toArray().min() ?? Scalar(0)
    }
    
    /// Normalize to unit length.
    func normalized() -> Self {
        let n = norm
        guard n > Scalar(0) else { return self }
        return (Scalar(1) / n) * self
    }
    
    /// Project onto another vector.
    func project(onto other: Self) -> Self {
        let dotProduct = self.dot(other)
        let otherNormSquared = other.squaredNorm
        guard otherNormSquared > Scalar(0) else { return Self.zero }
        return (dotProduct / otherNormSquared) * other
    }
    
    /// Angle between two vectors (in radians).
    func angle(with other: Self) -> Scalar {
        let dotProduct = self.dot(other)
        let norms = self.norm * other.norm
        guard norms > Scalar(0) else { return Scalar(0) }
        let cosTheta = dotProduct / norms
        // Clamp to [-1, 1] to avoid numerical issues
        let clamped = min(max(cosTheta, -Scalar(1)), Scalar(1))
        return Scalar.acos(clamped)
    }
}

// MARK: - Matrix-Vector Operations

public extension VectorSpace {
    /// Multiply by a matrix (represented as array of row vectors).
    func multiply(by matrix: [Self]) -> Self? {
        let input = self.toArray()
        guard !input.isEmpty else { return nil }
        
        var result: [Scalar] = []
        for row in matrix {
            let rowArray = row.toArray()
            guard rowArray.count == input.count else { return nil }
            
            let dotProduct = zip(rowArray, input)
                .map { $0 * $1 }
                .reduce(Scalar(0), +)
            result.append(dotProduct)
        }
        
        return Self.fromArray(result)
    }
    
    /// Outer product with another vector.
    func outerProduct(with other: Self) -> [[Scalar]] {
        let lhsArray = self.toArray()
        let rhsArray = other.toArray()
        
        return lhsArray.map { a in
            rhsArray.map { b in
                a * b
            }
        }
    }
}

// MARK: - Conformance for Standard Types

extension Double: VectorSpace {
    public typealias Scalar = Double
    
    public static var zero: Double { 0.0 }
    
    public static func + (lhs: Double, rhs: Double) -> Double {
        lhs + rhs
    }
    
    public static func * (lhs: Double, rhs: Double) -> Double {
        lhs * rhs
    }
    
    public static prefix func - (value: Double) -> Double {
        -value
    }
    
    public var norm: Double {
        abs(self)
    }
    
    public func dot(_ other: Double) -> Double {
        self * other
    }
    
    public static func fromArray(_ array: [Double]) -> Double? {
        guard array.count == 1 else { return nil }
        return array[0]
    }
    
    public func toArray() -> [Double] {
        [self]
    }
    
    public static var dimension: Int { 1 }
    
    public var isFinite: Bool {
        self.isFinite
    }
}

extension Float: VectorSpace {
    public typealias Scalar = Float
    
    public static var zero: Float { 0.0 }
    
    public static func + (lhs: Float, rhs: Float) -> Float {
        lhs + rhs
    }
    
    public static func * (lhs: Float, rhs: Float) -> Float {
        lhs * rhs
    }
    
    public static prefix func - (value: Float) -> Float {
        -value
    }
    
    public var norm: Float {
        abs(self)
    }
    
    public func dot(_ other: Float) -> Float {
        self * other
    }
    
    public static func fromArray(_ array: [Float]) -> Float? {
        guard array.count == 1 else { return nil }
        return array[0]
    }
    
    public func toArray() -> [Float] {
        [self]
    }
    
    public static var dimension: Int { 1 }
    
    public var isFinite: Bool {
        self.isFinite
    }
}
```

### Step 2.2: VectorSpace Test Suite

**File:** `Tests/BusinessMathTests/OptimizationTests/VectorSpaceTests.swift`

```swift
//
//  VectorSpaceTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on [Date].
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("VectorSpace Protocol")
struct VectorSpaceTests {
    
    // MARK: - Vector2D Tests
    
    @Test("Vector2D basic operations")
    func vector2DBasicOperations() {
        let v1 = Vector2D<Double>(x: 1.0, y: 2.0)
        let v2 = Vector2D<Double>(x: 3.0, y: 4.0)
        
        // Addition
        let sum = v1 + v2
        #expect(sum.x == 4.0)
        #expect(sum.y == 6.0)
        
        // Scalar multiplication
        let scaled = 2.0 * v1
        #expect(scaled.x == 2.0)
        #expect(scaled.y == 4.0)
        
        // Negation
        let neg = -v1
        #expect(neg.x == -1.0)
        #expect(neg.y == -2.0)
        
        // Subtraction (default implementation)
        let diff = v1 - v2
        #expect(diff.x == -2.0)
        #expect(diff.y == -2.0)
    }
    
    @Test("Vector2D norm and dot product")
    func vector2DNormAndDot() {
        let v1 = Vector2D<Double>(x: 3.0, y: 4.0)
        let v2 = Vector2D<Double>(x: 1.0, y: 2.0)
        
        // Norm
        #expect(v1.norm == 5.0)
        #expect(v2.norm == sqrt(5.0))
        
        // Squared norm
        #expect(v1.squaredNorm == 25.0)
        #expect(v2.squaredNorm == 5.0)
        
        // Dot product
        let dot = v1.dot(v2)
        #expect(dot == 3.0 * 1.0 + 4.0 * 2.0)
        
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
        #expect(array[0] == 1.5)
        #expect(array[1] == 2.5)
        
        // From array
        let fromArray = Vector2D<Double>.fromArray([3.0, 4.0])
        #expect(fromArray?.x == 3.0)
        #expect(fromArray?.y == 4.0)
        
        // Invalid array
        let invalid = Vector2D<Double>.fromArray([1.0])
        #expect(invalid == nil)
    }
    
    @Test("Vector2D convenience methods")
    func vector2DConvenienceMethods() {
        // Zero vector
        let zero = Vector2D<Double>.zero
        #expect(zero.x == 0.0)
        #expect(zero.y == 0.0)
        
        // Is finite
        let finite = Vector2D<Double>(x: 1.0, y: 2.0)
        #expect(finite.isFinite == true)
        
        let infinite = Vector2D<Double>(x: .infinity, y: 2.0)
        #expect(infinite.isFinite == false)
        
        // Linear interpolation
        let start = Vector2D<Double>(x: 0.0, y: 0.0)
        let end = Vector2D<Double>(x: 10.0, y: 20.0)
        let lerped = Vector2D<Double>.lerp(from: start, to: end, t: 0.5)
        #expect(lerped.x == 5.0)
        #expect(lerped.y == 10.0)
    }
    
    // MARK: - Vector3D Tests
    
    @Test("Vector3D basic operations")
    func vector3DBasicOperations() {
        let v1 = Vector3D<Double>(x: 1.0, y: 2.0, z: 3.0)
        let v2 = Vector3D<Double>(x: 4.0, y: 5.0, z: 6.0)
        
        let sum = v1 + v2
        #expect(sum.x == 5.0)
        #expect(sum.y == 7.0)
        #expect(sum.z == 9.0)
        
        let scaled = 2.0 * v1
        #expect(scaled.x == 2.0)
        #expect(scaled.y == 4.0)
        #expect(scaled.z == 6.0)
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
        #expect(v1[0] == 1.0)
        #expect(v1[1] == 2.0)
        #expect(v1[2] == 3.0)
        
        // Repeating
        let v2 = VectorN<Double>(repeating: 5.0, count: 4)
        #expect(v2.count == 4)
        #expect(v2[0] == 5.0)
        #expect(v2[3] == 5.0)
        
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
        #expect(sum[0] == 5.0)
        #expect(sum[1] == 7.0)
        #expect(sum[2] == 9.0)
        
        // Scalar multiplication
        let scaled = 2.0 * v1
        #expect(scaled[0] == 2.0)
        #expect(scaled[1] == 4.0)
        #expect(scaled[2] == 6.0)
        
        // Dot product
        let dot = v
I'll continue with the VectorN tests and complete the VectorSpace test suite:

**File:** `Tests/BusinessMathTests/OptimizationTests/VectorSpaceTests.swift` (Continued)

```swift
    @Test("VectorN operations with matching dimensions")
    func vectorNOperationsMatchingDimensions() {
        let v1 = VectorN<Double>([1.0, 2.0, 3.0])
        let v2 = VectorN<Double>([4.0, 5.0, 6.0])
        
        // Addition
        let sum = v1 + v2
        #expect(sum.count == 3)
        #expect(sum[0] == 5.0)
        #expect(sum[1] == 7.0)
        #expect(sum[2] == 9.0)
        
        // Scalar multiplication
        let scaled = 2.0 * v1
        #expect(scaled[0] == 2.0)
        #expect(scaled[1] == 4.0)
        #expect(scaled[2] == 6.0)
        
        // Dot product
        let dot = v1.dot(v2)
        #expect(dot == 1.0*4.0 + 2.0*5.0 + 3.0*6.0)
        
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
        #expect(sum[0] == 0.0)
        #expect(sum[1] == 0.0)
        #expect(sum[2] == 0.0)
        
        // Dot product with mismatch returns 0
        let dot = v1.dot(v2)
        #expect(dot == 0.0)
    }
    
    @Test("VectorN subscript access")
    func vectorNSubscriptAccess() {
        var v = VectorN<Double>([1.0, 2.0, 3.0])
        
        // Read access
        #expect(v[0] == 1.0)
        #expect(v[1] == 2.0)
        #expect(v[2] == 3.0)
        
        // Out of bounds read returns 0
        #expect(v[-1] == 0.0)
        #expect(v[10] == 0.0)
        
        // Write access
        v[1] = 99.0
        #expect(v[1] == 99.0)
        
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
        #expect(unit[0] == 0.0)
        #expect(unit[1] == 1.0)
        #expect(unit[2] == 0.0)
        
        // With dimension
        let sized = VectorN<Double>.withDimension(4, initialValue: 7.0)
        #expect(sized.count == 4)
        #expect(sized[0] == 7.0)
        #expect(sized[3] == 7.0)
        
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
        #expect(result[0] == 4.0)   // 1*4
        #expect(result[1] == 10.0)  // 2*5
        #expect(result[2] == 18.0)  // 3*6
        
        // Mismatched dimensions returns zero
        let v3 = VectorN<Double>([1.0, 2.0])
        let zeroResult = v1.hadamard(v3)
        #expect(zeroResult.count == 3)
        #expect(zeroResult[0] == 0.0)
    }
    
    @Test("Vector operations - elementwise division")
    func vectorElementwiseDivision() {
        let v1 = VectorN<Double>([10.0, 20.0, 30.0])
        let v2 = VectorN<Double>([2.0, 4.0, 5.0])
        
        let result = v1.elementwiseDivide(by: v2)
        #expect(result.count == 3)
        #expect(result[0] == 5.0)   // 10/2
        #expect(result[1] == 5.0)   // 20/4
        #expect(result[2] == 6.0)   // 30/5
    }
    
    @Test("Vector operations - statistics")
    func vectorStatistics() {
        let v = VectorN<Double>([1.0, 2.0, 3.0, 4.0, 5.0])
        
        #expect(v.sum == 15.0)
        #expect(v.mean == 3.0)
        #expect(abs(v.standardDeviation - sqrt(2.5)) < 1e-10)  // Population variance = 2.5
        #expect(v.max == 5.0)
        #expect(v.min == 1.0)
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
        
        let projection = v1.project(onto: v2)
        #expect(projection.count == 3)
        #expect(projection[0] == 1.0)  // Projects onto x-axis
        #expect(projection[1] == 0.0)
        #expect(projection[2] == 0.0)
        
        // Projection onto zero vector returns zero
        let zero = VectorN<Double>.zero
        let zeroProjection = v1.project(onto: zero)
        #expect(zeroProjection.count == 0)
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
    
    @Test("Matrix-vector multiplication")
    func matrixVectorMultiplication() {
        let v = VectorN<Double>([1.0, 2.0])
        let matrix = [
            VectorN<Double>([1.0, 0.0]),  // [1 0]
            VectorN<Double>([0.0, 1.0]),  // [0 1]
            VectorN<Double>([1.0, 1.0])   // [1 1]
        ]
        
        let result = v.multiply(by: matrix)
        #expect(result != nil)
        #expect(result!.count == 3)
        #expect(result![0] == 1.0)  // 1*1 + 2*0
        #expect(result![1] == 2.0)  // 1*0 + 2*1
        #expect(result![2] == 3.0)  // 1*1 + 2*1
        
        // Invalid dimensions
        let badMatrix = [VectorN<Double>([1.0])]
        let badResult = v.multiply(by: badMatrix)
        #expect(badResult == nil)
    }
    
    @Test("Outer product")
    func outerProduct() {
        let v1 = VectorN<Double>([1.0, 2.0])
        let v2 = VectorN<Double>([3.0, 4.0, 5.0])
        
        let result = v1.outerProduct(with: v2)
        #expect(result.count == 2)  // v1 dimension
        #expect(result[0].count == 3)  // v2 dimension
        
        #expect(result[0][0] == 3.0)  // 1*3
        #expect(result[0][1] == 4.0)  // 1*4
        #expect(result[0][2] == 5.0)  // 1*5
        #expect(result[1][0] == 6.0)  // 2*3
        #expect(result[1][1] == 8.0)  // 2*4
        #expect(result[1][2] == 10.0) // 2*5
    }
    
    // MARK: - Convenience Extensions Tests
    
    @Test("Convenience vector creation")
    func convenienceVectorCreation() {
        // Variadic arguments
        let v1 = VectorN<Double>.vector(1.0, 2.0, 3.0)
        #expect(v1 != nil)
        #expect(v1!.count == 3)
        #expect(v1![0] == 1.0)
        
        // Filled vector
        let v2 = VectorN<Double>.filled(with: 7.0, dimension: 4)
        #expect(v2 != nil)
        #expect(v2!.count == 4)
        #expect(v2![0] == 7.0)
        #expect(v2![3] == 7.0)
        
        // Random vector
        let v3 = VectorN<Double>.random(dimension: 5)
        #expect(v3 != nil)
        #expect(v3!.count == 5)
        #expect(v3!.isFinite == true)
        
        // Random vector in range
        let v4 = VectorN<Double>.random(in: -1.0...1.0, dimension: 3)
        #expect(v4 != nil)
        #expect(v4!.count == 3)
        #expect(v4!.min >= -1.0)
        #expect(v4!.max <= 1.0)
    }
    
    // MARK: - Scalar Type Conformance Tests
    
    @Test("Double as VectorSpace")
    func doubleAsVectorSpace() {
        let d1: Double = 3.0
        let d2: Double = 4.0
        
        // Operations
        #expect(d1 + d2 == 7.0)
        #expect(2.0 * d1 == 6.0)
        #expect(-d1 == -3.0)
        
        // Norm
        #expect(d1.norm == 3.0)
        
        // Dot product
        #expect(d1.dot(d2) == 12.0)
        
        // Array conversion
        #expect(d1.toArray() == [3.0])
        #expect(Double.fromArray([5.0]) == 5.0)
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
        
        #expect(f1 + f2 == 7.0)
        #expect(2.0 * f1 == 6.0)
        #expect(f1.norm == 3.0)
        #expect(f1.dot(f2) == 12.0)
        #expect(Float.dimension == 1)
    }
    
    // MARK: - Performance Tests
    
    @Test("VectorN performance", .tags(.performance))
    func vectorNPerformance() async throws {
        let size = 1000
        let v1 = VectorN<Double>(repeating: 1.0, count: size)
        let v2 = VectorN<Double>(repeating: 2.0, count: size)
        
        // Measure addition
        try await #measure(iterations: 1000) {
            _ = v1 + v2
        }
        
        // Measure dot product
        try await #measure(iterations: 1000) {
            _ = v1.dot(v2)
        }
        
        // Measure norm
        try await #measure(iterations: 1000) {
            _ = v1.norm
        }
    }
    
    @Test("Vector2D vs VectorN performance", .tags(.performance))
    func vector2DvsVectorNPerformance() async throws {
        let iterations = 10000
        
        // Vector2D
        let v2d1 = Vector2D<Double>(x: 1.0, y: 2.0)
        let v2d2 = Vector2D<Double>(x: 3.0, y: 4.0)
        
        let v2dTime = try await #measure(iterations: iterations) {
            _ = v2d1 + v2d2
            _ = v2d1.dot(v2d2)
            _ = v2d1.norm
        }
        
        // VectorN with 2 dimensions
        let vn1 = VectorN<Double>([1.0, 2.0])
        let vn2 = VectorN<Double>([3.0, 4.0])
        
        let vnTime = try await #measure(iterations: iterations) {
            _ = vn1 + vn2
            _ = vn1.dot(vn2)
            _ = vn1.norm
        }
        
        // Vector2D should be faster due to compile-time optimization
        #expect(v2dTime < vnTime * 1.5)  // Allow some overhead
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("Empty vector operations")
    func emptyVectorOperations() {
        let empty = VectorN<Double>.zero
        
        #expect(empty.count == 0)
        #expect(empty.norm == 0.0)
        #expect(empty.sum == 0.0)
        #expect(empty.mean == 0.0)
        #expect(empty.standardDeviation == 0.0)
        
        // Operations with empty vectors
        let result = empty + empty
        #expect(result.count == 0)
        
        let dot = empty.dot(empty)
        #expect(dot == 0.0)
    }
    
    @Test("Vector with NaN and infinity")
    func vectorWithNaNandInfinity() {
        let v = VectorN<Double>([1.0, .nan, .infinity, 4.0])
        
        #expect(v.isFinite == false)
        #expect(v.norm.isNaN == true)  // Norm with NaN is NaN
        
        // Operations with NaN
        let v2 = VectorN<Double>([2.0, 3.0, 4.0, 5.0])
        let sum = v + v2
        #expect(sum[0] == 3.0)  // 1 + 2
        #expect(sum[1].isNaN == true)  // NaN + 3
        #expect(sum[2].isInfinite == true)  // ∞ + 4
        #expect(sum[3] == 9.0)  // 4 + 5
    }
    
    @Test("Large dimension vectors")
    func
I'll continue with the edge case tests and complete the VectorSpace test suite:

**File:** `Tests/BusinessMathTests/OptimizationTests/VectorSpaceTests.swift` (Continued)

```swift
    @Test("Large dimension vectors")
    func largeDimensionVectors() {
        let dimension = 10000
        let v1 = VectorN<Double>(repeating: 1.0, count: dimension)
        let v2 = VectorN<Double>(repeating: 2.0, count: dimension)
        
        // Basic operations should work
        let sum = v1 + v2
        #expect(sum.count == dimension)
        #expect(sum[0] == 3.0)
        #expect(sum[dimension - 1] == 3.0)
        
        let dot = v1.dot(v2)
        #expect(dot == Double(dimension) * 2.0)  // 1*2 for each component
        
        let norm = v1.norm
        #expect(abs(norm - sqrt(Double(dimension))) < 1e-10)
        
        // Statistics
        #expect(v1.sum == Double(dimension))
        #expect(v1.mean == 1.0)
        #expect(v1.standardDeviation == 0.0)
    }
    
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
        
        #expect(v1[0] == 1.0)  // v1 unchanged
        #expect(v2[0] == 99.0) // v2 modified
        
        // Modify v1 - should not affect v2
        v1[1] = 88.0
        #expect(v1[1] == 88.0)
        #expect(v2[1] == 2.0)  // v2 unchanged
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
        #expect(decoded[0] == 1.0)
        #expect(decoded[3] == 4.0)
        
        // Test Vector2D serialization
        let v2d = Vector2D<Double>(x: 1.5, y: 2.5)
        let v2dData = try encoder.encode(v2d)
        let decodedV2D = try decoder.decode(Vector2D<Double>.self, from: v2dData)
        
        #expect(decodedV2D.x == 1.5)
        #expect(decodedV2D.y == 2.5)
    }
    
    @Test("Vector description and debug strings")
    func vectorDescription() {
        let v = VectorN<Double>([1.0, 2.0, 3.0])
        let description = v.description
        let debugDescription = v.debugDescription
        
        #expect(description.contains("VectorN"))
        #expect(description.contains("1.0"))
        #expect(description.contains("3.0"))
        #expect(debugDescription.contains("VectorN"))
        
        // Vector2D description
        let v2d = Vector2D<Double>(x: 1.0, y: 2.0)
        let v2dDescription = v2d.description
        #expect(v2dDescription.contains("Vector2D"))
        #expect(v2dDescription.contains("x: 1.0"))
        #expect(v2dDescription.contains("y: 2.0"))
    }
    
    // MARK: - Cross Product Tests (3D specific)
    
    @Test("Vector3D cross product")
    func vector3DCrossProduct() {
        let v1 = Vector3D<Double>(x: 1.0, y: 0.0, z: 0.0)
        let v2 = Vector3D<Double>(x: 0.0, y: 1.0, z: 0.0)
        
        let cross = v1.cross(v2)
        #expect(cross.x == 0.0)
        #expect(cross.y == 0.0)
        #expect(cross.z == 1.0)  // Right-hand rule: x × y = z
        
        // Test anticommutativity: v1 × v2 = -(v2 × v1)
        let crossReverse = v2.cross(v1)
        #expect(crossReverse.x == 0.0)
        #expect(crossReverse.y == 0.0)
        #expect(crossReverse.z == -1.0)
        
        // Parallel vectors have zero cross product
        let v3 = Vector3D<Double>(x: 2.0, y: 0.0, z: 0.0)
        let parallelCross = v1.cross(v3)
        #expect(parallelCross.x == 0.0)
        #expect(parallelCross.y == 0.0)
        #expect(parallelCross.z == 0.0)
    }
    
    @Test("Vector3D triple product")
    func vector3DTripleProduct() {
        let a = Vector3D<Double>(x: 1.0, y: 0.0, z: 0.0)
        let b = Vector3D<Double>(x: 0.0, y: 1.0, z: 0.0)
        let c = Vector3D<Double>(x: 0.0, y: 0.0, z: 1.0)
        
        // Scalar triple product: a · (b × c)
        let triple = a.tripleProduct(b, c)
        #expect(triple == 1.0)  // Should be 1 for right-handed basis
        
        // Vector triple product: a × (b × c)
        let vectorTriple = a.vectorTripleProduct(b, c)
        #expect(vectorTriple.x == 0.0)
        #expect(vectorTriple.y == 1.0)  // a × (b × c) = b(a·c) - c(a·b)
        #expect(vectorTriple.z == 0.0)
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
        #expect(lerpMid[0] == 5.0)
        #expect(lerpMid[1] == 10.0)
        
        // t outside [0, 1] - extrapolation
        let extrapolate = VectorN<Double>.lerp(from: start, to: end, t: 2.0)
        #expect(extrapolate[0] == 20.0)
        #expect(extrapolate[1] == 40.0)
    }
    
    // MARK: - Distance and Similarity Tests
    
    @Test("Distance metrics")
    func distanceMetrics() {
        let v1 = VectorN<Double>([0.0, 0.0])
        let v2 = VectorN<Double>([3.0, 4.0])
        
        // Euclidean distance
        let euclidean = v1.distance(to: v2)
        #expect(euclidean == 5.0)  // 3-4-5 triangle
        
        // Squared distance (faster, avoids sqrt)
        let squared = v1.squaredDistance(to: v2)
        #expect(squared == 25.0)
        
        // Manhattan distance
        let manhattan = v1.manhattanDistance(to: v2)
        #expect(manhattan == 7.0)  // 3 + 4
        
        // Chebyshev distance
        let chebyshev = v1.chebyshevDistance(to: v2)
        #expect(chebyshev == 4.0)  // max(3, 4)
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
        
        #expect(e1[0] == 1.0)
        #expect(e1[1] == 0.0)
        #expect(e1[2] == 0.0)
        
        #expect(e2[0] == 0.0)
        #expect(e2[1] == 1.0)
        #expect(e2[2] == 0.0)
        
        #expect(e3[0] == 0.0)
        #expect(e3[1] == 0.0)
        #expect(e3[2] == 1.0)
        
        // Orthogonality
        #expect(e1.dot(e2) == 0.0)
        #expect(e1.dot(e3) == 0.0)
        #expect(e2.dot(e3) == 0.0)
        
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
        #expect(sizedZero.sum == 0.0)
        
        // Ones vector
        let ones = VectorN<Double>.filled(with: 1.0, dimension: dimension)
        #expect(ones != nil)
        #expect(ones!.count == dimension)
        #expect(ones!.sum == Double(dimension))
        
        // Custom filled vector
        let sevens = VectorN<Double>.filled(with: 7.0, dimension: 3)
        #expect(sevens != nil)
        #expect(sevens![0] == 7.0)
        #expect(sevens![1] == 7.0)
        #expect(sevens![2] == 7.0)
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
        #expect(normalizedZero.count == 0)  // Returns itself
        
        // Angle with zero vector
        let angleWithZero = v1.angle(with: zero)
        #expect(angleWithZero == 0.0)  // Defined as 0
        
        // Projection onto zero vector
        let projection = v1.project(onto: zero)
        #expect(projection.count == 0)
        
        // Cosine similarity with zero vector
        let cosineWithZero = v1.cosineSimilarity(with: zero)
        #expect(cosineWithZero == 0.0)  // Defined as 0
    }
    
    // MARK: - Type Safety Tests
    
    @Test("Type safety and generic constraints")
    func typeSafety() {
        // Should compile with different numeric types
        let doubleVec = VectorN<Double>([1.0, 2.0])
        let floatVec = VectorN<Float>([1.0, 2.0])
        let cgFloatVec = VectorN<CGFloat>([1.0, 2.0])
        
        // All should support basic operations
        #expect(doubleVec.norm is Double)
        #expect(floatVec.norm is Float)
        #expect(cgFloatVec.norm is CGFloat)
        
        // Mixing types should not compile (type safety)
        // Uncommenting this should cause a compile error:
        // let mixed = doubleVec + floatVec  // Should not compile
        
        // But conversion should work
        let converted = VectorN<Double>(floatVec.toArray().map { Double($0) })
        #expect(converted.count == 2)
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
        #expect(norm == sqrt(14.0))
        
        // Vector2D should also be Sendable
        let v2d = Vector2D<Double>(x: 1.0, y: 2.0)
        let v2dTask = Task {
            return v2d.norm
        }
        
        let v2dNorm = await v2dTask.value
        #expect(v2dNorm == sqrt(5.0))
    }
    
    // MARK: - Integration Tests
    
    @Test("Integration with existing math functions")
    func integrationWithMathFunctions() {
        // Test that vectors work with existing BusinessMath functions
        let v = VectorN<Double>([1.0, 2.0, 3.0])
        
        // Apply element-wise functions
        let squared = v.hadamard(v)
        #expect(squared[0] == 1.0)
        #expect(squared[1] == 4.0)
        #expect(squared[2] == 9.0)
        
        // Use in optimization context (placeholder for future tests)
        let gradient = VectorN<Double>([0.1, -0.2, 0.3])
        let step = 0.1 * gradient
        #expect(step[0] == 0.01)
        #expect(step[1
I'll continue with the integration tests and complete the VectorSpace test suite:

**File:** `Tests/BusinessMathTests/OptimizationTests/VectorSpaceTests.swift` (Continued)

```swift
    @Test("Integration with existing math functions")
    func integrationWithMathFunctions() {
        // Test that vectors work with existing BusinessMath functions
        let v = VectorN<Double>([1.0, 2.0, 3.0])
        
        // Apply element-wise functions
        let squared = v.hadamard(v)
        #expect(squared[0] == 1.0)
        #expect(squared[1] == 4.0)
        #expect(squared[2] == 9.0)
        
        // Use in optimization context (placeholder for future tests)
        let gradient = VectorN<Double>([0.1, -0.2, 0.3])
        let step = 0.1 * gradient
        #expect(step[0] == 0.01)
        #expect(step[1] == -0.02)
        #expect(step[2] == 0.03)
        
        // Test with statistical functions
        let data = VectorN<Double>([1.0, 2.0, 3.0, 4.0, 5.0])
        let mean = data.mean
        let stdDev = data.standardDeviation
        #expect(mean == 3.0)
        #expect(abs(stdDev - sqrt(2.5)) < 1e-10)
        
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
        let target = VectorN<Double>([0.0])  // Minimum at x = 0
        
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
        
        let rotated = vector.multiply(by: rotation90)
        #expect(rotated != nil)
        #expect(rotated![0] == -2.0)  // 0*1 + (-1)*2
        #expect(rotated![1] == 1.0)   // 1*1 + 0*2
        
        // Scaling matrix
        let scaling = [
            VectorN<Double>([2.0, 0.0]),
            VectorN<Double>([0.0, 3.0])
        ]
        
        let scaled = vector.multiply(by: scaling)
        #expect(scaled != nil)
        #expect(scaled![0] == 2.0)  // 2*1 + 0*2
        #expect(scaled![1] == 6.0)  // 0*1 + 3*2
        
        // Test outer product for covariance-like calculation
        let v1 = VectorN<Double>([1.0, 2.0, 3.0])
        let v2 = VectorN<Double>([4.0, 5.0, 6.0])
        let outer = v1.outerProduct(with: v2)
        
        // Should produce 3x3 matrix
        #expect(outer.count == 3)
        #expect(outer[0].count == 3)
        #expect(outer[0][0] == 4.0)  // 1*4
        #expect(outer[2][2] == 18.0) // 3*6
    }
    
    @Test("Integration with probability distributions")
    func integrationWithProbabilityDistributions() {
        // Generate random vectors for Monte Carlo simulation
        let dimension = 3
        let sampleSize = 1000
        
        var samples: [VectorN<Double>] = []
        var sum = VectorN<Double>.withDimension(dimension)
        
        // Generate samples from uniform distribution
        for _ in 0..<sampleSize {
            if let sample = VectorN<Double>.random(in: 0...1, dimension: dimension) {
                samples.append(sample)
                sum = sum + sample
            }
        }
        
        // Calculate sample mean
        let sampleMean = (1.0 / Double(sampleSize)) * sum
        
        // Mean should be near 0.5 for uniform [0,1]
        #expect(abs(sampleMean.mean - 0.5) < 0.05)
        
        // Calculate sample covariance (simplified)
        var covariance = VectorN<Double>.withDimension(dimension)
        for sample in samples {
            let centered = sample - sampleMean
            covariance = covariance + centered.hadamard(centered)
        }
        covariance = (1.0 / Double(sampleSize - 1)) * covariance
        
        // Variance of each component should be near 1/12 ≈ 0.0833
        #expect(abs(covariance.mean - 1.0/12.0) < 0.01)
    }
    
    // MARK: - Real-world Use Case Tests
    
    @Test("Portfolio optimization simulation")
    func portfolioOptimizationSimulation() {
        // Simulate portfolio with 3 assets
        let returns = VectorN<Double>([0.08, 0.12, 0.05])  // Expected returns
        let weights = VectorN<Double>([0.4, 0.4, 0.2])     // Portfolio weights
        
        // Expected portfolio return: weighted sum
        let expectedReturn = returns.dot(weights)
        #expect(abs(expectedReturn - 0.088) < 1e-10)  // 0.4*0.08 + 0.4*0.12 + 0.2*0.05
        
        // Simulate covariance matrix (simplified)
        let volatilities = VectorN<Double>([0.15, 0.20, 0.10])  // Standard deviations
        let correlations = VectorN<Double>([1.0, 0.3, 0.1])     // Correlation with first asset
        
        // Calculate portfolio variance (simplified)
        let variance = weights.hadamard(volatilities).dot(weights.hadamard(volatilities))
        #expect(variance > 0)
        
        // Normalize weights to sum to 1
        let normalizedWeights = weights.normalized()
        #expect(abs(normalizedWeights.sum - 1.0) < 1e-10)
    }
    
    @Test("Neural network gradient calculation")
    func neuralNetworkGradientCalculation() {
        // Simulate neural network layer with 3 inputs, 2 outputs
        let inputs = VectorN<Double>([0.5, -0.2, 0.8])
        let weights = [
            VectorN<Double>([0.1, 0.2, -0.1]),  // First neuron weights
            VectorN<Double>([-0.2, 0.3, 0.1])   // Second neuron weights
        ]
        
        // Forward pass: W * x
        let outputs = inputs.multiply(by: weights)
        #expect(outputs != nil)
        #expect(outputs!.count == 2)
        
        // Calculate output: 0.1*0.5 + 0.2*(-0.2) + (-0.1)*0.8 = -0.07
        #expect(abs(outputs![0] - (-0.07)) < 1e-10)
        
        // Backward pass: gradient w.r.t. inputs
        let outputGradients = VectorN<Double>([1.0, -1.0])  // Example gradients
        var inputGradients = VectorN<Double>.withDimension(inputs.count)
        
        for (i, weightVector) in weights.enumerated() {
            inputGradients = inputGradients + outputGradients[i] * weightVector
        }
        
        #expect(inputGradients.count == 3)
        // Should be: [0.1*1 + (-0.2)*(-1), 0.2*1 + 0.3*(-1), (-0.1)*1 + 0.1*(-1)]
        #expect(abs(inputGradients[0] - 0.3) < 1e-10)
        #expect(abs(inputGradients[1] - (-0.1)) < 1e-10)
        #expect(abs(inputGradients[2] - (-0.2)) < 1e-10)
    }
    
    @Test("Physical simulation - projectile motion")
    func physicalSimulationProjectileMotion() {
        // Simulate projectile motion with vectors
        let gravity = VectorN<Double>([0.0, -9.81])  // m/s²
        let initialVelocity = VectorN<Double>([10.0, 20.0])  // m/s
        let initialPosition = VectorN<Double>([0.0, 0.0])    // meters
        
        let timeSteps = 100
        let dt = 0.1  // seconds
        
        var position = initialPosition
        var velocity = initialVelocity
        
        var trajectory: [VectorN<Double>] = [position]
        
        for _ in 0..<timeSteps {
            // Update velocity: v = v + a*dt
            velocity = velocity + gravity * dt
            
            // Update position: p = p + v*dt
            position = position + velocity * dt
            
            trajectory.append(position)
        }
        
        // Verify physics
        #expect(trajectory.count == timeSteps + 1)
        
        // Final y-position should be negative (fell below starting point)
        #expect(trajectory.last![1] < 0)
        
        // x-position should increase monotonically
        for i in 1..<trajectory.count {
            #expect(trajectory[i][0] > trajectory[i-1][0])
        }
        
        // Peak height calculation
        let timeToPeak = -initialVelocity[1] / gravity[1]  // vy = 0 at peak
        let peakHeight = initialPosition[1] + initialVelocity[1] * timeToPeak + 0.5 * gravity[1] * timeToPeak * timeToPeak
        #expect(peakHeight > 0)
    }
    
    @Test("Data normalization for machine learning")
    func dataNormalizationForMachineLearning() {
        // Create dataset with different scales
        let dataset = [
            VectorN<Double>([100.0, 0.1, 50000.0]),
            VectorN<Double>([200.0, 0.2, 60000.0]),
            VectorN<Double>([150.0, 0.15, 55000.0]),
            VectorN<Double>([180.0, 0.18, 58000.0])
        ]
        
        // Calculate mean and standard deviation
        var mean = VectorN<Double>.withDimension(3)
        for sample in dataset {
            mean = mean + sample
        }
        mean = (1.0 / Double(dataset.count)) * mean
        
        var variance = VectorN<Double>.withDimension(3)
        for sample in dataset {
            let diff = sample - mean
            variance = variance + diff.hadamard(diff)
        }
        variance = (1.0 / Double(dataset.count - 1)) * variance
        let stdDev = variance.toArray().map { sqrt($0) }
        
        // Normalize dataset: (x - mean) / stdDev
        var normalizedDataset: [VectorN<Double>] = []
        for sample in dataset {
            let normalized = (sample - mean).elementwiseDivide(by: VectorN<Double>(stdDev))
            normalizedDataset.append(normalized)
            
            // Check properties
            #expect(abs(normalized.mean) < 0.01)  // Mean near 0
            #expect(abs(normalized.standardDeviation - 1.0) < 0.01)  // Std dev near 1
        }
        
        #expect(normalizedDataset.count == dataset.count)
    }
    
    @Test("Image processing - vectorized operations")
    func imageProcessingVectorizedOperations() {
        // Simulate image pixel operations (grayscale, 3x3 patch)
        let patch = VectorN<Double>([
            0.1, 0.2, 0.3,
            0.4, 0.5, 0.6,
            0.7, 0.8, 0.9
        ])
        
        // Edge detection kernel (simplified Sobel)
        let sobelX = VectorN<Double>([
            -1, 0, 1,
            -2, 0, 2,
            -1, 0, 1
        ])
        
        let sobelY = VectorN<Double>([
            -1, -2, -1,
             0,  0,  0,
             1,  2,  1
        ])
        
        // Convolution as dot product
        let gradientX = patch.dot(sobelX)
        let gradientY = patch.dot(sobelY)
        
        // Gradient magnitude
        let magnitude = sqrt(gradientX * gradientX + gradientY * gradientY)
        #expect(magnitude > 0)
        
        // Gradient direction
        let direction = atan2(gradientY, gradientX)
        #expect(direction >= -.pi && direction <= .pi)
        
        // Test brightness adjustment
        let brightnessFactor = 1.5
        let brightened = brightnessFactor * patch
        #expect(brightened.mean > patch.mean)
        
        // Test contrast adjustment
        let meanBrightness = patch.mean
        let contrastAdjusted = (patch - meanBrightness) * 2.0 + meanBrightness
        #expect(contrastAdjusted.standardDeviation > patch.standardDeviation)
    }
    
    // MARK: - Advanced Mathematical Tests
    
    @Test("Gram-Schmidt orthogonalization")
    func gramSchmidtOrthogonalization() {
        // Create a set of linearly independent vectors
        let v1 = VectorN<Double>([1.0, 1.0, 0.0])
        let v2 = VectorN<Double>([1.0, 0.0, 1.0])
        let v3 = VectorN<Double>([0.0, 1.0, 1.0])
        
        var orthogonalSet: [VectorN<Double>] = []
        
        // Gram-Schmidt process
        for v in [v1, v2, v3] {
            var u = v
            for orthoVec in orthogonalSet {
                let projection = v.project(onto: orthoVec)
                u = u - projection
            }
            
            // Only add if not zero vector (linearly independent)
            if u.norm > 1e-10 {
                orthogonalSet.append(u.normalized())
            }
        }
        
        // All vectors should be orthogonal
        for i in 0..<orthogonalSet.count {
            for j in 0..<orthogonalSet.count where i != j {
                let dotProduct = orthogonalSet[i].dot(orthogonalSet[j])
                #expect(abs(dotProduct) < 1e-10)
            }
            // And unit length
            #expect(abs(orthogonalSet[i].norm - 1.0) < 1e-10)
        }
        
        #expect(orthogonalSet.count == 3)  // Should have 3 orthogonal vectors
    }
    
    @Test("Eigenvalue approximation (power iteration)")
    func eigenvalueApproximation() {
        // Simple symmetric matrix
        let matrix = [
            VectorN<Double>([2.0, 1.0]),
            VectorN<Double>([1.0, 2.0])
        ]
        
        // Power iteration for dominant eigenvalue
        var b = VectorN<Double>([1.0, 1.0]).normalized()
        var eigenvalue: Double = 0.0
        
        for _ in 0..<100 {
            // Multiply by matrix
            guard let Ab = b.multiply(by: matrix) else { break }
            
            // Normalize
            let newB = Ab.normalized()
            
            // Rayleigh quotient for eigenvalue estimate
            eigenvalue = b.dot(Ab) / b.dot(b)
            
            // Check convergence
            if (newB - b).norm < 1e-10 {
                break
            }

I'll continue with the advanced mathematical tests and complete the VectorSpace test suite:

**File:** `Tests/BusinessMathTests/OptimizationTests/VectorSpaceTests.swift` (Continued)

```swift
            b = newB
        }
        
        // Dominant eigenvalue should be 3 for this matrix
        #expect(abs(eigenvalue - 3.0) < 1e-8)
        
        // Eigenvector should be [1, 1] direction (normalized)
        let expectedEigenvector = VectorN<Double>([1.0, 1.0]).normalized()
        let angle = b.angle(with: expectedEigenvector)
        #expect(abs(angle) < 1e-8)  // Should be aligned
    }
    
    @Test("Singular Value Decomposition simulation")
    func singularValueDecompositionSimulation() {
        // Simple 2x2 matrix for SVD simulation
        let A = [
            VectorN<Double>([3.0, 0.0]),
            VectorN<Double>([0.0, 2.0])
        ]
        
        // Compute A^T * A for eigenvalues (squares of singular values)
        let n = A[0].count
        var ATA = [[Double]](repeating: [Double](repeating: 0.0, count: n), count: n)
        
        for i in 0..<n {
            for j in 0..<n {
                var sum: Double = 0.0
                for row in A {
                    sum += row[i] * row[j]
                }
                ATA[i][j] = sum
            }
        }
        
        // For diagonal matrix, eigenvalues are diagonal entries
        let singularValues = [sqrt(ATA[0][0]), sqrt(ATA[1][1])]
        #expect(abs(singularValues[0] - 3.0) < 1e-10)
        #expect(abs(singularValues[1] - 2.0) < 1e-10)
        
        // Test matrix reconstruction using outer products
        let u1 = VectorN<Double>([1.0, 0.0])
        let u2 = VectorN<Double>([0.0, 1.0])
        let v1 = VectorN<Double>([1.0, 0.0])
        let v2 = VectorN<Double>([0.0, 1.0])
        
        // A = σ1 * u1 * v1^T + σ2 * u2 * v2^T
        let outer1 = u1.outerProduct(with: v1)
        let outer2 = u2.outerProduct(with: v2)
        
        // Reconstruct matrix
        var reconstructed = [[Double]](repeating: [Double](repeating: 0.0, count: n), count: A.count)
        for i in 0..<A.count {
            for j in 0..<n {
                reconstructed[i][j] = singularValues[0] * outer1[i][j] + 
                                      singularValues[1] * outer2[i][j]
            }
        }
        
        // Should match original matrix
        #expect(abs(reconstructed[0][0] - 3.0) < 1e-10)
        #expect(abs(reconstructed[1][1] - 2.0) < 1e-10)
        #expect(abs(reconstructed[0][1]) < 1e-10)
        #expect(abs(reconstructed[1][0]) < 1e-10)
    }
    
    @Test("Linear system solving (conjugate gradient)")
    func linearSystemSolving() {
        // Solve Ax = b using conjugate gradient method
        // A = [[4, 1], [1, 3]] (symmetric positive definite)
        let A = [
            VectorN<Double>([4.0, 1.0]),
            VectorN<Double>([1.0, 3.0])
        ]
        let b = VectorN<Double>([1.0, 2.0])
        
        // Initial guess
        var x = VectorN<Double>([0.0, 0.0])
        var r = b  // Residual: r = b - A*x
        var p = r  // Search direction
        
        for _ in 0..<10 {
            // Compute A*p
            guard let Ap = p.multiply(by: A) else { break }
            
            // Compute alpha
            let alpha = r.dot(r) / p.dot(Ap)
            
            // Update solution
            x = x + alpha * p
            
            // Update residual
            let rNew = r - alpha * Ap
            
            // Compute beta
            let beta = rNew.dot(rNew) / r.dot(r)
            
            // Update search direction
            p = rNew + beta * p
            
            r = rNew
            
            // Check convergence
            if r.norm < 1e-10 {
                break
            }
        }
        
        // Verify solution: x should satisfy A*x ≈ b
        guard let Ax = x.multiply(by: A) else {
            Issue.record("Matrix multiplication failed")
            return
        }
        
        let residual = b - Ax
        #expect(residual.norm < 1e-8)
        
        // Exact solution is [0.0909..., 0.6363...]
        #expect(abs(x[0] - 1.0/11.0) < 1e-8)
        #expect(abs(x[1] - 7.0/11.0) < 1e-8)
    }
    
    @Test("Principal Component Analysis simulation")
    func principalComponentAnalysisSimulation() {
        // Create correlated 2D data
        let data = [
            VectorN<Double>([1.0, 1.0]),
            VectorN<Double>([2.0, 2.0]),
            VectorN<Double>([3.0, 3.0]),
            VectorN<Double>([4.0, 4.0]),
            VectorN<Double>([5.0, 5.0])
        ]
        
        // Center the data
        var mean = VectorN<Double>.withDimension(2)
        for point in data {
            mean = mean + point
        }
        mean = (1.0 / Double(data.count)) * mean
        
        let centeredData = data.map { $0 - mean }
        
        // Compute covariance matrix
        var covariance = [[Double]](repeating: [Double](repeating: 0.0, count: 2), count: 2)
        for point in centeredData {
            let outer = point.outerProduct(with: point)
            for i in 0..<2 {
                for j in 0..<2 {
                    covariance[i][j] += outer[i][j]
                }
            }
        }
        
        for i in 0..<2 {
            for j in 0..<2 {
                covariance[i][j] /= Double(data.count - 1)
            }
        }
        
        // For perfectly correlated data, first principal component should be [1, 1] direction
        let expectedPC = VectorN<Double>([1.0, 1.0]).normalized()
        
        // Power iteration to find first principal component
        var pc = VectorN<Double>([1.0, 0.0])
        let covMatrix = [
            VectorN<Double>(covariance[0]),
            VectorN<Double>(covariance[1])
        ]
        
        for _ in 0..<50 {
            guard let newPC = pc.multiply(by: covMatrix) else { break }
            pc = newPC.normalized()
        }
        
        // Should align with [1, 1] direction
        let angle = pc.angle(with: expectedPC)
        #expect(abs(angle) < 1e-8 || abs(angle - .pi) < 1e-8)  // Direction or opposite
        
        // Project data onto first PC
        let projectedData = centeredData.map { $0.project(onto: pc) }
        
        // Variance along PC should be large
        let varianceAlongPC = projectedData.map { $0.squaredNorm }.reduce(0, +) / Double(data.count - 1)
        #expect(varianceAlongPC > 0)
    }
    
    @Test("Manifold optimization - gradient on sphere")
    func manifoldOptimizationOnSphere() {
        // Optimize a function on the unit sphere (manifold constraint)
        // Function: f(x) = xᵀ * M * x, where M = diag(1, 2, 3)
        // Constraint: ||x|| = 1
        
        let M = [
            VectorN<Double>([1.0, 0.0, 0.0]),
            VectorN<Double>([0.0, 2.0, 0.0]),
            VectorN<Double>([0.0, 0.0, 3.0])
        ]
        
        // Riemannian gradient descent on sphere
        var x = VectorN<Double>([1.0, 1.0, 1.0]).normalized()
        let learningRate = 0.1
        
        for _ in 0..<100 {
            // Euclidean gradient: ∇f(x) = 2 * M * x
            guard let Mx = x.multiply(by: M) else { break }
            let euclideanGradient = 2.0 * Mx
            
            // Riemannian gradient: project onto tangent space
            let riemannianGradient = euclideanGradient - euclideanGradient.dot(x) * x
            
            // Retraction: move along geodesic (simplified)
            let step = -learningRate * riemannianGradient
            x = (x + step).normalized()
        }
        
        // Should converge to eigenvector of M with smallest eigenvalue (1)
        // which is [1, 0, 0] direction
        let expectedMin = VectorN<Double>([1.0, 0.0, 0.0])
        let angle = x.angle(with: expectedMin)
        #expect(abs(angle) < 0.1)  // Should be close to x-axis
        
        // Verify constraint maintained
        #expect(abs(x.norm - 1.0) < 1e-10)
    }
    
    @Test("Automatic differentiation simulation")
    func automaticDifferentiationSimulation() {
        // Simulate forward-mode automatic differentiation using dual numbers
        struct DualNumber {
            let value: Double
            let derivative: Double
            
            static func *(lhs: DualNumber, rhs: DualNumber) -> DualNumber {
                DualNumber(
                    value: lhs.value * rhs.value,
                    derivative: lhs.derivative * rhs.value + lhs.value * rhs.derivative
                )
            }
            
            static func +(lhs: DualNumber, rhs: DualNumber) -> DualNumber {
                DualNumber(
                    value: lhs.value + rhs.value,
                    derivative: lhs.derivative + rhs.derivative
                )
            }
        }
        
        // Function: f(x,y) = x² + y²
        // Gradient should be [2x, 2y]
        let x = DualNumber(value: 3.0, derivative: 1.0)  // Differentiate w.r.t. x
        let y = DualNumber(value: 4.0, derivative: 0.0)  // Constant w.r.t. x
        
        let xSquared = x * x
        let ySquared = y * y
        let f = xSquared + ySquared
        
        // ∂f/∂x = 2x = 6
        #expect(abs(f.derivative - 6.0) < 1e-10)
        #expect(abs(f.value - 25.0) < 1e-10)  // 3² + 4² = 25
        
        // Now differentiate w.r.t. y
        let x2 = DualNumber(value: 3.0, derivative: 0.0)
        let y2 = DualNumber(value: 4.0, derivative: 1.0)
        
        let f2 = (x2 * x2) + (y2 * y2)
        #expect(abs(f2.derivative - 8.0) < 1e-10)  // 2y = 8
        
        // Vector version: compute gradient of vector function
        let input = VectorN<DualNumber>([
            DualNumber(value: 1.0, derivative: 1.0),
            DualNumber(value: 2.0, derivative: 0.0)
        ])
        
        // Function: [x², y²]
        let output = VectorN<DualNumber>([
            input[0] * input[0],
            input[1] * input[1]
        ])
        
        // Jacobian diagonal should be [2x, 2y] = [2, 4]
        #expect(abs(output[0].derivative - 2.0) < 1e-10)
        #expect(abs(output[1].derivative - 0.0) < 1e-10)  // ∂(y²)/∂x = 0
    }
    
    @Test("Fourier analysis simulation")
    func fourierAnalysisSimulation() {
        // Discrete Fourier Transform using vector operations
        let signal = VectorN<Double>([1.0, 0.0, -1.0, 0.0])
        let N = signal.count
        
        // Compute DFT matrix
        var dftMatrix: [VectorN<Double>] = []
        for k in 0..<N {
            var row: [Double] = []
            for n in 0..<N {
                let angle = -2.0 * .pi * Double(k) * Double(n) / Double(N)
                row.append(cos(angle))  // Real part only for simplicity
            }
            dftMatrix.append(VectorN<Double>(row))
        }
        
        // Compute DFT
        guard let dft = signal.multiply(by: dftMatrix) else {
            Issue.record("DFT computation failed")
            return
        }
        
        // For signal [1, 0, -1, 0], DFT should have specific pattern
        // DC component (k=0) should be 0
        #expect(abs(dft[0]) < 1e-10)
        
        // Parseval's theorem: sum(|x[n]|²) = (1/N) * sum(|X[k]|²)
        let signalEnergy = signal.toArray().map { $0 * $0 }.reduce(0, +)
        let spectrumEnergy = dft.toArray().map { $0 * $0 }.reduce(0, +) / Double(N)
        #expect(abs(signalEnergy - spectrumEnergy) < 1e-10)
        
        // Test convolution theorem: convolution in time = multiplication in frequency
        let kernel = VectorN<Double>([1.0, 1.0])
        
        // Time-domain convolution (simplified)
        var convolution = VectorN<Double>.withDimension(N)
        for i in 0..<N {
            for j in 0..<kernel.count {
                if i - j >= 0 {
                    convolution[i] = convolution[i] + signal[i - j] * kernel[j]
                }
            }
        }
        
        // Frequency-domain multiplication
        guard let signalDFT = signal.multiply(by: dftMatrix),
              let kernelDFT = kernel.multiply(by: dftMatrix) else {
            Issue.record("DFT computation failed")
            return
        }
        
        let productDFT = signalDFT.hadamard(kernelDFT)
        
        // Should satisfy convolution theorem (within scaling)
        let convolutionEnergy = convolution.toArray().map { $0 * $0 }.reduce(0, +)
        let productEnergy = productDFT.toArray().map { $0 * $0 }.reduce(0, +) / Double(N)
        #expect(abs(convolutionEnergy - productEnergy) < 1e-10)
    }
    
    @Test("Support Vector Machine margin calculation")
    func supportVectorMachineMarginCalculation() {
        // Simple linear SVM with 2D data
        let positiveExamples = [
            VectorN<Double>([1.0, 2.0]),
            VectorN<Double>([2.0, 3.0]),
            VectorN<Double>([3.0, 3.0])
        ]
        
        let negativeExamples = [
            VectorN<Double>([-1.0, -1.0]),
            VectorN<Double>([-2.0, -2.0]),
            VectorN<Double>([-3.0, -2.0])
        ]
        
        // Find maximum margin hyperplane (simplified)
        // For linearly separable data along x=y line, optimal w = [1, -1]
        let w = VectorN<Double>([1.0, -1.0]).normalized()
        let b = 0.0
        
        // Calculate margins
        var minPositiveMargin = Double.infinity
        var minNegativeMargin = Double.infinity
        
        for example in positiveExamples {
            let margin = w.dot(example) + b
            minPositiveMargin = min(minPositiveMargin, margin)
        }
        
        for example in negativeExamples {
            let margin = w.dot(example) + b
            minNegativeMargin = min(minNegativeMargin, -margin)  // Negative class
        }
        
        // Total margin = distance between closest points of each class
        let totalMargin = minPositiveMargin + minNegativeMargin
        #expect(totalMargin > 0)
        
        // Support vectors should be closest to hyperplane
        let supportVectors = (positiveExamples + negativeExamples).filter { example in
            let distance = abs(w.dot(example) + b)
            return abs(distance - minPositiveMargin) < 1e-10 || 
                   abs(distance - minNegativeMargin) < 1e-10
        }
        
        #expect(supportVectors.count >= 2)  // At least one from each class
        
        // Verify classification
        for example in positiveExamples {
            let prediction = w.dot(example) + b
            #expect(prediction > 0)
        }
        
        for example in negativeExamples {
            let prediction = w.dot(example) + b
            #expect(prediction < 0)
        }
    }
    
    @Test("Kalman filter state update")
    func kalmanFilterStateUpdate() {
        // Simple 
I'll continue with the Kalman filter tests and complete the VectorSpace test suite:

**File:** `Tests/BusinessMathTests/OptimizationTests/VectorSpaceTests.swift` (Continued)

```swift
    @Test("Kalman filter state update")
    func kalmanFilterStateUpdate() {
        // Simple 1D Kalman filter simulation
        // State: position and velocity
        var state = VectorN<Double>([0.0, 0.0])  // [position, velocity]
        let stateTransition = [
            VectorN<Double>([1.0, 1.0]),  // position_new = position + velocity
            VectorN<Double>([0.0, 1.0])   // velocity_new = velocity
        ]
        
        let processNoiseCovariance = [
            VectorN<Double>([0.01, 0.0]),
            VectorN<Double>([0.0, 0.01])
        ]
        
        let measurementMatrix = [
            VectorN<Double>([1.0, 0.0])  // Only measure position
        ]
        
        let measurementNoise = 0.1
        
        // Simulate measurements
        let truePosition = 5.0
        let trueVelocity = 0.5
        var measurements: [Double] = []
        var estimatedStates: [VectorN<Double>] = [state]
        
        // Kalman filter matrices (simplified)
        var covariance = [
            VectorN<Double>([1.0, 0.0]),
            VectorN<Double>([0.0, 1.0])
        ]
        
        for step in 0..<10 {
            // True state evolution
            let trueState = VectorN<Double>([
                truePosition + trueVelocity * Double(step),
                trueVelocity
            ])
            
            // Generate noisy measurement
            let measurement = trueState[0] + Double.random(in: -0.5...0.5)
            measurements.append(measurement)
            
            // Prediction step
            guard let predictedState = state.multiply(by: stateTransition),
                  let predictedCovariance = multiplyMatrices(
                    multiplyMatrices(stateTransition, covariance),
                    transposeMatrix(stateTransition)
                  ) else {
                Issue.record("Prediction failed")
                return
            }
            
            // Add process noise
            let predictedCovarianceWithNoise = addMatrices(
                predictedCovariance,
                processNoiseCovariance
            )
            
            // Update step (Kalman gain)
            guard let S = multiplyMatrices(
                    multiplyMatrices(measurementMatrix, predictedCovarianceWithNoise),
                    transposeMatrix(measurementMatrix)
                  ) else {
                Issue.record("Innovation covariance failed")
                return
            }
            
            let innovationCovariance = S[0][0] + measurementNoise
            guard let K = multiplyMatrices(
                    predictedCovarianceWithNoise,
                    transposeMatrix(measurementMatrix)
                  )?.map({ row in
                    VectorN<Double>(row.map { $0 / innovationCovariance })
                  }) else {
                Issue.record("Kalman gain failed")
                return
            }
            
            // State update
            let measurementVector = VectorN<Double>([measurement])
            guard let measurementPrediction = predictedState.multiply(by: measurementMatrix),
                  let innovation = measurementVector - measurementPrediction,
                  let correction = K.multiply(by: [innovation]) else {
                Issue.record("Update failed")
                return
            }
            
            state = predictedState + correction[0]
            estimatedStates.append(state)
            
            // Covariance update
            guard let KH = multiplyMatrices(K, measurementMatrix) else {
                Issue.record("Covariance update failed")
                return
            }
            
            let identity = createIdentityMatrix(size: 2)
            let IminusKH = subtractMatrices(identity, KH)
            covariance = multiplyMatrices(
                multiplyMatrices(IminusKH, predictedCovarianceWithNoise),
                transposeMatrix(IminusKH)
            ) ?? covariance
        }
        
        // Verify filter convergence
        #expect(estimatedStates.count == 11)
        
        // Final estimate should be close to true values
        let finalError = abs(state[0] - (truePosition + trueVelocity * 9.0))
        #expect(finalError < 1.0)  // Should converge within reasonable error
        
        // Velocity estimate should also converge
        #expect(abs(state[1] - trueVelocity) < 0.5)
    }
    
    // Helper functions for matrix operations
    private func multiplyMatrices(_ A: [VectorN<Double>], _ B: [VectorN<Double>]) -> [VectorN<Double>]? {
        guard !A.isEmpty && !B.isEmpty else { return nil }
        
        let n = A.count
        let m = B[0].count
        let p = B.count
        
        var result = [VectorN<Double>]()
        
        for i in 0..<n {
            var row = [Double]()
            for j in 0..<m {
                var sum = 0.0
                for k in 0..<p {
                    sum += A[i][k] * B[k][j]
                }
                row.append(sum)
            }
            result.append(VectorN<Double>(row))
        }
        
        return result
    }
    
    private func transposeMatrix(_ A: [VectorN<Double>]) -> [VectorN<Double>] {
        guard !A.isEmpty else { return [] }
        
        let n = A.count
        let m = A[0].count
        
        var result = [VectorN<Double>]()
        
        for j in 0..<m {
            var column = [Double]()
            for i in 0..<n {
                column.append(A[i][j])
            }
            result.append(VectorN<Double>(column))
        }
        
        return result
    }
    
    private func addMatrices(_ A: [VectorN<Double>], _ B: [VectorN<Double>]) -> [VectorN<Double>] {
        guard A.count == B.count && !A.isEmpty else { return [] }
        
        var result = [VectorN<Double>]()
        for i in 0..<A.count {
            result.append(A[i] + B[i])
        }
        return result
    }
    
    private func subtractMatrices(_ A: [VectorN<Double>], _ B: [VectorN<Double>]) -> [VectorN<Double>] {
        guard A.count == B.count && !A.isEmpty else { return [] }
        
        var result = [VectorN<Double>]()
        for i in 0..<A.count {
            result.append(A[i] - B[i])
        }
        return result
    }
    
    private func createIdentityMatrix(size: Int) -> [VectorN<Double>] {
        var result = [VectorN<Double>]()
        for i in 0..<size {
            var row = [Double](repeating: 0.0, count: size)
            row[i] = 1.0
            result.append(VectorN<Double>(row))
        }
        return result
    }
    
    // MARK: - Quantum Computing Simulation
    
    @Test("Quantum state vector operations")
    func quantumStateVectorOperations() {
        // Quantum state represented as complex vector
        // For simplicity, use real vectors with paired components [real, imag]
        
        // |0⟩ state: [1, 0, 0, 0] as [real0, imag0, real1, imag1]
        let zeroState = VectorN<Double>([1.0, 0.0, 0.0, 0.0])
        
        // |1⟩ state: [0, 0, 1, 0]
        let oneState = VectorN<Double>([0.0, 0.0, 1.0, 0.0])
        
        // Hadamard gate on |0⟩: H|0⟩ = (|0⟩ + |1⟩)/√2
        let hadamardMatrix = [
            VectorN<Double>([1.0/√2, 0.0, 1.0/√2, 0.0]),
            VectorN<Double>([0.0, 1.0/√2, 0.0, 1.0/√2]),
            VectorN<Double>([1.0/√2, 0.0, -1.0/√2, 0.0]),
            VectorN<Double>([0.0, 1.0/√2, 0.0, -1.0/√2])
        ]
        
        guard let hadamardZero = zeroState.multiply(by: hadamardMatrix) else {
            Issue.record("Hadamard gate failed")
            return
        }
        
        // Should produce equal superposition
        let expectedSuperposition = VectorN<Double>([
            1.0/√2, 0.0,  // real0
            0.0, 1.0/√2,  // imag0 (should be 0)
            1.0/√2, 0.0,  // real1
            0.0, 1.0/√2   // imag1 (should be 0)
        ])
        
        // Check magnitude (norm should be 1 for quantum states)
        #expect(abs(hadamardZero.norm - 1.0) < 1e-10)
        
        // Check probabilities: |amplitude|²
        let prob0 = hadamardZero[0]*hadamardZero[0] + hadamardZero[1]*hadamardZero[1]
        let prob1 = hadamardZero[2]*hadamardZero[2] + hadamardZero[3]*hadamardZero[3]
        
        #expect(abs(prob0 - 0.5) < 1e-10)
        #expect(abs(prob1 - 0.5) < 1e-10)
        
        // Pauli-X gate (quantum NOT): X|0⟩ = |1⟩
        let pauliX = [
            VectorN<Double>([0.0, 0.0, 1.0, 0.0]),
            VectorN<Double>([0.0, 0.0, 0.0, 1.0]),
            VectorN<Double>([1.0, 0.0, 0.0, 0.0]),
            VectorN<Double>([0.0, 1.0, 0.0, 0.0])
        ]
        
        guard let xOnZero = zeroState.multiply(by: pauliX) else {
            Issue.record("Pauli-X gate failed")
            return
        }
        
        #expect(abs(xOnZero[0]) < 1e-10)  // real0 ≈ 0
        #expect(abs(xOnZero[2] - 1.0) < 1e-10)  // real1 ≈ 1
    }
    
    @Test("Quantum entanglement (Bell state)")
    func quantumEntanglementBellState() {
        // Create Bell state: (|00⟩ + |11⟩)/√2
        // Represented as 4-qubit state vector (simplified as real)
        
        let bellState = VectorN<Double>([
            1.0/√2, 0.0,  // |00⟩ amplitude
            0.0, 0.0,     // |01⟩
            0.0, 0.0,     // |10⟩
            1.0/√2, 0.0   // |11⟩
        ])
        
        // Verify entanglement properties
        #expect(abs(bellState.norm - 1.0) < 1e-10)
        
        // Probabilities
        let prob00 = bellState[0]*bellState[0] + bellState[1]*bellState[1]
        let prob11 = bellState[6]*bellState[6] + bellState[7]*bellState[7]
        
        #expect(abs(prob00 - 0.5) < 1e-10)
        #expect(abs(prob11 - 0.5) < 1e-10)
        
        // Measurement correlation: if first qubit is 0, second must be 0
        // if first qubit is 1, second must be 1
        // This is the defining property of entanglement
    }
    
    // MARK: - Game Theory and Economics
    
    @Test("Nash equilibrium calculation")
    func nashEquilibriumCalculation() {
        // Simple 2x2 game: Prisoner's Dilemma
        // Payoff matrices for two players
        
        // Player 1 payoffs (Cooperate, Defect) x (Cooperate, Defect)
        let player1Payoffs = [
            VectorN<Double>([3.0, 0.0]),  // If both cooperate
            VectorN<Double>([5.0, 1.0])   // If player1 defects
        ]
        
        // Player 2 payoffs (transpose for symmetry in Prisoner's Dilemma)
        let player2Payoffs = [
            VectorN<Double>([3.0, 5.0]),  // If both cooperate
            VectorN<Double>([0.0, 1.0])   // If player2 defects
        ]
        
        // Find Nash equilibrium (both defect is equilibrium in Prisoner's Dilemma)
        let strategies = [VectorN<Double>([1.0, 0.0]),  // Cooperate
                         VectorN<Double>([0.0, 1.0])]  // Defect
        
        var nashEquilibria: [(VectorN<Double>, VectorN<Double>)] = []
        
        for s1 in strategies {
            for s2 in strategies {
                // Calculate expected payoffs
                guard let p1 = s1.multiply(by: player1Payoffs),
                      let p2 = s2.multiply(by: player2Payoffs),
                      let payoff1 = p1.dot(s2),
                      let payoff2 = p2.dot(s1) else {
                    continue
                }
                
                // Check if it's a Nash equilibrium
                var isNash = true
                
                for altS1 in strategies where altS1 != s1 {
                    guard let altP1 = altS1.multiply(by: player1Payoffs),
                          let altPayoff1 = altP1.dot(s2) else {
                        continue
                    }
                    if altPayoff1 > payoff1 {
                        isNash = false
                        break
                    }
                }
                
                for altS2 in strategies where altS2 != s2 {
                    guard let altP2 = altS2.multiply(by: player2Payoffs),
                          let altPayoff2 = altP2.dot(s1) else {
                        continue
                    }
                    if altPayoff2 > payoff2 {
                        isNash = false
                        break
                    }
                }
                
                if isNash {
                    nashEquilibria.append((s1, s2))
                }
            }
        }
        
        // In Prisoner's Dilemma, only (Defect, Defect) is Nash equilibrium
        #expect(nashEquilibria.count == 1)
        let (eq1, eq2) = nashEquilibria[0]
        #expect(eq1[1] == 1.0)  // Player 1 defects
        #expect(eq2[1] == 1.0)  // Player 2 defects
    }
    
    @Test("Portfolio risk optimization")
    func portfolioRiskOptimization() {
        // Modern Portfolio Theory optimization
        let nAssets = 3
        
        // Expected returns
        let returns = VectorN<Double>([0.08, 0.12, 0.05])
        
        // Covariance matrix (simplified diagonal)
        let volatilities = VectorN<Double>([0.15, 0.20, 0.10])
        let correlation = 0.3
        
        // Build covariance matrix
        var covariance = [[Double]](repeating: [Double](repeating: 0.0, count: nAssets), count: nAssets)
        for i in 0..<nAssets {
            for j in 0..<nAssets {
                if i == j {
                    covariance[i][j] = volatilities[i] * volatilities[i]
                } else {
                    covariance[i][j] = correlation * volatilities[i] * volatilities[j]
                }
            }
        }
        
        // Convert to vector representation
        let covMatrix = covariance.map { VectorN<Double>($0) }
        
        // Find minimum variance portfolio
        // Solve: min wᵀΣw subject to ∑w = 1
        let ones = VectorN<Double>(repeating: 1.0, count: nAssets)
        
        // For diagonal covariance with equal correlation, solution is proportional to 1/σ²
        let inverseVariances = volatilities.toArray().map { 1.0 / ($0 * $0) }
        let sumInverse = inverseVariances.reduce(0, +)
        let minVarWeights = VectorN<Double>(inverseVariances.map { $0 / sumInverse })
        
        // Calculate portfolio statistics
        let portfolioReturn = returns.dot(minVarWeights)
        guard let portfolioVariance = minVarWeights.multiply(by: covMatrix)?.dot(minVarWeights) else {
            Issue.record("Portfolio variance calculation failed")
            return
        }
        
        let portfolioVolatility = sqrt(portfolioVariance)
        
        // Verify constraints
        #expect(abs(minVarWeights.sum - 1.0) < 1e-10)
        #expect(portfolioReturn > 0)
        #expect(portfolioVolatility > 0)
        
        // Sharpe ratio (assuming risk-free rate = 0.02)
        let riskFreeRate = 0.02
        let sharpeRatio = (portfolioReturn - riskFreeRate) / portfolioVolatility
        
        #expect(sharpeRatio > 0)  // Should be positive for these returns
    }
    
    // MARK: - Control Systems
    
    @Test("PID controller simulation")
    func pidControllerSimulation() {
        // Simulate PID controller for temperature control
        let setpoint = 100.0  // Desired temperature
        var processVariable = 20.0  // Current temperature
        let dt = 0.1  // Time step
        
        // PID
I'll continue with the PID controller simulation and complete the VectorSpace test suite:

**File:** `Tests/BusinessMathTests/OptimizationTests/VectorSpaceTests.swift` (Continued)

```swift
    @Test("PID controller simulation")
    func pidControllerSimulation() {
        // Simulate PID controller for temperature control
        let setpoint = 100.0  // Desired temperature
        var processVariable = 20.0  // Current temperature
        let dt = 0.1  // Time step
        
        // PID parameters
        let Kp = 2.0  // Proportional gain
        let Ki = 0.5  // Integral gain
        let Kd = 1.0  // Derivative gain
        
        var integral = 0.0
        var previousError = 0.0
        var timeHistory: [Double] = []
        var temperatureHistory: [Double] = []
        var controlHistory: [Double] = []
        
        // Simulate 100 time steps
        for step in 0..<100 {
            let error = setpoint - processVariable
            
            // PID terms
            let proportional = Kp * error
            integral += error * dt
            let integralTerm = Ki * integral
            let derivative = (error - previousError) / dt
            let derivativeTerm = Kd * derivative
            
            // Control output (heater power)
            let controlOutput = proportional + integralTerm + derivativeTerm
            
            // Clamp control output to realistic range
            let clampedOutput = max(0.0, min(controlOutput, 100.0))
            
            // Process model: simple first-order system
            // Temperature change = (heating - cooling) * dt
            let heating = clampedOutput * 0.1  // Heating efficiency
            let cooling = (processVariable - 20.0) * 0.05  // Natural cooling
            let temperatureChange = (heating - cooling) * dt
            
            processVariable += temperatureChange
            
            // Record history
            timeHistory.append(Double(step) * dt)
            temperatureHistory.append(processVariable)
            controlHistory.append(clampedOutput)
            
            previousError = error
        }
        
        // Convert histories to vectors for analysis
        let timeVector = VectorN<Double>(timeHistory)
        let tempVector = VectorN<Double>(temperatureHistory)
        let controlVector = VectorN<Double>(controlHistory)
        
        // Verify controller performance
        #expect(timeVector.count == 100)
        #expect(tempVector.count == 100)
        #expect(controlVector.count == 100)
        
        // Should reach near setpoint
        let finalError = abs(setpoint - tempVector[tempVector.count - 1])
        #expect(finalError < 5.0)  // Within 5 degrees
        
        // Check for overshoot (common in PID)
        let maxTemp = tempVector.max
        #expect(maxTemp > setpoint)  // Should overshoot slightly
        
        // Check settling time (time to reach within 2% of setpoint)
        let targetRange = setpoint * 0.02  // 2% tolerance
        var settlingTime: Double?
        
        for (i, temp) in tempVector.toArray().enumerated() {
            if abs(temp - setpoint) < targetRange {
                settlingTime = timeVector[i]
                break
            }
        }
        
        #expect(settlingTime != nil)
        #expect(settlingTime! < 5.0)  // Should settle within 5 seconds
        
        // Analyze control effort
        let avgControl = controlVector.mean
        #expect(avgControl > 0 && avgControl < 100)
        
        // Check for steady-state error (should be near zero with integral term)
        let steadyStateError = abs(setpoint - tempVector.mean)
        #expect(steadyStateError < 1.0)
    }
    
    @Test("State-space system simulation")
    func stateSpaceSystemSimulation() {
        // Mass-spring-damper system: m*x'' + c*x' + k*x = F
        // State-space representation: x' = A*x + B*u
        
        // Parameters
        let m = 1.0  // mass
        let c = 0.5  // damping
        let k = 2.0  // stiffness
        
        // State vector: [position, velocity]
        var x = VectorN<Double>([0.0, 0.0])
        
        // State matrix A
        let A = [
            VectorN<Double>([0.0, 1.0]),
            VectorN<Double>([-k/m, -c/m])
        ]
        
        // Input matrix B
        let B = [
            VectorN<Double>([0.0]),
            VectorN<Double>([1.0/m])
        ]
        
        // Simulation parameters
        let dt = 0.01
        let simulationTime = 10.0
        let steps = Int(simulationTime / dt)
        
        // Input force (step input)
        let F = 1.0
        
        var timeHistory: [Double] = []
        var positionHistory: [Double] = []
        var velocityHistory: [Double] = []
        
        for step in 0..<steps {
            let time = Double(step) * dt
            
            // State derivative: x' = A*x + B*u
            guard let Ax = x.multiply(by: A),
                  let Bu = VectorN<Double>([F]).multiply(by: B) else {
                Issue.record("State-space calculation failed")
                return
            }
            
            let xdot = Ax + Bu[0]
            
            // Euler integration: x = x + x'*dt
            x = x + xdot * dt
            
            // Record history
            timeHistory.append(time)
            positionHistory.append(x[0])
            velocityHistory.append(x[1])
        }
        
        // Convert to vectors
        let timeVector = VectorN<Double>(timeHistory)
        let positionVector = VectorN<Double>(positionHistory)
        let velocityVector = VectorN<Double>(velocityHistory)
        
        // Verify system properties
        #expect(timeVector.count == steps)
        #expect(positionVector.count == steps)
        #expect(velocityVector.count == steps)
        
        // Check steady-state position (for step input)
        // Static deflection: x_ss = F/k = 1/2 = 0.5
        let steadyStatePosition = 1.0 / k  // F/k
        let finalPosition = positionVector[positionVector.count - 1]
        #expect(abs(finalPosition - steadyStatePosition) < 0.01)
        
        // Check damping (should be underdamped with these parameters)
        // Natural frequency: ω_n = sqrt(k/m) = sqrt(2)
        // Damping ratio: ζ = c/(2*sqrt(m*k)) = 0.5/(2*sqrt(2)) ≈ 0.177 < 1 (underdamped)
        
        // Find peaks for oscillation analysis
        var peaks: [Double] = []
        for i in 1..<(positionVector.count - 1) {
            if positionVector[i] > positionVector[i-1] && positionVector[i] > positionVector[i+1] {
                peaks.append(positionVector[i])
            }
        }
        
        #expect(peaks.count > 2)  // Should oscillate
        
        // Calculate damping from peak ratios (logarithmic decrement)
        if peaks.count >= 3 {
            let delta = log(peaks[0] / peaks[1])
            let dampingRatio = delta / sqrt(4 * .pi * .pi + delta * delta)
            #expect(dampingRatio > 0.1 && dampingRatio < 0.3)  // Should match calculated ~0.177
        }
        
        // Energy conservation check (kinetic + potential)
        var totalEnergyHistory: [Double] = []
        for i in 0..<positionVector.count {
            let kinetic = 0.5 * m * velocityVector[i] * velocityVector[i]
            let potential = 0.5 * k * positionVector[i] * positionVector[i]
            totalEnergyHistory.append(kinetic + potential)
        }
        
        let energyVector = VectorN<Double>(totalEnergyHistory)
        let initialEnergy = energyVector[0]
        let finalEnergy = energyVector[energyVector.count - 1]
        
        // Energy should decrease due to damping
        #expect(finalEnergy < initialEnergy)
        
        // But should approach steady-state energy
        let steadyStateEnergy = 0.5 * k * steadyStatePosition * steadyStatePosition
        #expect(abs(finalEnergy - steadyStateEnergy) < 0.01)
    }
    
    @Test("Optimal control - LQR design")
    func optimalControlLQRDesign() {
        // Linear Quadratic Regulator design for double integrator
        // System: x' = A*x + B*u
        // Cost: J = ∫(xᵀQx + uᵀRu) dt
        
        // Double integrator: position and velocity
        let A = [
            VectorN<Double>([0.0, 1.0]),
            VectorN<Double>([0.0, 0.0])
        ]
        
        let B = [
            VectorN<Double>([0.0]),
            VectorN<Double>([1.0])
        ]
        
        // Weight matrices
        let Q = [
            VectorN<Double>([1.0, 0.0]),  // Penalize position error
            VectorN<Double>([0.0, 0.1])   // Penalize velocity
        ]
        
        let R = [VectorN<Double>([0.01])]  // Control effort penalty
        
        // Solve Algebraic Riccati Equation (simplified for this system)
        // For double integrator with these weights, solution is known
        
        // Optimal feedback gain: K = R⁻¹BᵀP
        // Where P solves: AᵀP + PA - PBR⁻¹BᵀP + Q = 0
        
        // For this simple case, we can compute directly
        // Let P = [[p11, p12], [p12, p22]]
        // Solving gives: p11 = sqrt(2R), p12 = R, p22 = sqrt(2R)
        
        let R_value = R[0][0]
        let p11 = sqrt(2.0 * R_value)
        let p12 = R_value
        let p22 = sqrt(2.0 * R_value)
        
        let P = [
            VectorN<Double>([p11, p12]),
            VectorN<Double>([p12, p22])
        ]
        
        // Compute optimal gain K = R⁻¹BᵀP
        guard let B_transpose = transposeMatrix(B),
              let BP = multiplyMatrices(B_transpose, P) else {
            Issue.record("Matrix multiplication failed")
            return
        }
        
        let K = BP.map { row in
            VectorN<Double>(row.toArray().map { $0 / R_value })
        }
        
        #expect(K.count == 1)  // Single input
        #expect(K[0].count == 2)  // Two states
        
        // Simulate closed-loop system
        var x = VectorN<Double>([1.0, 0.0])  // Initial position = 1, velocity = 0
        let dt = 0.01
        let steps = 500
        
        var positionHistory: [Double] = []
        var controlHistory: [Double] = []
        
        for _ in 0..<steps {
            // Optimal control: u = -K*x
            guard let u_vec = x.multiply(by: K) else { break }
            let u = -u_vec[0]  // Negative feedback
            
            // System dynamics: x' = A*x + B*u
            guard let Ax = x.multiply(by: A),
                  let Bu = VectorN<Double>([u]).multiply(by: B) else {
                break
            }
            
            let xdot = Ax + Bu[0]
            x = x + xdot * dt
            
            positionHistory.append(x[0])
            controlHistory.append(u)
        }
        
        // Verify optimal control properties
        let finalPosition = positionHistory.last ?? 0.0
        #expect(abs(finalPosition) < 0.01)  // Should regulate to zero
        
        // Control effort should be reasonable
        let controlEffort = controlHistory.map { $0 * $0 }.reduce(0, +) * dt
        #expect(controlEffort > 0 && controlEffort < 10.0)
        
        // Cost comparison with other gains
        let otherGains = [
            VectorN<Double>([0.5, 0.5]),  // Suboptimal
            VectorN<Double>([2.0, 2.0])   // Aggressive
        ]
        
        var costs: [Double] = []
        
        for testK in [K[0]] + otherGains {
            var testX = VectorN<Double>([1.0, 0.0])
            var testCost = 0.0
            
            for _ in 0..<steps {
                guard let u_vec = testX.multiply(by: [testK]) else { break }
                let u = -u_vec[0]
                
                // State cost: xᵀQx
                guard let Qx = testX.multiply(by: Q) else { break }
                let stateCost = testX.dot(Qx)
                
                // Control cost: uᵀRu
                let controlCost = u * R_value * u
                
                testCost += (stateCost + controlCost) * dt
                
                // Update state
                guard let Ax = testX.multiply(by: A),
                      let Bu = VectorN<Double>([u]).multiply(by: B) else {
                    break
                }
                
                let xdot = Ax + Bu[0]
                testX = testX + xdot * dt
            }
            
            costs.append(testCost)
        }
        
        // LQR should have lowest cost
        #expect(costs[0] < costs[1])  // Better than suboptimal
        #expect(costs[0] < costs[2])  // Better than aggressive
    }
    
    @Test("Model Predictive Control simulation")
    func modelPredictiveControlSimulation() {
        // Simple MPC for temperature control with constraints
        
        // System: first-order thermal system
        // T' = (T_env - T)/τ + α*u
        let tau = 5.0  // Time constant (seconds)
        let alpha = 0.2  // Heating coefficient
        let T_env = 20.0  // Ambient temperature
        
        var T = 20.0  // Current temperature
        let T_setpoint = 100.0
        let dt = 0.1
        
        // MPC parameters
        let horizon = 10  // Prediction horizon
        let controlHorizon = 5  // Control horizon
        
        // Constraints
        let u_min = 0.0
        let u_max = 100.0
        let T_min = 0.0
        let T_max = 150.0
        
        var timeHistory: [Double] = []
        var tempHistory: [Double] = []
        var controlHistory: [Double] = []
        
        // MPC simulation
        for step in 0..<100 {
            let time = Double(step) * dt
            
            // MPC optimization (simplified - gradient descent)
            var bestU: [Double] = Array(repeating: 0.0, count: controlHorizon)
            var bestCost = Double.infinity
            
            // Simple grid search for demonstration
            let u_options = stride(from: u_min, to: u_max, by: 10.0)
            
            for u_test in u_options {
                var T_pred = T
                var cost = 0.0
                var u_sequence: [Double] = []
                
                for k in 0..<horizon {
                    let u = (k < controlHorizon) ? u_test : 0.0
                    u_sequence.append(u)
                    
                    // Predict temperature
                    let dT = ((T_env - T_pred)/tau + alpha * u) * dt
                    T_pred += dT
                    
                    // Clamp temperature prediction
                    T_pred = max(T_min, min(T_max, T_pred))
                    
                    // Cost: tracking error + control effort
                    let error = T_setpoint - T_pred
                    cost += error * error * dt + 0.01 * u * u * dt
                }
                
                if cost < bestCost {
                    bestCost = cost
                    bestU = u_sequence
                }
            }
            
            // Apply first control input
            let u_optimal = bestU[0]
            
            // Update system
            let dT = ((T_env - T)/tau + alpha * u_optimal) * dt
            T += dT
            
            // Record
            timeHistory.append(time)
            tempHistory.append(T)
            controlHistory.append(u_optimal)
        }
        
        // Convert to vectors
        let timeVector = VectorN<Double>(timeHistory)
        let tempVector = VectorN<Double>(tempHistory)
        let controlVector = VectorN<Double>(controlHistory)
        
        // Verify MPC performance
        #expect(timeVector.count == 100)
        #expect(tempVector.count == 100)
        #expect(controlVector.count == 100)
        
        // Should reach setpoint
        let finalError = abs(T_setpoint - tempVector[tempVector.count - 1])
        #expect(finalError < 5.0)
        
        // Check constraint satisfaction
        #expect(controlVector.min >= u_min)
        #expect(controlVector.max <= u_max)
        #expect(tempVector.min >= T_min)
        #expect(tempVector.max <= T_max)
        
        // Control should be smooth (no excessive chattering)
        let controlChanges = (0..<(controlVector.count-1)).map { i in
            abs(controlVector[i+1] - controlVector[i])
        }
        
        let avgControlChange = VectorN<Double>(controlChanges).mean
        #expect(avgControlChange < 5.0)  // Smooth control
        
        // Compare with PID (from previous test)
        // MPC should have better constraint handling and preview capability
    }
    
    @Test("Robust control - H∞ design simulation")
    func robustControlHInfinityDesign() {
        // Simplified H∞ control simulation
        // System with uncertainty and disturbance
        
        // Nominal plant: G(s) = 1

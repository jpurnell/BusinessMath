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
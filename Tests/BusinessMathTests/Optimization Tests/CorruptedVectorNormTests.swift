//
//  CorruptedVectorNormTests.swift
//  BusinessMathTests
//
//  `VectorSpace.norm` scales by the largest component to avoid overflow, and guards the
//  division:
//
//      guard largest > T(0) else { return T(0) }
//
//  `T.maximum` follows IEEE 754 `maxNum`, which treats a NaN as *missing* — so
//  `maximum(nan, 4)` is `4` and only `maximum(nan, nan)` is `nan`. A vector with one bad
//  component therefore propagates NaN correctly, while a vector with **every** component bad
//  lands on `nan > 0`, which is false, and returns a norm of `0`.
//
//  Measured:
//
//      Vector2D(3, 4).norm         = 5
//      Vector2D(nan, 4).norm       = nan     <- propagates
//      Vector2D(nan, nan).norm     = 0       <- the zero vector
//      Vector3D(nan, nan, nan).norm = 0
//      VectorN([nan, nan]).norm    = 0
//
//  The consequence is stated in this file's own documentation, directly above the guard:
//  "a zero norm is read as a stationary point". A completely corrupted gradient therefore
//  reads as convergence, which is the one reading that stops the search instead of reporting
//  the failure.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Norms of a corrupted vector")
struct CorruptedVectorNormTests {

    /// One bad component already behaved correctly; this pins that it still does.
    @Test("PartiallyCorrupted_AlreadyPropagated")
    func partiallyCorruptedAlreadyPropagated() {
        #expect(Vector2D(x: Double.nan, y: 4.0).norm.isNaN)
        #expect(VectorN([Double.nan, 4.0]).norm.isNaN)
    }

    /// The gap: every component bad.
    @Test("FullyCorrupted_IsNotTheZeroVector")
    func fullyCorruptedIsNotTheZeroVector() {
        let two = Vector2D(x: Double.nan, y: Double.nan).norm
        let three = Vector3D(x: Double.nan, y: Double.nan, z: Double.nan).norm
        let n = VectorN([Double.nan, Double.nan]).norm
        #expect(two.isNaN, "Vector2D gave \(two)")
        #expect(three.isNaN, "Vector3D gave \(three)")
        #expect(n.isNaN, "VectorN gave \(n)")
    }

    /// A norm of zero has to keep meaning "the zero vector", or the fix would break the
    /// convergence test it protects.
    @Test("GenuineZeroVector_StillHasZeroNorm")
    func genuineZeroVectorStillHasZeroNorm() {
        #expect(Vector2D(x: 0.0, y: 0.0).norm.isEqual(to: 0.0))
        #expect(Vector3D(x: 0.0, y: 0.0, z: 0.0).norm.isEqual(to: 0.0))
        #expect(VectorN([0.0, 0.0, 0.0]).norm.isEqual(to: 0.0))
    }

    /// Control: ordinary vectors are untouched, including the overflow-scaling path.
    @Test("OrdinaryVectors_Unchanged")
    func ordinaryVectorsUnchanged() {
        #expect(Vector2D(x: 3.0, y: 4.0).norm.isEqual(to: 5.0))
        #expect(Vector3D(x: 2.0, y: 3.0, z: 6.0).norm.isEqual(to: 7.0))
        #expect(VectorN([3.0, 4.0]).norm.isEqual(to: 5.0))
        let huge = Vector2D(x: 3e300, y: 4e300).norm
        #expect(abs(huge - 5e300) < 1e288, "the scaling trick still avoids overflow: \(huge)")
    }
}

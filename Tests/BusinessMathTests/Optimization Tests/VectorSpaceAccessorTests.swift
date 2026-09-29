//
//  VectorSpaceAccessorTests.swift
//  BusinessMathTests
//
//  `VectorSpace.swift` was the largest genuinely untested file in the package — 35 real
//  members never executed, of which `simplexProjection()` turned out to be a normalisation
//  wearing a projection's name and is fixed and tested separately.
//
//  This covers the rest. The geometry is asserted against its defining properties rather
//  than against a restatement of the implementation: a rotation must preserve length and
//  carry the basis vectors to the right places, a two-dimensional cross product must be
//  antisymmetric, and `angle` must land in the correct quadrant on all four sides — each of
//  which a sign error breaks and none of which a transcription of the formula would catch.
//
//  Everything here was already correct.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Vector space geometry and accessors")
struct VectorSpaceAccessorTests {

    private static let tolerance = 1e-12

    private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
        // `isEqual(to:)` is IEEE equality, so `nan.isEqual(to: .nan)` is **false**. This sweep
    // deliberately marks unevaluable positions with `.nan`, so two NaNs in the same slot
    // are an agreement, not a mismatch — without this a marked position can never match.
    lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) || ($0.isNaN && $1.isNaN) }
    }

    // MARK: - Rotation

    /// Positive angles rotate **counter-clockwise**, which is the convention the rest of the
    /// library's trigonometry assumes. A sign error here is invisible in the norm and obvious
    /// in the basis vectors, so the basis is what is asserted.
    @Test("Rotation_IsCounterClockwise") func rotationIsCounterClockwise() {
        let quarterTurn = Double.pi / 2
        let rotatedX = Vector2D(x: 1.0, y: 0.0).rotated(by: quarterTurn)
        #expect(abs(rotatedX.x - 0.0) < 1e-15, "x went to \(rotatedX.x)")
        #expect(abs(rotatedX.y - 1.0) < Self.tolerance, "+90° carries (1,0) to (0,1), not (0,-1)")

        let rotatedY = Vector2D(x: 0.0, y: 1.0).rotated(by: quarterTurn)
        #expect(abs(rotatedY.x - (-1.0)) < Self.tolerance, "and (0,1) to (-1,0)")
        #expect(abs(rotatedY.y - 0.0) < 1e-15)
    }

    /// A rotation is an isometry: length is invariant at every angle.
    @Test("Rotation_PreservesLength", arguments: [0.0, 0.7, 1.5, 3.0, -2.2])
    func rotationPreservesLength(angle: Double) {
        let v = Vector2D(x: 3.0, y: -4.0)
        #expect(abs(v.rotated(by: angle).norm - v.norm) < 1e-12, "angle \(angle)")
    }

    /// Four quarter-turns return to the start.
    @Test("Rotation_FullTurnIsIdentity") func rotationFullTurnIsIdentity() {
        let v = Vector2D(x: 2.0, y: -5.0)
        var turned = v
        for _ in 0..<4 { turned = turned.rotated(by: Double.pi / 2) }
        #expect(abs(turned.x - v.x) < 1e-12)
        #expect(abs(turned.y - v.y) < 1e-12)
    }

    // MARK: - Cross product

    /// The two-dimensional cross product is the scalar `x₁y₂ - y₁x₂`: antisymmetric, zero on
    /// parallel inputs, and `+1` for the standard basis in order.
    @Test("Cross_IsAntisymmetric") func crossIsAntisymmetric() {
        let e1 = Vector2D(x: 1.0, y: 0.0)
        let e2 = Vector2D(x: 0.0, y: 1.0)
        #expect(e1.cross(e2).isEqual(to: 1.0), "right-handed")
        #expect(e2.cross(e1).isEqual(to: -1.0), "and reversing the operands flips the sign")
        #expect(e1.cross(e1).isEqual(to: 0.0), "parallel vectors have no cross")

        let a = Vector2D(x: 3.0, y: 4.0)
        let b = Vector2D(x: 1.0, y: 2.0)
        #expect(a.cross(b).isEqual(to: 2.0), "3·2 − 4·1")
        #expect(b.cross(a).isEqual(to: -2.0))
    }

    // MARK: - Angle

    /// All four quadrants, including the branch where `atan2` goes negative — a naive
    /// `atan(y/x)` agrees on the first quadrant and is wrong on the other three.
    @Test("Angle_IsCorrectInEveryQuadrant", arguments: [
        (1.0, 0.0, 0.0),
        (0.0, 1.0, Double.pi / 2),
        (-1.0, 0.0, Double.pi),
        (1.0, 1.0, Double.pi / 4),
        (-1.0, -1.0, -3.0 * Double.pi / 4),
        (1.0, -1.0, -Double.pi / 4),
    ])
    func angleIsCorrectInEveryQuadrant(x: Double, y: Double, expected: Double) {
        #expect(abs(Vector2D(x: x, y: y).angle - expected) < Self.tolerance,
                "angle(\(x), \(y))")
    }

    // MARK: - VectorN accessors

    private static let sample = VectorN([3.0, 1.0, 4.0, 1.0, 5.0])

    @Test("Range_IsMinAndMax") func rangeIsMinAndMax() throws {
        let range = try #require(Self.sample.range)
        #expect(range.min.isEqual(to: 1.0))
        #expect(range.max.isEqual(to: 5.0))
        #expect(VectorN<Double>([]).range == nil, "an empty vector has no range")
    }

    @Test("StructuralEdits") func structuralEdits() throws {
        let v = Self.sample
        #expect(agree(v.appending(9.0).toArray(), [3, 1, 4, 1, 5, 9]))
        #expect(agree(try #require(v.removingLast()).toArray(), [3, 1, 4, 1]))
        #expect(agree(v.concatenated(with: VectorN([7.0])).toArray(), [3, 1, 4, 1, 5, 7]))
        #expect(agree(try #require(v.slice(1..<3)).toArray(), [1, 4]))
        #expect(agree(try #require(v.settingComponent(at: 2, to: 99.0)).toArray(), [3, 1, 99, 1, 5]))
    }

    /// Out-of-range requests report `nil` rather than trapping or clamping.
    @Test("StructuralEdits_OutOfRangeIsNil") func structuralEditsOutOfRangeIsNil() {
        let v = Self.sample
        #expect(v.slice(0..<9) == nil)
        #expect(v.settingComponent(at: 9, to: 99.0) == nil)
        #expect(v.settingComponent(at: -1, to: 99.0) == nil)
        #expect(VectorN<Double>([]).removingLast() == nil, "nothing to remove")
    }

    @Test("FunctionalOperations") func functionalOperations() {
        let v = Self.sample
        #expect(agree(v.map { $0 * 2 }.toArray(), [6, 2, 8, 2, 10]))
        #expect(agree(v.filter { $0 > 2 }.toArray(), [3, 4, 5]))
        #expect(v.reduce(0.0) { $0 + $1 }.isEqual(to: 14.0))
        #expect(agree(v.zipWith(v) { $0 + $1 }.toArray(), [6, 2, 8, 2, 10]))
    }

    @Test("ArithmeticOperators") func arithmeticOperators() {
        let v = Self.sample
        #expect(agree((-v).toArray(), [-3, -1, -4, -1, -5]))
        #expect(agree((v / 2.0).toArray(), [1.5, 0.5, 2.0, 0.5, 2.5]))
        #expect(agree(VectorN<Double>.ones(dimension: 3).toArray(), [1, 1, 1]))
    }

    // MARK: - Spaces

    /// `linearSpace` hits both endpoints exactly and steps evenly between them.
    @Test("LinearSpace_HitsBothEndpoints") func linearSpaceHitsBothEndpoints() {
        let points = VectorN<Double>.linearSpace(from: 0.0, to: 1.0, count: 5).toArray()
        #expect(agree(points, [0.0, 0.25, 0.5, 0.75, 1.0]))
    }

    /// `logSpace` is geometric, so consecutive ratios are constant.
    @Test("LogSpace_IsGeometric") func logSpaceIsGeometric() {
        let points = VectorN<Double>.logSpace(from: 1.0, to: 1_000.0, count: 4).toArray()
        #expect(points.count == 4)
        #expect(abs(points[0] - 1.0) < 1e-12)
        #expect(abs(points[3] - 1_000.0) < 1e-9, "the far endpoint")
        for index in 1..<points.count {
            #expect(abs(points[index] / points[index - 1] - 10.0) < 1e-9,
                    "ratio at \(index) was \(points[index] / points[index - 1])")
        }
    }

    // MARK: - Geometric relations, already verified but pinned

    @Test("RejectionIsOrthogonalToItsReference") func rejectionIsOrthogonal() {
        let v = VectorN([1.0, 2.0, 3.0])
        let u = VectorN([4.0, 5.0, 6.0])
        let rejection = v.rejection(from: u)
        #expect(abs(rejection.dot(u)) < 1e-12, "by definition")
        #expect(rejection.isOrthogonal(to: u), "and the predicate agrees")

        // A zero reference has no direction to project onto, so nothing is removed.
        #expect(agree(v.rejection(from: VectorN([0.0, 0.0, 0.0])).toArray(), [1, 2, 3]))
    }

    @Test("ParallelAndOrthogonalPredicates") func parallelAndOrthogonalPredicates() {
        let v = VectorN([1.0, 2.0])
        #expect(v.isParallel(to: VectorN([3.0, 6.0])), "a positive multiple")
        #expect(v.isParallel(to: VectorN([-2.0, -4.0])), "and a negative one")
        #expect(!v.isParallel(to: VectorN([1.0, 0.0])))
        #expect(VectorN([1.0, 0.0]).isOrthogonal(to: VectorN([0.0, 1.0])))
    }

    /// The Kronecker product has length `m·n`, with entries `aᵢ·bⱼ` in row-major order.
    @Test("KroneckerProduct_IsTheOuterProductFlattened") func kroneckerProduct() {
        let result = VectorN([1.0, 2.0]).kroneckerProduct(with: VectorN([10.0, 20.0, 30.0]))
        #expect(agree(result.toArray(), [10, 20, 30, 20, 40, 60]))
    }
}

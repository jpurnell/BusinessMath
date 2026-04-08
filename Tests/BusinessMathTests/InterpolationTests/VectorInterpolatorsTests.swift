//
//  VectorInterpolatorsTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//
//  Tests for the 10 vector-output flavors. The core invariant under test:
//  a vector-output interpolator MUST produce per-channel results identical
//  to running each channel through the corresponding scalar interpolator
//  independently. This ensures the vector flavors are correct by
//  construction (no algorithmic bugs introduced in the channel-wise
//  wrapping).
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Vector-output interpolators")
struct VectorInterpolatorsTests {

    // 5 sample points with 3-channel vector output (e.g., 3-axis sensor)
    static let xs: [Double] = [0, 1, 2, 3, 4]
    static let ys: [VectorN<Double>] = [
        VectorN([0.0, 10.0, 100.0]),
        VectorN([1.0, 11.0, 110.0]),
        VectorN([4.0, 14.0, 140.0]),
        VectorN([9.0, 19.0, 190.0]),
        VectorN([16.0, 26.0, 260.0]),
    ]

    /// Per-channel scalar arrays for cross-checking against scalar interpolators.
    static var channels: [[Double]] {
        [
            ys.map { $0.toArray()[0] },
            ys.map { $0.toArray()[1] },
            ys.map { $0.toArray()[2] },
        ]
    }

    static let probes: [Double] = [0.0, 0.7, 1.5, 2.3, 3.0, 3.9, 4.0]

    // MARK: - Equivalence helper

    /// For each probe, build the expected vector by running each channel
    /// through the scalar interpolator and assemble the result. Compare
    /// against the vector interpolator's output element-wise.
    static func assertChannelwiseEquivalence(
        vector: (Double) -> VectorN<Double>,
        scalarsByChannel: [(Double) -> Double]
    ) {
        for q in probes {
            let actual = vector(q)
            let expected = VectorN(scalarsByChannel.map { $0(q) })
            #expect(actual.dimension == expected.dimension)
            for c in 0..<actual.dimension {
                #expect(abs(actual.toArray()[c] - expected.toArray()[c]) < 1e-12)
            }
        }
    }

    // MARK: - Construction tests

    @Test("All 10 vector interpolators report outputDimension == channel count")
    func outputDimensions() throws {
        let near = try VectorNearestNeighborInterpolator(xs: Self.xs, ys: Self.ys)
        let prev = try VectorPreviousValueInterpolator(xs: Self.xs, ys: Self.ys)
        let next = try VectorNextValueInterpolator(xs: Self.xs, ys: Self.ys)
        let lin = try VectorLinearInterpolator(xs: Self.xs, ys: Self.ys)
        let cs = try VectorCubicSplineInterpolator(xs: Self.xs, ys: Self.ys)
        let pchip = try VectorPCHIPInterpolator(xs: Self.xs, ys: Self.ys)
        let akima = try VectorAkimaInterpolator(xs: Self.xs, ys: Self.ys)
        let crom = try VectorCatmullRomInterpolator(xs: Self.xs, ys: Self.ys)
        let bs = try VectorBSplineInterpolator(xs: Self.xs, ys: Self.ys)
        let bary = try VectorBarycentricLagrangeInterpolator(xs: Self.xs, ys: Self.ys)
        for interp in [near.outputDimension, prev.outputDimension, next.outputDimension,
                       lin.outputDimension, cs.outputDimension, pchip.outputDimension,
                       akima.outputDimension, crom.outputDimension, bs.outputDimension,
                       bary.outputDimension] {
            #expect(interp == 3)
        }
    }

    @Test("Mismatched vector dimensions throws")
    func mismatchedVectorDimensions() {
        let xs: [Double] = [0, 1, 2]
        let ys: [VectorN<Double>] = [
            VectorN([0.0, 10.0]),
            VectorN([1.0, 11.0, 100.0]),  // wrong dimension
            VectorN([4.0, 14.0]),
        ]
        #expect(throws: InterpolationError.self) {
            _ = try VectorLinearInterpolator(xs: xs, ys: ys)
        }
    }

    // MARK: - Channelwise equivalence tests (one per method)

    @Test("VectorNearestNeighbor matches per-channel scalar")
    func nearestEquivalence() throws {
        let v = try VectorNearestNeighborInterpolator(xs: Self.xs, ys: Self.ys)
        let scalars = try Self.channels.map { try NearestNeighborInterpolator(xs: Self.xs, ys: $0) }
        Self.assertChannelwiseEquivalence(
            vector: v.callAsFunction(_:),
            scalarsByChannel: scalars.map { s in { s($0) } }
        )
    }

    @Test("VectorPreviousValue matches per-channel scalar")
    func previousEquivalence() throws {
        let v = try VectorPreviousValueInterpolator(xs: Self.xs, ys: Self.ys)
        let scalars = try Self.channels.map { try PreviousValueInterpolator(xs: Self.xs, ys: $0) }
        Self.assertChannelwiseEquivalence(
            vector: v.callAsFunction(_:),
            scalarsByChannel: scalars.map { s in { s($0) } }
        )
    }

    @Test("VectorNextValue matches per-channel scalar")
    func nextEquivalence() throws {
        let v = try VectorNextValueInterpolator(xs: Self.xs, ys: Self.ys)
        let scalars = try Self.channels.map { try NextValueInterpolator(xs: Self.xs, ys: $0) }
        Self.assertChannelwiseEquivalence(
            vector: v.callAsFunction(_:),
            scalarsByChannel: scalars.map { s in { s($0) } }
        )
    }

    @Test("VectorLinear matches per-channel scalar")
    func linearEquivalence() throws {
        let v = try VectorLinearInterpolator(xs: Self.xs, ys: Self.ys)
        let scalars = try Self.channels.map { try LinearInterpolator(xs: Self.xs, ys: $0) }
        Self.assertChannelwiseEquivalence(
            vector: v.callAsFunction(_:),
            scalarsByChannel: scalars.map { s in { s($0) } }
        )
    }

    @Test("VectorCubicSpline matches per-channel scalar")
    func cubicSplineEquivalence() throws {
        let v = try VectorCubicSplineInterpolator(xs: Self.xs, ys: Self.ys)
        let scalars = try Self.channels.map { try CubicSplineInterpolator(xs: Self.xs, ys: $0) }
        Self.assertChannelwiseEquivalence(
            vector: v.callAsFunction(_:),
            scalarsByChannel: scalars.map { s in { s($0) } }
        )
    }

    @Test("VectorPCHIP matches per-channel scalar")
    func pchipEquivalence() throws {
        let v = try VectorPCHIPInterpolator(xs: Self.xs, ys: Self.ys)
        let scalars = try Self.channels.map { try PCHIPInterpolator(xs: Self.xs, ys: $0) }
        Self.assertChannelwiseEquivalence(
            vector: v.callAsFunction(_:),
            scalarsByChannel: scalars.map { s in { s($0) } }
        )
    }

    @Test("VectorAkima matches per-channel scalar")
    func akimaEquivalence() throws {
        let v = try VectorAkimaInterpolator(xs: Self.xs, ys: Self.ys)
        let scalars = try Self.channels.map { try AkimaInterpolator(xs: Self.xs, ys: $0) }
        Self.assertChannelwiseEquivalence(
            vector: v.callAsFunction(_:),
            scalarsByChannel: scalars.map { s in { s($0) } }
        )
    }

    @Test("VectorCatmullRom matches per-channel scalar")
    func catmullRomEquivalence() throws {
        let v = try VectorCatmullRomInterpolator(xs: Self.xs, ys: Self.ys)
        let scalars = try Self.channels.map { try CatmullRomInterpolator(xs: Self.xs, ys: $0) }
        Self.assertChannelwiseEquivalence(
            vector: v.callAsFunction(_:),
            scalarsByChannel: scalars.map { s in { s($0) } }
        )
    }

    @Test("VectorBSpline matches per-channel scalar")
    func bsplineEquivalence() throws {
        let v = try VectorBSplineInterpolator(xs: Self.xs, ys: Self.ys)
        let scalars = try Self.channels.map { try BSplineInterpolator(xs: Self.xs, ys: $0) }
        Self.assertChannelwiseEquivalence(
            vector: v.callAsFunction(_:),
            scalarsByChannel: scalars.map { s in { s($0) } }
        )
    }

    @Test("VectorBarycentricLagrange matches per-channel scalar")
    func barycentricEquivalence() throws {
        let v = try VectorBarycentricLagrangeInterpolator(xs: Self.xs, ys: Self.ys)
        let scalars = try Self.channels.map { try BarycentricLagrangeInterpolator(xs: Self.xs, ys: $0) }
        Self.assertChannelwiseEquivalence(
            vector: v.callAsFunction(_:),
            scalarsByChannel: scalars.map { s in { s($0) } }
        )
    }

    // MARK: - Pass-through invariant for vector flavors

    @Test("VectorLinear pass-through at exact knots")
    func vectorLinearPassThrough() throws {
        let v = try VectorLinearInterpolator(xs: Self.xs, ys: Self.ys)
        for i in 0..<Self.xs.count {
            let result = v(Self.xs[i])
            let expected = Self.ys[i]
            #expect(result.dimension == expected.dimension)
            for c in 0..<result.dimension {
                #expect(abs(result.toArray()[c] - expected.toArray()[c]) < 1e-12)
            }
        }
    }

    @Test("VectorCubicSpline pass-through at exact knots")
    func vectorCubicSplinePassThrough() throws {
        let v = try VectorCubicSplineInterpolator(xs: Self.xs, ys: Self.ys)
        for i in 0..<Self.xs.count {
            let result = v(Self.xs[i])
            let expected = Self.ys[i]
            for c in 0..<result.dimension {
                #expect(abs(result.toArray()[c] - expected.toArray()[c]) < 1e-12)
            }
        }
    }

    @Test("Vector1D query equivalence")
    func vector1DQueryEquivalence() throws {
        let v = try VectorLinearInterpolator(xs: Self.xs, ys: Self.ys)
        let viaPoint = v(at: Vector1D(2.5))
        let viaScalar = v(2.5)
        for c in 0..<viaPoint.dimension {
            #expect(viaPoint.toArray()[c] == viaScalar.toArray()[c])
        }
    }
}

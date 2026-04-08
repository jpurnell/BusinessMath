//
//  VectorInterpolators.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//
//  Vector-output flavors of the 10 1D interpolators. Each takes
//  ys: [VectorN<T>] (one vector per knot) and produces VectorN<T> output
//  at each query point. Internally constructs one scalar interpolator
//  per output channel, so the algorithm is shared verbatim.
//
//  Common use cases:
//   - 3-axis accelerometer over time → 3-component vector per sample
//   - Multi-channel EEG over time → N-component vector per sample
//   - Stock portfolio historical values → M-component vector per sample
//   - Multi-sensor fusion → K-component vector per sample
//

import Foundation
import Numerics

// MARK: - Common helper

/// Validate that all vectors in `ys` have the same dimension as `ys[0]`,
/// and return that dimension. Throws if mismatched.
@inlinable
internal func validateVectorYs<T: Real & Sendable & Codable>(
    _ ys: [VectorN<T>]
) throws -> Int {
    guard let first = ys.first else { return 0 }
    let dim = first.dimension
    for (i, v) in ys.enumerated() where v.dimension != dim {
        throw InterpolationError.invalidParameter(
            message: "All vector ys must have the same dimension; ys[\(i)] has \(v.dimension) but ys[0] has \(dim)"
        )
    }
    return dim
}

/// Transpose `[VectorN<T>]` of length `n` (each of dimension `dim`) into
/// `dim` channels, each a `[T]` of length `n`.
@inlinable
internal func transposeChannels<T: Real & Sendable & Codable>(
    _ ys: [VectorN<T>],
    dimension dim: Int
) -> [[T]] {
    var channels = [[T]](repeating: [T](repeating: T(0), count: ys.count), count: dim)
    for (i, v) in ys.enumerated() {
        let arr = v.toArray()
        for c in 0..<dim {
            channels[c][i] = arr[c]
        }
    }
    return channels
}

// MARK: - VectorNearestNeighborInterpolator

public struct VectorNearestNeighborInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = VectorN<T>

    public let inputDimension = 1
    public let outputDimension: Int
    public let xs: [T]
    public let ys: [VectorN<T>]

    @usableFromInline
    internal let channels: [NearestNeighborInterpolator<T>]

    public init(
        xs: [T],
        ys: [VectorN<T>],
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        try validateXY(xs: xs, ysCount: ys.count, minimumPoints: 1)
        let dim = try validateVectorYs(ys)
        self.xs = xs
        self.ys = ys
        self.outputDimension = dim
        let chans = transposeChannels(ys, dimension: dim)
        self.channels = try chans.map {
            try NearestNeighborInterpolator(xs: xs, ys: $0, outOfBounds: outOfBounds)
        }
    }

    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorPreviousValueInterpolator

public struct VectorPreviousValueInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = VectorN<T>

    public let inputDimension = 1
    public let outputDimension: Int
    public let xs: [T]
    public let ys: [VectorN<T>]

    @usableFromInline
    internal let channels: [PreviousValueInterpolator<T>]

    public init(
        xs: [T],
        ys: [VectorN<T>],
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        try validateXY(xs: xs, ysCount: ys.count, minimumPoints: 1)
        let dim = try validateVectorYs(ys)
        self.xs = xs
        self.ys = ys
        self.outputDimension = dim
        let chans = transposeChannels(ys, dimension: dim)
        self.channels = try chans.map {
            try PreviousValueInterpolator(xs: xs, ys: $0, outOfBounds: outOfBounds)
        }
    }

    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorNextValueInterpolator

public struct VectorNextValueInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = VectorN<T>

    public let inputDimension = 1
    public let outputDimension: Int
    public let xs: [T]
    public let ys: [VectorN<T>]

    @usableFromInline
    internal let channels: [NextValueInterpolator<T>]

    public init(
        xs: [T],
        ys: [VectorN<T>],
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        try validateXY(xs: xs, ysCount: ys.count, minimumPoints: 1)
        let dim = try validateVectorYs(ys)
        self.xs = xs
        self.ys = ys
        self.outputDimension = dim
        let chans = transposeChannels(ys, dimension: dim)
        self.channels = try chans.map {
            try NextValueInterpolator(xs: xs, ys: $0, outOfBounds: outOfBounds)
        }
    }

    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorLinearInterpolator

public struct VectorLinearInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = VectorN<T>

    public let inputDimension = 1
    public let outputDimension: Int
    public let xs: [T]
    public let ys: [VectorN<T>]

    @usableFromInline
    internal let channels: [LinearInterpolator<T>]

    public init(
        xs: [T],
        ys: [VectorN<T>],
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        try validateXY(xs: xs, ysCount: ys.count, minimumPoints: 2)
        let dim = try validateVectorYs(ys)
        self.xs = xs
        self.ys = ys
        self.outputDimension = dim
        let chans = transposeChannels(ys, dimension: dim)
        self.channels = try chans.map {
            try LinearInterpolator(xs: xs, ys: $0, outOfBounds: outOfBounds)
        }
    }

    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorCubicSplineInterpolator

public struct VectorCubicSplineInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = VectorN<T>
    public typealias BoundaryCondition = CubicSplineInterpolator<T>.BoundaryCondition

    public let inputDimension = 1
    public let outputDimension: Int
    public let xs: [T]
    public let ys: [VectorN<T>]
    public let boundary: BoundaryCondition

    @usableFromInline
    internal let channels: [CubicSplineInterpolator<T>]

    public init(
        xs: [T],
        ys: [VectorN<T>],
        boundary: BoundaryCondition = .natural,
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        let dim = try validateVectorYs(ys)
        self.xs = xs
        self.ys = ys
        self.outputDimension = dim
        self.boundary = boundary
        let chans = transposeChannels(ys, dimension: dim)
        self.channels = try chans.map {
            try CubicSplineInterpolator(xs: xs, ys: $0, boundary: boundary, outOfBounds: outOfBounds)
        }
    }

    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorPCHIPInterpolator

public struct VectorPCHIPInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = VectorN<T>

    public let inputDimension = 1
    public let outputDimension: Int
    public let xs: [T]
    public let ys: [VectorN<T>]

    @usableFromInline
    internal let channels: [PCHIPInterpolator<T>]

    public init(
        xs: [T],
        ys: [VectorN<T>],
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        let dim = try validateVectorYs(ys)
        self.xs = xs
        self.ys = ys
        self.outputDimension = dim
        let chans = transposeChannels(ys, dimension: dim)
        self.channels = try chans.map {
            try PCHIPInterpolator(xs: xs, ys: $0, outOfBounds: outOfBounds)
        }
    }

    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorAkimaInterpolator

public struct VectorAkimaInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = VectorN<T>

    public let inputDimension = 1
    public let outputDimension: Int
    public let xs: [T]
    public let ys: [VectorN<T>]
    public let modified: Bool

    @usableFromInline
    internal let channels: [AkimaInterpolator<T>]

    public init(
        xs: [T],
        ys: [VectorN<T>],
        modified: Bool = true,
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        let dim = try validateVectorYs(ys)
        self.xs = xs
        self.ys = ys
        self.outputDimension = dim
        self.modified = modified
        let chans = transposeChannels(ys, dimension: dim)
        self.channels = try chans.map {
            try AkimaInterpolator(xs: xs, ys: $0, modified: modified, outOfBounds: outOfBounds)
        }
    }

    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorCatmullRomInterpolator

public struct VectorCatmullRomInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = VectorN<T>

    public let inputDimension = 1
    public let outputDimension: Int
    public let xs: [T]
    public let ys: [VectorN<T>]
    public let tension: T

    @usableFromInline
    internal let channels: [CatmullRomInterpolator<T>]

    public init(
        xs: [T],
        ys: [VectorN<T>],
        tension: T = T(0),
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        let dim = try validateVectorYs(ys)
        self.xs = xs
        self.ys = ys
        self.outputDimension = dim
        self.tension = tension
        let chans = transposeChannels(ys, dimension: dim)
        self.channels = try chans.map {
            try CatmullRomInterpolator(xs: xs, ys: $0, tension: tension, outOfBounds: outOfBounds)
        }
    }

    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorBSplineInterpolator

public struct VectorBSplineInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = VectorN<T>

    public let inputDimension = 1
    public let outputDimension: Int
    public let xs: [T]
    public let ys: [VectorN<T>]
    public let degree: Int

    @usableFromInline
    internal let channels: [BSplineInterpolator<T>]

    public init(
        xs: [T],
        ys: [VectorN<T>],
        degree: Int = 3,
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        let dim = try validateVectorYs(ys)
        self.xs = xs
        self.ys = ys
        self.outputDimension = dim
        self.degree = degree
        let chans = transposeChannels(ys, dimension: dim)
        self.channels = try chans.map {
            try BSplineInterpolator(xs: xs, ys: $0, degree: degree, outOfBounds: outOfBounds)
        }
    }

    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorBarycentricLagrangeInterpolator

public struct VectorBarycentricLagrangeInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = VectorN<T>

    public let inputDimension = 1
    public let outputDimension: Int
    public let xs: [T]
    public let ys: [VectorN<T>]

    @usableFromInline
    internal let channels: [BarycentricLagrangeInterpolator<T>]

    public init(
        xs: [T],
        ys: [VectorN<T>],
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        try validateXY(xs: xs, ysCount: ys.count, minimumPoints: 1)
        let dim = try validateVectorYs(ys)
        self.xs = xs
        self.ys = ys
        self.outputDimension = dim
        let chans = transposeChannels(ys, dimension: dim)
        self.channels = try chans.map {
            try BarycentricLagrangeInterpolator(xs: xs, ys: $0, outOfBounds: outOfBounds)
        }
    }

    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

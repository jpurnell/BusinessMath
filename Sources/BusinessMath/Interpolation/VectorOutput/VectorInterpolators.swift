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

/// Vector-output nearest-neighbor interpolation, returning the vector at the closest knot.
///
/// Each output channel is interpolated independently using ``NearestNeighborInterpolator``.
public struct VectorNearestNeighborInterpolator<T: Real & Sendable & Codable>: Interpolator {
    /// The scalar type for coordinates.
    public typealias Scalar = T
    /// Input point type (1D scalar wrapped in ``Vector1D``).
    public typealias Point = Vector1D<T>
    /// Output value type (N-dimensional vector).
    public typealias Value = VectorN<T>

    /// The number of input dimensions (always 1).
    public let inputDimension = 1
    /// The number of output dimensions (vector length of each `ys` element).
    public let outputDimension: Int
    /// Sample x-coordinates, strictly monotonically increasing.
    public let xs: [T]
    /// Sample vector values at each knot, all of equal dimension.
    public let ys: [VectorN<T>]

    @usableFromInline
    internal let channels: [NearestNeighborInterpolator<T>]

    /// Create a vector nearest-neighbor interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates. At least 1 element.
    ///   - ys: Vector values at each knot. All vectors must have the same dimension.
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: ``InterpolationError`` if inputs are invalid or vector dimensions are mismatched.
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

    /// Evaluate the interpolator at a wrapped query point.
    ///
    /// - Parameter query: The query point as a ``Vector1D``.
    /// - Returns: Interpolated vector value.
    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    /// Evaluate the interpolator at a scalar query point.
    ///
    /// - Parameter t: The x-coordinate to evaluate at.
    /// - Returns: Interpolated vector value (nearest knot's vector).
    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorPreviousValueInterpolator

/// Vector-output step interpolation holding the previous known vector value.
///
/// Each output channel is interpolated independently using ``PreviousValueInterpolator``.
public struct VectorPreviousValueInterpolator<T: Real & Sendable & Codable>: Interpolator {
    /// The scalar type for coordinates.
    public typealias Scalar = T
    /// Input point type (1D scalar wrapped in ``Vector1D``).
    public typealias Point = Vector1D<T>
    /// Output value type (N-dimensional vector).
    public typealias Value = VectorN<T>

    /// The number of input dimensions (always 1).
    public let inputDimension = 1
    /// The number of output dimensions (vector length of each `ys` element).
    public let outputDimension: Int
    /// Sample x-coordinates, strictly monotonically increasing.
    public let xs: [T]
    /// Sample vector values at each knot, all of equal dimension.
    public let ys: [VectorN<T>]

    @usableFromInline
    internal let channels: [PreviousValueInterpolator<T>]

    /// Create a vector previous-value step interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates. At least 1 element.
    ///   - ys: Vector values at each knot. All vectors must have the same dimension.
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: ``InterpolationError`` if inputs are invalid or vector dimensions are mismatched.
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

    /// Evaluate the interpolator at a wrapped query point.
    ///
    /// - Parameter query: The query point as a ``Vector1D``.
    /// - Returns: Interpolated vector value.
    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    /// Evaluate the interpolator at a scalar query point.
    ///
    /// - Parameter t: The x-coordinate to evaluate at.
    /// - Returns: The most recent knot vector at or before `t`.
    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorNextValueInterpolator

/// Vector-output step interpolation holding the next known vector value.
///
/// Each output channel is interpolated independently using ``NextValueInterpolator``.
public struct VectorNextValueInterpolator<T: Real & Sendable & Codable>: Interpolator {
    /// The scalar type for coordinates.
    public typealias Scalar = T
    /// Input point type (1D scalar wrapped in ``Vector1D``).
    public typealias Point = Vector1D<T>
    /// Output value type (N-dimensional vector).
    public typealias Value = VectorN<T>

    /// The number of input dimensions (always 1).
    public let inputDimension = 1
    /// The number of output dimensions (vector length of each `ys` element).
    public let outputDimension: Int
    /// Sample x-coordinates, strictly monotonically increasing.
    public let xs: [T]
    /// Sample vector values at each knot, all of equal dimension.
    public let ys: [VectorN<T>]

    @usableFromInline
    internal let channels: [NextValueInterpolator<T>]

    /// Create a vector next-value step interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates. At least 1 element.
    ///   - ys: Vector values at each knot. All vectors must have the same dimension.
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: ``InterpolationError`` if inputs are invalid or vector dimensions are mismatched.
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

    /// Evaluate the interpolator at a wrapped query point.
    ///
    /// - Parameter query: The query point as a ``Vector1D``.
    /// - Returns: Interpolated vector value.
    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    /// Evaluate the interpolator at a scalar query point.
    ///
    /// - Parameter t: The x-coordinate to evaluate at.
    /// - Returns: The next knot vector after `t`.
    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorLinearInterpolator

/// Vector-output piecewise-linear interpolation between knot vectors.
///
/// Each output channel is interpolated independently using ``LinearInterpolator``.
public struct VectorLinearInterpolator<T: Real & Sendable & Codable>: Interpolator {
    /// The scalar type for coordinates.
    public typealias Scalar = T
    /// Input point type (1D scalar wrapped in ``Vector1D``).
    public typealias Point = Vector1D<T>
    /// Output value type (N-dimensional vector).
    public typealias Value = VectorN<T>

    /// The number of input dimensions (always 1).
    public let inputDimension = 1
    /// The number of output dimensions (vector length of each `ys` element).
    public let outputDimension: Int
    /// Sample x-coordinates, strictly monotonically increasing.
    public let xs: [T]
    /// Sample vector values at each knot, all of equal dimension.
    public let ys: [VectorN<T>]

    @usableFromInline
    internal let channels: [LinearInterpolator<T>]

    /// Create a vector linear interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates. At least 2 elements.
    ///   - ys: Vector values at each knot. All vectors must have the same dimension.
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: ``InterpolationError`` if inputs are invalid or vector dimensions are mismatched.
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

    /// Evaluate the interpolator at a wrapped query point.
    ///
    /// - Parameter query: The query point as a ``Vector1D``.
    /// - Returns: Linearly interpolated vector value.
    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    /// Evaluate the interpolator at a scalar query point.
    ///
    /// - Parameter t: The x-coordinate to evaluate at.
    /// - Returns: Linearly interpolated vector between the two bracketing knots.
    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorCubicSplineInterpolator

/// Vector-output cubic spline interpolation with configurable boundary conditions.
///
/// Each output channel is interpolated independently using ``CubicSplineInterpolator``.
public struct VectorCubicSplineInterpolator<T: Real & Sendable & Codable>: Interpolator {
    /// The scalar type for coordinates.
    public typealias Scalar = T
    /// Input point type (1D scalar wrapped in ``Vector1D``).
    public typealias Point = Vector1D<T>
    /// Output value type (N-dimensional vector).
    public typealias Value = VectorN<T>
    /// Boundary condition type, forwarded from ``CubicSplineInterpolator``.
    public typealias BoundaryCondition = CubicSplineInterpolator<T>.BoundaryCondition

    /// The number of input dimensions (always 1).
    public let inputDimension = 1
    /// The number of output dimensions (vector length of each `ys` element).
    public let outputDimension: Int
    /// Sample x-coordinates, strictly monotonically increasing.
    public let xs: [T]
    /// Sample vector values at each knot, all of equal dimension.
    public let ys: [VectorN<T>]
    /// The boundary condition applied to each channel's cubic spline.
    public let boundary: BoundaryCondition

    @usableFromInline
    internal let channels: [CubicSplineInterpolator<T>]

    /// Create a vector cubic spline interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates.
    ///   - ys: Vector values at each knot. All vectors must have the same dimension.
    ///   - boundary: Boundary condition for each channel's spline. Defaults to `.natural`.
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: ``InterpolationError`` if inputs are invalid or vector dimensions are mismatched.
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

    /// Evaluate the interpolator at a wrapped query point.
    ///
    /// - Parameter query: The query point as a ``Vector1D``.
    /// - Returns: Cubic-spline-interpolated vector value.
    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    /// Evaluate the interpolator at a scalar query point.
    ///
    /// - Parameter t: The x-coordinate to evaluate at.
    /// - Returns: Cubic-spline-interpolated vector, C2-smooth across knots.
    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorPCHIPInterpolator

/// Vector-output monotone cubic (PCHIP) interpolation preserving per-channel monotonicity.
///
/// Each output channel is interpolated independently using ``PCHIPInterpolator``.
public struct VectorPCHIPInterpolator<T: Real & Sendable & Codable>: Interpolator {
    /// The scalar type for coordinates.
    public typealias Scalar = T
    /// Input point type (1D scalar wrapped in ``Vector1D``).
    public typealias Point = Vector1D<T>
    /// Output value type (N-dimensional vector).
    public typealias Value = VectorN<T>

    /// The number of input dimensions (always 1).
    public let inputDimension = 1
    /// The number of output dimensions (vector length of each `ys` element).
    public let outputDimension: Int
    /// Sample x-coordinates, strictly monotonically increasing.
    public let xs: [T]
    /// Sample vector values at each knot, all of equal dimension.
    public let ys: [VectorN<T>]

    @usableFromInline
    internal let channels: [PCHIPInterpolator<T>]

    /// Create a vector PCHIP interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates.
    ///   - ys: Vector values at each knot. All vectors must have the same dimension.
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: ``InterpolationError`` if inputs are invalid or vector dimensions are mismatched.
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

    /// Evaluate the interpolator at a wrapped query point.
    ///
    /// - Parameter query: The query point as a ``Vector1D``.
    /// - Returns: PCHIP-interpolated vector value.
    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    /// Evaluate the interpolator at a scalar query point.
    ///
    /// - Parameter t: The x-coordinate to evaluate at.
    /// - Returns: Monotone-cubic-interpolated vector, overshoot-safe per channel.
    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorAkimaInterpolator

/// Vector-output Akima spline interpolation with optional modified ("makima") variant.
///
/// Each output channel is interpolated independently using ``AkimaInterpolator``.
public struct VectorAkimaInterpolator<T: Real & Sendable & Codable>: Interpolator {
    /// The scalar type for coordinates.
    public typealias Scalar = T
    /// Input point type (1D scalar wrapped in ``Vector1D``).
    public typealias Point = Vector1D<T>
    /// Output value type (N-dimensional vector).
    public typealias Value = VectorN<T>

    /// The number of input dimensions (always 1).
    public let inputDimension = 1
    /// The number of output dimensions (vector length of each `ys` element).
    public let outputDimension: Int
    /// Sample x-coordinates, strictly monotonically increasing.
    public let xs: [T]
    /// Sample vector values at each knot, all of equal dimension.
    public let ys: [VectorN<T>]
    /// Whether to use the modified Akima ("makima") formulation.
    public let modified: Bool

    @usableFromInline
    internal let channels: [AkimaInterpolator<T>]

    /// Create a vector Akima spline interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates.
    ///   - ys: Vector values at each knot. All vectors must have the same dimension.
    ///   - modified: When `true` (default), uses the modified "makima" formulation.
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: ``InterpolationError`` if inputs are invalid or vector dimensions are mismatched.
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

    /// Evaluate the interpolator at a wrapped query point.
    ///
    /// - Parameter query: The query point as a ``Vector1D``.
    /// - Returns: Akima-interpolated vector value.
    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    /// Evaluate the interpolator at a scalar query point.
    ///
    /// - Parameter t: The x-coordinate to evaluate at.
    /// - Returns: Akima-interpolated vector, outlier-robust per channel.
    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorCatmullRomInterpolator

/// Vector-output Catmull-Rom (cardinal) spline interpolation with configurable tension.
///
/// Each output channel is interpolated independently using ``CatmullRomInterpolator``.
public struct VectorCatmullRomInterpolator<T: Real & Sendable & Codable>: Interpolator {
    /// The scalar type for coordinates.
    public typealias Scalar = T
    /// Input point type (1D scalar wrapped in ``Vector1D``).
    public typealias Point = Vector1D<T>
    /// Output value type (N-dimensional vector).
    public typealias Value = VectorN<T>

    /// The number of input dimensions (always 1).
    public let inputDimension = 1
    /// The number of output dimensions (vector length of each `ys` element).
    public let outputDimension: Int
    /// Sample x-coordinates, strictly monotonically increasing.
    public let xs: [T]
    /// Sample vector values at each knot, all of equal dimension.
    public let ys: [VectorN<T>]
    /// Cardinal spline tension in `[0, 1]`. Zero gives standard Catmull-Rom.
    public let tension: T

    @usableFromInline
    internal let channels: [CatmullRomInterpolator<T>]

    /// Create a vector Catmull-Rom (cardinal) spline interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates.
    ///   - ys: Vector values at each knot. All vectors must have the same dimension.
    ///   - tension: Cardinal spline tension in `[0, 1]`. Defaults to `0` (standard Catmull-Rom).
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: ``InterpolationError`` if inputs are invalid or vector dimensions are mismatched.
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

    /// Evaluate the interpolator at a wrapped query point.
    ///
    /// - Parameter query: The query point as a ``Vector1D``.
    /// - Returns: Catmull-Rom-interpolated vector value.
    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    /// Evaluate the interpolator at a scalar query point.
    ///
    /// - Parameter t: The x-coordinate to evaluate at.
    /// - Returns: Cardinal-spline-interpolated vector, C1-smooth across knots.
    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorBSplineInterpolator

/// Vector-output interpolating B-spline of configurable degree (1--5).
///
/// Each output channel is interpolated independently using ``BSplineInterpolator``.
public struct VectorBSplineInterpolator<T: Real & Sendable & Codable>: Interpolator {
    /// The scalar type for coordinates.
    public typealias Scalar = T
    /// Input point type (1D scalar wrapped in ``Vector1D``).
    public typealias Point = Vector1D<T>
    /// Output value type (N-dimensional vector).
    public typealias Value = VectorN<T>

    /// The number of input dimensions (always 1).
    public let inputDimension = 1
    /// The number of output dimensions (vector length of each `ys` element).
    public let outputDimension: Int
    /// Sample x-coordinates, strictly monotonically increasing.
    public let xs: [T]
    /// Sample vector values at each knot, all of equal dimension.
    public let ys: [VectorN<T>]
    /// Polynomial degree of the B-spline basis (1 = linear, 3 = cubic).
    public let degree: Int

    @usableFromInline
    internal let channels: [BSplineInterpolator<T>]

    /// Create a vector B-spline interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates.
    ///   - ys: Vector values at each knot. All vectors must have the same dimension.
    ///   - degree: Polynomial degree in `1...5`. Defaults to `3` (cubic).
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: ``InterpolationError`` if inputs are invalid or vector dimensions are mismatched.
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

    /// Evaluate the interpolator at a wrapped query point.
    ///
    /// - Parameter query: The query point as a ``Vector1D``.
    /// - Returns: B-spline-interpolated vector value.
    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    /// Evaluate the interpolator at a scalar query point.
    ///
    /// - Parameter t: The x-coordinate to evaluate at.
    /// - Returns: B-spline-interpolated vector at the given degree.
    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

// MARK: - VectorBarycentricLagrangeInterpolator

/// Vector-output barycentric Lagrange polynomial interpolation through all knots.
///
/// Each output channel is interpolated independently using ``BarycentricLagrangeInterpolator``.
/// Best for small datasets (N <= 20); larger datasets risk Runge-phenomenon oscillation.
public struct VectorBarycentricLagrangeInterpolator<T: Real & Sendable & Codable>: Interpolator {
    /// The scalar type for coordinates.
    public typealias Scalar = T
    /// Input point type (1D scalar wrapped in ``Vector1D``).
    public typealias Point = Vector1D<T>
    /// Output value type (N-dimensional vector).
    public typealias Value = VectorN<T>

    /// The number of input dimensions (always 1).
    public let inputDimension = 1
    /// The number of output dimensions (vector length of each `ys` element).
    public let outputDimension: Int
    /// Sample x-coordinates, strictly monotonically increasing.
    public let xs: [T]
    /// Sample vector values at each knot, all of equal dimension.
    public let ys: [VectorN<T>]

    @usableFromInline
    internal let channels: [BarycentricLagrangeInterpolator<T>]

    /// Create a vector barycentric Lagrange interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates. At least 1 element.
    ///   - ys: Vector values at each knot. All vectors must have the same dimension.
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: ``InterpolationError`` if inputs are invalid or vector dimensions are mismatched.
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

    /// Evaluate the interpolator at a wrapped query point.
    ///
    /// - Parameter query: The query point as a ``Vector1D``.
    /// - Returns: Polynomial-interpolated vector value.
    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T> {
        callAsFunction(query.value)
    }

    /// Evaluate the interpolator at a scalar query point.
    ///
    /// - Parameter t: The x-coordinate to evaluate at.
    /// - Returns: Polynomial-interpolated vector through all knots.
    public func callAsFunction(_ t: T) -> VectorN<T> {
        VectorN(channels.map { $0(t) })
    }
}

//
//  VolatilitySurface.swift
//  BusinessMath
//
//  Created by Justin Purnell on 4/15/26.
//

import Foundation
import Numerics

// MARK: - VolatilitySurface

/// A volatility surface in strike-expiry space for equities and rates.
///
/// `VolatilitySurface` stores a grid of implied volatilities indexed by strike
/// and expiry, and provides bilinear interpolation for arbitrary (strike, expiry)
/// queries. It also includes SABR calibration for fitting parametric models to
/// observed market smiles.
///
/// ## Usage
///
/// ```swift
/// let surface = VolatilitySurface(
///     underlier: "SPX",
///     strikes: [90, 95, 100, 105, 110],
///     expiries: [0.25, 0.5, 1.0],
///     vols: [
///         [0.22, 0.20, 0.18, 0.19, 0.21],  // 3-month smile
///         [0.21, 0.19, 0.18, 0.18, 0.20],  // 6-month smile
///         [0.20, 0.19, 0.18, 0.18, 0.19],  // 1-year smile
///     ]
/// )
/// let vol = surface.impliedVol(strike: 97.5, expiry: 0.375)
/// ```
public struct VolatilitySurface: Sendable {
    /// Identifier for the underlying asset.
    public let underlier: String
    /// Sorted ascending array of strike prices.
    public let strikes: [Double]
    /// Sorted ascending array of expiry times in years.
    public let expiries: [Double]
    /// Implied volatilities indexed as `vols[expiryIndex][strikeIndex]`.
    public let vols: [[Double]]

    /// Creates a volatility surface from a grid of implied volatilities.
    ///
    /// - Parameters:
    ///   - underlier: Identifier for the underlying asset (e.g., ticker symbol).
    ///   - strikes: Strike prices, sorted in ascending order.
    ///   - expiries: Expiry times in years, sorted in ascending order.
    ///   - vols: 2D array of implied volatilities. Outer index is expiry, inner index is strike.
    ///     Must have `expiries.count` rows and `strikes.count` columns.
    public init(underlier: String, strikes: [Double], expiries: [Double], vols: [[Double]]) {
        self.underlier = underlier
        self.strikes = strikes
        self.expiries = expiries
        self.vols = vols
    }

    /// Implied volatility via bilinear interpolation.
    ///
    /// Interpolates the volatility surface at an arbitrary (strike, expiry) point
    /// using bilinear interpolation. Points outside the grid are clamped to the
    /// nearest boundary value.
    ///
    /// - Parameters:
    ///   - strike: The option strike price.
    ///   - expiry: Time to expiration in years.
    /// - Returns: The interpolated implied volatility.
    public func impliedVol(strike: Double, expiry: Double) -> Double {
        guard !strikes.isEmpty, !expiries.isEmpty, !vols.isEmpty else {
            return 0.0
        }

        // Find strike indices and weight
        let (si, sw) = interpolationIndices(value: strike, in: strikes)

        // Find expiry indices and weight
        let (ei, ew) = interpolationIndices(value: expiry, in: expiries)

        // Bilinear interpolation
        let v00 = vols[ei.lower][si.lower]
        let v01 = vols[ei.lower][si.upper]
        let v10 = vols[ei.upper][si.lower]
        let v11 = vols[ei.upper][si.upper]

        let interpLow = v00 * (1.0 - sw) + v01 * sw
        let interpHigh = v10 * (1.0 - sw) + v11 * sw

        return interpLow * (1.0 - ew) + interpHigh * ew
    }

    /// Calibrate SABR parameters to a single expiry slice of market data.
    ///
    /// Fits the SABR model to observed market implied volatilities by minimizing
    /// the sum of squared volatility errors over (alpha, rho, nu) with beta fixed.
    /// Uses a grid search followed by Nelder-Mead refinement.
    ///
    /// - Parameters:
    ///   - forward: The forward price of the underlying for this expiry.
    ///   - strikes: Array of strike prices for the smile.
    ///   - marketVols: Array of observed implied volatilities corresponding to strikes.
    ///   - timeToExpiry: Time to expiration in years.
    ///   - beta: Fixed CEV exponent. Defaults to 0.5.
    /// - Returns: Calibrated ``SABRParameters``.
    public static func calibrateSABR(
        forward: Double,
        strikes: [Double],
        marketVols: [Double],
        timeToExpiry: Double,
        beta: Double = 0.5
    ) -> SABRParameters {
        guard !strikes.isEmpty, strikes.count == marketVols.count else {
            return SABRParameters(alpha: 0.2, beta: beta, rho: 0.0, nu: 0.3)
        }

        // Objective: sum of squared vol errors
        func objective(alpha: Double, rho: Double, nu: Double) -> Double {
            let params = SABRParameters(alpha: alpha, beta: beta, rho: rho, nu: nu)
            var sumSqError = 0.0
            for i in 0..<strikes.count {
                let modelVol = params.impliedVol(
                    forward: forward, strike: strikes[i], timeToExpiry: timeToExpiry)
                let err = modelVol - marketVols[i]
                sumSqError += err * err
            }
            return sumSqError
        }

        // Phase 1: Grid search for initial guess
        var bestAlpha = 0.2
        var bestRho = 0.0
        var bestNu = 0.3
        var bestError = Double.infinity

        let alphaGrid = stride(from: 0.05, through: 1.0, by: 0.05)
        let rhoGrid = stride(from: -0.9, through: 0.9, by: 0.1)
        let nuGrid = stride(from: 0.05, through: 1.5, by: 0.1)

        for a in alphaGrid {
            for r in rhoGrid {
                for n in nuGrid {
                    let err = objective(alpha: a, rho: r, nu: n)
                    if err < bestError {
                        bestError = err
                        bestAlpha = a
                        bestRho = r
                        bestNu = n
                    }
                }
            }
        }

        // Phase 2: Nelder-Mead refinement
        let result = nelderMead(
            initialPoint: [bestAlpha, bestRho, bestNu],
            objective: { params in
                let a = max(params[0], 1e-6)
                let r = max(-0.999, min(0.999, params[1]))
                let n = max(1e-6, params[2])
                return objective(alpha: a, rho: r, nu: n)
            },
            maxIterations: 500,
            tolerance: 1e-10
        )

        let finalAlpha = max(result[0], 1e-6)
        let finalRho = max(-0.999, min(0.999, result[1]))
        let finalNu = max(result[2], 1e-6)

        return SABRParameters(alpha: finalAlpha, beta: beta, rho: finalRho, nu: finalNu)
    }

    // MARK: - Private Helpers

    /// Index pair for interpolation.
    private struct IndexPair {
        let lower: Int
        let upper: Int
    }

    /// Find bracketing indices and interpolation weight for a value in a sorted array.
    private func interpolationIndices(
        value: Double, in array: [Double]
    ) -> (IndexPair, Double) {
        guard array.count > 1 else {
            return (IndexPair(lower: 0, upper: 0), 0.0)
        }

        // Clamp to boundaries
        if value <= array[0] {
            return (IndexPair(lower: 0, upper: 0), 0.0)
        }
        if value >= array[array.count - 1] {
            let last = array.count - 1
            return (IndexPair(lower: last, upper: last), 0.0)
        }

        // Binary search for bracketing interval
        var lo = 0
        var hi = array.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if array[mid] <= value {
                lo = mid
            } else {
                hi = mid
            }
        }

        let span = array[hi] - array[lo]
        let weight = span > 0 ? (value - array[lo]) / span : 0.0

        return (IndexPair(lower: lo, upper: hi), weight)
    }

    /// Nelder-Mead simplex optimization.
    ///
    /// - Parameters:
    ///   - initialPoint: Starting point in parameter space.
    ///   - objective: Function to minimize.
    ///   - maxIterations: Maximum number of iterations.
    ///   - tolerance: Convergence tolerance on function value spread.
    /// - Returns: Optimized parameter vector.
    private static func nelderMead(
        initialPoint: [Double],
        objective: ([Double]) -> Double,
        maxIterations: Int,
        tolerance: Double
    ) -> [Double] {
        let n = initialPoint.count

        // Build initial simplex
        var simplex: [[Double]] = [initialPoint]
        for i in 0..<n {
            var point = initialPoint
            let step = abs(initialPoint[i]) > 1e-8 ? initialPoint[i] * 0.1 : 0.05
            point[i] += step
            simplex.append(point)
        }

        var values = simplex.map { objective($0) }

        let reflectionCoeff = 1.0
        let expansionCoeff = 2.0
        let contractionCoeff = 0.5
        let shrinkCoeff = 0.5

        for _ in 0..<maxIterations {
            // Sort simplex by objective value
            let order = (0...n).sorted { values[$0] < values[$1] }
            simplex = order.map { simplex[$0] }
            values = order.map { values[$0] }

            // Check convergence
            let spread = values[n] - values[0]
            if spread < tolerance {
                break
            }

            // Centroid of all points except worst
            var centroid = [Double](repeating: 0.0, count: n)
            for i in 0..<n {
                for j in 0..<n {
                    centroid[j] += simplex[i][j]
                }
            }
            for j in 0..<n {
                centroid[j] /= Double(n)
            }

            // Reflection
            let reflected = (0..<n).map { centroid[$0] + reflectionCoeff * (centroid[$0] - simplex[n][$0]) }
            let reflectedValue = objective(reflected)

            if reflectedValue < values[0] {
                // Try expansion
                let expanded = (0..<n).map { centroid[$0] + expansionCoeff * (reflected[$0] - centroid[$0]) }
                let expandedValue = objective(expanded)
                if expandedValue < reflectedValue {
                    simplex[n] = expanded
                    values[n] = expandedValue
                } else {
                    simplex[n] = reflected
                    values[n] = reflectedValue
                }
            } else if reflectedValue < values[n - 1] {
                simplex[n] = reflected
                values[n] = reflectedValue
            } else {
                // Contraction
                let contracted: [Double]
                if reflectedValue < values[n] {
                    contracted = (0..<n).map { centroid[$0] + contractionCoeff * (reflected[$0] - centroid[$0]) }
                } else {
                    contracted = (0..<n).map { centroid[$0] + contractionCoeff * (simplex[n][$0] - centroid[$0]) }
                }
                let contractedValue = objective(contracted)

                if contractedValue < min(reflectedValue, values[n]) {
                    simplex[n] = contracted
                    values[n] = contractedValue
                } else {
                    // Shrink
                    for i in 1...n {
                        simplex[i] = (0..<n).map { simplex[0][$0] + shrinkCoeff * (simplex[i][$0] - simplex[0][$0]) }
                        values[i] = objective(simplex[i])
                    }
                }
            }
        }

        // Return best point
        let bestIdx = values.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
        return simplex[bestIdx]
    }
}

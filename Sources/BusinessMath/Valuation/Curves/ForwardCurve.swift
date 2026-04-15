//
//  ForwardCurve.swift
//  BusinessMath
//
//  A forward rate curve derived from a discount curve for a specific tenor index.
//
//  Created by Justin Purnell on 2026-04-15.
//

import Foundation

// MARK: - ForwardCurve

/// A forward rate curve derived from a ``DiscountCurve`` for a specific tenor index.
///
/// `ForwardCurve` computes simply compounded forward rates from an underlying
/// discount curve. Each forward rate covers a period of length ``tenor`` starting
/// at a given point in time.
///
/// ## Example
///
/// ```swift
/// let ois = DiscountCurve(
///     asOfDate: Date(),
///     tenors: [1.0, 2.0, 5.0],
///     discountFactors: [0.97, 0.94, 0.86]
/// )
/// let sofr3M = ForwardCurve(
///     indexName: "SOFR_3M",
///     tenor: 0.25,
///     referenceCurve: ois
/// )
/// let rate = sofr3M.forwardRate(at: 1.0)  // 3M forward starting in 1Y
/// ```
public struct ForwardCurve: Sendable {

    /// The name of the rate index this curve represents (e.g., `"SOFR_3M"`, `"EURIBOR_6M"`).
    public let indexName: String

    /// The forward rate tenor in years (e.g., 0.25 for a 3-month rate).
    public let tenor: Double

    /// The discount curve from which forward rates are derived.
    public let referenceCurve: DiscountCurve

    /// Creates a forward rate curve for a given index and tenor.
    ///
    /// - Parameters:
    ///   - indexName: The name of the rate index (e.g., `"SOFR_3M"`).
    ///   - tenor: The forward rate tenor in years. Must be non-negative.
    ///   - referenceCurve: The ``DiscountCurve`` used to derive forward rates.
    public init(indexName: String, tenor: Double, referenceCurve: DiscountCurve) {
        self.indexName = indexName
        self.tenor = tenor
        self.referenceCurve = referenceCurve
    }

    /// Returns the forward rate fixing at a given start date.
    ///
    /// The continuously compounded forward rate `f(t, t + tenor)` is derived from
    /// the discount curve as:
    /// ```
    /// f = -[ln(DF(t + tenor)) - ln(DF(t))] / tenor
    /// ```
    ///
    /// When ``tenor`` is zero or very small, the zero rate at `startTenor` is returned
    /// to avoid division by zero.
    ///
    /// - Parameter startTenor: The start date in years from the curve's as-of date.
    /// - Returns: The continuously compounded forward rate for the period
    ///   `[startTenor, startTenor + tenor]`.
    public func forwardRate(at startTenor: Double) -> Double {
        guard tenor > 1e-15 else {
            return referenceCurve.zeroRate(at: startTenor)
        }
        return referenceCurve.forwardRate(from: startTenor, to: startTenor + tenor)
    }

    /// Generates forward rate fixings for a schedule of start dates.
    ///
    /// - Parameter startTenors: An array of start dates in years from the curve's as-of date.
    /// - Returns: An array of forward rates, one per input date.
    public func fixings(at startTenors: [Double]) -> [Double] {
        return startTenors.map { forwardRate(at: $0) }
    }
}

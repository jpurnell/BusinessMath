//
//  MultiCurveEnvironment.swift
//  BusinessMath
//
//  A multi-curve environment supporting OIS discounting and term-rate projection.
//
//  Created by Justin Purnell on 2026-04-15.
//

import Foundation

// MARK: - MultiCurveEnvironment

/// A multi-curve environment that separates OIS discounting from term-rate projection.
///
/// In modern derivatives pricing, a single curve is not sufficient. The OIS curve
/// (e.g., SOFR or ESTR) is used for discounting cash flows, while separate term
/// curves (e.g., 3M SOFR, 6M EURIBOR) are used to project floating-rate fixings.
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
/// let env = MultiCurveEnvironment(
///     discountCurve: ois,
///     forwardCurves: ["SOFR_3M": sofr3M]
/// )
/// let df = env.discountFactor(at: 2.0)
/// let fwd = env.forwardCurve(for: "SOFR_3M")?.forwardRate(at: 1.0)
/// ```
public struct MultiCurveEnvironment: Sendable {

    /// The OIS discount curve used for present-value calculations.
    public let discountCurve: DiscountCurve

    /// Forward curves keyed by index name (e.g., `"SOFR_3M"`, `"EURIBOR_6M"`).
    public let forwardCurves: [String: ForwardCurve]

    /// Creates a multi-curve environment.
    ///
    /// - Parameters:
    ///   - discountCurve: The OIS curve used for discounting.
    ///   - forwardCurves: A dictionary of ``ForwardCurve`` instances keyed by index name.
    public init(discountCurve: DiscountCurve, forwardCurves: [String: ForwardCurve]) {
        self.discountCurve = discountCurve
        self.forwardCurves = forwardCurves
    }

    /// Looks up a forward curve by its index name.
    ///
    /// - Parameter indexName: The name of the rate index (e.g., `"SOFR_3M"`).
    /// - Returns: The matching ``ForwardCurve``, or `nil` if no curve exists for that index.
    public func forwardCurve(for indexName: String) -> ForwardCurve? {
        return forwardCurves[indexName]
    }

    /// Returns the discount factor from the OIS curve at the given tenor.
    ///
    /// This is a convenience method that delegates to ``DiscountCurve/discountFactor(at:)``.
    ///
    /// - Parameter tenor: Time in years from the as-of date.
    /// - Returns: The discount factor from the OIS curve.
    public func discountFactor(at tenor: Double) -> Double {
        return discountCurve.discountFactor(at: tenor)
    }
}

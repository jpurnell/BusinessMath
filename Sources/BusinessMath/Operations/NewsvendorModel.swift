//
//  NewsvendorModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-05-09.
//

import Foundation
import Numerics

/// A single-period stocking model for perishable or seasonal goods under demand uncertainty.
///
/// The newsvendor (or newsboy) model determines the optimal order quantity that balances
/// the cost of ordering too many units (overage) against the cost of ordering too few (underage).
///
/// ```swift
/// let result = try NewsvendorModel<Double>.optimalQuantity(
///     meanDemand: 100.0,
///     demandStdDev: 25.0,
///     underageCost: 5.0,
///     overageCost: 2.0
/// )
/// print(result.optimalQuantity)  // ≈ 116.13
/// ```
public struct NewsvendorModel<T: Real & Sendable & Codable>: Sendable {

    /// The result of an optimal quantity computation.
    public struct Result: Sendable {
        /// The optimal order quantity Q*.
        public let optimalQuantity: T
        /// The critical fractile p_c = c_u / (c_u + c_o).
        public let criticalFractile: T
        /// The z-score corresponding to the critical fractile.
        public let zScore: T
        /// The expected profit at the optimal quantity.
        public let expectedProfit: T
        /// The expected number of units left over (overstock).
        public let expectedOverstock: T
        /// The expected number of units of unmet demand (understock).
        public let expectedUnderstock: T
        /// The optimal cycle service level (equal to the critical fractile).
        public let serviceLevel: T
    }

    /// Computes the critical fractile (critical ratio) for the newsvendor problem.
    ///
    /// The critical fractile represents the optimal probability of not stocking out,
    /// computed as `p_c = c_u / (c_u + c_o)`.
    ///
    /// - Parameters:
    ///   - underageCost: The per-unit cost of stocking too few (c_u). Must be positive.
    ///   - overageCost: The per-unit cost of stocking too many (c_o). Must be positive.
    /// - Returns: The critical fractile in the open interval (0, 1).
    /// - Throws: ``OperationsError/negativeCost`` if either cost is zero or negative.
    public static func criticalFractile(underageCost: T, overageCost: T) throws -> T {
        guard underageCost > 0 else {
            throw OperationsError.negativeCost
        }
        guard overageCost > 0 else {
            throw OperationsError.negativeCost
        }
        let denominator = underageCost + overageCost
        return underageCost / denominator
    }

    /// Computes the optimal order quantity and associated metrics for normally distributed demand.
    ///
    /// Uses the classical newsvendor formula: `Q* = mu + z* x sigma`, where `z*` is the
    /// inverse normal CDF evaluated at the critical fractile.
    ///
    /// - Parameters:
    ///   - meanDemand: The mean of the normal demand distribution (mu).
    ///   - demandStdDev: The standard deviation of the normal demand distribution (sigma).
    ///   - underageCost: The per-unit cost of under-stocking (c_u). Must be positive.
    ///   - overageCost: The per-unit cost of over-stocking (c_o). Must be positive.
    /// - Returns: A ``Result`` containing the optimal quantity and related metrics.
    /// - Throws: ``OperationsError/negativeCost`` if either cost is zero or negative.
    public static func optimalQuantity(
        meanDemand: T,
        demandStdDev: T,
        underageCost: T,
        overageCost: T
    ) throws -> Result {
        let pc = try criticalFractile(underageCost: underageCost, overageCost: overageCost)
        let z = inverseNormalCDF(p: pc)
        let q = meanDemand + z * demandStdDev

        let overstock = expectedOverstockNormal(quantity: q, meanDemand: meanDemand, demandStdDev: demandStdDev)
        let understock = expectedUnderstockNormal(quantity: q, meanDemand: meanDemand, demandStdDev: demandStdDev)

        // Expected profit at Q*: use underage and overage costs
        let expectedSales = q - overstock
        let profit = underageCost * expectedSales - overageCost * overstock

        return Result(
            optimalQuantity: q,
            criticalFractile: pc,
            zScore: z,
            expectedProfit: profit,
            expectedOverstock: overstock,
            expectedUnderstock: understock,
            serviceLevel: pc
        )
    }

    /// Computes the expected profit for a given stocking quantity under normally distributed demand.
    ///
    /// Uses the formula:
    /// `E[profit] = sellingPrice x E[min(D, Q)] - unitCost x Q + salvageValue x E[max(0, Q - D)]`
    ///
    /// - Parameters:
    ///   - quantity: The number of units ordered (Q).
    ///   - meanDemand: The mean of the normal demand distribution.
    ///   - demandStdDev: The standard deviation of the normal demand distribution.
    ///   - sellingPrice: The revenue per unit sold.
    ///   - unitCost: The cost per unit ordered.
    ///   - salvageValue: The value recovered per unsold unit.
    /// - Returns: The expected profit.
    public static func expectedProfit(
        quantity: T,
        meanDemand: T,
        demandStdDev: T,
        sellingPrice: T,
        unitCost: T,
        salvageValue: T
    ) -> T {
        guard quantity > 0 else {
            return T(0)
        }

        let overstock = expectedOverstockNormal(quantity: quantity, meanDemand: meanDemand, demandStdDev: demandStdDev)
        let expectedSales = quantity - overstock

        return sellingPrice * expectedSales - unitCost * quantity + salvageValue * overstock
    }

    // MARK: - Private helpers

    /// Computes E[max(0, Q - D)] for Normal(mu, sigma) demand.
    ///
    /// Formula: `E[overstock] = (Q - mu) * Phi(z) + sigma * phi(z)`
    /// where `z = (Q - mu) / sigma`.
    private static func expectedOverstockNormal(quantity: T, meanDemand: T, demandStdDev: T) -> T {
        guard demandStdDev > 0 else {
            // Deterministic demand: overstock is simply max(0, Q - mu)
            let diff = quantity - meanDemand
            return diff > 0 ? diff : T(0)
        }
        let z = (quantity - meanDemand) / demandStdDev
        let phi = normalPDF(x: z)
        let bigPhi = normalCDF(x: z)
        return (quantity - meanDemand) * bigPhi + demandStdDev * phi
    }

    /// Computes E[max(0, D - Q)] for Normal(mu, sigma) demand.
    ///
    /// Formula: `E[understock] = (mu - Q) * (1 - Phi(z)) + sigma * phi(z)`
    /// where `z = (Q - mu) / sigma`.
    private static func expectedUnderstockNormal(quantity: T, meanDemand: T, demandStdDev: T) -> T {
        guard demandStdDev > 0 else {
            // Deterministic demand: understock is simply max(0, mu - Q)
            let diff = meanDemand - quantity
            return diff > 0 ? diff : T(0)
        }
        let z = (quantity - meanDemand) / demandStdDev
        let phi = normalPDF(x: z)
        let bigPhi = normalCDF(x: z)
        return (meanDemand - quantity) * (T(1) - bigPhi) + demandStdDev * phi
    }
}

//
//  SafetyStockModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-05-09.
//

import Foundation
import Numerics

/// A model for computing safety stock levels using various inventory management methods.
///
/// `SafetyStockModel` provides static methods to calculate safety stock quantities
/// based on demand variability, lead time variability, or forecast error,
/// targeting a desired service level.
///
/// ```swift
/// let ss = try SafetyStockModel<Double>.safetyStock(
///     method: .demandOnly,
///     serviceLevel: 0.95,
///     averageDemand: 100.0,
///     demandStdDev: 15.0,
///     leadTime: 7.0
/// )
/// ```
public struct SafetyStockModel<T: Real & Sendable & Codable>: Sendable {

    /// The method used to compute safety stock.
    public enum Method: Sendable {
        /// Uses only demand variability: `SS = z * sigma_d * sqrt(L)`.
        case demandOnly
        /// Uses both demand and lead time variability: `SS = z * sqrt(L * sigma_d^2 + d_bar^2 * sigma_L^2)`.
        case demandAndLeadTime
        /// Uses forecast RMSE as the error measure: `SS = z * RMSE * sqrt(L)`.
        case forecastError
    }

    /// Returns the z-score (inverse normal CDF) corresponding to a target service level.
    ///
    /// - Parameter serviceLevel: The desired cycle service level, strictly between 0 and 1.
    /// - Returns: The z-score from the standard normal distribution.
    /// - Throws: ``OperationsError/invalidServiceLevel`` if the service level is not in the open interval (0, 1).
    public static func zScore(for serviceLevel: T) throws -> T {
        guard serviceLevel > 0, serviceLevel < 1 else {
            throw OperationsError.invalidServiceLevel
        }
        return inverseNormalCDF(p: serviceLevel)
    }

    /// Computes the safety stock quantity for a given method and service level.
    ///
    /// - Parameters:
    ///   - method: The calculation method to use.
    ///   - serviceLevel: The target cycle service level, strictly between 0 and 1.
    ///   - averageDemand: The average demand per period (must be positive).
    ///   - demandStdDev: The standard deviation of demand per period.
    ///   - leadTime: The replenishment lead time in periods.
    ///   - leadTimeStdDev: The standard deviation of lead time (used only with ``Method/demandAndLeadTime``). Defaults to 0.
    ///   - forecastRMSE: The root mean square error of the demand forecast (required for ``Method/forecastError``). Defaults to `nil`.
    /// - Returns: The calculated safety stock quantity.
    /// - Throws: ``OperationsError/invalidServiceLevel`` if service level is not in (0, 1).
    /// - Throws: ``OperationsError/zeroDemand`` if `averageDemand` is less than or equal to zero.
    /// - Throws: ``OperationsError/invalidParameter(_:)`` if ``Method/forecastError`` is selected but `forecastRMSE` is `nil`.
    public static func safetyStock(
        method: Method,
        serviceLevel: T,
        averageDemand: T,
        demandStdDev: T,
        leadTime: T,
        leadTimeStdDev: T = 0,
        forecastRMSE: T? = nil
    ) throws -> T {
        guard serviceLevel > 0, serviceLevel < 1 else {
            throw OperationsError.invalidServiceLevel
        }
        guard averageDemand > 0 else {
            throw OperationsError.zeroDemand
        }

        let z = try zScore(for: serviceLevel)
        let sqrtL = T.sqrt(leadTime)

        switch method {
        case .demandOnly:
            // SS = z * sigma_d * sqrt(L)
            return z * demandStdDev * sqrtL

        case .demandAndLeadTime:
            // SS = z * sqrt(L * sigma_d^2 + d_bar^2 * sigma_L^2)
            let varianceComponent = leadTime * demandStdDev * demandStdDev
                + averageDemand * averageDemand * leadTimeStdDev * leadTimeStdDev
            return z * T.sqrt(varianceComponent)

        case .forecastError:
            guard let rmse = forecastRMSE else {
                throw OperationsError.invalidParameter("forecastRMSE is required for the forecastError method")
            }
            // SS = z * RMSE * sqrt(L)
            return z * rmse * sqrtL
        }
    }
}

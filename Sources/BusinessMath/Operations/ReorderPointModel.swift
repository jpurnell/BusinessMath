//
//  ReorderPointModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-05-09.
//

import Foundation
import Numerics

/// A model for computing reorder points and stockout probabilities in inventory management.
///
/// The reorder point formula is `r = d̄ × L + SS`, where `d̄` is average daily demand,
/// `L` is lead time, and `SS` is safety stock.
///
/// ```swift
/// let result = try ReorderPointModel<Double>.calculate(
///     demandHistory: dailySales,
///     leadTime: 7.0,
///     serviceLevel: 0.95
/// )
/// print("Reorder when stock reaches \(result.reorderPoint)")
/// ```
public struct ReorderPointModel<T: Real & Sendable & Codable>: Sendable {

    /// The result of a reorder point calculation.
    public struct Result: Sendable {
        /// The inventory level at which a replenishment order should be placed.
        public let reorderPoint: T
        /// The buffer stock held to protect against demand and lead time variability.
        public let safetyStock: T
        /// The expected total demand during the lead time period (`d̄ × L`).
        public let demandDuringLeadTime: T
        /// The mean demand per period computed from the demand history.
        public let averageDailyDemand: T
        /// The sample standard deviation of demand per period.
        public let demandStdDev: T
        /// The z-score corresponding to the target service level.
        public let zScore: T
        /// The target cycle service level used in the calculation.
        public let serviceLevel: T
        /// The safety stock calculation method that was applied.
        public let method: SafetyStockModel<T>.Method
    }

    /// Computes the reorder point from an array of historical demand observations.
    ///
    /// - Parameters:
    ///   - demandHistory: An array of demand observations per period (must not be empty).
    ///   - leadTime: The replenishment lead time in periods.
    ///   - serviceLevel: The target cycle service level, strictly between 0 and 1.
    ///   - leadTimeStdDev: The standard deviation of lead time. Defaults to 0.
    ///   - method: The safety stock calculation method. Defaults to ``SafetyStockModel/Method/demandOnly``.
    /// - Returns: A ``Result`` containing the reorder point and supporting metrics.
    /// - Throws: ``OperationsError/insufficientData(required:got:)`` if `demandHistory` is empty.
    /// - Throws: ``OperationsError/invalidServiceLevel`` if `serviceLevel` is not in the open interval (0, 1).
    public static func calculate(
        demandHistory: [T],
        leadTime: T,
        serviceLevel: T,
        leadTimeStdDev: T = T(0),
        method: SafetyStockModel<T>.Method = .demandOnly
    ) throws -> Result {
        guard !demandHistory.isEmpty else {
            throw OperationsError.insufficientData(required: 1, got: 0)
        }
        guard serviceLevel > T(0), serviceLevel < T(1) else {
            throw OperationsError.invalidServiceLevel
        }

        let demandMean = mean(demandHistory)
        let sigma = stdDev(demandHistory)

        let demandDuringLeadTime = demandMean * leadTime

        let z = try SafetyStockModel<T>.zScore(for: serviceLevel)

        let ss = try SafetyStockModel<T>.safetyStock(
            method: method,
            serviceLevel: serviceLevel,
            averageDemand: demandMean,
            demandStdDev: sigma,
            leadTime: leadTime,
            leadTimeStdDev: leadTimeStdDev
        )

        let reorderPoint = demandDuringLeadTime + ss

        return Result(
            reorderPoint: reorderPoint,
            safetyStock: ss,
            demandDuringLeadTime: demandDuringLeadTime,
            averageDailyDemand: demandMean,
            demandStdDev: sigma,
            zScore: z,
            serviceLevel: serviceLevel,
            method: method
        )
    }

    /// Computes the reorder point from a ``TimeSeries`` of demand observations.
    ///
    /// Extracts the values from the time series and delegates to the array-based overload.
    ///
    /// - Parameters:
    ///   - demandTimeSeries: A time series of demand observations per period.
    ///   - leadTime: The replenishment lead time in periods.
    ///   - serviceLevel: The target cycle service level, strictly between 0 and 1.
    ///   - leadTimeStdDev: The standard deviation of lead time. Defaults to 0.
    ///   - method: The safety stock calculation method. Defaults to ``SafetyStockModel/Method/demandOnly``.
    /// - Returns: A ``Result`` containing the reorder point and supporting metrics.
    /// - Throws: ``OperationsError/insufficientData(required:got:)`` if the time series is empty.
    /// - Throws: ``OperationsError/invalidServiceLevel`` if `serviceLevel` is not in the open interval (0, 1).
    public static func calculate(
        demandTimeSeries: TimeSeries<T>,
        leadTime: T,
        serviceLevel: T,
        leadTimeStdDev: T = T(0),
        method: SafetyStockModel<T>.Method = .demandOnly
    ) throws -> Result {
        return try calculate(
            demandHistory: demandTimeSeries.valuesArray,
            leadTime: leadTime,
            serviceLevel: serviceLevel,
            leadTimeStdDev: leadTimeStdDev,
            method: method
        )
    }

    /// Estimates the probability that current stock will be insufficient to cover demand during lead time.
    ///
    /// When both `demandStdDev` and `leadTimeStdDev` are zero, the result is binary:
    /// 0 if stock is sufficient, 1 otherwise.
    ///
    /// - Parameters:
    ///   - currentStock: The current on-hand inventory quantity.
    ///   - averageDemand: The average demand per period.
    ///   - demandStdDev: The standard deviation of demand per period.
    ///   - leadTime: The replenishment lead time in periods.
    ///   - leadTimeStdDev: The standard deviation of lead time. Defaults to 0.
    /// - Returns: The estimated stockout probability in the range [0, 1].
    public static func stockoutProbability(
        currentStock: T,
        averageDemand: T,
        demandStdDev: T,
        leadTime: T,
        leadTimeStdDev: T = T(0)
    ) -> T {
        let demandMean = averageDemand * leadTime

        // Deterministic case: no variability at all
        guard demandStdDev != T(0) || leadTimeStdDev != T(0) else {
            return currentStock >= demandMean ? T(0) : T(1)
        }

        // Combined standard deviation during lead time:
        // sigma = sqrt(L * sigma_d^2 + d_bar^2 * sigma_L^2)
        let varianceComponent = leadTime * demandStdDev * demandStdDev
            + averageDemand * averageDemand * leadTimeStdDev * leadTimeStdDev
        let demandStdDevDuringLT = T.sqrt(varianceComponent)

        guard demandStdDevDuringLT > T(0) else {
            return currentStock >= demandMean ? T(0) : T(1)
        }

        let z = (currentStock - demandMean) / demandStdDevDuringLT
        return T(1) - normalCDF(x: z)
    }
}

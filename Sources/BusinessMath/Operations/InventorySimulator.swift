//
//  InventorySimulator.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-05-09.
//

import Foundation

/// A Monte Carlo inventory simulator that estimates reorder points and safety stock
/// through demand-during-lead-time sampling.
///
/// Unlike the analytical ``ReorderPointModel`` which assumes normally distributed demand,
/// `InventorySimulator` builds an empirical distribution of demand-during-lead-time (DDLT)
/// by running thousands of independent trials. This captures non-normal demand patterns,
/// lead time variability, and their interaction.
///
/// ```swift
/// let result = try InventorySimulator.simulate(
///     demandHistory: dailySales,
///     meanLeadTime: 7.0,
///     serviceLevel: 0.95,
///     strategy: .empirical,
///     iterations: 10_000,
///     seed: 42
/// )
/// print("Simulated reorder point: \(result.reorderPoint)")
/// print("Safety stock: \(result.safetyStock)")
/// ```
public struct InventorySimulator: Sendable {

    /// The sampling strategy used to generate demand draws in each simulation trial.
    public enum SamplingStrategy: Sendable {
        /// Bootstraps demand from the raw historical observations.
        /// Best when the demand distribution is unknown or non-normal.
        case empirical
        /// Fits a normal distribution to the demand history and samples from it.
        /// Appropriate when demand is approximately bell-shaped.
        case normal
    }

    /// The output of an inventory simulation run.
    public struct Result: Sendable {
        /// The inventory level at which to trigger a replenishment order,
        /// estimated as the service-level percentile of the DDLT distribution.
        public let reorderPoint: Double
        /// The buffer stock above expected DDLT:
        /// `safetyStock = reorderPoint - demandDuringLeadTimeMean`.
        public let safetyStock: Double
        /// The mean demand-during-lead-time across all simulated paths.
        public let demandDuringLeadTimeMean: Double
        /// The standard deviation of demand-during-lead-time across paths.
        public let demandDuringLeadTimeStdDev: Double
        /// The number of simulation paths (iterations) executed.
        public let pathCount: Int
        /// A human-readable label for the sampling strategy used.
        public let samplingStrategy: String
        /// The full ``SimulationResults`` for further analysis (percentiles, histograms, etc.).
        public let simulationResults: SimulationResults
    }

    /// Runs a Monte Carlo inventory simulation to estimate the reorder point and safety stock.
    ///
    /// Each iteration samples a lead time, then draws that many daily demands using the
    /// chosen ``SamplingStrategy``, summing them to get one demand-during-lead-time (DDLT)
    /// observation. After all iterations, the reorder point is the percentile of the DDLT
    /// distribution corresponding to the target service level.
    ///
    /// - Parameters:
    ///   - demandHistory: Historical demand observations per period. Must not be empty.
    ///   - meanLeadTime: The mean replenishment lead time in periods.
    ///   - leadTimeStdDev: The standard deviation of lead time. Defaults to 0 (fixed lead time).
    ///   - serviceLevel: The target cycle service level, strictly between 0 and 1.
    ///   - strategy: The demand sampling strategy. Defaults to `.empirical`.
    ///   - iterations: The number of simulation paths to run. Defaults to 10,000.
    ///   - seed: An optional seed for reproducible results. When `nil`, uses system randomness.
    /// - Returns: A ``Result`` containing the simulated reorder point and supporting metrics.
    /// - Throws: ``OperationsError/insufficientData(required:got:)`` if `demandHistory` is empty.
    /// - Throws: ``OperationsError/invalidServiceLevel`` if `serviceLevel` is not in (0, 1).
    public static func simulate(
        demandHistory: [Double],
        meanLeadTime: Double,
        leadTimeStdDev: Double = 0.0,
        serviceLevel: Double,
        strategy: SamplingStrategy = .empirical,
        iterations: Int = 10_000,
        seed: UInt64? = nil
    ) throws -> Result {
        guard !demandHistory.isEmpty else {
            throw OperationsError.insufficientData(required: 1, got: 0)
        }
        guard serviceLevel > 0, serviceLevel < 1 else {
            throw OperationsError.invalidServiceLevel
        }

        let demandMean = mean(demandHistory)
        let demandStdDev = stdDev(demandHistory)

        var ddltValues: [Double] = []
        ddltValues.reserveCapacity(iterations)

        if let seed = seed {
            var rng = DeterministicRNG(seed: seed)
            for _ in 0..<iterations {
                let lt = sampleLeadTime(mean: meanLeadTime, stdDev: leadTimeStdDev, using: &rng)
                let ddlt = sampleDDLT(
                    days: lt,
                    history: demandHistory,
                    mean: demandMean,
                    stdDev: demandStdDev,
                    strategy: strategy,
                    using: &rng
                )
                ddltValues.append(ddlt)
            }
        } else {
            var rng = SystemRandomNumberGenerator() // stochastic:exempt
            for _ in 0..<iterations {
                let lt = sampleLeadTime(mean: meanLeadTime, stdDev: leadTimeStdDev, using: &rng)
                let ddlt = sampleDDLT(
                    days: lt,
                    history: demandHistory,
                    mean: demandMean,
                    stdDev: demandStdDev,
                    strategy: strategy,
                    using: &rng
                )
                ddltValues.append(ddlt)
            }
        }

        let simResults = SimulationResults(values: ddltValues)

        let sorted = ddltValues.sorted()
        let index = Int((serviceLevel * Double(iterations)).rounded(.up)) - 1
        let clampedIndex = max(0, min(sorted.count - 1, index))
        let reorderPoint = sorted[clampedIndex]

        let ddltMean = simResults.statistics.mean

        return Result(
            reorderPoint: reorderPoint,
            safetyStock: reorderPoint - ddltMean,
            demandDuringLeadTimeMean: ddltMean,
            demandDuringLeadTimeStdDev: simResults.statistics.stdDev,
            pathCount: iterations,
            samplingStrategy: strategyLabel(strategy),
            simulationResults: simResults
        )
    }

    // MARK: - Private helpers

    private static func normalSample<G: RandomNumberGenerator>(
        mean: Double = 0.0, stdDev: Double = 1.0, using rng: inout G
    ) -> Double {
        let u1 = Double.random(in: Double.leastNonzeroMagnitude..<1.0, using: &rng)
        let u2 = Double.random(in: 0.0..<1.0, using: &rng)
        return distributionNormal(mean: mean, stdDev: stdDev, u1, u2)
    }

    private static func sampleLeadTime<G: RandomNumberGenerator>(
        mean: Double, stdDev: Double, using rng: inout G
    ) -> Int {
        guard stdDev > 0 else {
            return max(1, Int(mean.rounded()))
        }
        let lt = normalSample(mean: mean, stdDev: stdDev, using: &rng)
        return max(1, Int(lt.rounded()))
    }

    private static func sampleDDLT<G: RandomNumberGenerator>(
        days: Int,
        history: [Double],
        mean: Double,
        stdDev: Double,
        strategy: SamplingStrategy,
        using rng: inout G
    ) -> Double {
        var total = 0.0
        for _ in 0..<days {
            switch strategy {
            case .empirical:
                let idx = Int.random(in: 0..<history.count, using: &rng)
                total += max(0, history[idx])
            case .normal:
                total += max(0, normalSample(mean: mean, stdDev: stdDev, using: &rng))
            }
        }
        return total
    }

    private static func strategyLabel(_ strategy: SamplingStrategy) -> String {
        switch strategy {
        case .empirical: return "empirical"
        case .normal: return "normal"
        }
    }
}

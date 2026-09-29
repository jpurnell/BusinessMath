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
/// let dailySales = [100.0, 110.0, 120.0, 130.0, 105.0, 118.0]
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
    ///   - iterations: The number of simulation paths to run. Defaults to 10,000. Must be at
    ///     least 1: a reorder point is a percentile of the simulated paths, so zero of them
    ///     is not a distribution to take one from.
    ///   - seed: An optional seed for reproducible results. When `nil`, uses system randomness.
    /// - Returns: An ``InventorySimulator/Result`` containing the simulated reorder point and supporting metrics.
    /// - Throws: ``OperationsError/insufficientData(required:got:)`` if `demandHistory` is empty.
    /// - Throws: ``OperationsError/invalidServiceLevel`` if `serviceLevel` is not in (0, 1).
    /// - Throws: ``OperationsError/invalidParameter(_:)`` if `meanLeadTime` or `leadTimeStdDev`
    ///   is not finite or lies outside `0 ... 100_000` periods. A lead time is both a
    ///   `Double`-to-`Int` conversion and the trip count of the inner sampling loop, so an
    ///   unscreened one is fatal twice over — see the guards below.
    /// - Throws: ``OperationsError/invalidParameter(_:)`` if `iterations` is less than 1.
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
        // `meanLeadTime` and `leadTimeStdDev` were never screened, and they are fatal in two
        // different ways. `sampleLeadTime` converts the sampled lead time with `Int(_:)`,
        // which traps on `nan` and on `infinity` — the crash reported against `:167` and
        // `:170`. Screening only for finiteness fixes the wrong half: a merely enormous
        // *finite* lead time such as `1e18` converts perfectly well and then becomes the trip
        // count of `sampleDDLT`'s `for _ in 0..<days` loop, so the crash turns into a run that
        // never returns. A hang tells the caller even less than a trap does. Both are refused
        // here, at the entry point, before any sampling runs.
        //
        // The range test also catches `nan` and the infinities on its own — every comparison
        // against `nan` is false, and `infinity <= maximumLeadTime` is false — so there is one
        // guard per parameter rather than a finiteness guard and a magnitude guard for each.
        // The message states both halves so the diagnosis matches the condition.
        //
        // `maximumLeadTime` is 100,000 demand periods: about 274 years of daily
        // replenishment, and already 10^9 inner draws at the default 10,000 iterations.
        // Beyond that the number is a data-entry error, not a lead time.
        guard meanLeadTime >= 0, meanLeadTime <= maximumLeadTime else {
            throw OperationsError.invalidParameter(
                "meanLeadTime must be finite and within 0 ... \(maximumLeadTime) periods"
            )
        }
        guard leadTimeStdDev >= 0, leadTimeStdDev <= maximumLeadTime else {
            throw OperationsError.invalidParameter(
                "leadTimeStdDev must be finite and within 0 ... \(maximumLeadTime) periods"
            )
        }
        // `iterations` had no guard at all, and it is fatal in two different ways — the same
        // pair the lead-time parameters above were screened for. `iterations: 0` produces an
        // empty `ddltValues`, so `sorted.count - 1` is `-1`, `max(0, min(-1, index))` clamps
        // *up* to `0`, and `sorted[0]` on an empty array is `Index out of range`: the clamp
        // written to make the subscript safe is exactly what makes it fatal, because it
        // cannot express "there is no element to take". A negative `iterations` dies earlier
        // and even more obscurely, inside `reserveCapacity`, before any of this code is
        // reached. Neither told the caller anything — the process ended.
        //
        // Refused here rather than returned as a degenerate `Result`, because a reorder point
        // is a percentile of the simulated distribution and zero paths is no distribution:
        // any value this could hand back would be a service level nobody measured. The
        // sibling guards throw for the same reason and this one matches them.
        guard iterations > 0 else {
            throw OperationsError.invalidParameter(
                "iterations must be at least 1; got \(iterations)"
            )
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
            var rng = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
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
        let u1 = openUnitUniform(Double.self, using: &rng)
        let u2 = openUnitUniform(Double.self, using: &rng)
        return distributionNormal(mean: mean, stdDev: stdDev, u1, u2)
    }

    private static func sampleLeadTime<G: RandomNumberGenerator>(
        mean: Double, stdDev: Double, using rng: inout G
    ) -> Int {
        guard stdDev > 0 else {
            return boundedLeadTimePeriods(mean.rounded())
        }
        let lt = normalSample(mean: mean, stdDev: stdDev, using: &rng)
        return boundedLeadTimePeriods(lt.rounded())
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

    /// The largest lead time, in demand periods, that `simulate(demandHistory:meanLeadTime:leadTimeStdDev:serviceLevel:strategy:iterations:seed:)` will run.
    ///
    /// 100,000 periods is roughly 274 years of daily replenishment, and at the default 10,000
    /// iterations it is already 10^9 inner demand draws. The bound exists because a lead time
    /// is a loop trip count, not because any real supply chain approaches it.
    private static let maximumLeadTime: Double = 100_000

    /// Reduces a sampled lead time to a trip count that is safe to convert and safe to loop over.
    ///
    /// The value this returns is used twice: as an `Int` (and `Int(_:)` on a `Double` traps on
    /// a non-finite value and on anything outside `Int`'s range) and as the upper bound of
    /// `sampleDDLT`'s `for _ in 0..<days` loop (where a merely enormous value is a run that
    /// never finishes). The entry-point guards in `simulate` already refuse a mean or a
    /// standard deviation outside `0 ... maximumLeadTime`, but a normal *draw* is not bounded
    /// by its mean, so the draw is bounded here as well — clamped in `Double`, before the
    /// conversion, never after it.
    ///
    /// - Parameter periods: A sampled lead time in demand periods.
    /// - Returns: A whole number of periods, at least 1 and at most `maximumLeadTime`.
    private static func boundedLeadTimePeriods(_ periods: Double) -> Int {
        // Unreachable through `simulate`, whose parameter guards run first. Kept so the
        // conversion is total on its own terms rather than by relying on that ordering; a
        // clamp cannot do this job, because `Swift.min(Swift.max(.nan, 1), x)` is `nan`.
        guard periods.isFinite else { return 1 }
        let clamped = Swift.min(Swift.max(periods, 1), maximumLeadTime)
        return Int(clamped)
    }
}

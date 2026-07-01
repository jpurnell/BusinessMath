//
//  AsyncDEASolver.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-07-01.
//

import Foundation

/// Asynchronous DEA solver that dispatches LP solves concurrently via TaskGroup.
///
/// Each DMU's linear program is fully independent, making DEA an ideal candidate
/// for parallel execution. ``AsyncDEASolver`` uses Swift concurrency to distribute
/// LP solves across available cores while bounding concurrency to avoid resource
/// exhaustion.
///
/// Results are deterministic regardless of concurrency level — the same inputs
/// always produce the same outputs.
///
/// ## Example
/// ```swift
/// let solver = AsyncDEASolver(maxConcurrency: 4)
/// let dmus = [
///     DMU(name: "A", inputs: [2, 5], outputs: [1, 4]),
///     DMU(name: "B", inputs: [3, 3], outputs: [2, 2]),
///     DMU(name: "C", inputs: [6, 2], outputs: [3, 1])
/// ]
/// let result = try await solver.solve(dmus: dmus)
/// ```
///
/// ## See Also
/// - ``DEASolver``
/// - ``DMU``
/// - ``DEAResult``
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public struct AsyncDEASolver: Sendable {

    /// Maximum number of concurrent LP solves.
    public let maxConcurrency: Int

    /// Creates an asynchronous DEA solver.
    ///
    /// - Parameter maxConcurrency: Maximum simultaneous LP solves. Defaults to the
    ///   number of active processors reported by the system.
    public init(maxConcurrency: Int? = nil) {
        let requested = maxConcurrency ?? ProcessInfo.processInfo.activeProcessorCount
        self.maxConcurrency = max(requested, 1)
    }

    /// Evaluate the relative efficiency of DMUs concurrently.
    ///
    /// Validates inputs once, then dispatches one LP per DMU via a bounded
    /// ``TaskGroup``. Results are collected in the original DMU order.
    ///
    /// - Parameters:
    ///   - dmus: Array of decision-making units to evaluate. Minimum 2.
    ///   - model: CCR (constant returns to scale) or BCC (variable returns to scale).
    ///   - orientation: Input-oriented or output-oriented.
    ///   - inputNames: Optional labels for input dimensions.
    ///   - outputNames: Optional labels for output dimensions.
    /// - Returns: DEA results including efficiency scores and improvement targets.
    /// - Throws: ``DEAError`` if inputs are invalid or any LP fails.
    ///   Also throws `CancellationError` if the enclosing task is cancelled.
    public func solve(
        dmus: [DMU],
        model: DEAModelType = .ccr,
        orientation: DEAOrientation = .inputOriented,
        inputNames: [String]? = nil,
        outputNames: [String]? = nil
    ) async throws -> DEAResult {
        let workhorse = DEASolver()
        try workhorse.validate(dmus: dmus)

        let count = dmus.count
        let concurrencyLimit = maxConcurrency

        let indexedResults: [(Int, DMUScore, Int)] = try await withThrowingTaskGroup(
            of: (Int, DMUScore, Int).self
        ) { group in
            var collected: [(Int, DMUScore, Int)] = []
            collected.reserveCapacity(count)

            var nextToSubmit = 0

            while nextToSubmit < count, nextToSubmit < concurrencyLimit {
                let index = nextToSubmit
                group.addTask {
                    let result = try workhorse.solveSingleDMU(
                        index: index,
                        dmus: dmus,
                        model: model,
                        orientation: orientation
                    )
                    return (index, result.score, result.iterations)
                }
                nextToSubmit += 1
            }

            while let completed = try await group.next() {
                collected.append(completed)

                if nextToSubmit < count {
                    try Task.checkCancellation()

                    let index = nextToSubmit
                    group.addTask {
                        let result = try workhorse.solveSingleDMU(
                            index: index,
                            dmus: dmus,
                            model: model,
                            orientation: orientation
                        )
                        return (index, result.score, result.iterations)
                    }
                    nextToSubmit += 1
                }
            }

            return collected
        }

        let sorted = indexedResults.sorted { $0.0 < $1.0 }
        let scores = sorted.map { $0.1 }
        let totalIterations = sorted.reduce(0) { $0 + $1.2 }

        return DEAResult(
            scores: scores,
            model: model,
            orientation: orientation,
            totalIterations: totalIterations
        )
    }
}

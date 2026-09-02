import Foundation
import Numerics

// MARK: - Rollforward

/// Carries one account's closing value into another account's opening value, one
/// period later.
///
/// This is the piece a formula deliberately cannot express. `FormulaEvaluator`
/// and `CycleSolver` both document that a formula reads accounts *in the period
/// it is evaluating* and never reaches into another one, and that the
/// roll-forward carrying a closing balance into the next period is the caller's
/// loop. A `Rollforward` is that carry, written as data rather than hidden inside
/// a formula — so it can be read, listed, and refused when it does not make sense.
/// The seed is generic rather than `Double`, which the design sketch had
/// proposed. A `ModelDefinition` is generic over its numeric type, and there is
/// no total conversion from `Double` into an arbitrary `Real` — the alternatives
/// were a failable string round-trip or a silent fallback to zero, and a seed
/// that quietly becomes zero is a balance sheet that quietly starts empty.
public struct Rollforward<T: Real & Sendable>: Sendable, Equatable, Hashable {

    /// The account that receives the prior period's closing value.
    public let opening: String

    /// The account whose closing value is carried forward.
    public let closing: String

    /// The opening account's value in the first period, where there is no prior.
    public let seed: T

    /// Declares a carry between two accounts.
    ///
    /// - Parameters:
    ///   - opening: The account that receives the prior period's value.
    ///   - closing: The account whose value is carried.
    ///   - seed: The opening value for the first period.
    public init(opening: String, closing: String, seed: T) {
        self.opening = opening
        self.closing = closing
        self.seed = seed
    }
}

// MARK: - Errors

/// Why a timeline could not be run.
public enum PeriodDriverError: Error, Sendable, Equatable {

    /// A rollforward named an account the model neither supplies nor defines.
    case unknownAccount(String, inRollforward: String)

    /// Rollforwards carry into one another in a loop, so no period can start.
    case rollforwardCycle([String])

    /// A period failed. Carries which one, because a model that works for three
    /// periods and fails in the fourth is a very different problem from one that
    /// never worked.
    case periodFailure(Period, underlying: String)

    /// There were no periods to run.
    case emptyTimeline
}

// MARK: - Driver

/// Runs a period-local `ModelDefinition` across a timeline, carrying rollforwards.
///
/// Each period: seed the opening accounts from the previous period's closing
/// values, slice the inputs to that period, solve, and collect. The two kinds of
/// circularity stay separate and neither is asked to do the other's job:
///
/// | Circularity | Resolved by |
/// |---|---|
/// | Within one period — interest on an average balance | `CycleSolver` |
/// | Across periods — closing becomes next opening | This type |
///
/// That separation is what lets a sweep whose interest depends on its own
/// repayment converge inside a period, while the balance still moves forward
/// between periods without either mechanism seeing the other.
public struct PeriodDriver<T: Real & Sendable & LosslessStringConvertible>: Sendable {

    private let definition: ModelDefinition<T>
    private let rollforwards: [Rollforward<T>]

    /// Creates a driver for a model and its carries.
    ///
    /// - Parameters:
    ///   - definition: A period-local model.
    ///   - rollforwards: The balances that move between periods.
    public init(definition: ModelDefinition<T>, rollforwards: [Rollforward<T>]) {
        self.definition = definition
        self.rollforwards = rollforwards
    }

    /// Runs the model over a timeline.
    ///
    /// - Parameters:
    ///   - periods: The timeline, in order.
    ///   - settings: How hard to try on within-period cycles.
    /// - Returns: Every account, supplied and derived, as a series over `periods`.
    /// - Throws: ``PeriodDriverError``. A failure inside a period is wrapped with
    ///   the period it happened in rather than propagated bare, because knowing
    ///   *when* a model broke is most of knowing why.
    public func run(
        over periods: [Period],
        settings: IterationSettings<T> = IterationSettings()
    ) throws -> [String: TimeSeries<T>] {
        guard !periods.isEmpty else { throw PeriodDriverError.emptyTimeline }
        try validateRollforwards()

        var collected: [String: [Period: T]] = [:]
        var carried: [String: T] = [:]
        for rollforward in rollforwards {
            carried[rollforward.opening] = rollforward.seed
        }

        for period in periods {
            var inputs = slice(definition.inputs, to: period)
            for (account, value) in carried {
                inputs[account] = TimeSeries(periods: [period], values: [value])
            }

            let single = ModelDefinition<T>(
                inputs: inputs,
                definitions: definition.definitions
            )

            let solved: [String: TimeSeries<T>]
            do {
                solved = try single.solve(settings: settings)
            } catch {
                throw PeriodDriverError.periodFailure(period, underlying: "\(error)")
            }

            for (account, series) in solved {
                guard let value = series[period] else { continue }
                collected[account, default: [:]][period] = value
            }

            // The next period opens where this one closed.
            for rollforward in rollforwards {
                guard let closing = solved[rollforward.closing]?[period] else {
                    throw PeriodDriverError.periodFailure(
                        period,
                        underlying: "the rollforward's closing account "
                            + "'\(rollforward.closing)' produced no value"
                    )
                }
                carried[rollforward.opening] = closing
            }
        }

        return assemble(collected, over: periods)
    }

    // MARK: - Private

    /// Checks the carries before running, so a mistake is reported once rather
    /// than as a failure in every period.
    private func validateRollforwards() throws {
        let known = Set(definition.inputs.keys)
            .union(definition.definitions.map(\.name))

        for rollforward in rollforwards {
            guard known.contains(rollforward.closing) else {
                throw PeriodDriverError.unknownAccount(
                    rollforward.closing, inRollforward: rollforward.opening)
            }
        }

        // An opening that is itself carried from elsewhere has no period to start
        // in, because both would be waiting on the other.
        let openings = Set(rollforwards.map(\.opening))
        let cycle = rollforwards.filter { openings.contains($0.closing) }
        guard cycle.isEmpty else {
            throw PeriodDriverError.rollforwardCycle(cycle.map(\.opening).sorted())
        }
    }

    /// Narrows every input to a single period.
    private func slice(
        _ inputs: [String: TimeSeries<T>], to period: Period
    ) -> [String: TimeSeries<T>] {
        var sliced: [String: TimeSeries<T>] = [:]
        for (name, series) in inputs {
            guard let value = series[period] else { continue }
            sliced[name] = TimeSeries(periods: [period], values: [value])
        }
        return sliced
    }

    /// Reassembles per-period values into series, in timeline order.
    ///
    /// An account missing from a period is left out rather than filled, which is
    /// the same rule the rest of the library follows for periods that do not line
    /// up.
    private func assemble(
        _ collected: [String: [Period: T]], over periods: [Period]
    ) -> [String: TimeSeries<T>] {
        var results: [String: TimeSeries<T>] = [:]
        for (account, byPeriod) in collected {
            var accountPeriods: [Period] = []
            var values: [T] = []
            for period in periods {
                guard let value = byPeriod[period] else { continue }
                accountPeriods.append(period)
                values.append(value)
            }
            results[account] = TimeSeries(periods: accountPeriods, values: values)
        }
        return results
    }
}

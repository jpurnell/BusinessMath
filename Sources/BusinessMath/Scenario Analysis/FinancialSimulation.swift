//
//  FinancialSimulation.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/20/25.
//

import Foundation
import Numerics

/// Results of a Monte Carlo financial simulation with probabilistic drivers.
///
/// `FinancialSimulation` runs a scenario multiple times with probabilistic drivers,
/// collecting all projection results for statistical analysis. This enables risk
/// assessment, confidence intervals, and probabilistic forecasting.
///
/// ## Creating Financial Simulations
///
/// Simulations are created using ``runFinancialSimulation(scenario:entity:periods:iterations:builder:)``:
///
/// ```swift
/// // Create scenario with uncertain revenue
/// let uncertainRevenue = ProbabilisticDriver(
///     name: "Revenue",
///     distribution: DistributionNormal(mean: 100_000.0, standardDeviation: 15_000.0)
///     )
///
/// var overrides: [String: AnyDriver<Double>] = [:]
/// overrides["Revenue"] = AnyDriver(uncertainRevenue)
///
/// let scenario = FinancialScenario(
///     name: "Uncertain Revenue",
///     description: "Revenue with market uncertainty",
///     driverOverrides: overrides
/// )
///
/// // Run 1000 Monte Carlo iterations
/// let simulation = try runFinancialSimulation(
///     scenario: scenario,
///     entity: entity,
///     periods: periods,
///     iterations: 1000,
///     builder: builder
/// )
/// ```
///
/// ## Analyzing Results
///
/// Extract any metric from the projections and analyze its distribution:
///
/// ```swift
/// let q1 = Period.quarter(year: 2025, quarter: 1)
///
/// // Percentiles
/// let p10 = simulation.percentile(0.10) { $0.incomeStatement.netIncome[q1]! }
/// let p50 = simulation.percentile(0.50) { $0.incomeStatement.netIncome[q1]! }  // Median
/// let p90 = simulation.percentile(0.90) { $0.incomeStatement.netIncome[q1]! }
///
/// print("Net Income Range:")
/// print("  10th percentile: \(p10)")
/// print("  Median (P50): \(p50)")
/// print("  90th percentile: \(p90)")
///
/// // Confidence intervals
/// let ci90 = simulation.confidenceInterval(0.90) { $0.incomeStatement.netIncome[q1]! }
/// print("90% Confidence Interval: \(ci90.lowerBound) to \(ci90.upperBound)")
///
/// // Risk metrics
/// let var95 = simulation.valueAtRisk(0.95) { $0.incomeStatement.netIncome[q1]! }
/// let cvar95 = simulation.conditionalValueAtRisk(0.95) { $0.incomeStatement.netIncome[q1]! }
/// let probLoss = simulation.probabilityOfLoss { $0.incomeStatement.netIncome[q1]! }
///
/// print("Risk Metrics:")
/// print("  VaR (95%): \(var95)")
/// print("  CVaR (95%): \(cvar95)")
/// print("  Probability of Loss: \(probLoss * 100)%")
/// ```
///
/// ## Use Cases
///
/// - **Risk Assessment**: Understand the range of possible outcomes
/// - **Confidence Intervals**: Provide probabilistic forecasts
/// - **Stress Testing**: Measure resilience to adverse scenarios
/// - **Capital Planning**: Size reserves based on VaR/CVaR
/// - **Decision Making**: Make decisions robust to uncertainty
///
/// ## Topics
///
/// ### Properties
/// - ``projections``
/// - ``iterations``
///
/// ### Statistical Methods
/// - ``percentile(_:metric:)``
/// - ``confidenceInterval(_:metric:)``
/// - ``mean(metric:)``
///
/// ### Risk Metrics
/// - ``valueAtRisk(_:metric:)``
/// - ``conditionalValueAtRisk(_:metric:)``
/// - ``probabilityOfLoss(metric:)``
///
/// ### Related Types
/// - ``runFinancialSimulation(scenario:entity:periods:iterations:builder:)``
public struct FinancialSimulation: Sendable {

	// MARK: - Properties

	/// All financial projections from the simulation.
	///
	/// Each projection represents one Monte Carlo iteration with sampled
	/// driver values.
	public let projections: [FinancialProjection]

	/// The number of Monte Carlo iterations run.
	///
	/// Equal to `projections.count`.
	public let iterations: Int

	// MARK: - Initialization

	/// Creates a financial simulation result.
	///
	/// - Parameters:
	///   - projections: All projections from the simulation.
	///
	/// - Note: In typical usage, simulations are created by
	///   ``runFinancialSimulation(scenario:entity:periods:iterations:builder:)``
	///   rather than constructed manually.
	public init(projections: [FinancialProjection]) {
		self.projections = projections
		self.iterations = projections.count
	}
}

// MARK: - Statistical Methods

extension FinancialSimulation {

	/// Calculates the mean (average) of a metric across all projections.
	///
	/// - Parameter metric: A function that extracts the metric from a projection.
	///
	/// - Returns: The arithmetic mean of the metric values.
	///
	/// ## Example
	/// ```swift
	/// let meanNetIncome = simulation.mean { projection in
	///     let q1 = Period.quarter(year: 2025, quarter: 1)
	///     return projection.incomeStatement.netIncome[q1]!
	/// }
	/// ```
	public func mean(metric: (FinancialProjection) -> Double) -> Double {
		// Optimization: compute sum without intermediate array
		var sum = 0.0
		for projection in projections {
			sum += metric(projection)
		}
		return sum / Double(projections.count)
	}

	/// Calculates a percentile of a metric across all projections.
	///
	/// - Parameters:
	///   - p: The percentile to calculate (0.0 to 1.0).
	///   - metric: A function that extracts the metric from a projection.
	///
	/// - Returns: The value at the specified percentile.
	///
	/// ## Example
	/// ```swift
	/// // Calculate median (50th percentile) net income
	/// let medianNetIncome = simulation.percentile(0.50) { projection in
	///     let q1 = Period.quarter(year: 2025, quarter: 1)
	///     return projection.incomeStatement.netIncome[q1]!
	/// }
	/// ```
	///
	/// ## Algorithm
	/// Uses linear interpolation between adjacent values for non-integer positions.
	public func percentile(_ p: Double, metric: (FinancialProjection) -> Double) -> Double {
		let sortedValues = projections.map(metric).sorted()
		return percentileFromSorted(p, values: sortedValues)
	}

	/// Helper to calculate percentile from pre-sorted values.
	@usableFromInline
	@inline(__always)
	internal func percentileFromSorted(_ p: Double, values: [Double]) -> Double {
		guard !values.isEmpty else { return 0.0 }

		let position = p * Double(values.count - 1)
		let lowerIndex = Int(position)
		let upperIndex = min(lowerIndex + 1, values.count - 1)
		let fraction = position - Double(lowerIndex)

		return values[lowerIndex] * (1.0 - fraction) + values[upperIndex] * fraction
	}

	/// Calculates a confidence interval for a metric.
	///
	/// - Parameters:
	///   - level: The confidence level (e.g., 0.90 for 90% confidence).
	///   - metric: A function that extracts the metric from a projection.
	///
	/// - Returns: A tuple with the lower and upper bounds of the confidence interval.
	///
	/// ## Example
	/// ```swift
	/// let ci = simulation.confidenceInterval(0.95) { projection in
	///     let q1 = Period.quarter(year: 2025, quarter: 1)
	///     return projection.incomeStatement.netIncome[q1]!
	/// }
	///
	/// print("95% Confidence Interval: [\(ci.lowerBound), \(ci.upperBound)]")
	/// ```
	///
	/// ## Algorithm
	/// For a 90% confidence interval, returns the 5th and 95th percentiles.
	/// For a 95% confidence interval, returns the 2.5th and 97.5th percentiles.
	public func confidenceInterval(
		_ level: Double,
		metric: (FinancialProjection) -> Double
	) -> (lowerBound: Double, upperBound: Double) {
		// Optimization: sort once and reuse for both bounds
		let sortedValues = projections.map(metric).sorted()
		let tail = (1.0 - level) / 2.0
		let lowerBound = percentileFromSorted(tail, values: sortedValues)
		let upperBound = percentileFromSorted(1.0 - tail, values: sortedValues)
		return (lowerBound: lowerBound, upperBound: upperBound)
	}
}

// MARK: - Risk Metrics

extension FinancialSimulation {

	/// Calculates Value at Risk (VaR) for a metric.
	///
	/// VaR is the threshold below which the metric falls with a given probability.
	/// For 95% VaR, there's a 5% chance the metric will be below this value.
	///
	/// - Parameters:
	///   - confidence: The confidence level (e.g., 0.95 for 95% VaR).
	///   - metric: A function that extracts the metric from a projection.
	///
	/// - Returns: The Value at Risk.
	///
	/// ## Example
	/// ```swift
	/// // 95% VaR: there's a 5% chance net income will be below this value
	/// let var95 = simulation.valueAtRisk(0.95) { projection in
	///     let q1 = Period.quarter(year: 2025, quarter: 1)
	///     return projection.incomeStatement.netIncome[q1]!
	/// }
	///
	/// print("VaR (95%): \(var95)")
	/// print("There's a 5% chance net income will be below \(var95)")
	/// ```
	public func valueAtRisk(_ confidence: Double, metric: (FinancialProjection) -> Double) -> Double {
		return percentile(1.0 - confidence, metric: metric)
	}

	/// Calculates Conditional Value at Risk (CVaR) for a metric.
	///
	/// CVaR is the expected value of the metric given that it's below the VaR threshold.
	/// Also known as Expected Shortfall (ES) or Average Value at Risk (AVaR).
	///
	/// - Parameters:
	///   - confidence: The confidence level (e.g., 0.95 for 95% CVaR).
	///   - metric: A function that extracts the metric from a projection.
	///
	/// - Returns: The Conditional Value at Risk.
	///
	/// ## Example
	/// ```swift
	/// let cvar95 = simulation.conditionalValueAtRisk(0.95) { projection in
	///     let q1 = Period.quarter(year: 2025, quarter: 1)
	///     return projection.incomeStatement.netIncome[q1]!
	/// }
	///
	/// print("CVaR (95%): \(cvar95)")
	/// print("If we're in the worst 5% of cases, expected net income is \(cvar95)")
	/// ```
	///
	/// ## Algorithm
	/// Calculates the average of all values below the VaR threshold.
	public func conditionalValueAtRisk(
		_ confidence: Double,
		metric: (FinancialProjection) -> Double
	) -> Double {
		// Optimization: sort once and reuse for both VaR and tail calculation
		let sortedValues = projections.map(metric).sorted()

		// Calculate the tail size (e.g., 5% for 95% confidence)
		let tailSize = Int(ceil(Double(sortedValues.count) * (1.0 - confidence)))
		guard tailSize > 0 else { return sortedValues.first ?? 0.0 }

		// Sum the worst outcomes (already sorted, so first tailSize elements)
		// This is much faster than filter + reduce
		var sum = 0.0
		let endIndex = min(tailSize, sortedValues.count)
		for i in 0..<endIndex {
			sum += sortedValues[i]
		}

		return sum / Double(endIndex)
	}

	/// Calculates the probability that a metric will be negative (a loss).
	///
	/// - Parameter metric: A function that extracts the metric from a projection.
	///
	/// - Returns: Probability of loss (0.0 to 1.0).
	///
	/// ## Example
	/// ```swift
	/// let probLoss = simulation.probabilityOfLoss { projection in
	///     let q1 = Period.quarter(year: 2025, quarter: 1)
	///     return projection.incomeStatement.netIncome[q1]!
	/// }
	///
	/// print("Probability of negative net income: \(probLoss * 100)%")
	/// ```
	public func probabilityOfLoss(metric: (FinancialProjection) -> Double) -> Double {
		// Optimization: count directly without intermediate arrays
		var lossCount = 0
		for projection in projections {
			if metric(projection) < 0.0 {
				lossCount += 1
			}
		}
		return Double(lossCount) / Double(projections.count)
	}

	/// Calculates the probability that a metric will be below a threshold.
	///
	/// - Parameters:
	///   - threshold: The threshold value.
	///   - metric: A function that extracts the metric from a projection.
	///
	/// - Returns: Probability of being below threshold (0.0 to 1.0).
	///
	/// ## Example
	/// ```swift
	/// // Probability that revenue is below $80,000
	/// let prob = simulation.probabilityBelow(80_000.0) { projection in
	///     let q1 = Period.quarter(year: 2025, quarter: 1)
	///     return projection.incomeStatement.totalRevenue[q1]!
	/// }
	/// ```
	public func probabilityBelow(
		_ threshold: Double,
		metric: (FinancialProjection) -> Double
	) -> Double {
		// Optimization: count directly without intermediate arrays
		var belowCount = 0
		for projection in projections {
			if metric(projection) < threshold {
				belowCount += 1
			}
		}
		return Double(belowCount) / Double(projections.count)
	}

	/// Calculates the probability that a metric will be above a threshold.
	///
	/// - Parameters:
	///   - threshold: The threshold value.
	///   - metric: A function that extracts the metric from a projection.
	///
	/// - Returns: Probability of being above threshold (0.0 to 1.0).
	///
	/// ## Example
	/// ```swift
	/// // Probability that net income exceeds $50,000
	/// let prob = simulation.probabilityAbove(50_000.0) { projection in
	///     let q1 = Period.quarter(year: 2025, quarter: 1)
	///     return projection.incomeStatement.netIncome[q1]!
	/// }
	/// ```
	public func probabilityAbove(
		_ threshold: Double,
		metric: (FinancialProjection) -> Double
	) -> Double {
		return 1.0 - probabilityBelow(threshold, metric: metric)
	}
}

// MARK: - Monte Carlo Simulation Function

/// Runs a Monte Carlo financial simulation with a scenario containing probabilistic drivers.
///
/// This function executes a scenario multiple times, sampling from probabilistic drivers
/// each time, to produce a distribution of possible outcomes. This enables probabilistic
/// forecasting and risk assessment.
///
/// - Parameters:
///   - scenario: The scenario to simulate (typically contains probabilistic drivers).
///   - entity: The entity (company) for the projections.
///   - periods: The time periods to project over.
///   - iterations: The number of Monte Carlo iterations to run (e.g., 1000, 10000).
///   - builder: A function that builds financial statements from drivers.
///
/// - Returns: A ``FinancialSimulation`` containing all projection results.
///
/// - Throws: Any errors from the builder function.
///
/// ## Example
/// ```swift
/// // Create scenario with uncertain drivers
/// let uncertainRevenue = ProbabilisticDriver(
///     name: "Revenue",
///     distribution: DistributionNormal(mean: 100_000.0, standardDeviation: 15_000.0)
/// )
///
/// let uncertainCosts = ProbabilisticDriver(
///     name: "Costs",
///     distribution: DistributionNormal(mean: 60_000.0, standardDeviation: 8_000.0)
/// )
///
/// var overrides: [String: AnyDriver<Double>] = [:]
/// overrides["Revenue"] = AnyDriver(uncertainRevenue)
/// overrides["Costs"] = AnyDriver(uncertainCosts)
///
/// let scenario = FinancialScenario(
///     name: "Uncertain Scenario",
///     description: "Revenue and costs with market uncertainty",
///     driverOverrides: overrides
/// )
///
/// // Run 10,000 Monte Carlo iterations
/// let simulation = try runFinancialSimulation(
///     scenario: scenario,
///     entity: entity,
///     periods: periods,
///     iterations: 10000,
///     builder: builder
/// )
///
/// // Analyze results
/// let q1 = Period.quarter(year: 2025, quarter: 1)
///
/// let meanIncome = simulation.mean { $0.incomeStatement.netIncome[q1]! }
/// let var95 = simulation.valueAtRisk(0.95) { $0.incomeStatement.netIncome[q1]! }
/// let probLoss = simulation.probabilityOfLoss { $0.incomeStatement.netIncome[q1]! }
///
/// print("Mean Net Income: \(meanIncome)")
/// print("VaR (95%): \(var95)")
/// print("Probability of Loss: \(probLoss * 100)%")
/// ```
///
/// ## Performance
/// Runs `iterations` complete projections. For typical models:
/// - 1,000 iterations: ~1-2 seconds
/// - 10,000 iterations: ~10-20 seconds
///
/// ## Algorithm
/// 1. Initialize empty array for projections
/// 2. For each iteration:
///    - Sample all probabilistic drivers (each call samples new values)
///    - Run ScenarioRunner with sampled drivers
///    - Collect the resulting projection
/// 3. Return FinancialSimulation with all projections
public func runFinancialSimulation(
	scenario: FinancialScenario,
	entity: Entity,
	periods: [Period],
	iterations: Int,
	builder: @escaping ScenarioRunner.StatementBuilder
) throws -> FinancialSimulation {
	let runner = ScenarioRunner()
	var projections: [FinancialProjection] = []
	projections.reserveCapacity(iterations)

	for _ in 0..<iterations {
		// Each iteration samples new values from probabilistic drivers
		let projection = try runner.run(
			scenario: scenario,
			entity: entity,
			periods: periods,
			builder: builder
		)

		projections.append(projection)
	}

	return FinancialSimulation(projections: projections)
}

//
//  SensitivityAnalysis.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/20/25.
//

import Foundation
import Numerics

/// Results of a one-way scenario sensitivity analysis showing how an output metric varies with a single input.
///
/// `ScenarioSensitivityAnalysis` captures the relationship between a single driver input and
/// a financial output metric in scenario-based projections. It's useful for understanding which
/// inputs have the greatest impact on outcomes and for creating sensitivity charts and tornado diagrams.
///
/// ## Creating Sensitivity Analysis
///
/// Sensitivity analyses are created using the ``runSensitivity(baseCase:entity:periods:inputDriver:inputRange:steps:builder:outputExtractor:)``
/// function, which varies a single driver across a range and measures the impact:
///
/// ```swift
/// let entity = Entity(id: "AAPL", primaryType: .ticker, name: "Apple Inc.")
/// let periods = Period.year(2025).quarters()
///
/// // Base case scenario
/// let baseRevenue = DeterministicDriver(name: "Revenue", value: 100_000.0)
/// var overrides: [String: AnyDriver<Double>] = [:]
/// overrides["Revenue"] = AnyDriver(baseRevenue)
///
/// let baseCase = FinancialScenario(
///     name: "Base Case",
///     description: "Expected scenario",
///     driverOverrides: overrides
/// )
///
/// // Run sensitivity on Revenue from 80K to 120K
/// let sensitivity = try runSensitivity(
///     baseCase: baseCase,
///     entity: entity,
///     periods: periods,
///     inputDriver: "Revenue",
///     inputRange: 80_000.0...120_000.0,
///     steps: 9,
///     builder: builder
/// ) { projection in
///     // Extract Q1 net income as output
///     let q1 = Period.quarter(year: 2025, quarter: 1)
///     return projection.incomeStatement.netIncome[q1]!
/// }
/// ```
///
/// ## Analyzing Results
///
/// Once created, you can analyze the input-output relationship:
///
/// ```swift
/// // View input values tested
/// print("Revenue values: \(sensitivity.inputValues)")
/// // Output: [80000, 85000, 90000, 95000, 100000, 105000, 110000, 115000, 120000]
///
/// // View corresponding outputs
/// print("Net income: \(sensitivity.outputValues)")
///
/// // Calculate sensitivity (slope)
/// let deltaOutput = sensitivity.outputValues.last! - sensitivity.outputValues.first!
/// let deltaInput = sensitivity.inputValues.last! - sensitivity.inputValues.first!
/// let elasticity = (deltaOutput / deltaInput) * 100  // % change in output per unit input
/// ```
///
/// ## Use Cases
///
/// ### Tornado Diagrams
/// Run sensitivity for multiple inputs, then rank by impact:
///
/// ```swift
/// let revenueSensitivity = try runSensitivity(...)  // Vary revenue ±20%
/// let costSensitivity = try runSensitivity(...)     // Vary costs ±20%
/// let priceSensitivity = try runSensitivity(...)    // Vary price ±20%
///
/// // Calculate impact ranges
/// let revenueImpact = revenueSensitivity.outputRange
/// let costImpact = costSensitivity.outputRange
/// let priceImpact = priceSensitivity.outputRange
///
/// // Rank by impact (largest first)
/// // Create tornado diagram visualization
/// ```
///
/// ### Breakeven Analysis
/// Find the input value where output crosses a threshold:
///
/// ```swift
/// // Find revenue needed for positive net income
/// if let breakeven = sensitivity.findInput(whereOutputEquals: 0.0) {
///     print("Breakeven revenue: \(breakeven)")
/// }
/// ```
///
/// ### Risk Assessment
/// Understand the range of possible outcomes:
///
/// ```swift
/// let worstCase = sensitivity.outputValues.min()!
/// let bestCase = sensitivity.outputValues.max()!
/// let baseCase = sensitivity.outputValues[sensitivity.inputValues.count / 2]
///
/// let downside = baseCase - worstCase
/// let upside = bestCase - baseCase
/// let asymmetry = upside / downside  // > 1 means more upside potential
/// ```
///
/// ## Design Principles
///
/// - **Immutability**: Results are value types and cannot be modified
/// - **Simplicity**: Single input, single output for clarity
/// - **Flexibility**: Output extractor allows any derived metric
/// - **Performance**: Results are pre-computed, not lazily evaluated
///
/// ## Topics
///
/// ### Properties
/// - ``inputDriver``
/// - ``inputValues``
/// - ``outputValues``
///
/// ### Convenience
/// - ``outputRange``
/// - ``count``
///
/// ### Related Types
/// - ``TwoWayScenarioSensitivityAnalysis``
/// - ``runSensitivity(baseCase:entity:periods:inputDriver:inputRange:steps:builder:outputExtractor:)``
/// - ``runTwoWaySensitivity(baseCase:entity:periods:inputDriver1:inputRange1:steps1:inputDriver2:inputRange2:steps2:builder:outputExtractor:)``
public struct ScenarioSensitivityAnalysis: Sendable {

	// MARK: - Properties

	/// The name of the driver being varied in this sensitivity analysis.
	///
	/// This corresponds to a key in the scenario's driver overrides dictionary.
	///
	/// ## Example
	/// ```swift
	/// if sensitivity.inputDriver == "Revenue" {
	///     print("Analyzing revenue sensitivity")
	/// }
	/// ```
	public let inputDriver: String

	/// The input values tested in the sensitivity analysis.
	///
	/// These are the values that the input driver was set to across the analysis.
	/// They are evenly spaced across the specified range.
	///
	/// ## Example
	/// ```swift
	/// print("Revenue values tested: \(sensitivity.inputValues)")
	/// // Output: [800.0, 900.0, 1000.0, 1100.0, 1200.0]
	/// ```
	public let inputValues: [Double]

	/// The output values corresponding to each input value.
	///
	/// For each input value in ``inputValues``, this contains the resulting
	/// output metric extracted from the financial projection. The arrays have
	/// the same length and are aligned by index.
	///
	/// ## Example
	/// ```swift
	/// for (input, output) in zip(sensitivity.inputValues, sensitivity.outputValues) {
	///     print("Revenue: \(input) → Net Income: \(output)")
	/// }
	/// ```
	public let outputValues: [Double]

	// MARK: - Initialization

	/// Creates a sensitivity analysis result.
	///
	/// - Parameters:
	///   - inputDriver: The name of the driver being varied.
	///   - inputValues: The input values tested (must not be empty).
	///   - outputValues: The output values (must match length of inputValues).
	///
	/// - Note: In typical usage, sensitivity analyses are created by
	///   ``runSensitivity(baseCase:entity:periods:inputDriver:inputRange:steps:builder:outputExtractor:)``
	///   rather than constructed manually.
	public init(
		inputDriver: String,
		inputValues: [Double],
		outputValues: [Double]
	) {
		self.inputDriver = inputDriver
		self.inputValues = inputValues
		self.outputValues = outputValues
	}
}

// MARK: - Convenience Methods

extension ScenarioSensitivityAnalysis {

	/// The number of data points in the sensitivity analysis.
	public var count: Int {
		return inputValues.count
	}

	/// The range of output values (max - min).
	///
	/// Useful for ranking sensitivities by their impact on the output.
	///
	/// ## Example
	/// ```swift
	/// let revenueRange = revenueSensitivity.outputRange
	/// let costRange = costSensitivity.outputRange
	///
	/// if revenueRange > costRange {
	///     print("Revenue has greater impact than costs")
	/// }
	/// ```
	public var outputRange: Double {
		guard let min = outputValues.min(),
			  let max = outputValues.max() else {
			return 0.0
		}
		return max - min
	}
}

// MARK: - Two-Way Sensitivity Analysis

/// Results of a two-way scenario sensitivity analysis showing how an output varies with two inputs.
///
/// `TwoWayScenarioSensitivityAnalysis` creates a data table showing the combined effect
/// of varying two drivers simultaneously in scenario-based projections. This is useful for
/// understanding interaction effects and creating scenario matrices.
///
/// ## Creating Two-Way Sensitivity
///
/// Two-way analyses are created using ``runTwoWaySensitivity(baseCase:entity:periods:inputDriver1:inputRange1:steps1:inputDriver2:inputRange2:steps2:builder:outputExtractor:)``:
///
/// ```swift
/// let sensitivity = try runTwoWaySensitivity(
///     baseCase: baseCase,
///     entity: entity,
///     periods: periods,
///     inputDriver1: "Revenue",
///     inputRange1: 80_000.0...120_000.0,
///     steps1: 5,
///     inputDriver2: "Costs",
///     inputRange2: 40_000.0...60_000.0,
///     steps2: 5,
///     builder: builder
/// ) { projection in
///     let q1 = Period.quarter(year: 2025, quarter: 1)
///     return projection.incomeStatement.netIncome[q1]!
/// }
/// ```
///
/// ## Analyzing Results
///
/// The results form a 2D grid where `results[i][j]` corresponds to
/// `inputValues1[i]` and `inputValues2[j]`:
///
/// ```swift
/// // Print data table
/// print("         ", terminator: "")
/// for cost in sensitivity.inputValues2 {
///     print(cost.number(0).paddingLeft(to: 10), terminator: "")
/// }
/// print()
///
/// for (i, revenue) in sensitivity.inputValues1.enumerated() {
///     print(revenue.number(0).paddingLeft(to: 8), terminator: "")
///     for j in 0..<sensitivity.inputValues2.count {
///         print(sensitivity.results[i][j].number(0).paddingLeft(to: 12)), terminator: "")
///     }	
///     print()
/// }
/// ```
///
/// ## Use Cases
///
/// - **Data Tables**: Create Excel-style data tables for scenario analysis
/// - **Interaction Effects**: Understand how two inputs combine
/// - **Optimization**: Find optimal combinations of two inputs
/// - **Risk Matrices**: Combine probability and impact dimensions
///
/// ## Topics
///
/// ### Properties
/// - ``inputDriver1``
/// - ``inputDriver2``
/// - ``inputValues1``
/// - ``inputValues2``
/// - ``results``
///
/// ### Related Types
/// - ``ScenarioSensitivityAnalysis``
/// - ``runTwoWaySensitivity(baseCase:entity:periods:inputDriver1:inputRange1:steps1:inputDriver2:inputRange2:steps2:builder:outputExtractor:)``
public struct TwoWayScenarioSensitivityAnalysis: Sendable {

	// MARK: - Properties

	/// The name of the first driver being varied (typically shown on rows).
	public let inputDriver1: String

	/// The name of the second driver being varied (typically shown on columns).
	public let inputDriver2: String

	/// The values tested for the first input driver.
	public let inputValues1: [Double]

	/// The values tested for the second input driver.
	public let inputValues2: [Double]

	/// The output results as a 2D array.
	///
	/// `results[i][j]` contains the output for `inputValues1[i]` and `inputValues2[j]`.
	///
	/// ## Example
	/// ```swift
	/// // Access specific combination
	/// let highRevenueLowCost = sensitivity.results[4][0]  // Last revenue, first cost
	/// let lowRevenueHighCost = sensitivity.results[0][4]  // First revenue, last cost
	/// ```
	public let results: [[Double]]

	// MARK: - Initialization

	/// Creates a two-way sensitivity analysis result.
	///
	/// - Parameters:
	///   - inputDriver1: The name of the first driver.
	///   - inputDriver2: The name of the second driver.
	///   - inputValues1: The first input values tested.
	///   - inputValues2: The second input values tested.
	///   - results: 2D array of outputs (results[i][j] for inputValues1[i], inputValues2[j]).
	///
	/// - Note: In typical usage, two-way analyses are created by
	///   ``runTwoWaySensitivity(baseCase:entity:periods:inputDriver1:inputRange1:steps1:inputDriver2:inputRange2:steps2:builder:outputExtractor:)``
	///   rather than constructed manually.
	public init(
		inputDriver1: String,
		inputDriver2: String,
		inputValues1: [Double],
		inputValues2: [Double],
		results: [[Double]]
	) {
		self.inputDriver1 = inputDriver1
		self.inputDriver2 = inputDriver2
		self.inputValues1 = inputValues1
		self.inputValues2 = inputValues2
		self.results = results
	}
}

// MARK: - Sensitivity Analysis Functions

/// Performs a one-way sensitivity analysis by varying a single input driver.
///
/// This function creates multiple scenarios by varying a single driver across a range,
/// runs each scenario, and collects the resulting output metric. The result shows
/// how the output changes as the input changes.
///
/// - Parameters:
///   - baseCase: The base scenario containing default driver values.
///   - entity: The entity (company) for the projections.
///   - periods: The time periods to project over.
///   - inputDriver: The name of the driver to vary (must exist in base case overrides).
///   - inputRange: The range of values to test for the input driver.
///   - steps: The number of evenly-spaced values to test (must be >= 1).
///   - builder: A function that builds financial statements from drivers.
///   - outputExtractor: A function that extracts the output metric from a projection.
///
/// - Returns: A ``ScenarioSensitivityAnalysis`` containing the input values tested and corresponding outputs.
///
/// - Throws: Any errors from the builder function.
///
/// ## Example
/// ```swift
/// let sensitivity = try runSensitivity(
///     baseCase: baseCase,
///     entity: entity,
///     periods: periods,
///     inputDriver: "Revenue",
///     inputRange: 80_000.0...120_000.0,
///     steps: 9,
///     builder: builder
/// ) { projection in
///     let q1 = Period.quarter(year: 2025, quarter: 1)
///     return projection.incomeStatement.netIncome[q1]!
/// }
///
/// print("Revenue sensitivity:")
/// for (input, output) in zip(sensitivity.inputValues, sensitivity.outputValues) {
///     print("  Revenue: \(input) → Net Income: \(output)")
/// }
/// ```
///
/// ## Algorithm
/// 1. Generate `steps` evenly-spaced values across `inputRange`
/// 2. For each input value:
///    - Create a new scenario with the input driver set to that value
///    - Run the scenario using `ScenarioRunner`
///    - Extract the output using `outputExtractor`
/// 3. Return the collected inputs and outputs
///
/// ## Performance
/// Runs `steps` complete scenario projections, so complexity is O(steps × projection_cost).
/// For typical use cases with 5-20 steps, this completes in under a second.
public func runSensitivity(
	baseCase: FinancialScenario,
	entity: Entity,
	periods: [Period],
	inputDriver: String,
	inputRange: ClosedRange<Double>,
	steps: Int,
	builder: @escaping ScenarioRunner.StatementBuilder,
	outputExtractor: @Sendable @escaping (FinancialProjection) -> Double
) throws -> ScenarioSensitivityAnalysis {
	guard steps >= 1 else {
		fatalError("Steps must be at least 1")
	}

	// Generate input values
	let inputValues = generateSteps(from: inputRange.lowerBound, to: inputRange.upperBound, steps: steps)

	// Run scenario for each input value
	let runner = ScenarioRunner()
	var outputValues: [Double] = []
	outputValues.reserveCapacity(steps)

	for inputValue in inputValues {
		// Create scenario with this input value (reuse base overrides)
		let driver = DeterministicDriver(name: inputDriver, value: inputValue)
		var overrides = baseCase.driverOverrides
		overrides[inputDriver] = AnyDriver(driver)

		// Optimization: use simple name (scenario name is rarely used in hot paths)
		let scenario = FinancialScenario(
			name: "Sensitivity",
			description: "Sensitivity analysis",
			driverOverrides: overrides,
			assumptions: baseCase.assumptions
		)

		// Run the scenario
		let projection = try runner.run(
			scenario: scenario,
			entity: entity,
			periods: periods,
			builder: builder
		)

		// Extract output
		let output = outputExtractor(projection)
		outputValues.append(output)
	}

	return ScenarioSensitivityAnalysis(
		inputDriver: inputDriver,
		inputValues: inputValues,
		outputValues: outputValues
	)
}

/// Performs a two-way sensitivity analysis by varying two input drivers simultaneously.
///
/// This function creates a grid of scenarios by varying two drivers, runs each combination,
/// and collects the resulting output metrics. The result is a data table showing how the
/// output changes with both inputs.
///
/// - Parameters:
///   - baseCase: The base scenario containing default driver values.
///   - entity: The entity (company) for the projections.
///   - periods: The time periods to project over.
///   - inputDriver1: The name of the first driver to vary.
///   - inputRange1: The range of values to test for the first driver.
///   - steps1: The number of values to test for the first driver.
///   - inputDriver2: The name of the second driver to vary.
///   - inputRange2: The range of values to test for the second driver.
///   - steps2: The number of values to test for the second driver.
///   - builder: A function that builds financial statements from drivers.
///   - outputExtractor: A function that extracts the output metric from a projection.
///
/// - Returns: A ``TwoWayScenarioSensitivityAnalysis`` containing the data table of results.
///
/// - Throws: Any errors from the builder function.
///
/// ## Example
/// ```swift
/// let sensitivity = try runTwoWaySensitivity(
///     baseCase: baseCase,
///     entity: entity,
///     periods: periods,
///     inputDriver1: "Revenue",
///     inputRange1: 80_000.0...120_000.0,
///     steps1: 5,
///     inputDriver2: "Costs",
///     inputRange2: 40_000.0...60_000.0,
///     steps2: 5,
///     builder: builder
/// ) { projection in
///     let q1 = Period.quarter(year: 2025, quarter: 1)
///     return projection.incomeStatement.netIncome[q1]!
/// }
///
/// // Print data table
/// for (i, revenue) in sensitivity.inputValues1.enumerated() {
///     for (j, cost) in sensitivity.inputValues2.enumerated() {
///         let netIncome = sensitivity.results[i][j]
///         print("Revenue: \(revenue), Cost: \(cost) → Net Income: \(netIncome)")
///     }
/// }
/// ```
///
/// ## Performance
/// Runs `steps1 × steps2` complete scenario projections. For a 5×5 grid, this is 25 projections.
/// Typical execution time is under 2 seconds for moderate complexity models.
public func runTwoWaySensitivity(
	baseCase: FinancialScenario,
	entity: Entity,
	periods: [Period],
	inputDriver1: String,
	inputRange1: ClosedRange<Double>,
	steps1: Int,
	inputDriver2: String,
	inputRange2: ClosedRange<Double>,
	steps2: Int,
	builder: @escaping ScenarioRunner.StatementBuilder,
	outputExtractor: @Sendable @escaping (FinancialProjection) -> Double
) throws -> TwoWayScenarioSensitivityAnalysis {
	guard steps1 >= 1, steps2 >= 1 else {
		fatalError("Steps must be at least 1 for both dimensions")
	}

	// Generate input values
	let inputValues1 = generateSteps(from: inputRange1.lowerBound, to: inputRange1.upperBound, steps: steps1)
	let inputValues2 = generateSteps(from: inputRange2.lowerBound, to: inputRange2.upperBound, steps: steps2)

	// Run scenario for each combination
	let runner = ScenarioRunner()
	var results: [[Double]] = Array(repeating: Array(repeating: 0.0, count: steps2), count: steps1)

	for (i, inputValue1) in inputValues1.enumerated() {
		for (j, inputValue2) in inputValues2.enumerated() {
			// Create scenario with both input values
			let driver1 = DeterministicDriver(name: inputDriver1, value: inputValue1)
			let driver2 = DeterministicDriver(name: inputDriver2, value: inputValue2)
			var overrides = baseCase.driverOverrides
			overrides[inputDriver1] = AnyDriver(driver1)
			overrides[inputDriver2] = AnyDriver(driver2)

			// Optimization: use simple name (reduces string allocation overhead)
			let scenario = FinancialScenario(
				name: "Two-way sensitivity",
				description: "Two-way sensitivity",
				driverOverrides: overrides,
				assumptions: baseCase.assumptions
			)

			// Run the scenario
			let projection = try runner.run(
				scenario: scenario,
				entity: entity,
				periods: periods,
				builder: builder
			)

			// Extract output
			let output = outputExtractor(projection)
			results[i][j] = output
		}
	}

	return TwoWayScenarioSensitivityAnalysis(
		inputDriver1: inputDriver1,
		inputDriver2: inputDriver2,
		inputValues1: inputValues1,
		inputValues2: inputValues2,
		results: results
	)
}

// MARK: - Tornado Diagram Analysis

/// Results of a tornado diagram analysis showing relative impact of multiple inputs.
///
/// `TornadoDiagramAnalysis` ranks input drivers by their impact on an output metric,
/// making it easy to identify which inputs have the greatest influence on outcomes.
/// This is the classic "tornado chart" used in sensitivity analysis.
///
/// ## Creating Tornado Diagrams
///
/// Tornado diagrams are created using ``runTornadoAnalysis(baseCase:entity:periods:inputDrivers:variationPercent:steps:builder:outputExtractor:)``:
///
/// ```swift
/// let tornado = try runTornadoAnalysis(
///     baseCase: baseCase,
///     entity: entity,
///     periods: periods,
///     inputDrivers: ["Revenue", "Costs", "OpEx", "Tax Rate"],
///     variationPercent: 0.20,  // ±20%
///     steps: 2,  // Just low and high
///     builder: builder
/// ) { projection in
///     let q1 = Period.quarter(year: 2025, quarter: 1)
///     return projection.incomeStatement.netIncome[q1]!
/// }
/// ```
///
/// ## Interpreting Results
///
/// Inputs are ranked by impact (largest first):
///
/// ```swift
/// print("Tornado Diagram - Ranked by Impact:")
/// for input in tornado.inputs {
///     let impact = tornado.impacts[input]!
///     let low = tornado.lowValues[input]!
///     let high = tornado.highValues[input]!
///     print("\(input): \(low) to \(high) (range: \(impact))")
/// }
/// ```
///
/// ## Visualization
///
/// The data is structured for easy charting. Use `plotTornadoDiagram(_:)` for command-line visualization:
///
/// ```swift
/// let plot = plotTornadoDiagram(tornado)
/// print(plot)
///
/// // Output:
/// // Tornado Diagram - Sensitivity Analysis
/// // Base Case: 1,000.00
/// //
/// // Revenue    ◄████████████████████████████►     Impact: 500.00 (50.0%)
/// //            750                     1000                 1250
/// //
/// // Costs      ◄████████████████►                 Impact: 300.00 (30.0%)
/// //            850            1000        1150
/// ```
///
/// ## Topics
///
/// ### Properties
/// - ``inputs``
/// - ``impacts``
/// - ``lowValues``
/// - ``highValues``
/// - ``baseCaseOutput``
///
/// ### Related Types
/// - ``runTornadoAnalysis(baseCase:entity:periods:inputDrivers:variationPercent:steps:builder:outputExtractor:)``
/// - ``ScenarioSensitivityAnalysis``
public struct TornadoDiagramAnalysis: Sendable {

	// MARK: - Properties

	/// Input drivers ranked by their impact (descending order).
	///
	/// The first input has the greatest impact, the last has the least.
	///
	/// ## Example
	/// ```swift
	/// print("Top 3 drivers:")
	/// for input in tornado.inputs.prefix(3) {
	///     print("- \(input): \(tornado.impacts[input]!)")
	/// }
	/// ```
	public let inputs: [String]

	/// Impact (output range) for each input.
	///
	/// Impact is calculated as the difference between the highest and lowest
	/// output values when the input is varied.
	///
	/// ## Example
	/// ```swift
	/// for input in tornado.inputs {
	///     let impact = tornado.impacts[input]!
	///     let percentImpact = (impact / tornado.baseCaseOutput) * 100.0
	///     print("\(input): \(percentImpact)% swing")
	/// }
	/// ```
	public let impacts: [String: Double]

	/// Low output value for each input (when input is at its low value).
	///
	/// For each input, this is the output when the input is decreased by
	/// the variation percentage.
	public let lowValues: [String: Double]

	/// High output value for each input (when input is at its high value).
	///
	/// For each input, this is the output when the input is increased by
	/// the variation percentage.
	public let highValues: [String: Double]

	/// The base case output value.
	///
	/// This is the output with all inputs at their base case values.
	public let baseCaseOutput: Double

	// MARK: - Initialization

	/// Creates a tornado diagram analysis result.
	///
	/// - Parameters:
	///   - inputs: Input drivers ranked by impact (descending).
	///   - impacts: Impact (range) for each input.
	///   - lowValues: Low output values.
	///   - highValues: High output values.
	///   - baseCaseOutput: Base case output value.
	///
	/// - Note: In typical usage, tornado diagrams are created by
	///   ``runTornadoAnalysis(baseCase:entity:periods:inputDrivers:variationPercent:steps:builder:outputExtractor:)``
	///   rather than constructed manually.
	public init(
		inputs: [String],
		impacts: [String: Double],
		lowValues: [String: Double],
		highValues: [String: Double],
		baseCaseOutput: Double
	) {
		self.inputs = inputs
		self.impacts = impacts
		self.lowValues = lowValues
		self.highValues = highValues
		self.baseCaseOutput = baseCaseOutput
	}
}

/// Performs tornado diagram analysis by varying multiple inputs and ranking by impact.
///
/// This function runs sensitivity analysis on each input driver, varying them by a
/// fixed percentage, then ranks the inputs by their impact on the output metric.
///
/// - Parameters:
///   - baseCase: The base scenario containing default driver values.
///   - entity: The entity (company) for the projections.
///   - periods: The time periods to project over.
///   - inputDrivers: Names of the drivers to analyze (must exist in base case).
///   - variationPercent: The percentage to vary each input (e.g., 0.20 for ±20%).
///   - steps: Number of steps for sensitivity analysis (2 = just low/high, 3+ = including intermediate).
///   - builder: A function that builds financial statements from drivers.
///   - outputExtractor: A function that extracts the output metric from a projection.
///
/// - Returns: A ``TornadoDiagramAnalysis`` with inputs ranked by impact.
///
/// - Throws: Any errors from the builder function.
///
/// ## Example
/// ```swift
/// let tornado = try runTornadoAnalysis(
///     baseCase: baseCase,
///     entity: entity,
///     periods: periods,
///     inputDrivers: ["Revenue", "Costs", "Marketing", "Tax Rate"],
///     variationPercent: 0.20,  // Vary each by ±20%
///     steps: 2,  // Just evaluate at low (-20%) and high (+20%)
///     builder: builder
/// ) { projection in
///     let q1 = Period.quarter(year: 2025, quarter: 1)
///     return projection.incomeStatement.netIncome[q1]!
/// }
///
/// print("Most impactful driver: \(tornado.inputs.first!)")
/// print("Impact: \(tornado.impacts[tornado.inputs.first!]!)")
/// ```
///
/// ## Algorithm
/// 1. Calculate base case output
/// 2. For each input driver:
///    - Run sensitivity analysis varying it by ±variationPercent
///    - Record low and high output values
///    - Calculate impact (high - low)
/// 3. Rank inputs by impact (descending)
/// 4. Return structured results
///
/// ## Performance
/// Runs sensitivity analysis for each input, so complexity is O(inputs × steps × projection_cost).
/// For 5 inputs with 2 steps each, this is 10 projections plus the base case.
public func runTornadoAnalysis(
	baseCase: FinancialScenario,
	entity: Entity,
	periods: [Period],
	inputDrivers: [String],
	variationPercent: Double,
	steps: Int,
	builder: @escaping ScenarioRunner.StatementBuilder,
	outputExtractor: @Sendable @escaping (FinancialProjection) -> Double
) throws -> TornadoDiagramAnalysis {
	// Run base case to get baseline output
	let runner = ScenarioRunner()
	let baseProjection = try runner.run(
		scenario: baseCase,
		entity: entity,
		periods: periods,
		builder: builder
	)
	let baseCaseOutput = outputExtractor(baseProjection)

	// Run sensitivity analysis for each input
	var impacts: [String: Double] = [:]
	var lowValues: [String: Double] = [:]
	var highValues: [String: Double] = [:]

	for inputDriver in inputDrivers {
		// Get base value for this input
		guard let baseDriverAny = baseCase.driverOverrides[inputDriver] else {
			continue
		}
		let baseValue = baseDriverAny.sample(for: periods[0])

		// Calculate low and high values
		let lowValue = baseValue * (1.0 - variationPercent)
		let highValue = baseValue * (1.0 + variationPercent)

		// Run sensitivity
		let sensitivity = try runSensitivity(
			baseCase: baseCase,
			entity: entity,
			periods: periods,
			inputDriver: inputDriver,
			inputRange: lowValue...highValue,
			steps: steps,
			builder: builder,
			outputExtractor: outputExtractor
		)

		// Record low and high outputs
		let outputLow = sensitivity.outputValues.min() ?? baseCaseOutput
		let outputHigh = sensitivity.outputValues.max() ?? baseCaseOutput

		lowValues[inputDriver] = outputLow
		highValues[inputDriver] = outputHigh
		impacts[inputDriver] = outputHigh - outputLow
	}

	// Rank inputs by impact (descending)
	let rankedInputs = inputDrivers.sorted { input1, input2 in
		let impact1 = impacts[input1] ?? 0.0
		let impact2 = impacts[input2] ?? 0.0
		return impact1 > impact2
	}

	return TornadoDiagramAnalysis(
		inputs: rankedInputs,
		impacts: impacts,
		lowValues: lowValues,
		highValues: highValues,
		baseCaseOutput: baseCaseOutput
	)
}

// MARK: - Helper Functions

/// Generates evenly-spaced values between two endpoints.
///
/// - Parameters:
///   - from: The start value (inclusive).
///   - to: The end value (inclusive).
///   - steps: The number of values to generate (must be >= 1).
///
/// - Returns: An array of `steps` evenly-spaced values.
///
/// ## Example
/// ```swift
/// let values = generateSteps(from: 0.0, to: 100.0, steps: 5)
/// // Result: [0.0, 25.0, 50.0, 75.0, 100.0]
/// ```
@inline(__always)
private func generateSteps(from: Double, to: Double, steps: Int) -> [Double] {
	guard steps > 1 else {
		return [from]
	}

	// Optimization: pre-allocate array and fill directly (faster than map)
	var result = [Double]()
	result.reserveCapacity(steps)

	let stepSize = (to - from) / Double(steps - 1)
	for i in 0..<steps {
		result.append(from + Double(i) * stepSize)
	}

	return result
}

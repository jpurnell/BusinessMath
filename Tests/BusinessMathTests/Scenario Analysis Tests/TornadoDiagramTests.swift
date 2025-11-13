//
//  TornadoDiagramTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/20/25.
//

import Testing
import Numerics
import OSLog
@testable import BusinessMath

@Suite("Tornado Diagram Tests")
struct TornadoDiagramTests {
	let logger = Logger(subsystem: "\(#file)", category: "\(#function)")
	// MARK: - Test Helpers

	private func createTestEntity() -> Entity {
		return Entity(id: "TEST", primaryType: .ticker, name: "Test Company")
	}

	private func createTestPeriods() -> [Period] {
		return [
			Period.quarter(year: 2025, quarter: 1),
			Period.quarter(year: 2025, quarter: 2),
			Period.quarter(year: 2025, quarter: 3),
			Period.quarter(year: 2025, quarter: 4)
		]
	}

	/// Helper to create a builder that uses revenue, cost, and volume drivers
	private func createMultiDriverBuilder(
		entity: Entity,
		periods: [Period]
	) -> ScenarioRunner.StatementBuilder {
		return { drivers, periods in
			// Sample all drivers
			let revenuePerUnit = drivers["Price"]?.sample(for: periods[0]) ?? 100.0
			let volumeValue = drivers["Volume"]?.sample(for: periods[0]) ?? 1000.0
			let costPerUnit = drivers["Cost"]?.sample(for: periods[0]) ?? 60.0

			// Calculate revenue and costs
			let revenue = revenuePerUnit * volumeValue
			let costs = costPerUnit * volumeValue

			// Create time series (same value for all periods in this simple model)
			let revenueValues = Array(repeating: revenue, count: periods.count)
			let costValues = Array(repeating: costs, count: periods.count)

			let revenueSeries = TimeSeries<Double>(periods: periods, values: revenueValues)
			let costSeries = TimeSeries<Double>(periods: periods, values: costValues)

			let revenueAccount = try Account(entity: entity, name: "Revenue", type: .revenue, timeSeries: revenueSeries)
			let costAccount = try Account(entity: entity, name: "Costs", type: .expense, timeSeries: costSeries)

			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: periods,
				revenueAccounts: [revenueAccount],
				expenseAccounts: [costAccount]
			)

			// Minimal balance sheet
			let netIncome = incomeStatement.netIncome
			let assetAccount = try Account(entity: entity, name: "Cash", type: .asset, timeSeries: netIncome)
			let equityAccount = try Account(entity: entity, name: "Equity", type: .equity, timeSeries: netIncome)
			let balanceSheet = try BalanceSheet(
				entity: entity,
				periods: periods,
				assetAccounts: [assetAccount],
				liabilityAccounts: [],
				equityAccounts: [equityAccount]
			)

			// Minimal cash flow
			let cashAccount = try Account(entity: entity, name: "Operating Cash", type: .operating, timeSeries: netIncome)
			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				operatingAccounts: [cashAccount],
				investingAccounts: [],
				financingAccounts: []
			)

			return (incomeStatement, balanceSheet, cashFlowStatement)
		}
	}

	// MARK: - Basic Tornado Diagram Tests

	@Test("Tornado diagram with multiple inputs")
	func tornadoDiagramBasic() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		// Create base case with three drivers
		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Price"] = AnyDriver(DeterministicDriver(name: "Price", value: 100.0))
		baseOverrides["Volume"] = AnyDriver(DeterministicDriver(name: "Volume", value: 1000.0))
		baseOverrides["Cost"] = AnyDriver(DeterministicDriver(name: "Cost", value: 60.0))

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base scenario",
			driverOverrides: baseOverrides
		)

		let builder = createMultiDriverBuilder(entity: entity, periods: periods)

		// Run tornado analysis varying each input by ±20%
		let tornado = try runTornadoAnalysis(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDrivers: ["Price", "Volume", "Cost"],
			variationPercent: 0.20,
			steps: 3,
			builder: builder
		) { projection in
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}
		let plot = plotTornadoDiagram(tornado)
//		logger.info("Tornado diagram - Basic Test:\n\n\(plot)")

		// Verify structure
		#expect(tornado.inputs.count == 3)
		#expect(tornado.inputs.contains("Price"))
		#expect(tornado.inputs.contains("Volume"))
		#expect(tornado.inputs.contains("Cost"))

		// Verify inputs are ranked by impact (descending)
		for i in 0..<(tornado.inputs.count - 1) {
			let currentImpact = tornado.impacts[tornado.inputs[i]]!
			let nextImpact = tornado.impacts[tornado.inputs[i + 1]]!
			#expect(currentImpact >= nextImpact)
		}
	}

	@Test("Tornado diagram ranks inputs correctly")
	func tornadoDiagramRanking() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		// Create scenario where Volume has biggest impact, then Price, then Cost
		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Price"] = AnyDriver(DeterministicDriver(name: "Price", value: 100.0))
		baseOverrides["Volume"] = AnyDriver(DeterministicDriver(name: "Volume", value: 1000.0))
		baseOverrides["Cost"] = AnyDriver(DeterministicDriver(name: "Cost", value: 60.0))

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base scenario",
			driverOverrides: baseOverrides
		)

		let builder = createMultiDriverBuilder(entity: entity, periods: periods)

		let tornado = try runTornadoAnalysis(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDrivers: ["Price", "Volume", "Cost"],
			variationPercent: 0.20,
			steps: 5,
			builder: builder
		) { projection in
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}
		
		let plot = plotTornadoDiagram(tornado)
//		logger.info("Tornado diagram - Diagram Ranking:\n\n\(plot)")

		// In this model: NetIncome = Price * Volume - Cost * Volume
		// NetIncome = Volume * (Price - Cost)
		// So Volume should have the largest impact, then Price and Cost should be equal

		// Get the top input (should be Volume)
		let topInput = tornado.inputs.first!
		#expect(topInput == "Volume" || topInput == "Price")

		// Verify impacts are positive (ranges are positive)
		for input in tornado.inputs {
			let impact = tornado.impacts[input]!
			#expect(impact > 0.0)
		}
	}

	@Test("Tornado diagram with low and high values")
	func tornadoDiagramLowHighValues() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Price"] = AnyDriver(DeterministicDriver(name: "Price", value: 100.0))
		baseOverrides["Volume"] = AnyDriver(DeterministicDriver(name: "Volume", value: 1000.0))
		baseOverrides["Cost"] = AnyDriver(DeterministicDriver(name: "Cost", value: 60.0))

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base scenario",
			driverOverrides: baseOverrides
		)

		let builder = createMultiDriverBuilder(entity: entity, periods: periods)

		let tornado = try runTornadoAnalysis(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDrivers: ["Price", "Volume", "Cost"],
			variationPercent: 0.20,
			steps: 2,  // Just low and high
			builder: builder
		) { projection in
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}
		
		let plot = plotTornadoDiagram(tornado)
//		logger.info("Tornado diagram - Low/High Values Test:\n\n\(plot)")

		// Verify we have low and high values for each input
		for input in tornado.inputs {
			let lowValue = tornado.lowValues[input]!
			let highValue = tornado.highValues[input]!
			#expect(lowValue < highValue)

			// Low should be about 80% of base, high should be about 120% of base
			// (given 20% variation)
		}
	}

	@Test("Tornado diagram with single input")
	func tornadoDiagramSingleInput() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Price"] = AnyDriver(DeterministicDriver(name: "Price", value: 100.0))
		baseOverrides["Volume"] = AnyDriver(DeterministicDriver(name: "Volume", value: 1000.0))
		baseOverrides["Cost"] = AnyDriver(DeterministicDriver(name: "Cost", value: 60.0))

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base scenario",
			driverOverrides: baseOverrides
		)

		let builder = createMultiDriverBuilder(entity: entity, periods: periods)

		// Test with just one input
		let tornado = try runTornadoAnalysis(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDrivers: ["Price"],
			variationPercent: 0.15,
			steps: 3,
			builder: builder
		) { projection in
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}
		
		let plot = plotTornadoDiagram(tornado)
//		logger.info("Tornado diagram - Single Inputs Test:\n\n\(plot)")

		#expect(tornado.inputs.count == 1)
		#expect(tornado.inputs.first == "Price")
		#expect(tornado.impacts["Price"]! > 0.0)
	}

	@Test("Tornado diagram with different variation percentages")
	func tornadoDiagramDifferentVariations() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Price"] = AnyDriver(DeterministicDriver(name: "Price", value: 100.0))
		baseOverrides["Volume"] = AnyDriver(DeterministicDriver(name: "Volume", value: 1000.0))
		baseOverrides["Cost"] = AnyDriver(DeterministicDriver(name: "Cost", value: 60.0))

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base scenario",
			driverOverrides: baseOverrides
		)

		let builder = createMultiDriverBuilder(entity: entity, periods: periods)

		// Test with 10% variation
		let tornado10 = try runTornadoAnalysis(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDrivers: ["Price", "Volume"],
			variationPercent: 0.10,
			steps: 2,
			builder: builder
		) { projection in
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}
		
		let plot10 = plotTornadoDiagram(tornado10)
//		logger.info("Tornado diagram - 10% Variation:\n\n\(plot10)")

		// Test with 30% variation
		let tornado30 = try runTornadoAnalysis(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDrivers: ["Price", "Volume"],
			variationPercent: 0.30,
			steps: 2,
			builder: builder
		) { projection in
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}

		
		let plot30 = plotTornadoDiagram(tornado30)
//		logger.info("Tornado diagram - 30% Variation:\n\n\(plot30)")
		
		// Larger variation should produce larger impacts
		let price10Impact = tornado10.impacts["Price"]!
		let price30Impact = tornado30.impacts["Price"]!
		#expect(price30Impact > price10Impact)

		let volume10Impact = tornado10.impacts["Volume"]!
		let volume30Impact = tornado30.impacts["Volume"]!
		#expect(volume30Impact > volume10Impact)
	}

	@Test("Tornado diagram preserves base case value")
	func tornadoDiagramBaseCase() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Price"] = AnyDriver(DeterministicDriver(name: "Price", value: 100.0))
		baseOverrides["Volume"] = AnyDriver(DeterministicDriver(name: "Volume", value: 1000.0))
		baseOverrides["Cost"] = AnyDriver(DeterministicDriver(name: "Cost", value: 60.0))

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base scenario",
			driverOverrides: baseOverrides
		)

		let builder = createMultiDriverBuilder(entity: entity, periods: periods)

		let tornado = try runTornadoAnalysis(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDrivers: ["Price", "Volume", "Cost"],
			variationPercent: 0.20,
			steps: 3,
			builder: builder
		) { projection in
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}
		
		let plot = plotTornadoDiagram(tornado)
//		logger.info("Tornado diagram - Base Case Test:\n\n\(plot)")

		// Verify base case value is stored
		#expect(tornado.baseCaseOutput > 0.0)

		// For each input, base case should be between low and high
		for input in tornado.inputs {
			let low = tornado.lowValues[input]!
			let high = tornado.highValues[input]!
			#expect(low <= tornado.baseCaseOutput)
			#expect(tornado.baseCaseOutput <= high)
		}
	}

	// MARK: - Edge Cases

	@Test("Tornado diagram with zero variation")
	func tornadoDiagramZeroVariation() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Price"] = AnyDriver(DeterministicDriver(name: "Price", value: 100.0))
		baseOverrides["Volume"] = AnyDriver(DeterministicDriver(name: "Volume", value: 1000.0))

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base scenario",
			driverOverrides: baseOverrides
		)

		let builder = createMultiDriverBuilder(entity: entity, periods: periods)

		// 0% variation means all values are the same
		let tornado = try runTornadoAnalysis(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDrivers: ["Price"],
			variationPercent: 0.0,
			steps: 3,
			builder: builder
		) { projection in
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}
		
		let plot = plotTornadoDiagram(tornado)
//		logger.info("Tornado diagram - Zero Variation:\n\n\(plot)")

		// Impact should be zero (no variation)
		#expect(tornado.impacts["Price"]! == 0.0)
	}

	@Test("Tornado diagram with many inputs")
	func tornadoDiagramManyInputs() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		// Create 5 different drivers
		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Price"] = AnyDriver(DeterministicDriver(name: "Price", value: 100.0))
		baseOverrides["Volume"] = AnyDriver(DeterministicDriver(name: "Volume", value: 1000.0))
		baseOverrides["Cost"] = AnyDriver(DeterministicDriver(name: "Cost", value: 60.0))
		baseOverrides["OpEx"] = AnyDriver(DeterministicDriver(name: "OpEx", value: 10000.0))
		baseOverrides["Tax Rate"] = AnyDriver(DeterministicDriver(name: "Tax Rate", value: 0.25))

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base scenario",
			driverOverrides: baseOverrides
		)

		// Extended builder that uses all drivers
		let builder: ScenarioRunner.StatementBuilder = { drivers, periods in
			let price = drivers["Price"]?.sample(for: periods[0]) ?? 100.0
			let volume = drivers["Volume"]?.sample(for: periods[0]) ?? 1000.0
			let cost = drivers["Cost"]?.sample(for: periods[0]) ?? 60.0
			let opex = drivers["OpEx"]?.sample(for: periods[0]) ?? 10000.0
			let taxRate = drivers["Tax Rate"]?.sample(for: periods[0]) ?? 0.25

			let revenue = price * volume
			let cogs = cost * volume
			let netBeforeTax = revenue - cogs - opex
			let netAfterTax = netBeforeTax * (1.0 - taxRate)

			let revenueValues = Array(repeating: revenue, count: periods.count)
			let cogsValues = Array(repeating: cogs, count: periods.count)
			let opexValues = Array(repeating: opex, count: periods.count)
			let netValues = Array(repeating: netAfterTax, count: periods.count)

			let revenueSeries = TimeSeries<Double>(periods: periods, values: revenueValues)
			let cogsSeries = TimeSeries<Double>(periods: periods, values: cogsValues)
			let opexSeries = TimeSeries<Double>(periods: periods, values: opexValues)
			let netSeries = TimeSeries<Double>(periods: periods, values: netValues)

			let revenueAccount = try Account(entity: entity, name: "Revenue", type: .revenue, timeSeries: revenueSeries)
			let cogsAccount = try Account(entity: entity, name: "COGS", type: .expense, timeSeries: cogsSeries)
			let opexAccount = try Account(entity: entity, name: "OpEx", type: .expense, timeSeries: opexSeries)

			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: periods,
				revenueAccounts: [revenueAccount],
				expenseAccounts: [cogsAccount, opexAccount]
			)

			let assetAccount = try Account(entity: entity, name: "Cash", type: .asset, timeSeries: netSeries)
			let equityAccount = try Account(entity: entity, name: "Equity", type: .equity, timeSeries: netSeries)
			let balanceSheet = try BalanceSheet(
				entity: entity,
				periods: periods,
				assetAccounts: [assetAccount],
				liabilityAccounts: [],
				equityAccounts: [equityAccount]
			)

			let cashAccount = try Account(entity: entity, name: "Operating Cash", type: .operating, timeSeries: netSeries)
			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				operatingAccounts: [cashAccount],
				investingAccounts: [],
				financingAccounts: []
			)

			return (incomeStatement, balanceSheet, cashFlowStatement)
		}

		let tornado = try runTornadoAnalysis(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDrivers: ["Price", "Volume", "Cost", "OpEx", "Tax Rate"],
			variationPercent: 0.20,
			steps: 3,
			builder: builder
		) { projection in
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}
		let plot = plotTornadoDiagram(tornado)
//		logger.info("Tornado diagram - Many Inputs Test:\n\n\(plot)")

		// Should have all 5 inputs ranked
		#expect(tornado.inputs.count == 5)

		// All impacts should be non-negative (Tax Rate won't affect net income since we're extracting from income statement, not after-tax calculation)
		for input in tornado.inputs {
			#expect(tornado.impacts[input]! >= 0.0)
		}

		// Price, Volume, Cost, and OpEx should have positive impacts
		#expect(tornado.impacts["Price"]! > 0.0)
		#expect(tornado.impacts["Volume"]! > 0.0)
		#expect(tornado.impacts["Cost"]! > 0.0)
		#expect(tornado.impacts["OpEx"]! > 0.0)

		// Verify ranking is correct (descending order)
		for i in 0..<(tornado.inputs.count - 1) {
			let currentImpact = tornado.impacts[tornado.inputs[i]]!
			let nextImpact = tornado.impacts[tornado.inputs[i + 1]]!
			#expect(currentImpact >= nextImpact)
		}
	}
}

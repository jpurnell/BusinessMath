import Testing
import Foundation
@testable import BusinessMath

@Suite("Model Validator Tests")
struct ModelValidatorTests {

	// MARK: - Helper Functions

	func makeValidProjection() throws -> FinancialProjection {
		let entity = Entity(id: "TEST", primaryType: .ticker, name: "Test Co")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 110_000.0])
		)

		let cogs = try Account(
			entity: entity,
			name: "COGS",
			type: .expense,
			timeSeries: TimeSeries(periods: periods, values: [60_000.0, 65_000.0]),
			expenseType: .costOfGoodsSold
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs]
		)

		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 110_000.0]),
			assetType: .cashAndEquivalents
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 110_000.0]),
			equityType: .commonStock
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [],
			equityAccounts: [equity]
		)

		// Create operating cash flow accounts
		let operatingCF = try Account(
			entity: entity,
			name: "Operating Cash Flow",
			type: .operating,
			timeSeries: TimeSeries(periods: periods, values: [40_000.0, 45_000.0])
		)

		let cashFlowStatement = try CashFlowStatement<Double>(
			entity: entity,
			periods: periods,
			operatingAccounts: [operatingCF],
			investingAccounts: [],
			financingAccounts: []
		)

		// Create a scenario
		let scenario = FinancialScenario(
			name: "Test Scenario",
			description: "Test scenario for validation"
		)

		return FinancialProjection(
			scenario: scenario,
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement
		)
	}

	// MARK: - Validation Tests

	@Test("Validate valid financial projection")
	func validateValidProjection() throws {
		let projection = try makeValidProjection()
		let validator = ModelValidator<Double>()

		let report = validator.validate(projection: projection)

		#expect(report.isValid)
		#expect(report.errors.isEmpty)
		#expect(report.summary.contains("✅"))
	}

	@Test("Validation report with warnings")
	func validationWithWarnings() throws {
		// Create projection with unusual but valid values
		let entity = Entity(id: "TEST", primaryType: .ticker, name: "Test Co")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		// Very high gross margin (95%) - unusual but valid
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0])
		)

		let cogs = try Account(
			entity: entity,
			name: "COGS",
			type: .expense,
			timeSeries: TimeSeries(periods: periods, values: [5_000.0]),
			expenseType: .costOfGoodsSold
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs]
		)

		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0]),
			assetType: .cashAndEquivalents
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0]),
			equityType: .commonStock
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [],
			equityAccounts: [equity]
		)

		let operatingCF = try Account(
			entity: entity,
			name: "Operating Cash Flow",
			type: .operating,
			timeSeries: TimeSeries(periods: periods, values: [95_000.0])
		)

		let cashFlowStatement = try CashFlowStatement<Double>(
			entity: entity,
			periods: periods,
			operatingAccounts: [operatingCF],
			investingAccounts: [],
			financingAccounts: []
		)

		let scenario = FinancialScenario(
			name: "Warning Test Scenario",
			description: "Test scenario with warnings"
		)

		let projection = FinancialProjection(
			scenario: scenario,
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement
		)

		let validator = ModelValidator<Double>()
		let report = validator.validate(projection: projection)

		#expect(report.isValid)
		#expect(report.warnings.count > 0)
		#expect(report.summary.contains("⚠️"))
	}

	@Test("Validation fails with errors")
	func validationWithErrors() throws {
		let entity = Entity(id: "TEST", primaryType: .ticker, name: "Test Co")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		// Negative revenue - should fail
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [-100_000.0])
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: []
		)

		// Unbalanced balance sheet
		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0]),
			assetType: .cashAndEquivalents
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: periods, values: [90_000.0]),  // Should be 100k
			equityType: .commonStock
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [],
			equityAccounts: [equity]
		)

		let operatingCF = try Account(
			entity: entity,
			name: "Operating Cash Flow",
			type: .operating,
			timeSeries: TimeSeries(periods: periods, values: [-100_000.0])
		)

		let cashFlowStatement = try CashFlowStatement<Double>(
			entity: entity,
			periods: periods,
			operatingAccounts: [operatingCF],
			investingAccounts: [],
			financingAccounts: []
		)

		let scenario = FinancialScenario(
			name: "Error Test Scenario",
			description: "Test scenario with errors"
		)

		let projection = FinancialProjection(
			scenario: scenario,
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement
		)

		let validator = ModelValidator<Double>()
		let report = validator.validate(projection: projection)

		#expect(!report.isValid)
		#expect(report.errors.count > 0)
		#expect(report.summary.contains("❌"))
	}

	@Test("Detailed report format")
	func detailedReport() throws {
		let projection = try makeValidProjection()
		let validator = ModelValidator<Double>()

		let report = validator.validate(projection: projection)
		let detailedReport = report.detailedReport

		#expect(detailedReport.contains("Validation"))
		// Should contain summary and timestamp
	}

	@Test("Custom validation rules")
	func customValidationRules() throws {
		struct MinimumRevenueRule: FinancialValidationRule {
			let minimumRevenue: Double

			func validate(_ projection: FinancialProjection) -> ValidationResult {
				for period in projection.incomeStatement.periods {
					let revenue = projection.incomeStatement.totalRevenue[period] ?? 0
					if revenue < minimumRevenue {
						return .invalid([ValidationError(
							field: "Revenue",
							value: revenue,
							rule: "MinimumRevenue",
							message: "Revenue below minimum threshold of \(minimumRevenue)",
							suggestion: "Verify revenue projections"
						)])
					}
				}
				return .valid
			}
		}

		let projection = try makeValidProjection()
		let customRule = MinimumRevenueRule(minimumRevenue: 50_000)

		let validator = ModelValidator<Double>(financialRules: [customRule])
		let report = validator.validate(projection: projection)

		#expect(report.isValid)
	}
}

@Suite("Model Validator - Additional Tests")
struct ModelValidatorAdditionalTests {
	
	func makeValidProjection() throws -> FinancialProjection {
		let entity = Entity(id: "TEST", primaryType: .ticker, name: "Test Co")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]
		
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 110_000.0])
		)
		let cogs = try Account(
			entity: entity,
			name: "COGS",
			type: .expense,
			timeSeries: TimeSeries(periods: periods, values: [60_000.0, 65_000.0]),
			expenseType: .costOfGoodsSold
		)
		let isStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs]
		)
		
		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 110_000.0]),
			assetType: .cashAndEquivalents
		)
		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 110_000.0]),
			equityType: .commonStock
		)
		let bs = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [],
			equityAccounts: [equity]
		)
		let opCF = try Account(
			entity: entity,
			name: "Operating Cash Flow",
			type: .operating,
			timeSeries: TimeSeries(periods: periods, values: [40_000.0, 45_000.0])
		)
		let cf = try CashFlowStatement<Double>(
			entity: entity,
			periods: periods,
			operatingAccounts: [opCF],
			investingAccounts: [],
			financingAccounts: []
		)
		let scenario = FinancialScenario(name: "Test Scenario", description: "Additional")
		return FinancialProjection(scenario: scenario, incomeStatement: isStmt, balanceSheet: bs, cashFlowStatement: cf)
	}
	
	@Test("Custom rule failing integrates into report")
	func customRuleFailing() throws {
		struct MinimumRevenueRule: FinancialValidationRule {
			let minimumRevenue: Double
			func validate(_ projection: FinancialProjection) -> ValidationResult {
				for period in projection.incomeStatement.periods {
					let revenue = projection.incomeStatement.totalRevenue[period] ?? 0
					if revenue < minimumRevenue {
						return .invalid([ValidationError(
							field: "Revenue",
							value: revenue,
							rule: "MinimumRevenue",
							message: "Revenue below minimum threshold of \(minimumRevenue)",
							suggestion: "Verify revenue projections"
						)])
					}
				}
				return .valid
			}
		}

		let projection = try makeValidProjection()
		let validator = ModelValidator<Double>(financialRules: [MinimumRevenueRule(minimumRevenue: 200_000.0)])
		let report = validator.validate(projection: projection)

		#expect(!report.isValid)
		#expect(report.errors.count >= 1)
		#expect(report.errors.first?.field == "Revenue")
	}

	@Test("Detailed report includes scenario name and counts")
	func detailedReportHasScenarioAndCounts() throws {
		let projection = try makeValidProjection()
		let validator = ModelValidator<Double>()
		let report = validator.validate(projection: projection)

		let text = report.detailedReport
		#expect(text.contains("Test Scenario"))
		#expect(text.contains("Errors") || text.contains("errors"))
		#expect(text.contains("Warnings") || text.contains("warnings"))
	}
}

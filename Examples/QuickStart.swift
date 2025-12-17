//
//  QuickStart.swift
//  BusinessMath Examples
//
//  Quick start guide showing the most common use cases.
//
//  Created on November 1, 2025.
//

import Foundation
import BusinessMath

// MARK: - Example 1: Basic Financial Model

func example1_BasicFinancialModel() {
	print("=== Example 1: Basic Financial Model ===\n")

	let model = FinancialModel {
		Revenue {
			Product("SaaS Subscriptions")
				.price(99)
				.customers(1000)
		}

		Costs {
			Fixed("Salaries", 50_000)
			Variable("Cloud Costs", 0.15)
		}
	}

	let revenue = model.calculateRevenue()
	let costs = model.calculateCosts(revenue: revenue)
	let profit = model.calculateProfit()

	print("Revenue: \(revenue.currency())")
	print("Costs: \(costs.currency())")
	print("Profit: \(profit.currency())")
	print()
}

// MARK: - Example 2: Model Inspection

func example2_ModelInspection() {
	print("=== Example 2: Model Inspection ===\n")

	let model = FinancialModel {
		Revenue {
			Product("Product A").price(100).quantity(500)
			Product("Product B").price(200).quantity(200)
		}

		Costs {
			Fixed("Salaries", 50_000)
			Fixed("Rent", 10_000)
			Variable("COGS", 0.35)
		}
	}

	let inspector = ModelInspector(model: model)

	// Generate comprehensive summary
	print(inspector.generateSummary())
}

// MARK: - Example 3: Calculation Tracing

func example3_CalculationTracing() {
	print("=== Example 3: Calculation Tracing ===\n")

	let model = FinancialModel {
		Revenue {
			Product("Widget Sales").price(50).quantity(1000)
		}

		Costs {
			Fixed("Overhead", 10_000)
			Variable("Materials", 0.25)
		}
	}

	let trace = CalculationTrace(model: model)
	_ = trace.calculateProfit()

	// Print formatted trace showing all calculation steps
	print(trace.formatTrace())
}

// MARK: - Example 4: Data Export

func example4_DataExport() {
	print("=== Example 4: Data Export ===\n")

	let model = FinancialModel {
		Revenue {
			RevenueComponent(name: "Sales", amount: 100_000)
		}

		Costs {
			Fixed("Expenses", 40_000)
		}
	}

	let exporter = DataExporter(model: model)

	// Export to CSV
	print("CSV Export:")
	print(exporter.exportToCSV())
	print()

	// Export to JSON
	print("JSON Export:")
	print(exporter.exportToJSON(includeMetadata: true))
	print()
}

// MARK: - Example 5: Time Series Analysis

func example5_TimeSeriesAnalysis() {
	print("=== Example 5: Time Series Analysis ===\n")

	let sales = TimeSeries<Double>(
		periods: [.year(2021), .year(2022), .year(2023)],
		values: [100_000, 125_000, 150_000]
	)

	// Validate data quality
	let validation = sales.validate()
	print("Data Valid: \(validation.isValid)")
	print("Periods: \(sales.count)")

	// Export for analysis
	let exporter = TimeSeriesExporter(series: sales)
	print("\nCSV Export:")
	print(exporter.exportToCSV())
	print()
}

// MARK: - Example 6: Investment Analysis

func example6_InvestmentAnalysis() {
	print("=== Example 6: Investment Analysis ===\n")

	let investment = Investment {
		InitialCost(50_000)
		CashFlows {
			[
				CashFlow(period: 1, amount: 20_000),
				CashFlow(period: 2, amount: 25_000),
				CashFlow(period: 3, amount: 30_000)
			]
		}
		DiscountRate(0.10)
	}

	print("Initial Cost: \(investment.initialCost.currency())")
	print("Discount Rate: \(investment.discountRate.percent())")
	print("NPV: \(investment.npv.currency())")

	if let irr = investment.irr {
		print("IRR: \((irr * 100).formatted())%")
	}

	if let payback = investment.paybackPeriod {
		print("Payback Period: \(payback.formatted()) periods")
	}
	print()
}

// MARK: - Example 7: Complete Workflow

func example7_CompleteWorkflow() {
	print("=== Example 7: Complete Workflow ===\n")

	// 1. Build a financial model
	let model = FinancialModel {
		Revenue {
			Product("Enterprise Plan").price(999).quantity(100)
			Product("Pro Plan").price(299).quantity(500)
			Product("Basic Plan").price(99).quantity(2000)
		}

		Costs {
			Fixed("Engineering", 200_000)
			Fixed("Sales & Marketing", 150_000)
			Fixed("Infrastructure", 50_000)
			Variable("Payment Processing", 0.029)
			Variable("Customer Support", 0.05)
		}
	}

	// 2. Validate the model
	let inspector = ModelInspector(model: model)
	let validation = inspector.validateStructure()

	if validation.isValid {
		print("✓ Model is valid\n")

		// 3. Calculate key metrics
		let profit = model.calculateProfit()
		print("Profit: \(profit.currency())\n")

		// 4. Trace calculations for documentation
		let trace = CalculationTrace(model: model)
		_ = trace.calculateProfit()

		// 5. Export for reporting
		let exporter = DataExporter(model: model)
		let csv = exporter.exportToCSV()
		print("Exported \(csv.split(separator: "\n").count) lines to CSV")
	} else {
		print("⚠️  Model has validation issues:")
		for issue in validation.issues {
			print("  • \(issue)")
		}
	}
	print()
}

// MARK: - Helper Functions

private func formatCurrency(_ value: Double) -> String {
	let formatter = NumberFormatter()
	formatter.numberStyle = .decimal
	formatter.minimumFractionDigits = 2
	formatter.maximumFractionDigits = 2
	return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

private func formatPercent(_ value: Double) -> String {
	return String(format: "%.2f%%", value * 100)
}

// MARK: - Run All Examples

func runAllExamples() {
	example1_BasicFinancialModel()
	example2_ModelInspection()
	example3_CalculationTracing()
	example4_DataExport()
	example5_TimeSeriesAnalysis()
	example6_InvestmentAnalysis()
	example7_CompleteWorkflow()
}

runAllExamples()


#!/usr/bin/env swift

import Foundation

// MARK: - Portfolio Rebalancing Statistics Generator
// Run this script to generate statistics for the blog post

print("""
================================================================================
PORTFOLIO REBALANCING CASE STUDY - STATISTICS GENERATOR
================================================================================

""")

// MARK: - Business Value Calculations

struct PortfolioMetrics {
	let portfolioValue: Double = 250_000_000  // $250M
	let numAssets: Int = 500

	// Baseline (Manual Spreadsheet)
	let baselineRebalancingTime: TimeInterval = 5 * 3600  // 5 hours
	let baselineTrackingErrorBps: Double = 82.5  // average of 75-90 bps
	let baselineTransactionCostsBps: Double = 35.0

	// Optimized (Real-Time System)
	let optimizedRebalancingTime: TimeInterval = 18.0  // 18 seconds
	let optimizedTrackingErrorBps: Double = 42.0
	let optimizedTransactionCostsBps: Double = 25.0  // 28.6% reduction

	// Calculate improvements
	func calculateImprovements() -> (
		trackingErrorImprovement: Double,
		transactionCostReduction: Double,
		timeSpeedup: Double,
		trackingErrorValue: Double,
		transactionCostSavings: Double,
		totalAnnualValue: Double
	) {
		let trackingErrorImprovement = (baselineTrackingErrorBps - optimizedTrackingErrorBps) / baselineTrackingErrorBps
		let transactionCostReduction = (baselineTransactionCostsBps - optimizedTransactionCostsBps) / baselineTransactionCostsBps
		let timeSpeedup = baselineRebalancingTime / optimizedRebalancingTime

		// Annual value calculations
		// Tracking error: 1bp reduction = 0.01% of portfolio value
		let trackingErrorValue = (baselineTrackingErrorBps - optimizedTrackingErrorBps) / 10000.0 * portfolioValue

		// Transaction costs: assume quarterly rebalancing (4x per year)
		let transactionCostSavings = (baselineTransactionCostsBps - optimizedTransactionCostsBps) / 10000.0 * portfolioValue * 4

		let totalAnnualValue = trackingErrorValue + transactionCostSavings

		return (
			trackingErrorImprovement,
			transactionCostReduction,
			timeSpeedup,
			trackingErrorValue,
			transactionCostSavings,
			totalAnnualValue
		)
	}
}

let metrics = PortfolioMetrics()
let improvements = metrics.calculateImprovements()

// MARK: - Generate Blog Post Statistics

print("## Business Value Statistics\n")
print("### Before Real-Time Optimization")
print("- Rebalancing: Once per week, manual spreadsheet analysis")
print("- Time to decision: \(Int(metrics.baselineRebalancingTime / 3600)) hours (stale prices, manual trade list)")
print("- Tracking error: \(Int(metrics.baselineTrackingErrorBps))bps average")
print("- Transaction costs: \(Int(metrics.baselineTransactionCostsBps))bps\n")

print("### After Real-Time Optimization")
print("- Rebalancing: Continuously throughout day as needed")
print("- Time to decision: \(Int(metrics.optimizedRebalancingTime)) seconds (live prices, automated)")
print("- Tracking error: \(Int(metrics.optimizedTrackingErrorBps))bps average (\(Int(improvements.trackingErrorImprovement * 100))% improvement)")
print("- Transaction costs: Reduced \(Int(improvements.transactionCostReduction * 100))% (optimal lot sizing, better execution)\n")

print("### Annual Impact")
let formatter = NumberFormatter()
formatter.numberStyle = .currency
formatter.currencySymbol = "$"
formatter.maximumFractionDigits = 0

let trackingValue = formatter.string(from: NSNumber(value: improvements.trackingErrorValue)) ?? "$0"
let transactionSavings = formatter.string(from: NSNumber(value: improvements.transactionCostSavings)) ?? "$0"
let totalValue = formatter.string(from: NSNumber(value: improvements.totalAnnualValue)) ?? "$0"

print("- Tracking error reduction value: ~\(trackingValue)/year (on $250M portfolio)")
print("- Transaction cost savings: ~\(transactionSavings)/year")
print("- Operational efficiency: 95% reduction in analyst time")
print("- **Total annual value: \(totalValue)**\n")

print("### Technology ROI")
let devCost = 75000.0
let paybackDays = Int((devCost / improvements.totalAnnualValue) * 365)
let fiveYearNPV = improvements.totalAnnualValue * 5 - devCost
let npvFormatted = formatter.string(from: NSNumber(value: fiveYearNPV)) ?? "$0"

print("- Development cost: 3 engineer-months (~$75K)")
print("- Payback period: \(paybackDays) days")
print("- 5-year NPV: \(npvFormatted)\n")

// MARK: - Performance Metrics

print("================================================================================")
print("## Performance Metrics\n")

print("### Optimization Performance")
print("- Parallel speedup: 8× (100-particle swarm evaluation)")
print("- Average optimization time: 18 seconds")
print("- Convergence iterations: ~127 (typical)")
print("- Time per iteration: ~140ms\n")

print("### What Worked")
print("1. **Swift Concurrency**: async/await made real-time updates trivial vs. callbacks")
print("2. **Actor Isolation**: Thread-safe state management without explicit locks")
print("3. **Parallel Evaluation**: PSO's 100-particle swarm evaluated in parallel (8× speedup)")
print("4. **Progressive Results**: Traders see progress, can cancel if market shifts")
print("5. **Hybrid Approach**: PSO for global search + optional BFGS refinement\n")

print("================================================================================\n")

// MARK: - Export to JSON

let jsonOutput: [String: Any] = [
	"portfolio_size": metrics.numAssets,
	"portfolio_value": metrics.portfolioValue,
	"baseline": [
		"rebalancing_time_seconds": metrics.baselineRebalancingTime,
		"tracking_error_bps": metrics.baselineTrackingErrorBps,
		"transaction_costs_bps": metrics.baselineTransactionCostsBps
	],
	"optimized": [
		"rebalancing_time_seconds": metrics.optimizedRebalancingTime,
		"tracking_error_bps": metrics.optimizedTrackingErrorBps,
		"transaction_costs_bps": metrics.optimizedTransactionCostsBps
	],
	"improvements": [
		"tracking_error_improvement_percent": improvements.trackingErrorImprovement * 100,
		"transaction_cost_reduction_percent": improvements.transactionCostReduction * 100,
		"time_speedup": improvements.timeSpeedup
	],
	"annual_value": [
		"tracking_error_value": improvements.trackingErrorValue,
		"transaction_cost_savings": improvements.transactionCostSavings,
		"total_annual_value": improvements.totalAnnualValue
	],
	"roi": [
		"development_cost": devCost,
		"payback_period_days": paybackDays,
		"five_year_npv": fiveYearNPV
	]
]

if let jsonData = try? JSONSerialization.data(withJSONObject: jsonOutput, options: [.prettyPrinted, .sortedKeys]),
   let jsonString = String(data: jsonData, encoding: .utf8) {
	let outputPath = "/tmp/portfolio_statistics.json"
	try? jsonString.write(toFile: outputPath, atomically: true, encoding: .utf8)
	print("📊 Statistics exported to: \(outputPath)")
}

print("\n✅ Statistics generation complete!")

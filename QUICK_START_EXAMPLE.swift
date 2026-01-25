import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport


	// QUICK START EXAMPLE - Copy and run this code to see BusinessMath in action!
	//
	// This example shows a complete investment decision workflow:
	// 1. Calculate profitability metrics (NPV, IRR)
	// 2. Perform sensitivity analysis
	// 3. Run Monte Carlo risk analysis
	//
	// Requirements: Swift 6.0+, BusinessMath 2.0+

import BusinessMath
import Foundation

	// =============================================================================
	// SCENARIO: Evaluating a $100K Software Product Investment
	// =============================================================================

print("=== Investment Analysis: New Software Product ===\n")

	// Cash flows: Year 0 = initial investment, Years 1-4 = projected returns
let cashFlows = [-100_000.0, 30_000.0, 40_000.0, 50_000.0, 60_000.0]
let discountRate = 0.10  // 10% hurdle rate

	// -----------------------------------------------------------------------------
	// STEP 1: Calculate Profitability Metrics
	// -----------------------------------------------------------------------------

let npvValue = try! calculateNPV(discountRate: discountRate, cashFlows: cashFlows)
let irrValue = try! irr(cashFlows: cashFlows)
let pi = profitabilityIndex(rate: discountRate, cashFlows: cashFlows)
let payback = paybackPeriod(cashFlows: cashFlows)

print("📊 Profitability Metrics:")
print("   NPV at \(discountRate.percent(0)): \(npvValue.currency(0))")
print("   IRR: \(irrValue.percent(1))")
print("   Profitability Index: \(pi.number(2))")
print("   Payback Period: \(Double(payback!).number(0)) years")

	// Decision rule: NPV > 0, IRR > hurdle rate, PI > 1.0
let profitable = npvValue > 0 && irrValue > discountRate && pi > 1.0
print("   ✅ Investment is \(profitable ? "APPROVED" : "REJECTED")\n")

	// -----------------------------------------------------------------------------
	// STEP 2: Sensitivity Analysis - How sensitive is NPV to discount rate?
	// -----------------------------------------------------------------------------

print("📉 Sensitivity Analysis: NPV vs. Discount Rate")
let rates = stride(from: 0.05, through: 0.15, by: 0.01)

for rate in rates {
	let npvAtRate = try! calculateNPV(discountRate: rate, cashFlows: cashFlows)
	let ratePercent = rate.percent(0)
	let npvFormatted = npvAtRate.currency(0)
	print("   Rate: \(ratePercent.paddingLeft(toLength: 5)) → NPV: \(npvFormatted)")
}
print("   💡 NPV decreases as discount rate increases (inverse relationship)\n")

	// -----------------------------------------------------------------------------
	// STEP 3: Monte Carlo Risk Analysis - What if cash flows are uncertain?
	// -----------------------------------------------------------------------------
let uncertainty = 0.15
print("🎲 Monte Carlo Risk Analysis (10,000 iterations)")
print("   Modeling ±\(uncertainty.percent(0)) uncertainty in each year's cash flows\n")

	// Create simulation with 10,000 iterations
var simulation = MonteCarloSimulation(iterations: 100_000) { inputs in
		// Model uncertain cash flows: base case ± 20% volatility
	let year1 = 30_000 * (1 + inputs[0])
	let year2 = 40_000 * (1 + inputs[1])
	let year3 = 50_000 * (1 + inputs[2])
	let year4 = 60_000 * (1 + inputs[3])
	
	return try! calculateNPV(discountRate: 0.10, cashFlows: [-100_000, year1, year2, year3, year4])
}

	// Add uncertainty inputs: normal distribution with 20% std dev
for year in 1...4 {
	simulation.addInput(SimulationInput(
		name: "Year \(year) Variance",
		distribution: DistributionNormal(0.0, uncertainty)  // Mean: 0%, StdDev: (uncertainty * 100) %
	))
}

	// Run simulation and analyze results
let results = try! simulation.run()
let statistics = results.statistics

	// Risk metrics
let var95 = results.valueAtRisk(confidenceLevel: 0.95)
let cvar95 = results.conditionalValueAtRisk(confidenceLevel: 0.95)
let probLoss = results.probabilityBelow(0)

print("📈 Simulation Results:")
print("   Expected NPV:               \(statistics.mean.currency(0))")
print("   Median NPV:                 \(statistics.median.currency(0))")
print("   Std Deviation:              \(statistics.stdDev.currency(0))")
print("")
print("🛡️ Risk Metrics:")
print("   95% Value at Risk (VaR):    \(abs(var95).currency(0))")
print("   95% Conditional VaR (CVaR): \(abs(cvar95).currency(1))")
print("   Probability of Loss:        \(probLoss.percent(1))")
print("")

	// -----------------------------------------------------------------------------
	// FINAL RECOMMENDATION
	// -----------------------------------------------------------------------------

print("=== Final Investment Decision ===")
print("")
print("✅ RECOMMENDATION: \(profitable && probLoss < 0.10 ? "APPROVE" : "REVIEW") Investment")
print("")
print("Rationale:")
print("  • Strong positive NPV (\(npvValue.currency(0)))")
print("  • IRR (\(irrValue.percent(1))) exceeds hurdle rate (\(discountRate.percent(1)))")
print("  • Low probability of loss (\(probLoss.percent(1)))")
print("  • NPV remains positive across reasonable discount rate scenarios")
print("")

	// =============================================================================
	// Want to learn more?
	// - Documentation: Sources/BusinessMath/BusinessMath.docc/
	// - More Examples: EXAMPLES.md
	// - GPU Acceleration: GPU_ACCELERATION_TUTORIAL.md
	// =============================================================================

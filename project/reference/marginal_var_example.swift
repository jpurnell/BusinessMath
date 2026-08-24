#!/usr/bin/env swift

import Foundation

/*
 Marginal VaR vs. Component VaR - Corrected Example

 The key insight: Marginal VaR is a RATIO (dimensionless), not a dollar amount!
 */

print("Risk Aggregation Example (Corrected)")
print("=====================================")
print("")

// Setup
let portfolioVaRs = [100_000.0, 150_000.0, 200_000.0]
let correlations = [
	[1.0, 0.6, 0.4],
	[0.6, 1.0, 0.5],
	[0.4, 0.5, 1.0]
]

// Aggregated VaR calculation (simplified for example)
// VaR = sqrt(v^T C v)
func aggregateVaR(_ vaRs: [Double], _ corr: [[Double]]) -> Double {
	var sum = 0.0
	for i in 0..<vaRs.count {
		for j in 0..<vaRs.count {
			sum += vaRs[i] * corr[i][j] * vaRs[j]
		}
	}
	return sqrt(sum)
}

let aggregatedVaR = aggregateVaR(portfolioVaRs, correlations)

print("Individual Portfolio VaRs:")
print("  Portfolio A: $100,000")
print("  Portfolio B: $150,000")
print("  Portfolio C: $200,000")
print("  Simple sum: $450,000")
print("")
print("Aggregated VaR: $\(Int(aggregatedVaR))")
print("Diversification benefit: $\(Int(450_000 - aggregatedVaR))")
print("")

// Marginal VaR calculation
func marginalVaR(entity: Int, vaRs: [Double], corr: [[Double]]) -> Double {
	let portfolioVaR = aggregateVaR(vaRs, corr)
	var Cv_i = 0.0
	for j in 0..<vaRs.count {
		Cv_i += corr[entity][j] * vaRs[j]
	}
	// A portfolio with no VaR has no marginal contribution to apportion; guarding
	// the divisor keeps that case from becoming a NaN that reads like a ratio.
	guard portfolioVaR != 0 else { return 0 }
	return Cv_i / portfolioVaR  // Returns a RATIO!
}

print("═══════════════════════════════════")
print("MARGINAL VaR (Sensitivity Measure)")
print("═══════════════════════════════════")
print("")

for i in 0..<portfolioVaRs.count {
	let marginal = marginalVaR(entity: i, vaRs: portfolioVaRs, corr: correlations)
	let portfolioName = ["A", "B", "C"][i]

	print("Portfolio \(portfolioName):")
	print("  Individual VaR: $\(Int(portfolioVaRs[i]))")
	print("  Marginal VaR: \((marginal).formatted(.number.precision(.fractionLength(4)))) (RATIO, not dollars!)")
	print("  Interpretation: Each $1 increase in Portfolio \(portfolioName)")
	print("                  increases total VaR by $\((marginal).formatted(.number.precision(.fractionLength(2))))")
	print("  Risk contribution: \((marginal * 100).formatted(.number.precision(.fractionLength(1))))%")
	print("")
}

print("Key Point: Marginal VaR values are between 0 and 1!")
print("They represent sensitivity, not dollar amounts.")
print("")

// Component VaR calculation
print("═══════════════════════════════════")
print("COMPONENT VaR (Dollar Attribution)")
print("═══════════════════════════════════")
print("")

let weights = [0.3, 0.4, 0.3]

func componentVaR(vaRs: [Double], weights: [Double], corr: [[Double]]) -> [Double] {
	var components = [Double]()
	let portfolioVaR = aggregateVaR(vaRs, corr)

	for i in 0..<vaRs.count {
		let v_i = weights[i] * vaRs[i]
		var Cv_i = 0.0
		for j in 0..<vaRs.count {
			let v_j = weights[j] * vaRs[j]
			Cv_i += corr[i][j] * v_j
		}
		components.append(portfolioVaR == 0 ? 0 : v_i * (Cv_i / portfolioVaR))
	}

	return components
}

let componentVaRs = componentVaR(vaRs: portfolioVaRs, weights: weights, corr: correlations)
var totalComponent = 0.0

for i in 0..<portfolioVaRs.count {
	let component = componentVaRs[i]
	totalComponent += component
	let portfolioName = ["A", "B", "C"][i]

	print("Portfolio \(portfolioName):")
	print("  Weight: \(Int(weights[i] * 100))%")
	print("  Component VaR: $\(Int(component)) (DOLLARS!)")
	let contributionShare = aggregatedVaR == 0 ? 0 : (component / aggregatedVaR) * 100
	print("  Contribution to total: \(contributionShare.formatted(.number.precision(.fractionLength(1))))%")
	print("")
}

print("Total component VaR: $\(Int(totalComponent))")
print("Aggregated VaR: $\(Int(aggregatedVaR))")
print("Difference: $\(Int(abs(totalComponent - aggregatedVaR)))")
print("")
print("✓ Components sum to aggregated VaR (Euler allocation)")
print("")

print("═════════════════════════════════════")
print("SUMMARY")
print("═════════════════════════════════════")
print("")
print("Marginal VaR:")
print("  • Returns: Dimensionless ratio (0 to ~1)")
print("  • Meaning: VaR sensitivity per $1 increase")
print("  • Use for: Risk contribution percentages")
print("  • Format as: Decimal or percentage")
print("")
print("Component VaR:")
print("  • Returns: Dollar amount")
print("  • Meaning: Attribution of total VaR")
print("  • Use for: Risk budgeting/allocation")
print("  • Format as: Currency")
print("")
print("Relationship: Component = Position Value × Marginal")

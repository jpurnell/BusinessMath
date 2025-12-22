import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	// Helper function to calculate arbitrary confidence intervals
	func confidenceInterval(
		results: ProjectionResults<Double>,
		period: Period,
		confidence: Double  // e.g., 0.90 for 90%, 0.95 for 95%
	) -> (lower: Double, upper: Double) {
		let alpha = (1.0 - confidence) / 2.0  // Split the rest equally

		let lowerPercentile = alpha
		let upperPercentile = 1.0 - alpha

		let pctiles = results.percentiles[period]!

		// Map to closest available percentiles
		let lower: Double
		if lowerPercentile <= 0.05 {
			lower = pctiles.p5
		} else if lowerPercentile <= 0.25 {
			// Interpolate between p5 and p25
			let t = (lowerPercentile - 0.05) / 0.20
			lower = pctiles.p5 * (1 - t) + pctiles.p25 * t
		} else {
			lower = pctiles.p25
		}

		let upper: Double
		if upperPercentile >= 0.95 {
			upper = pctiles.p95
		} else if upperPercentile >= 0.75 {
			// Interpolate between p75 and p95
			let t = (upperPercentile - 0.75) / 0.20
			upper = pctiles.p75 * (1 - t) + pctiles.p95 * t
		} else {
			upper = pctiles.p75
		}

		return (lower, upper)
	}

	// Example usage
	let revenueDriver = ProbabilisticDriver<Double>.normal(
		name: "Revenue",
		mean: 1_000_000.0,
		stdDev: 100_000.0
	)

	let quarters = (1...8).map { Period.quarter(year: 2025 + ($0 - 1) / 4, quarter: (($0 - 1) % 4) + 1) }
	let projection = DriverProjection(driver: revenueDriver, periods: quarters)
	let results = projection.projectMonteCarlo(iterations: 10_000)

	print("\nConfidence Intervals for Revenue Forecast")
	print("==========================================")

	for quarter in quarters {
		let stats = results.statistics[quarter]!

		let ci90 = confidenceInterval(results: results, period: quarter, confidence: 0.90)
		let ci95 = confidenceInterval(results: results, period: quarter, confidence: 0.95)
		let ci99 = confidenceInterval(results: results, period: quarter, confidence: 0.99)

		print("\n\(quarter.label)")
		print("  Mean: \(stats.mean.currency(0))")
		print("  90% CI: [\(ci90.lower.currency(0)), \(ci90.upper.currency(0))]")
		print("  95% CI: [\(ci95.lower.currency(0)), \(ci95.upper.currency(0))]")
		print("  99% CI: [\(ci99.lower.currency(0)), \(ci99.upper.currency(0))]")
	}

	// Calculate downside risk and upside potential
	for quarter in quarters {
		let stats = results.statistics[quarter]!
		let pctiles = results.percentiles[quarter]!

		let downsideRisk = stats.mean - pctiles.p5
		let upsidePotential = pctiles.p95 - stats.mean
		let asymmetry = upsidePotential / downsideRisk

		print("\n\(quarter.label)")
		print("  Expected: \(stats.mean.currency(0))")
		print("  Downside Risk (P5): \(downsideRisk.currency(0))")
		print("  Upside Potential (P95): \(upsidePotential.currency(0))")
		print("  Risk/Reward Ratio: \(asymmetry.number(2))")

		if asymmetry > 1.0 {
			print("  → Favorable risk/reward profile")
		} else if asymmetry < 1.0 {
			print("  → Unfavorable risk/reward profile")
		} else {
			print("  → Balanced risk/reward")
		}
	}


	// Test different uncertainty levels
	let stdDevScenarios = [50_000.0, 100_000.0, 150_000.0, 200_000.0]

	print("\nSensitivity to Uncertainty Level")
	print("==================================")
	print("Std Dev\t\t90% CI Width\tCoefficient of Variation")
	print(String(repeating: "-", count: 60))

	for stdDev in stdDevScenarios {
		let driver = ProbabilisticDriver<Double>.normal(
			name: "Revenue",
			mean: 1_000_000.0,
			stdDev: stdDev
		)

		let proj = DriverProjection(driver: driver, periods: [quarters[0]])
		let res = proj.projectMonteCarlo(iterations: 10_000)

		let pctiles = res.percentiles[quarters[0]]!
		let stats = res.statistics[quarters[0]]!
		let ciWidth = pctiles.p95 - pctiles.p5
		let cov = stats.stdDev / stats.mean

		print("\(stdDev.currency(0).padding(toLength: 10, withPad: " ", startingAt: 0))\t\t\(ciWidth.currency(0))\t\t\(cov.percent(1))")
	}

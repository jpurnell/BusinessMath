import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	// $1M portfolio with 5 asset classes
	let assets = [
		"US Large Cap",
		"US Small Cap",
		"International",
		"Bonds",
		"Real Estate"
	]

	let expectedReturns = VectorN([0.10, 0.12, 0.11, 0.04, 0.09])

	let covariance = [
		[0.0225, 0.0180, 0.0150, 0.0020, 0.0100],
		[0.0180, 0.0400, 0.0200, 0.0010, 0.0150],
		[0.0150, 0.0200, 0.0400, 0.0030, 0.0120],
		[0.0020, 0.0010, 0.0030, 0.0016, 0.0010],
		[0.0100, 0.0150, 0.0120, 0.0010, 0.0256]
	]

	let optimizer = PortfolioOptimizer()

	// Conservative investor (minimum variance)
	let conservative = try optimizer.minimumVariancePortfolio(
		expectedReturns: expectedReturns,
		covariance: covariance,
		allowShortSelling: false
	)

	print("Conservative Portfolio ($1M):")
	for (i, asset) in assets.enumerated() {
		let weight = conservative.weights.toArray()[i]
		if weight > 0.01 {
			let allocation = 1_000_000 * weight
			print("  \(asset): \(allocation.currency()) (\(weight.percent(1)))")
		}
	}
print("  Expected Return: \(conservative.expectedReturn.percent(1)))")
print("  Volatility: \(conservative.volatility.percent(1))")

	// Moderate investor (max Sharpe)
	let moderate = try optimizer.maximumSharpePortfolio(
		expectedReturns: expectedReturns,
		covariance: covariance,
		riskFreeRate: 0.03,
		constraintSet: .longOnly
	)

	print("\nModerate Portfolio ($1M):")
	for (i, asset) in assets.enumerated() {
		let weight = moderate.weights.toArray()[i]
		if weight > 0.01 {
			let allocation = 1_000_000 * weight
			print("  \(asset): \(allocation.currency(0)) (\(weight.percent(1)))")
		}
	}
print("  Sharpe Ratio: \(moderate.sharpeRatio.number(2))")
print("  Expected Return: \(moderate.expectedReturn.percent(2))")
print("  Volatility: \(moderate.volatility.percent(2))")

	// Check if rebalancing is needed
	func needsRebalancing(
		current: [Double],
		target: [Double],
		threshold: Double = 0.05
	) -> Bool {
		for (curr, targ) in zip(current, target) {
			if abs(curr - targ) > threshold {
				return true
			}
		}
		return false
	}

	let currentWeights = [0.28, 0.32, 0.25, 0.15]  // After market moves
	let targetWeights = [0.25, 0.30, 0.25, 0.20]   // Original allocation

	if needsRebalancing(current: currentWeights, target: targetWeights) {
		print("Rebalancing needed:")
		for i in 0..<currentWeights.count {
			let diff = currentWeights[i] - targetWeights[i]
			let diffPercent = diff
			let action = diff > 0 ? "Sell" : "Buy"
			print("  \(assets[i]): \(action) \(abs(diffPercent).percent(1))")
		}
	}

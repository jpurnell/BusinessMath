import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	// 20-year glide path (240 months → 80 quarters)
	let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
		numberOfPeriods: 80,
		discountRate: 0.02  // 2% quarterly
	)

	// 3 assets: Stocks, Bonds, Cash
	let returns = VectorN([0.10, 0.05, 0.02])  // Expected annual returns
	let volatility = VectorN([0.18, 0.06, 0.01])

	// Risk tolerance decreases with age
	func riskAversion(quarter: Int, totalQuarters: Int) -> Double {
		let progress = Double(quarter) / Double(totalQuarters)
		return 1.0 + 4.0 * progress  // 1.0 → 5.0 over lifetime
	}

print("hello")


	// Objective: risk-adjusted return (mean-variance)
	let result = try optimizer.optimize(
		objective: { t, weights in
			let expectedReturn = weights.dot(returns)
			let risk = weights.toArray().enumerated()
				.map { i, w in w * w * volatility.toArray()[i] * volatility.toArray()[i] }
				.reduce(0, +)

			let lambda = riskAversion(quarter: t, totalQuarters: 80)
			return expectedReturn - lambda * risk
		},
		initialState: VectorN([0.80, 0.15, 0.05]),  // Start aggressive
		constraints: [
			.budgetEachPeriod,
			.turnoverLimit(0.10),  // 10% max rebalancing per quarter
			MultiPeriodConstraint<VectorN<Double>>.nonNegativityEachPeriod(dimension: 3)[0],
			MultiPeriodConstraint<VectorN<Double>>.nonNegativityEachPeriod(dimension: 3)[1],
			MultiPeriodConstraint<VectorN<Double>>.nonNegativityEachPeriod(dimension: 3)[2]
		],
		minimize: false
	)

print("hello")

	// Analyze glide path (sample every 5 years)
	print("Glide Path (every 5 years):")
	for year in stride(from: 0, through: 20, by: 5) {
		let quarter = year * 4
		if quarter < result.trajectory.count {
			let weights = result.trajectory[quarter].toArray()
			print("Year \(year): Stocks \(weights[0].percent(1))), " +
	  "Bonds \(weights[1].percent(1))), " +
				  "Cash \(weights[2].percent(2))")
		}
	}

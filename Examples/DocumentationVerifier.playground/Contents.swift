import BusinessMath
import OSLog
import PlaygroundSupport

let cashFlows = [-100000.0, 50000, 55000, 60000]
	// Portfolio returns (daily for 1 year)

public let spReturns: [Double] = [0.0088, 0.0079, -0.0116, -0.0024, -0.0016, -0.0107, 0.0021, 0.0067, -0.0009, -0.0035, 0.0019, 0.0011, 0.003, 0.0025, -0.0053, 0.0054, 0.0069, 0.0091, 0.0155, 0.0098, -0.0156, 0.0038, -0.0083, -0.0092, -0.0005, -0.0166, 0.0006, 0.0021, 0.0154, 0.0013, -0.0112, 0.0037, -0.0117, 0.0017, 0.0026, -0.0099, 0, 0.0023, 0.0123, 0.0079, 0.0058, -0.0053, 0, 0.0107, 0.0053, -0.0063, 0.004, -0.0016, 0.0156, -0.0271, -0.0028, 0.0058, -0.0038, 0.0036, 0.0001, 0.0006, 0.0034, 0.0041, 0.0026, 0.0059, -0.005, -0.0028, -0.0055, 0.0044, 0.0049, 0.0048, -0.001, -0.0013, 0.0047, -0.0005, 0.0085, 0.003, 0.0027, 0.0021, -0.0032, 0.0083, 0.0051, -0.0069, -0.0064, 0.0032, 0.0024, 0.0041, -0.0043, 0.0152, -0.004, -0.0024, -0.0059, -0.0001, -0.0029, 0.0003, 0.0032, 0.0113, -0.0025, 0.0078, -0.0008, 0.0073, -0.0049, 0.0147, -0.016, -0.0037, -0.0012, -0.003, 0.0002, 0.004, 0.0007, 0.0078, 0.0006, 0.0014, -0.0001, 0.0054, 0.0032, -0.004, 0.0014, -0.0033, 0.0027, 0.0061, -0.0007, -0.0079, 0.0083, 0.0047, -0.0011, 0.0052, 0.0052, 0.008, 0, 0.0111, 0.0096, -0.0022, -0.0003, -0.0084, 0.0094, -0.0113, 0.0038, -0.0027, 0.0055, 0.0009, 0.0103, -0.0053, 0.0001, 0.0058, 0.0041, -0.0001, 0.004, -0.0056, 0.0205, -0.0067, -0.0004, -0.0161, -0.0039, 0.0009, 0.007, 0.0041, 0.001, 0.0072, 0.0326, -0.0007, 0.0058, 0.0043, -0.0077, -0.0064, 0.0147, 0.0063, 0.0015, 0.0058, 0.0006, 0.0074, 0.0203, 0.0167, 0.0251, -0.0236, 0.0013, -0.0224, -0.0017, 0.0079, 0.0181, -0.0346, 0.0952, -0.0157, -0.0023, -0.0597, -0.0484, 0.0067, 0.0038, 0.0055, -0.0197, -0.0033, -0.0112, 0.0016, 0.0176, 0.0008, -0.0022, 0.0108, -0.0107, 0.0064, 0.0213, -0.0139, 0.0049, -0.0076, -0.027, 0.0055, -0.0178, 0.0112, -0.0122, -0.0176, 0.0159, -0.0159, 0.0001, -0.0047, -0.005, -0.0171, -0.0043, 0.0024, 0.0024, -0.0001, 0.0104, -0.0027, 0.0003, 0.0067, -0.0095, 0.0036, 0.0039, 0.0072, -0.0076, -0.005, 0.0053, -0.0047, 0.0092, -0.0146, -0.0029, 0.0053, 0.0061, 0.0088, 0.01, -0.0021, 0.0183, 0.0011, 0.0016, -0.0154, 0.0016, -0.0111, 0.0055, 0.0126, -0.0022, -0.0043, -0.0107, -0.0111, -0.0004, 0.011, 0.0073, 0.0109]

let spReturnMean = mean(spReturns)
let spReturnStdDev = stdDev(spReturns)
let returns: [Double] = (0..<250).map({_ in distributionNormal(mean: spReturnMean, stdDev: spReturnStdDev)}) /* 250 daily returns */

	let periods = (0..<spReturns.count).map { Period.day(Date().addingTimeInterval(Double($0) * 86400)) }
	let timeSeries = TimeSeries(periods: periods, values: spReturns)

	let riskMetrics = ComprehensiveRiskMetrics(
		returns: timeSeries,
		riskFreeRate: 0.02 / 250  // 2% annual = 0.008% daily
	)

	print("Value at Risk:")
	print("  95% VaR: \(riskMetrics.var95.percent())")
	print("  99% VaR: \(riskMetrics.var99.percent())")

	// Interpret: "95% confidence we won't lose more than X% in a day"
	let portfolioValue = 1_000_000.0
	let var95Loss = abs(riskMetrics.var95) * portfolioValue

	print("\nFor \(portfolioValue.currency(0)) portfolio:")
	print("  95% 1-day VaR: \(var95Loss.currency())")
	print("  Meaning: 95% confident daily loss won't exceed \(var95Loss.currency())")

	print("\nConditional VaR (Expected Shortfall):")
	print("  CVaR (95%): \(riskMetrics.cvar95.percent())")
	print("  Tail Risk Ratio: \(riskMetrics.tailRisk.number())")

	// CVaR is the expected loss if we're in the worst 5%
	let cvarLoss = abs(riskMetrics.cvar95) * portfolioValue
	print("  If in worst 5% of days, expect to lose: \(cvarLoss.currency())")

print("\nComprehensive Risk Profile:")
print(riskMetrics.description)

let drawdown = riskMetrics.maxDrawdown

print("\nDrawdown Analysis:")
print("  Maximum drawdown: \(drawdown.percent())")

if drawdown < 0.10 {
	print("  Risk level: Low")
} else if drawdown < 0.20 {
	print("  Risk level: Moderate")
} else {
	print("  Risk level: High")
}

print("\nRisk-Adjusted Returns:")
print("  Sharpe Ratio: \(riskMetrics.sharpeRatio.number(3))")
print("    (return per unit of total volatility)")

print("  Sortino Ratio: \(riskMetrics.sortinoRatio.number(3))")
print("    (return per unit of downside volatility)")

// Sortino > Sharpe indicates asymmetric returns (positive skew)
if riskMetrics.sortinoRatio > riskMetrics.sharpeRatio {
	print("  Portfolio has limited downside with upside potential")
}

print("\nTail Statistics:")
print("  Skewness: \(riskMetrics.skewness.number(3))")

if riskMetrics.skewness < -0.5 {
	print("    Negative skew: More frequent small gains, rare large losses")
	print("    Risk: Fat left tail")
} else if riskMetrics.skewness > 0.5 {
	print("    Positive skew: More frequent small losses, rare large gains")
	print("    Risk: Fat right tail")
} else {
	print("    Roughly symmetric distribution")
}

print("  Excess Kurtosis: \(riskMetrics.kurtosis.number(3))")

if riskMetrics.kurtosis > 1.0 {
	print("    Fat tails: More extreme events than normal distribution")
	print("    Risk: Higher probability of large moves")
}

struct RiskLimits {
	let maxVaR95: Double         // Maximum 95% VaR
	let maxDrawdown: Double      // Maximum allowed drawdown
	let minSharpeRatio: Double   // Minimum acceptable Sharpe
}

let limits = RiskLimits(
	maxVaR95: 0.03,      // 3% daily VaR
	maxDrawdown: 0.20,   // 20% drawdown
	minSharpeRatio: 0.5  // 0.5 Sharpe
)

func checkRiskLimits(metrics: ComprehensiveRiskMetrics<Double>, limits: RiskLimits) -> [String] {
	var breaches: [String] = []

	if abs(metrics.var95) > limits.maxVaR95 {
		breaches.append("VaR limit breached: \(abs(metrics.var95).percent()) > \(limits.maxVaR95.percent())")
	}

	if metrics.maxDrawdown > limits.maxDrawdown {
		breaches.append("Drawdown limit breached: \(metrics.maxDrawdown.percent()) > \(limits.maxDrawdown.percent())")
	}

	if metrics.sharpeRatio < limits.minSharpeRatio {
		breaches.append("Sharpe below minimum: \(metrics.sharpeRatio.number(3)) < \(limits.minSharpeRatio.number(3))")
	}

	return breaches
}

let breaches = checkRiskLimits(metrics: riskMetrics, limits: limits)
if breaches.isEmpty {
	print("✓ All risk limits satisfied")
} else {
	print("⚠️ Risk limit breaches:")
	for breach in breaches {
		print("  - \(breach)")
	}
}

	// Track risk metrics daily/weekly
	struct RiskSnapshot {
		let date: Date
		let var95: Double
		let sharpeRatio: Double
		let drawdown: Double
	}

	var riskHistory: [RiskSnapshot] = []

	// Add current snapshot
	riskHistory.append(RiskSnapshot(
		date: Date(),
		var95: riskMetrics.var95,
		sharpeRatio: riskMetrics.sharpeRatio,
		drawdown: riskMetrics.maxDrawdown
	))

	// Alert if risk increasing
	if riskHistory.count >= 2 {
		let current = riskHistory.last!
		let previous = riskHistory[riskHistory.count - 2]

		let varIncrease = (abs(current.var95) - abs(previous.var95)) / abs(previous.var95)

		if varIncrease > 0.20 {  // VaR increased >20%
			print("⚠️ ALERT: VaR increased \(varIncrease.percent()) since last measurement")
		}
	}

import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport


	// Investment opportunity: Rental property
 let propertyPrice = 250_000.0
 let downPayment = 50_000.0      // 20% down
 let renovationCosts = 20_000.0
 let initialInvestment = downPayment + renovationCosts  // Total: $70,000

 // Expected annual cash flows (after expenses and mortgage)
 let year1 = 8_000.0
 let year2 = 8_500.0
 let year3 = 9_000.0
 let year4 = 9_500.0
 let year5 = 10_000.0
 let salePrice = 300_000.0       // Expected sale price after 5 years
 let mortgagePayoff = 190_000.0  // Remaining mortgage balance
 let saleProceeds = salePrice - mortgagePayoff  // Net: $110,000

 print("Real Estate Investment Analysis")
 print("================================")
print("Initial Investment: \(initialInvestment.currency())")
print("  Down Payment: \(downPayment.currency())")
print("  Renovations: \(renovationCosts.currency())")
 print("\nExpected Cash Flows:")
 print("  Year 1-5: Annual rental income")
 print("  Year 5: + Sale proceeds")
 print("  Required Return: 12% (target rate)")
 

// ## Step 2: Calculate NPV
//
// Determine if the investment creates value at your required return.

  // Define all cash flows (negative initial, then positive returns)
 let cashFlows = [
	 -initialInvestment,  // Year 0: Investment
	 year1,               // Year 1: Rental income
	 year2,               // Year 2: Rental income
	 year3,               // Year 3: Rental income
	 year4,               // Year 4: Rental income
	 year5 + saleProceeds // Year 5: Rental income + sale
 ]

 // Calculate NPV at required return of 12%
 let requiredReturn = 0.12
 let npvValue = npv(discountRate: requiredReturn, cashFlows: cashFlows)

 print("\nNet Present Value Analysis")
 print("===========================")
print("Discount Rate: \(requiredReturn.percent())")
print("NPV: \(npvValue.currency(2))")

 if npvValue > 0 {
	 print("✓ Positive NPV - Investment adds value")
	 print("  For every $1 invested, you create \((1 + npvValue / initialInvestment).currency(2)) of value")
 } else if npvValue < 0 {
	 print("✗ Negative NPV - Investment destroys value")
	 print("  Should reject this opportunity")
 } else {
	 print("○ Zero NPV - Breakeven investment")
	 print("  Exactly meets required return")
 }

	// Calculate Internal Rate of Return
	let irrValue = try irr(cashFlows: cashFlows)

	print("\nInternal Rate of Return")
	print("=======================")
print("IRR: \(irrValue.percent(2))")
print("Required Return: \(requiredReturn.percent())")

	if irrValue > requiredReturn {
		let spread = (irrValue - requiredReturn) * 100
		print("✓ IRR exceeds required return by \(spread.number(2)) percentage points")
		print("  Investment is attractive")
	} else if irrValue < requiredReturn {
		let shortfall = (requiredReturn - irrValue) * 100
		print("✗ IRR falls short by \(shortfall.number(2)) percentage points")
		print("  Investment should be rejected")
	} else {
		print("○ IRR equals required return")
		print("  Investment is at breakeven")
	}

	// Verify: NPV at IRR should be ~0
	let npvAtIRR = npv(discountRate: irrValue, cashFlows: cashFlows)
print("\nVerification: NPV at IRR = \(npvAtIRR.currency()) (should be ~$0)")


	// Profitability Index
	let pi = profitabilityIndex(rate: requiredReturn, cashFlows: cashFlows)

	print("\nProfitability Index")
	print("===================")
print("PI: \(pi.number(2))")
	if pi > 1.0 {
		print("✓ PI > 1.0 - Creates value")
		print("  Returns \(pi.currency(2)) for every $1 invested (at \(requiredReturn.percent()))")
	} else if pi < 1.0 {
		print("✗ PI < 1.0 - Destroys value")
	} else {
		print("○ PI = 1.0 - Breakeven")
	}

	// Payback Period (simple)
	let payback = paybackPeriod(cashFlows: cashFlows)

	print("\nPayback Period")
	print("==============")
	if let pb = payback {
		print("Simple Payback: \(pb) years")
		print("  Investment recovered in year \(pb)")
	} else {
		print("Investment never recovers initial outlay")
	}

	// Discounted Payback Period
	let discountedPayback = discountedPaybackPeriod(rate: requiredReturn, cashFlows: cashFlows)

	if let dpb = discountedPayback {
		print("Discounted Payback: \(dpb) years (at \(requiredReturn.percent()))")
		if let pb = payback {
			let difference = dpb - pb
			print("  Takes \(difference) more year(s) when accounting for time value")
		}
	} else {
		print("Investment never recovers on discounted basis")
	}


// STEP 6: - SENSITIVITY

print("Sensitivity Analysis")
print("====================")

// Test different discount rates
let rates = stride(from: 0.08, through: 0.16, by: 0.02)

print("NPV at Different Discount Rates:")
print("Rate  | NPV        | Decision")
print("------|------------|----------")

for rate in rates {
	let npv = npv(discountRate: rate, cashFlows: cashFlows)
	let decision = npv > 0 ? "Accept" : "Reject"
	print("\(rate.percent(1).paddingLeft(toLength: 5)) | \(npv.currency(2).paddingLeft(toLength: 10)) | \(decision)")
}

// Test different sale prices
print("\nNPV at Different Sale Prices:")
print("Sale Price | Net Proceeds | NPV        | Decision")
print("-----------|--------------|------------|----------")

let salePrices = stride(from: 260000.0, to: 340000, by: 20000.0)

for price in salePrices {
	let proceeds = price - mortgagePayoff
	let flows = [
		-initialInvestment,
		year1, year2, year3, year4,
		year5 + proceeds
	]
	let npv = npv(discountRate: requiredReturn, cashFlows: flows)
	let decision = npv > 0 ? "Accept" : "Reject"
	print("\(price.currency(0).paddingLeft(toLength: 10)) | \(proceeds.currency(0).paddingLeft(toLength: 12)) | \(npv.currency(2).paddingLeft(toLength: 10)) | \(decision)")
}

// Find breakeven sale price (where NPV = 0)
print("\nBreakeven Analysis:")

var low = 200_000.0
var high = 350_000.0
var breakeven = (low + high) / 2

// Binary search for breakeven
for _ in 0..<20 {
	let proceeds = breakeven - mortgagePayoff
	let flows = [-initialInvestment, year1, year2, year3, year4, year5 + proceeds]
	let npv = npv(discountRate: requiredReturn, cashFlows: flows)

	if abs(npv) < 1.0 {
		break  // Close enough
	} else if npv > 0 {
		high = breakeven
	} else {
		low = breakeven
	}
	breakeven = (low + high) / 2
}

print("Breakeven Sale Price: \(breakeven.currency(0))")
print("  At this price, NPV = $0 and IRR = \(requiredReturn.percent(0))")
print("  Current assumption: \(salePrice.currency(0))")
print("  Safety margin: \((salePrice - breakeven).currency(0))")



print("\n\nComparing Investment Opportunities")
print("===================================")

// Define three investment opportunities
struct Investment {
	let name: String
	let cashFlows: [Double]
	let description: String
}

let investments = [
	Investment(
		name: "Real Estate",
		cashFlows: [-70_000, 8_000, 8_500, 9_000, 9_500, 120_000],
		description: "Rental property with 5-year hold"
	),
	Investment(
		name: "Stock Portfolio",
		cashFlows: [-70_000, 5_000, 5_500, 6_000, 6_500, 75_000],
		description: "Diversified equity portfolio"
	),
	Investment(
		name: "Business Expansion",
		cashFlows: [-70_000, 0, 10_000, 15_000, 20_000, 40_000],
		description: "Expand product line (delayed returns)"
	)
]

// Calculate metrics for each
print("Investment           | NPV       | IRR     | PI   | Payback | Ranking")
print("---------------------|-----------|---------|------|---------|--------")

var results: [(name: String, npv: Double, irr: Double, pi: Double)] = []

for investment in investments {
	let npv = npv(discountRate: requiredReturn, cashFlows: investment.cashFlows)
	let irr = try irr(cashFlows: investment.cashFlows)
	let pi = profitabilityIndex(rate: requiredReturn, cashFlows: investment.cashFlows)
	let payback = paybackPeriod(cashFlows: investment.cashFlows) ?? 99

	results.append((investment.name, npv, irr, pi))
	print("\(investment.name.padding(toLength: 20, withPad: " ", startingAt: 0)) | \(npv.currency(0).paddingLeft(toLength: 9)) | \(irr.percent(2).paddingLeft(toLength: 7)) | \(pi.number(2)) | \(payback) years |")
}

// Rank by NPV (best decision criterion for value creation)
let ranked = results.sorted { $0.npv > $1.npv }

print("\nRanking by NPV (Value Creation):")
for (i, result) in ranked.enumerated() {
	print("  \(i + 1). \(result.name.padding(toLength: 18, withPad: " ", startingAt: 0)) NPV: \(result.npv.currency(0, signStrategy: .accounting))")
}

print("\nRecommendation:")
print("  Choose '\(ranked[0].name)' - Highest NPV")
print("  Creates \(ranked[0].npv.currency(0)) of value at \(requiredReturn.percent()) required return")


print("\n\nIrregular Cash Flow Analysis")
print("============================")

// Real investment with irregular timing
let startDate = Date()
let dates = [
	startDate,                                          // Today: Initial investment
	startDate.addingTimeInterval(90 * 86400),          // 90 days: First return
	startDate.addingTimeInterval(250 * 86400),         // 250 days: Second return
	startDate.addingTimeInterval(400 * 86400),         // 400 days: Third return
	startDate.addingTimeInterval(600 * 86400),         // 600 days: Fourth return
	startDate.addingTimeInterval(5 * 365 * 86400)      // 5 years: Exit
]

let irregularCashFlows = [-70_000.0, 8_000, 8_500, 9_000, 9_500, 120_000]

// Calculate XNPV
let xnpvValue = try xnpv(rate: requiredReturn, dates: dates, cashFlows: irregularCashFlows)

print("Using XNPV for Irregular Timing:")
print("  XNPV: \(xnpvValue.currency(2))")

// Calculate XIRR
let xirrValue = try xirr(dates: dates, cashFlows: irregularCashFlows)

print("  XIRR: \(xirrValue.percent(2))")

// Compare to regular IRR
let regularIRR = try irr(cashFlows: irregularCashFlows)

print("\nComparison:")
print("  Regular IRR (assumes annual periods): \(regularIRR.percent(2))")
print("  XIRR (actual dates): \(xirrValue.percent(2))")
print("  Difference: \((xirrValue - regularIRR).percent(2)) percentage points")

// Verify XNPV at XIRR is ~0
let xnpvAtXIRR = try xnpv(rate: xirrValue, dates: dates, cashFlows: irregularCashFlows)
print("\nVerification: XNPV at XIRR = \(xnpvAtXIRR.currency(2))")



print("\n\nRisk-Adjusted Analysis")
print("======================")

// Define risk-adjusted discount rates
let riskFreeRate = 0.03      // Treasury rate
let marketReturn = 0.10      // Stock market average
let beta = 1.5               // Investment risk relative to market

// Calculate risk-adjusted rate using CAPM
let riskAdjustedRate = riskFreeRate + beta * (marketReturn - riskFreeRate)

print("Capital Asset Pricing Model (CAPM):")
print("  Risk-free rate: \(riskFreeRate.percent(1))")
print("  Market return: \(marketReturn.percent(1))")
print("  Beta (risk): \(beta.number(1))")
print("  Risk-adjusted rate: \(riskAdjustedRate.percent(1))")

// Recalculate NPV with risk-adjusted rate
let riskAdjustedNPV = npv(discountRate: riskAdjustedRate, cashFlows: cashFlows)

print("\nRisk-Adjusted NPV:")
print("  Original NPV (12% rate): \(npvValue.currency(2))")
print("  Risk-adjusted NPV (\(riskAdjustedRate.currency(1)) rate): \(riskAdjustedNPV.currency(2))")

if riskAdjustedNPV > 0 {
	print("  ✓ Still positive after risk adjustment")
} else {
	print("  ✗ Negative after accounting for risk")
}

// Scenario planning with probabilities
print("\nScenario Analysis:")
print("Scenario    | Probability | Sale Price | NPV        | Expected Value")
print("------------|-------------|------------|------------|---------------")

let scenarios = [
	(name: "Pessimistic", prob: 0.25, price: 260_000.0),
	(name: "Base Case  ", prob: 0.50, price: 300_000.0),
	(name: "Optimistic ", prob: 0.25, price: 340_000.0)
]

var expectedNPV = 0.0

for scenario in scenarios {
	let proceeds = scenario.price - mortgagePayoff
	let flows = [-initialInvestment, year1, year2, year3, year4, year5 + proceeds]
	let scenarioNPV = npv(discountRate: requiredReturn, cashFlows: flows)
	let expectedValue = scenarioNPV * scenario.prob

	expectedNPV += expectedValue
	print("\(scenario.name.padding(toLength: 11, withPad: " ", startingAt: 0)) | \(scenario.prob.percent(0).paddingLeft(toLength: 11)) | \(scenario.price.currency(0).paddingLeft(toLength: 10)) | \(scenarioNPV.currency(2).paddingLeft(toLength: 10)) | \(expectedValue.currency(2).paddingLeft(toLength: 10))")
}
print("\("Expected".padding(toLength: 11, withPad: " ", startingAt: 0))\(expectedNPV.currency().paddingLeft(toLength: 53))")

print("\nExpected NPV: \(expectedNPV.currency(2))")
if expectedNPV > 0 {
	print("✓ Positive expected value across scenarios")
} else {
	print("✗ Negative expected value")
}

struct InvestmentAnalysis {
	let name: String
	let initialInvestment: Double
	let cashFlows: [Double]
	let requiredReturn: Double

	var npv: Double {
		BusinessMath.npv(discountRate: requiredReturn, cashFlows: cashFlows)
	}

	var irr: Double {
		try! BusinessMath.irr(cashFlows: cashFlows)
	}

	var profitabilityIndex: Double {
		BusinessMath.profitabilityIndex(rate: requiredReturn, cashFlows: cashFlows)
	}

	var paybackPeriod: Int? {
		BusinessMath.paybackPeriod(cashFlows: cashFlows)
	}

	var shouldAccept: Bool {
		npv > 0 && irr > requiredReturn && profitabilityIndex > 1.0
	}

	func printReport() {
		print("\nInvestment Analysis: \(name)")
		print(String(repeating: "=", count: 40))
		print("Initial Investment: \( (-cashFlows[0]).currency())")
		print("Required Return: \(requiredReturn.percent(1))")
		print("\nMetrics:")
		print("  NPV: \(npv.currency(2))")
		print("  IRR: \(irr.percent(2))")
		print("  PI: \(profitabilityIndex.number(2))")
		if let pb = paybackPeriod {
			print("  Payback: \(pb) years")
		}

		print("\nDecision: \(shouldAccept ? "✓ ACCEPT" : "✗ REJECT")")

		if shouldAccept {
			print("  All metrics indicate value creation")
		} else {
			if npv <= 0 { print("  NPV is not positive") }
			if irr <= requiredReturn { print("  IRR below required return") }
			if profitabilityIndex <= 1.0 { print("  PI below 1.0") }
		}
	}
}

// Use the framework
let analysis = InvestmentAnalysis(
	name: "Rental Property Investment",
	initialInvestment: initialInvestment,
	cashFlows: cashFlows,
	requiredReturn: requiredReturn
)

analysis.printReport()

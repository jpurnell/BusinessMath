import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	// Scenario: Mature utility company
	// - Current dividend: $2.50 per share
	// - Expected stable growth: 4% annually
	// - Required return (cost of equity): 9%

	let utilityStock = GordonGrowthModel(
		dividendPerShare: 2.50,
		growthRate: 0.04,
		requiredReturn: 0.09
	)

	let intrinsicValue = utilityStock.valuePerShare()

	print("Gordon Growth Model Valuation")
	print("==============================")
	print("Current Dividend: $2.50")
	print("Growth Rate: 4%")
	print("Required Return: 9%")
print("Intrinsic Value: \(intrinsicValue.currency(2))")
	// Output: Intrinsic Value: $50.00

	// Compare to market price
	let marketPrice = 48.00
	if intrinsicValue > marketPrice {
		let upside = ((intrinsicValue / marketPrice) - 1.0)
		print("Assessment: UNDERVALUED by \(upside.percent(1))")
	} else {
		let downside = (1.0 - (intrinsicValue / marketPrice))
		print("Assessment: OVERVALUED by \(downside.percent(1))")
	}


	// Scenario: Technology company transitioning to maturity
	// - Current dividend: $1.00 per share
	// - High growth phase: 20% for 5 years
	// - Stable growth phase: 5% thereafter
	// - Required return: 12% (higher risk)

	let techStock = TwoStageDDM(
		currentDividend: 1.00,
		highGrowthRate: 0.20,
		highGrowthPeriods: 5,
		stableGrowthRate: 0.05,
		requiredReturn: 0.12
	)

	let techValue = techStock.valuePerShare()

	print("\nTwo-Stage DDM Valuation")
	print("========================")
	print("Current Dividend: $1.00")
	print("High Growth: 20% for 5 years")
	print("Stable Growth: 5% thereafter")
print("Intrinsic Value: \(techValue.currency(2))")

	// Break down the value components
	print("\nValue Components:")
	print("- High growth phase contributes significant premium")
	print("- Terminal value represents long-term stable phase")
	print("- Total captures the growth transition story")

	// Scenario: Emerging market company with declining growth
	// - Current dividend: $2.00
	// - Initial growth: 15% (current high growth)
	// - Terminal growth: 5% (mature growth)
	// - Half-life: 8 years (time for growth to decline)
	// - Required return: 11%

	let emergingStock = HModel(
		currentDividend: 2.00,
		initialGrowthRate: 0.15,
		terminalGrowthRate: 0.05,
		halfLife: 8,
		requiredReturn: 0.11
	)

	let emergingValue = emergingStock.valuePerShare()

	print("\nH-Model Valuation")
	print("==================")
	print("Current Dividend: $2.00")
	print("Growth: 15% declining to 5% over 8 years")
print("Intrinsic Value: \(emergingValue.currency(2))")


	// Scenario: High-growth tech company (no dividends)
	// Project 3 years of cash flows

	let periods = [
		Period.year(2024),
		Period.year(2025),
		Period.year(2026)
	]

	// Operating cash flow projections
	let operatingCF = TimeSeries(
		periods: periods,
		values: [500.0, 600.0, 720.0]  // Growing 20% per year (in millions)
	)

	// Capital expenditure requirements
	let capEx = TimeSeries(
		periods: periods,
		values: [100.0, 120.0, 144.0]  // Also growing 20%
	)

	// FCFE Model
	let fcfeModel = FCFEModel(
		operatingCashFlow: operatingCF,
		capitalExpenditures: capEx,
		netBorrowing: nil,  // No change in debt
		costOfEquity: 0.12,
		terminalGrowthRate: 0.05
	)

	// Calculate total equity value
	let totalEquityValue = fcfeModel.equityValue()

	// Value per share (100M shares outstanding)
	let sharesOutstanding = 100.0
	let fcfeSharePrice = fcfeModel.valuePerShare(sharesOutstanding: sharesOutstanding)

	print("\nFCFE Model Valuation")
	print("====================")
print("Total Equity Value: \(totalEquityValue.currency(0))M")
 print("Shares Outstanding: \(sharesOutstanding.number(0))M")
 print("Value Per Share: \(fcfeSharePrice.currency(2))")

	// Show the FCFE calculation for transparency
	let fcfeValues = fcfeModel.fcfe()
	print("\nProjected FCFE:")
	for (period, value) in zip(fcfeValues.periods, fcfeValues.valuesArray) {
		print("  \(period.label): \(value.currency(0))M")
	}


	// Scenario: Complete DCF workflow
	// Step 1: Calculate Enterprise Value from FCFF

	let fcffPeriods = [
		Period.year(2024),
		Period.year(2025),
		Period.year(2026)
	]

	let fcff = TimeSeries(
		periods: fcffPeriods,
		values: [150.0, 165.0, 181.5]  // Growing 10% (in millions)
	)

	// Calculate Enterprise Value
	let enterpriseValue = enterpriseValueFromFCFF(
		freeCashFlowToFirm: fcff,
		wacc: 0.09,
		terminalGrowthRate: 0.03
	)

	print("\nEnterprise Value Bridge")
	print("========================")
print("Enterprise Value: \(enterpriseValue.currency(0))M")

	// Step 2: Bridge to Equity Value
	let bridge = EnterpriseValueBridge(
		enterpriseValue: enterpriseValue,
		totalDebt: 500.0,           // Total debt outstanding
		cash: 100.0,                // Cash and equivalents
		nonOperatingAssets: 50.0,   // Marketable securities
		minorityInterest: 20.0,     // Minority shareholders' value
		preferredStock: 30.0        // Preferred equity
	)

	// Get detailed breakdown
	let breakdown = bridge.breakdown()

	print("\nBridge to Equity:")
print("  Enterprise Value:      \(breakdown.enterpriseValue.currency(0).paddingLeft(toLength: 6))M")
	print("  - Net Debt:            \(breakdown.netDebt.currency(0).paddingLeft(toLength: 6))M")
	print("  + Non-Op Assets:       \(breakdown.nonOperatingAssets.currency(0).paddingLeft(toLength: 6))M")
	print("  - Minority Interest:   \(breakdown.minorityInterest.currency(0).paddingLeft(toLength: 6))M")
	print("  - Preferred Stock:     \(breakdown.preferredStock.currency(0).paddingLeft(toLength: 6))M")
	print("  " + String(repeating: "=", count: 30))
	print("  Common Equity Value:   \(breakdown.equityValue.currency(0).paddingLeft(toLength: 6))M")

	// Value per share
	let bridgeSharePrice = bridge.valuePerShare(sharesOutstanding: 100.0)
	print("\nValue Per Share: \(bridgeSharePrice.currency(2))")


	// Scenario: Regional bank
	// Book value is meaningful, and accounting is relatively clean

	let riPeriods = [
		Period.year(2024),
		Period.year(2025),
		Period.year(2026)
	]

	// Projected earnings
	let netIncome = TimeSeries(
		periods: riPeriods,
		values: [120.0, 126.0, 132.3]  // 5% growth
	)

	// Book value of equity
	let bookValue = TimeSeries(
		periods: riPeriods,
		values: [1000.0, 1050.0, 1102.5]  // Growing with retained earnings
	)

	let riModel = ResidualIncomeModel(
		currentBookValue: 1000.0,
		netIncome: netIncome,
		bookValue: bookValue,
		costOfEquity: 0.10,
		terminalGrowthRate: 0.03
	)

	// Calculate equity value
	let riEquityValue = riModel.equityValue()
	let riSharePrice = riModel.valuePerShare(sharesOutstanding: 100.0)

	print("\nResidual Income Model")
	print("======================")
print("Current Book Value: \(riModel.currentBookValue.currency(0))M")
print("Equity Value: \(riEquityValue.currency(0))M")
print("Value Per Share: \(riSharePrice.currency(2))")
print("Book Value Per Share: \((riModel.currentBookValue / 100.0).currency(2))")

	// Calculate key metrics
	let priceToBooksRatio = riSharePrice / (riModel.currentBookValue / 100.0)
print("\nPrice-to-Book Ratio: \(priceToBooksRatio.number(2))x")

	// Show residual income (economic profit)
	let residualIncome = riModel.residualIncome()
	print("\nResidual Income (Economic Profit):")
	for (period, ri) in zip(residualIncome.periods, residualIncome.valuesArray) {
		if ri > 0 {
			print("  \(period.label): \(ri.currency(1))M (creating value)")
		} else {
			print("  \(period.label): \(ri.currency(1))M (destroying value)")
		}
	}

	// ROE analysis
	let roe = riModel.returnOnEquity()
	print("\nReturn on Equity (ROE):")
	for (period, roeValue) in zip(roe.periods, roe.valuesArray) {
		let spread = roeValue - riModel.costOfEquity
		print("  \(period.label): \(roeValue.percent(1)) (spread: \(spread.percent(1)))")
	}


	// Comprehensive valuation summary
	print("\n" + String(repeating: "=", count: 50))
	print("COMPREHENSIVE EQUITY VALUATION SUMMARY")
	print(String(repeating: "=", count: 50))

	struct ValuationSummary {
		let method: String
		let value: Double
		let confidence: String
		let applicability: String
	}

	// Collect all valuations (per share)
	let valuations = [
		ValuationSummary(
			method: "Gordon Growth DDM",
			value: intrinsicValue,
			confidence: "High",
			applicability: "Stable dividend payers"
		),
		ValuationSummary(
			method: "Two-Stage DDM",
			value: techValue,
			confidence: "Medium",
			applicability: "Growth-to-maturity transition"
		),
		ValuationSummary(
			method: "H-Model",
			value: emergingValue,
			confidence: "Medium",
			applicability: "Declining growth scenarios"
		),
		ValuationSummary(
			method: "FCFE Model",
			value: fcfeSharePrice,
			confidence: "High",
			applicability: "All companies with CF data"
		),
		ValuationSummary(
			method: "EV Bridge",
			value: bridgeSharePrice,
			confidence: "High",
			applicability: "Firm-level DCF to equity"
		),
		ValuationSummary(
			method: "Residual Income",
			value: riSharePrice,
			confidence: "High",
			applicability: "Financial institutions"
		)
	]

	print("\nValuation Method Comparison:")
	print(String(repeating: "-", count: 50))

	for valuation in valuations {
		print("\n\(valuation.method)")
		print("  Value: \(valuation.value.currency(2))")
		print("  Confidence: \(valuation.confidence)")
		print("  Best for: \(valuation.applicability)")
	}

	// Calculate valuation range
	let allValues = valuations.map { $0.value }
	let minValue = allValues.min() ?? 0
	let maxValue = allValues.max() ?? 0
	let avgValue = allValues.reduce(0, +) / Double(allValues.count)
	let medianValue = allValues.sorted()[allValues.count / 2]

	print("\n" + String(repeating: "-", count: 50))
	print("VALUATION RANGE SUMMARY")
	print(String(repeating: "-", count: 50))
print("Minimum:  \(minValue.currency(2))")
print("Maximum:  \(maxValue.currency(2))")
print("Average:  \(avgValue.currency(2))")
print("Median:   \(medianValue.currency(2))")
	print("\nMarket Price: $48.00")
	print("\nInvestment Decision:")
	if avgValue > 48.00 {
		let upside = ((avgValue / 48.00) - 1.0)
		print("  ✓ BUY - Average upside of \(upside.percent(1))")
	} else {
		let downside = (1.0 - (avgValue / 48.00))
		print("  ✗ SELL/AVOID - Average downside of \(downside.percent(1))")
	}



print("\n" + String(repeating: "=", count: 50))
print("SENSITIVITY ANALYSIS")
print(String(repeating: "=", count: 50))

// Test Gordon Growth sensitivity to cost of equity
print("\nGordon Growth: Sensitivity to Cost of Equity")
print("(Dividend: $2.50, Growth: 4%)")
print(String(repeating: "-", count: 50))

let costRange = stride(from: 0.08, through: 0.12, by: 0.01)
for cost in costRange {
	let model = GordonGrowthModel(
		dividendPerShare: 2.50,
		growthRate: 0.04,
		requiredReturn: cost
	)
	let value = model.valuePerShare()
	let costPercent = cost * 100
	print("  Cost of Equity: \(cost.percent(1).paddingLeft(toLength: 5)) →  Value: \(value.currency(2))")
}

// Test sensitivity to growth rate
print("\nGordon Growth: Sensitivity to Growth Rate")
print("(Dividend: $2.50, Cost of Equity: 9%)")
print(String(repeating: "-", count: 50))

let growthRange = stride(from: 0.02, through: 0.06, by: 0.01)
for growth in growthRange {
	let model = GordonGrowthModel(
		dividendPerShare: 2.50,
		growthRate: growth,
		requiredReturn: 0.09
	)
	print("  Growth Rate: \(growth.percent(1).paddingLeft(toLength: 5)) →  Value: \(model.valuePerShare().currency(2))")
}

print("\n⚠️  Key Takeaway:")
print("Equity valuations are highly sensitive to assumptions.")
print("Small changes in cost of equity or growth rates can")
print("dramatically impact intrinsic value. Always model multiple")
print("scenarios (base case, bull case, bear case).")



print("\n" + String(repeating: "=", count: 50))
print("REAL-WORLD EXAMPLE: VALUING A REIT")
print(String(repeating: "=", count: 50))

// Scenario: Real Estate Investment Trust (REIT)
// REITs must distribute 90% of income as dividends, making
// DDM and FCFE models particularly appropriate

// Current metrics
let currentFFO = 5.00  // Funds From Operations per share
let payoutRatio = 0.90
let currentDividend = currentFFO * payoutRatio  // $4.50

print("\nREIT Characteristics:")
print("  FFO per share: \(currentFFO.currency(2))")
print("  Payout ratio: \(payoutRatio.percent(1))")
print("  Current dividend: \(currentDividend.currency(2))")

// REITs typically grow with inflation + occupancy improvements
let reitGrowth = 0.03  // 3% (conservative)
let reitRequiredReturn = 0.08  // 8% (REITs are income-focused)

let reitValuation = GordonGrowthModel(
	dividendPerShare: currentDividend,
	growthRate: reitGrowth,
	requiredReturn: reitRequiredReturn
)

let reitValue = reitValuation.valuePerShare()

print("\nValuation:")
print("  Growth assumption: 3% (inflation-driven)")
print("  Required return: 8% (income-focused investors)")
print("  Intrinsic value: \(reitValue.currency(2))")

// Key metrics for REITs
let dividendYield = currentDividend / reitValue
let priceToFFO = reitValue / currentFFO

print("\nKey REIT Metrics:")
print("  Dividend Yield: \(dividendYield.percent(1))")
print("  Price/FFO: \(priceToFFO.number(1))x")
print("\n💡 For REITs, compare to:")
print("   - Sector average dividend yield (typically 3-5%)")
print("   - Price/FFO multiples of comparable REITs (15-20x)")
print("   - 10-year Treasury yield (income alternative)")

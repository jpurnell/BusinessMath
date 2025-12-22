import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

//	// Scenario: 5-year corporate bond
//	// - Face value: $1,000
//	// - Annual coupon: 6%
//	// - Semiannual payments
//	// - Current market yield: 5%
//
//	let calendar = Calendar.current
//	let today = Date()
//	let maturity = calendar.date(byAdding: .year, value: 5, to: today)!
//
//	let bond = Bond(
//		faceValue: 1000.0,
//		couponRate: 0.06,
//		maturityDate: maturity,
//		paymentFrequency: .semiAnnual,
//		issueDate: today
//	)
//
//	let marketPrice = bond.price(yield: 0.05, asOf: today)
//
//	print("Bond Pricing")
//	print("============")
//	print("Face Value: $1,000")
//	print("Coupon Rate: 6%")
//	print("Market Yield: 5%")
//	print("Price: \(marketPrice.currency(2))")
//	// Output: Price: $1,043.30 (trades at premium since coupon > yield)
//
//	// Calculate current yield
//	let currentYield = bond.currentYield(price: marketPrice)
//	print("Current Yield: \(currentYield.percent(2))")
//	// Output: Current Yield: 5.75%
//
//
//	// Scenario: Find YTM given market price
//
//	let observedPrice = 980.00  // Trading below par
//
//	do {
//		let ytm = try bond.yieldToMaturity(price: observedPrice, asOf: today)
//
//		print("\nYield to Maturity Analysis")
//		print("=========================")
//		print("Market Price: \(observedPrice.currency(2))")
//		print("YTM: \(ytm.percent(2))")
//
//		// Verify round-trip: Price → YTM → Price
//		let verifyPrice = bond.price(yield: ytm, asOf: today)
//		print("Verification Price: \(verifyPrice.currency(2))")
//		print("Difference: \(abs(verifyPrice - observedPrice).currency(2))")
//
//	} catch {
//		print("YTM calculation failed: \(error)")
//	}
//
//
//	// Duration measures price sensitivity to yield changes
//
//	let yield = 0.05
//
//	let macaulayDuration = bond.macaulayDuration(yield: yield, asOf: today)
//	let modifiedDuration = bond.modifiedDuration(yield: yield, asOf: today)
//	let convexity = bond.convexity(yield: yield, asOf: today)
//
//	print("\nInterest Rate Risk Metrics")
//	print("==========================")
//print("Macaulay Duration: \(macaulayDuration.number(2)) years")
//print("Modified Duration: \(modifiedDuration.number(2))")
//print("Convexity: \(convexity.number(2))")
//
//	// Estimate price change from 1% yield increase
//	let yieldChange = 0.01  // 100 bps
//	let priceChange = -modifiedDuration * yieldChange
//
//	print("\nIf yield increases by 100 bps:")
//	print("Estimated price change: \(priceChange.percent(2))")
//
//	// More accurate estimate using convexity
//	let convexityAdjustment = 0.5 * convexity * yieldChange * yieldChange
//	let improvedEstimate = priceChange + convexityAdjustment
//
//print("With convexity adjustment: \(improvedEstimate.percent(2))")
//
//	// Actual price change
//	let newPrice = bond.price(yield: yield + yieldChange, asOf: today)
//	let originalPrice = bond.price(yield: yield, asOf: today)
//	let actualChange = ((newPrice / originalPrice) - 1.0)
//
//print("Actual price change: \(actualChange.percent(2))")
//
//
//	// Scenario: Price a corporate bond given company fundamentals
//
//	// Step 1: Start with company credit metrics (Altman Z-Score)
//	let zScore = 2.3  // Grey zone (moderate credit risk)
//
//	// Step 2: Convert Z-Score to default probability
//	let creditModel = CreditSpreadModel<Double>()
//	let defaultProbability = creditModel.defaultProbability(zScore: zScore)
//
//	print("\nCredit Risk Analysis")
//	print("====================")
//print("Z-Score: \(zScore.number(2))")
//print("Default Probability: \(defaultProbability.percent(2))")
//
//	// Step 3: Determine recovery rate based on seniority
//	let seniority = Seniority.seniorUnsecured
//	let recoveryRate = RecoveryModel<Double>.standardRecoveryRate(
//		seniority: seniority
//	)
//
//	print("Seniority: Senior Unsecured")
//print("Expected Recovery: \(recoveryRate.percent(0))")
//
//	// Step 4: Calculate credit spread
//	let creditSpread = creditModel.creditSpread(
//		defaultProbability: defaultProbability,
//		recoveryRate: recoveryRate,
//		maturity: 5.0
//	)
//
//print("Credit Spread: \((creditSpread * 10000).number()) bps")
//
//	// Step 5: Calculate corporate bond yield
//	let riskFreeRate = 0.03  // 3% Treasury
//	let corporateYield = creditModel.corporateBondYield(
//		riskFreeRate: riskFreeRate,
//		creditSpread: creditSpread
//	)
//
//print("Risk-Free Rate: \(riskFreeRate.percent(2))")
//print("Corporate Yield: \(corporateYield.percent(2))")
//
//	// Step 6: Price the bond
//	let corporateBond = Bond(
//		faceValue: 1000.0,
//		couponRate: 0.05,  // 5% coupon
//		maturityDate: maturity,
//		paymentFrequency: .semiAnnual,
//		issueDate: today
//	)
//
//	let corporatePrice = corporateBond.price(yield: corporateYield, asOf: today)
//print("Bond Price: \(corporatePrice.currency(2))")
//
//
//
//	// Compare prices across credit quality spectrum
//
//	let scenarios = [
//		(name: "Investment Grade", zScore: 3.5),
//		(name: "Grey Zone", zScore: 2.0),
//		(name: "Distress", zScore: 1.0)
//	]
//
//	print("\nCredit Deterioration Impact")
//	print("===========================")
//
//	for scenario in scenarios {
//		let pd = creditModel.defaultProbability(zScore: scenario.zScore)
//		let spread = creditModel.creditSpread(
//			defaultProbability: pd,
//			recoveryRate: recoveryRate,
//			maturity: 5.0
//		)
//		let yld = riskFreeRate + spread
//		let price = corporateBond.price(yield: yld, asOf: today)
//
//		print("\n\(scenario.name):")
//		print("  Z-Score: \(scenario.zScore.number(1))")
//		print("  Default Prob: \(pd.percent(1))")
//		print("  Spread: \((spread * 10000).number(0)) bps")
//		print("  Price: \(price.currency(2))")
//	}
//
//
//	// Scenario: High-coupon callable bond
//	// Issuer has option to refinance if rates fall
//
//	let highCouponBond = Bond(
//		faceValue: 1000.0,
//		couponRate: 0.07,  // 7% coupon (above market)
//		maturityDate: calendar.date(byAdding: .year, value: 10, to: today)!,
//		paymentFrequency: .semiAnnual,
//		issueDate: today
//	)
//
//	// Callable after 3 years at 1040 (4% premium)
//	let callDate = calendar.date(byAdding: .year, value: 3, to: today)!
//	let callSchedule = [CallProvision(date: callDate, callPrice: 1040.0)]
//
//	let callableBond = CallableBond(
//		bond: highCouponBond,
//		callSchedule: callSchedule
//	)
//
//	let volatility = 0.15  // 15% interest rate volatility
//
//	// Step 1: Price non-callable bond
//	let straightYield = riskFreeRate + creditSpread
//	let straightPrice = highCouponBond.price(yield: straightYield, asOf: today)
//
//	// Step 2: Price callable bond
//	let callablePrice = callableBond.price(
//		riskFreeRate: riskFreeRate,
//		spread: creditSpread,
//		volatility: volatility,
//		asOf: today
//	)
//
//	// Step 3: Calculate embedded option value
//	let callOptionValue = callableBond.callOptionValue(
//		riskFreeRate: riskFreeRate,
//		spread: creditSpread,
//		volatility: volatility,
//		asOf: today
//	)
//
//	print("\nCallable Bond Analysis")
//	print("======================")
//print("Non-Callable Price: \(straightPrice.currency(2))")
//print("Callable Price: \(callablePrice.currency(2))")
//print("Call Option Value: \(callOptionValue.currency(2))")
//print("Difference: \((straightPrice - callablePrice).currency(2))")
//
//	// Step 4: Calculate Option-Adjusted Spread (OAS)
//	do {
//		let oas = try callableBond.optionAdjustedSpread(
//			marketPrice: callablePrice,
//			riskFreeRate: riskFreeRate,
//			volatility: volatility,
//			asOf: today
//		)
//
//		print("\nSpread Decomposition:")
//		print("Nominal Spread: \((creditSpread * 10000).number(0)) bps")
//		print("OAS (credit only): \((oas * 10000).number(0)) bps")
//		print("Option Spread: \(((creditSpread - oas) * 10000).number(0)) bps")
//
//	} catch {
//		print("OAS calculation failed: \(error)")
//	}
//
//	// Step 5: Effective duration (accounts for call option)
//	let effectiveDuration = callableBond.effectiveDuration(
//		riskFreeRate: riskFreeRate,
//		spread: creditSpread,
//		volatility: volatility,
//		asOf: today
//	)
//
//	let straightDuration = highCouponBond.macaulayDuration(
//		yield: straightYield,
//		asOf: today
//	)
//
//	print("\nDuration Comparison:")
//print("Non-Callable Duration: \(straightDuration.number(2)) years")
//print("Effective Duration: \(effectiveDuration.number(2)) years")
//print("Duration Reduction: \(((1 - effectiveDuration / straightDuration).percent(1)))")
//
//
//
//	// Build credit curve from market observations
//
//	let periods = [
//		Period.year(1),
//		Period.year(3),
//		Period.year(5),
//		Period.year(10)
//	]
//
//	// Observed credit spreads (typically upward sloping)
//	let marketSpreads = TimeSeries(
//		periods: periods,
//		values: [0.005, 0.012, 0.018, 0.025]  // 50, 120, 180, 250 bps
//	)
//
//	let creditCurve = CreditCurve(
//		spreads: marketSpreads,
//		recoveryRate: recoveryRate
//	)
//
//	print("\nCredit Curve Analysis")
//	print("=====================")
//
//	// Interpolate spreads for any maturity
//	for years in [2.0, 7.0] {
//		let spread = creditCurve.spread(maturity: years)
//		print("\(years.number(0))-Year Spread: \((spread * 10000).number(0)) bps")
//	}
//
//	// Calculate cumulative default probabilities
//	print("\nCumulative Default Probabilities:")
//	for year in [1, 3, 5, 10] {
//		let cdp = creditCurve.cumulativeDefaultProbability(maturity: Double(year))
//		let survival = 1.0 - cdp
//
//		print("\("\(year)-Year:".paddingLeft(toLength: 8)) \(cdp.percent(2)) default, \(survival.percent(2)) survival")
//	}
//
//	// Extract hazard rates (forward default intensities)
//	print("\nHazard Rates (Default Intensity):")
//	for year in [1, 5, 10] {
//		let hazard = creditCurve.hazardRate(maturity: Double(year))
//		print("\("\(year)-Year:".paddingLeft(toLength: 8)) \(hazard.percent(2)) per year")
//	}
//
//
//	// Scenario: Bond portfolio with different seniorities
//	// All bonds from same issuer (Z-Score = 2.0)
//
//	let portfolioZScore = 2.0
//	let portfolioPD = creditModel.defaultProbability(zScore: portfolioZScore)
//
//	let recoveryModel = RecoveryModel<Double>()
//
//	let positions = [
//		(name: "Senior Secured", exposure: 5_000_000.0, seniority: Seniority.seniorSecured),
//		(name: "Senior Unsecured", exposure: 3_000_000.0, seniority: Seniority.seniorUnsecured),
//		(name: "Subordinated", exposure: 2_000_000.0, seniority: Seniority.subordinated)
//	]
//
//	print("\nPortfolio Credit Risk")
//	print("=====================")
//print("Issuer Z-Score: \(portfolioZScore.number(1))")
//print("Default Probability: \(portfolioPD.percent(2))\n")
//
//	var totalExposure = 0.0
//	var totalExpectedLoss = 0.0
//
//	for position in positions {
//		let recovery = RecoveryModel<Double>.standardRecoveryRate(
//			seniority: position.seniority
//		)
//
//		let expectedLoss = recoveryModel.expectedLoss(
//			defaultProbability: portfolioPD,
//			recoveryRate: recovery,
//			exposure: position.exposure
//		)
//
//		let lossRate = (expectedLoss / position.exposure)
//
//		print("\(position.name):")
//		print("  Exposure: \(position.exposure.currency(2))")
//		print("  Recovery: \(recovery.percent(1))")
//		print("  Expected Loss: \(expectedLoss.currency(2))")
//		print("  Loss Rate: \(lossRate.percent(2))")
//		print()
//
//		totalExposure += position.exposure
//		totalExpectedLoss += expectedLoss
//	}
//
//	print("Portfolio Totals:")
//print("Total Exposure: \(totalExposure.currency(0))")
//print("Total Expected Loss: \(totalExpectedLoss.currency(0))")
//print("Reserve Ratio: \((totalExpectedLoss / totalExposure).percent(2))")
//
//
//	// Test callable bond pricing across volatility scenarios
//
//	let volatilityScenarios = [
//		(name: "Low Vol", vol: 0.05),
//		(name: "Normal Vol", vol: 0.15),
//		(name: "High Vol", vol: 0.25)
//	]
//
//	print("\nVolatility Impact on Callable Bonds")
//	print("====================================")
//
//	for scenario in volatilityScenarios {
//		let price = callableBond.price(
//			riskFreeRate: riskFreeRate,
//			spread: creditSpread,
//			volatility: scenario.vol,
//			asOf: today
//		)
//
//		let optionValue = callableBond.callOptionValue(
//			riskFreeRate: riskFreeRate,
//			spread: creditSpread,
//			volatility: scenario.vol,
//			asOf: today
//		)
//
//		print("\n\(scenario.name) (\(scenario.vol.percent(0))):")
//		print("  Bond Price: \(price.currency(2))")
//		print("  Option Value: \(optionValue.currency(2))")
//	}
//
//	print("\nKey Relationship:")
//	print("Higher volatility → More valuable call option → Lower bond price")
//
//
//	// Round-trip validation: Spread → Implied Recovery → Spread
//
//	print("\nModel Cross-Validation")
//	print("======================")
//
//	// Start with known parameters
//	let testPD = 0.02
//	let testRecovery = 0.40
//	let testMaturity = 5.0
//
//	// Calculate spread
//	let testSpread = creditModel.creditSpread(
//		defaultProbability: testPD,
//		recoveryRate: testRecovery,
//		maturity: testMaturity
//	)
//
//	// Reverse-engineer recovery rate
//	let impliedRecovery = recoveryModel.impliedRecoveryRate(
//		spread: testSpread,
//		defaultProbability: testPD,
//		maturity: testMaturity
//	)
//
//print("Original Recovery: \(testRecovery.percent(1))")
//print("Implied Recovery: \(impliedRecovery.percent(1))")
//print("Difference: \(abs(impliedRecovery - testRecovery).percent(2))")
//
//	// Price → YTM → Price validation
//	do {
//		let testBond = Bond(
//			faceValue: 1000.0,
//			couponRate: 0.05,
//			maturityDate: maturity,
//			paymentFrequency: .semiAnnual,
//			issueDate: today
//		)
//
//		let price1 = testBond.price(yield: corporateYield, asOf: today)
//		let ytmCalculated = try testBond.yieldToMaturity(price: price1, asOf: today)
//		let price2 = testBond.price(yield: ytmCalculated, asOf: today)
//
//		print("\nPrice → YTM → Price:")
//		print("Original Price: \(price1.currency(2))")
//		print("Calculated YTM: \(ytmCalculated.percent(4))")
//		print("Final Price: \(price2.currency(2))")
//		print("Price Difference: \(abs(price2 - price1).currency(4))")
//
//	} catch {
//		print("Validation failed: \(error)")
//	}



print("\n" + String(repeating: "=", count: 60))
print("COMPLETE BOND ANALYSIS EXAMPLE")
print(String(repeating: "=", count: 60))

// Company Profile
print("\nCompany: ABC Manufacturing Corp")
print("Credit Rating Equivalent: BBB- (grey zone)")
print("Altman Z-Score: 2.2")

// Bond Specifications
print("\nBond Specifications:")
print("  Face Value: $1,000")
print("  Coupon: 5.5%")
print("  Maturity: 7 years")
print("  Payment Frequency: Semiannual")
print("  Seniority: Senior Unsecured")
print("  Callable: Yes, after 3 years at $1,030")

let calendar = Calendar.current
let today = Date()

	// Step 1: Credit Analysis
let creditModel = CreditSpreadModel<Double>()
let companyZScore = 2.2
let companyPD = creditModel.defaultProbability(zScore: companyZScore)
let companySeniority = Seniority.seniorUnsecured
let companyRecovery = RecoveryModel<Double>.standardRecoveryRate(
	seniority: companySeniority
)

print("\nCredit Analysis:")
print("  Default Probability: \(companyPD.percent(2))")
print("  Expected Recovery: \(companyRecovery.percent(0))")

// Step 2: Spread Calculation
let maturityYears = 7.0
let companySpread = creditModel.creditSpread(
	defaultProbability: companyPD,
	recoveryRate: companyRecovery,
	maturity: maturityYears
)

print("  Credit Spread: \((companySpread * 10000).number(0)) bps")

// Step 3: Bond Pricing
let analysisMaturity = calendar.date(byAdding: .year, value: 7, to: today)!

let analysisBond = Bond(
	faceValue: 1000.0,
	couponRate: 0.055,
	maturityDate: analysisMaturity,
	paymentFrequency: .semiAnnual,
	issueDate: today
)

let riskFree = 0.030  // 3.0% Treasury
let fairYield = riskFree + companySpread
let fairValue = analysisBond.price(yield: fairYield, asOf: today)

print("\nValuation:")
print("  Risk-Free Rate: \(riskFree.percent(2))")
print("  Fair Yield: \(fairYield.percent(2))")
print("  Fair Value: \(fairValue.currency(2))")

// Step 4: Callable Bond Adjustment
let analysisCallDate = calendar.date(byAdding: .year, value: 3, to: today)!
let analysisCallSchedule = [CallProvision(date: analysisCallDate, callPrice: 1030.0)]

let analysisCallable = CallableBond(
	bond: analysisBond,
	callSchedule: analysisCallSchedule
)

let callableValue = analysisCallable.price(
	riskFreeRate: riskFree,
	spread: companySpread,
	volatility: 0.15,
	asOf: today
)

let callCost = fairValue - callableValue

print("\nCallable Bond:")
print("  Straight Value: \(fairValue.currency(2))")
print("  Callable Value: \(callableValue.currency(2))")
print("  Call Option Cost: \(callCost.currency(2))")

// Step 5: Risk Metrics
let bondDuration = analysisBond.macaulayDuration(yield: fairYield, asOf: today)
let bondConvexity = analysisBond.convexity(yield: fairYield, asOf: today)
let callableDuration = analysisCallable.effectiveDuration(
	riskFreeRate: riskFree,
	spread: companySpread,
	volatility: 0.15,
	asOf: today
)

print("\nRisk Metrics:")
print("  Duration (straight): \(bondDuration.number(2)) years")
print("  Duration (callable): \(callableDuration.number(2)) years")
print("  Convexity: \(bondConvexity.number(2))")

// Step 6: Investment Decision
let marketPrice = 1015.00  // Hypothetical market price

print("\nInvestment Decision:")
print("  Market Price: \(marketPrice.currency(2))")
print("  Fair Value: \(callableValue.currency(2))")

if callableValue > marketPrice {
	let upside = ((callableValue / marketPrice) - 1.0)
	print("  Assessment: UNDERVALUED by \(upside.percent(1))")
	print("  Recommendation: BUY")
} else {
	let downside = (1.0 - (callableValue / marketPrice))
	print("  Assessment: OVERVALUED by \(downside.percent(1))")
	print("  Recommendation: AVOID or SELL")
}

print("\n" + String(repeating: "=", count: 60))

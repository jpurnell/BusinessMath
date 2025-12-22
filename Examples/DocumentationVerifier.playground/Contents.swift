import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	// Scenario: 5-year CDS on a BBB-rated corporate
	// - Reference entity: ABC Manufacturing
	// - Notional: $10 million
	// - CDS Spread: 150 basis points (1.5%)
	// - Recovery assumption: 40%

	let cds = CDS(
		notional: 10_000_000.0,
		spread: 0.0150,  // 150 bps
		maturity: 5.0,
		recoveryRate: 0.40,
		paymentFrequency: .quarterly
	)

	print("CDS Contract Overview")
	print("=====================")
	print("Notional: $10,000,000")
	print("Spread: 150 bps")
	print("Maturity: 5 years")
	print("Recovery: 40%")
	print("Frequency: Quarterly")

	// Build discount curve (flat 5% risk-free rate for simplicity)
	let riskFreeRate = 0.05
	let numPeriods = Int(5.0 * 4)  // 5 years, quarterly

	var periods: [Period] = []
	var discountFactors: [Double] = []

for i in 1...numPeriods {
		let t = Double(i) / 4.0
		periods.append(Period.year(2024 + Int(t)))
		discountFactors.append(exp(-riskFreeRate * t))
	}

	let discountCurve = TimeSeries(periods: periods, values: discountFactors)

	// Build survival curve (assumes 2% constant hazard rate)
	let hazardRate = 0.02
	var survivalProbs: [Double] = []

	for i in 1...numPeriods {
		let t = Double(i) / 4.0
		// Survival probability: S(t) = exp(-λt)
		survivalProbs.append(exp(-hazardRate * t))
	}

	let survivalCurve = TimeSeries(periods: periods, values: survivalProbs)

	// Calculate premium leg value
	let premiumPV = cds.premiumLegPV(
		discountCurve: discountCurve,
		survivalProbabilities: survivalCurve
	)

	print("\nPremium Leg Valuation")
	print("=====================")
print("Hazard Rate: \(hazardRate.percent(2))")
print("5Y Survival Probability: \(survivalProbs.last!.percent(2))")
print("Premium Leg PV: \(premiumPV.currency(2))")
print("Annual Premium: \((10_000_000 * 0.0150).currency(2))")


	// Calculate protection leg value
	let protectionPV = cds.protectionLegPV(
		discountCurve: discountCurve,
		survivalProbabilities: survivalCurve
	)

	let lossGivenDefault = 1.0 - 0.40  // 60% loss

	print("\nProtection Leg Valuation")
	print("========================")
print("Loss Given Default: \(lossGivenDefault.percent(0))")
print("Protection Leg PV: \(protectionPV.currency(2))")
print("Max Payout (if default): \((10_000_000 * lossGivenDefault).currency(2))")


	// Calculate fair spread
	let fairSpread = cds.fairSpread(
		discountCurve: discountCurve,
		hazardRate: hazardRate
	)

	let fairSpreadBps = fairSpread * 10000

	print("\nFair Spread Calculation")
	print("=======================")
print("Premium Leg PV: \(premiumPV.currency(2))")
print("Protection Leg PV: \(protectionPV.currency(2))")
print("Fair Spread: \(fairSpreadBps.number(0)) bps")
	print("Market Spread: 150 bps")

	if fairSpreadBps > 150 {
		print("Assessment: CDS is CHEAP (protection underpriced)")
	} else {
		print("Assessment: CDS is RICH (protection overpriced)")
	}


	// Scenario: Bought protection at 150 bps, market now at 200 bps
	let contractSpread = 0.0150
	let marketSpread = 0.0200
	let marketHazard = 0.025  // Implied from 200 bps

	let mtm = cds.mtm(
		contractSpread: contractSpread,
		marketSpread: marketSpread,
		discountCurve: discountCurve,
		hazardRate: marketHazard
	)

	print("\nMark-to-Market")
	print("==============")
	print("Contract Spread: 150 bps")
	print("Market Spread: 200 bps")
	print("MTM Value: \(mtm.currency(2))")

	if mtm > 0 {
		print("Status: IN-THE-MONEY (credit quality deteriorated)")
	} else {
		print("Status: OUT-OF-THE-MONEY (credit quality improved)")
	}


	// Scenario: Publicly-traded manufacturing firm
	// - Market cap (equity): $50 million
	// - Book value of debt: $80 million
	// - Asset volatility: 25% (estimated)
	// - Debt maturity: 1 year

	let assetValue = 100_000_000.0  // Estimated from equity + debt
	let assetVolatility = 0.25
	let debtFaceValue = 80_000_000.0
//	let riskFreeRate = 0.05
	let maturity = 1.0

	let mertonModel = MertonModel(
		assetValue: assetValue,
		assetVolatility: assetVolatility,
		debtFaceValue: debtFaceValue,
		riskFreeRate: riskFreeRate,
		maturity: maturity
	)

	// Calculate metrics
	let equityValue = mertonModel.equityValue()
	let debtValue = mertonModel.debtValue()
	let defaultProb = mertonModel.defaultProbability()
	let distanceToDefault = mertonModel.distanceToDefault()
	let creditSpread = mertonModel.creditSpread()

	print("\nMerton Model Analysis")
	print("=====================")
print("Asset Value: \((assetValue / 1_000_000).currency(1))M")
print("Asset Volatility: \(assetVolatility.percent(1))")
print("Debt (Face): \((debtFaceValue / 1_000_000).currency(1))M")
	print("\nResults:")
print("Equity Value: \((equityValue / 1_000_000).currency(1))M")
print("Debt Value: \((debtValue / 1_000_000).currency(1))M")
print("Default Probability: \((defaultProb).percent(2))%")
print("Distance to Default: \(distanceToDefault.number(2)) σ")
print("Credit Spread: \((creditSpread * 10000).number(0)) bps")


	// Test different leverage scenarios
	let scenarios = [
		(name: "Low Leverage", assets: 150.0, debt: 80.0),
		(name: "Moderate Leverage", assets: 100.0, debt: 80.0),
		(name: "High Leverage", assets: 90.0, debt: 80.0)
	]

	print("\nDistance to Default Scenarios")
	print("=============================")

	for scenario in scenarios {
		let model = MertonModel(
			assetValue: scenario.assets * 1_000_000,
			assetVolatility: 0.25,
			debtFaceValue: scenario.debt * 1_000_000,
			riskFreeRate: 0.05,
			maturity: 1.0
		)

		let dd = model.distanceToDefault()
		let pd = model.defaultProbability()

		let rating = dd > 4 ? "AAA/AA" :
					 dd > 3 ? "A" :
					 dd > 2 ? "BBB" :
					 dd > 1 ? "BB" : "B"

		print("\n\(scenario.name):")
		print("  Assets: \(scenario.assets.currency(1))M")
		print("  Leverage: \( (scenario.debt / scenario.assets).percent(0))")
		print("  Distance to Default: \(dd.number(2)) σ")
		print("  Default Probability: \(pd.percent(2))%")
		print("  Implied Rating: \(rating)")
	}


	// Scenario: Observable market data
	// - Equity market cap: $25 million
	// - Equity volatility: 45% (from stock prices)
	// - Debt face value: $80 million (from balance sheet)

	let observedEquity = 25_000_000.0
	let equityVolatility = 0.45
	let observedDebt = 80_000_000.0

	do {
		let calibratedModel = try calibrateMertonModel(
			equityValue: observedEquity,
			equityVolatility: equityVolatility,
			debtFaceValue: observedDebt,
			riskFreeRate: 0.05,
			maturity: 1.0
		)

		print("\nMerton Model Calibration")
		print("========================")
		print("Inputs (Observable):")
		print("  Equity Value: \((observedEquity / 1_000_000).currency(1))M")
		print("  Equity Volatility: \(equityVolatility.percent(1))")
		print("  Debt Face Value: \((observedDebt / 1_000_000).currency(1))M")
		print("\nOutputs (Estimated):")
		print("  Asset Value: \((calibratedModel.assetValue / 1_000_000).currency(1))M")
		print("  Asset Volatility: \(calibratedModel.assetVolatility.percent(0))")
		print("  Default Probability: \(calibratedModel.defaultProbability().percent(2))%")

	} catch {
		print("Calibration failed: \(error)")
	}


	// Constant hazard rate model (exponential distribution)
	let constantHazard = ConstantHazardRate(hazardRate: 0.02)  // 2% annual

	print("\nConstant Hazard Rate Model")
	print("==========================")
	print("Hazard Rate (λ): 2.0% per year")
	print("\nSurvival & Default Probabilities:")

	for year in [1, 3, 5, 10] {
		let survival = constantHazard.survivalProbability(time: Double(year))
		let defaultProb = constantHazard.defaultProbability(time: Double(year))
		let density = constantHazard.defaultDensity(time: Double(year))

		print("\n\(year)-Year Horizon:")
		print("  Survival: \(survival.percent(2))")
		print("  Cumulative Default: \(defaultProb.percent(2))")
		print("  Default Density: \(density.percent(4))")
	}

	// Mean time to default
let meanTimeToDefault = 1.0 / constantHazard.hazardRate
print("\nMean Time to Default: \(meanTimeToDefault.number(0)) years")


	// Time-varying hazard rate (increasing over time)
	let annualPeriods = [
		Period.year(2024),
		Period.year(2025),
		Period.year(2026),
		Period.year(2027),
		Period.year(2028)
	]

	let hazardRates = TimeSeries(
		periods: annualPeriods,
		values: [0.01, 0.015, 0.02, 0.025, 0.03]  // 1% → 3%
	)

	let timeVarying = TimeVaryingHazardRate(hazardRates: hazardRates)

	print("\nTime-Varying Hazard Rate Model")
	print("===============================")
	print("Hazard Rate Term Structure:")
	for (i, period) in annualPeriods.enumerated() {
		print("  Year \(i+1): \(hazardRates.valuesArray[i].percent(2))")
	}

	print("\nSurvival Probabilities:")
	for year in [1, 3, 5] {
		let survival = timeVarying.survivalProbability(time: Double(year))
		let defaultProb = timeVarying.defaultProbability(time: Double(year))

		print("  \(year)-Year: S=\(survival.percent(2))%, PD=\(defaultProb.percent(2))%")
	}

	// Market observations
//	let marketSpread = 0.0200  // 200 bps
	let recoveryRate = 0.40

	// Convert spread to hazard rate
	let impliedHazard = hazardRateFromSpread(
		spread: marketSpread,
		recoveryRate: recoveryRate
	)

	print("\nSpread-to-Hazard Conversion")
	print("============================")
print("Market CDS Spread: \((marketSpread * 10000).number()) bps")
print("Recovery Rate: \(recoveryRate.percent(0))")
print("Loss Given Default: \((1 - recoveryRate).percent(0))")
print("Implied Hazard Rate: \(impliedHazard.percent(2))")

	// Verify: λ ≈ spread / (1 - R)
	let theoreticalHazard = marketSpread / (1 - recoveryRate)
print("Theoretical (λ = s/LGD): \(theoreticalHazard.percent(2))")
print("Difference: \(abs(impliedHazard - theoreticalHazard).percent(4))")



	// Market CDS quotes at standard maturities
	let cdsTenors = [1.0, 3.0, 5.0, 7.0, 10.0]
	let cdsSpreads = [
		0.0050,  // 1Y: 50 bps
		0.0100,  // 3Y: 100 bps
		0.0150,  // 5Y: 150 bps
		0.0175,  // 7Y: 175 bps
		0.0200   // 10Y: 200 bps
	]

	let recovery = 0.40

	// Bootstrap hazard rate curve
	let creditCurve = bootstrapCreditCurve(
		tenors: cdsTenors,
		cdsSpreads: cdsSpreads,
		recoveryRate: recovery
	)

	print("\nCredit Curve Bootstrapping")
	print("==========================")
	print("Market CDS Quotes:")
	for (i, tenor) in cdsTenors.enumerated() {
		let spreadBps = cdsSpreads[i] * 10000
		print("\(tenor.number(0).paddingLeft(toLength: 4))Y: \(spreadBps.number(0)) bps")
	}

	print("\nBootstrapped Hazard Rates:")
	for (i, tenor) in cdsTenors.enumerated() {
		let hazard = creditCurve.hazardRates.valuesArray[i]
		let survival = creditCurve.survivalProbability(time: tenor)
		let defaultProb = creditCurve.defaultProbability(time: tenor)

		print("\(tenor.number(0).paddingLeft(toLength: 4))Y: λ=\(hazard.percent(2)), S=\(survival.percent(1)), PD=\(defaultProb.percent(1))%")
	}


print("\nForward Hazard Rates")
print("====================")

for i in 1..<cdsTenors.count {
	let t1 = cdsTenors[i-1]
	let t2 = cdsTenors[i]
	let forwardHazard = creditCurve.forwardHazardRate(from: t1, to: t2)

	print("\(t1.number(0).paddingLeft(toLength: 4))Y-\(t2.number(0).paddingLeft(toLength: 2))Y Forward: \(forwardHazard.percent(2))")
}



	// Price a 4-year CDS (not directly quoted)
	let offMarketTenor = 4.0
	let offMarketSpread = creditCurve.cdsSpread(
		maturity: offMarketTenor,
		recoveryRate: recovery
	)

	print("\nOff-Market CDS Pricing")
	print("======================")
print("Tenor: \(offMarketTenor.number(0)) years")
print("Interpolated Spread: \((offMarketSpread * 10000).number(0)) bps")

	// Compare to surrounding quotes
	let spread3y = cdsSpreads[1] * 10000  // 100 bps
	let spread5y = cdsSpreads[2] * 10000  // 150 bps
print("3Y Quote: \(spread3y.number(0)) bps")
print("5Y Quote: \(spread5y.number(0)) bps")
	print("4Y is between 3Y and 5Y: \(offMarketSpread * 10000 > spread3y && offMarketSpread * 10000 < spread5y ? "✓" : "✗")")


print("\nModel Comparison")
print("================")

// Same firm analyzed both ways
let firmAssets = 100_000_000.0
let firmDebt = 80_000_000.0
let firmVolatility = 0.25

// Structural model (Merton)
let structuralModel = MertonModel(
	assetValue: firmAssets,
	assetVolatility: firmVolatility,
	debtFaceValue: firmDebt,
	riskFreeRate: 0.05,
	maturity: 5.0
)

let mertonPD = structuralModel.defaultProbability()
let mertonSpread = structuralModel.creditSpread()

// Reduced-form model (Hazard Rate from spread)
let marketCDSSpread = 0.0150
let impliedHazardRate = hazardRateFromSpread(
	spread: marketCDSSpread,
	recoveryRate: 0.40
)
let reducedFormModel = ConstantHazardRate(hazardRate: impliedHazardRate)
let reducedFormPD = reducedFormModel.defaultProbability(time: 5.0)

print("Structural (Merton) Model:")
print("  5Y Default Probability: \(mertonPD.percent(2))")
print("  Credit Spread: \((mertonSpread * 10000).number()) bps")

print("\nReduced-Form (Hazard) Model:")
print("  Implied Hazard Rate: \(impliedHazardRate.percent(2))")
print("  5Y Default Probability: \(reducedFormPD.percent(2))")
print("  Market CDS Spread: \((marketCDSSpread * 10000).number(0)) bps")

print("\nKey Differences:")
print("  Structural: Based on firm fundamentals (assets, volatility)")
print("  Reduced-Form: Based on market prices (CDS spreads)")
print("  Structural: Explains WHY default occurs")
print("  Reduced-Form: Focuses on WHEN default occurs")


print("\nCredit Stress Testing")
print("=====================")

let baseAssets = 100_000_000.0
let baseDebt = 80_000_000.0
let baseVol = 0.25

let stressScenarios = [
	(name: "Base Case", assets: 100.0, vol: 0.25),
	(name: "Asset Decline", assets: 90.0, vol: 0.25),
	(name: "Vol Spike", assets: 100.0, vol: 0.40),
	(name: "Combined Stress", assets: 90.0, vol: 0.40)
]

for scenario in stressScenarios {
	let model = MertonModel(
		assetValue: scenario.assets * 1_000_000,
		assetVolatility: scenario.vol,
		debtFaceValue: baseDebt,
		riskFreeRate: 0.05,
		maturity: 1.0
	)

	let pd = model.defaultProbability()
	let spread = model.creditSpread()
	let dd = model.distanceToDefault()

	print("\n\(scenario.name):")
	print("  Assets: \(scenario.assets.currency(1))M")
	print("  Volatility: \(scenario.vol.percent(0))")
	print("  Default Prob: \(pd.percent(2))")
	print("  Credit Spread: \((spread * 10000).number(0)) bps")
	print("  Distance to Default: \(dd.number(2)) σ")
}


print("\n" + String(repeating: "=", count: 70))
print("COMPLETE CREDIT DERIVATIVES ANALYSIS")
print(String(repeating: "=", count: 70))

// Company Profile
let companyName = "XYZ Industrial Corp"
let marketCap = 35_000_000.0
let totalDebt = 75_000_000.0
let equityVol = 0.42

print("\n1. COMPANY PROFILE")
print("   \(companyName)")
print("   Market Cap: \((marketCap / 1_000_000).currency(1))M")
print("   Total Debt: \((totalDebt / 1_000_000).currency(1))M")
print("   Equity Vol: \(equityVol.percent(0))")

// Calibrate Merton Model
print("\n2. STRUCTURAL MODEL (MERTON)")
do {
	let model = try calibrateMertonModel(
		equityValue: marketCap,
		equityVolatility: equityVol,
		debtFaceValue: totalDebt,
		riskFreeRate: 0.05,
		maturity: 1.0
	)

	print("   Estimated Asset Value: \((model.assetValue / 1_000_000).currency(1))M")
	print("   Estimated Asset Vol: \(model.assetVolatility.percent(1))")
	print("   1Y Default Probability: \(model.defaultProbability().percent(2))")
	print("   Distance to Default: \(model.distanceToDefault().number(2)) σ")
	print("   Implied Credit Spread: \((model.creditSpread() * 10000).number(0)) bps")
} catch {
	print("   Calibration failed")
}

// Market CDS Spreads
let marketQuotes = [
	(tenor: 1.0, spread: 0.0075),
	(tenor: 3.0, spread: 0.0125),
	(tenor: 5.0, spread: 0.0175)
]

print("\n3. MARKET CDS SPREADS")
for quote in marketQuotes {
	print("\(quote.tenor.number(0).paddingLeft(toLength: 4))Y: \((quote.spread * 10000).number(0)) bps")
}

// Bootstrap Credit Curve
let tenors = marketQuotes.map { $0.tenor }
let spreads = marketQuotes.map { $0.spread }
let curve = bootstrapCreditCurve(
	tenors: tenors,
	cdsSpreads: spreads,
	recoveryRate: 0.40
)

print("\n4. CREDIT CURVE")
for (i, tenor) in tenors.enumerated() {
	let hazard = curve.hazardRates.valuesArray[i]
	let survival = curve.survivalProbability(time: tenor)
	print("\(tenor.number(0).paddingLeft(toLength: 4))Y: λ=\((hazard * 100).percent(2)), S=\(survival.percent(1))")
}

// Hedging Recommendation
let notionalExposure = 10_000_000.0
let hedgeSpread = curve.cdsSpread(maturity: 5.0, recoveryRate: 0.40)
let annualCost = notionalExposure * hedgeSpread

print("\n5. HEDGING ANALYSIS")
print("   Exposure: \((notionalExposure / 1_000_000).currency(1))M")
print("   5Y CDS Spread: \((hedgeSpread * 10000).number(0)) bps")
print("   Annual Hedge Cost: \(annualCost.currency(0))")
print("   5Y Cumulative Cost: \((annualCost * 5).currency(0))")

print("\n6. RECOMMENDATION")
let fiveYearPD = curve.defaultProbability(time: 5.0)
let expectedLoss = fiveYearPD * (1 - 0.40) * notionalExposure

print("   5Y Default Probability: \(fiveYearPD.percent(2))")
print("   Expected Loss (unhedged): \(expectedLoss.currency(0))")
print("   Hedge Cost vs. Expected Loss: \(((annualCost * 5) / expectedLoss).number(1))x")

if (annualCost * 5) < expectedLoss {
	print("   Decision: HEDGE (cost < expected loss)")
} else {
	print("   Decision: RETAIN RISK (cost > expected loss)")
}

print("\n" + String(repeating: "=", count: 70))

import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	// Revenue grew from $100k to $120k
	let growth = try growthRate(from: 100_000, to: 120_000)
	print(growth)
	// Result: 0.20 (20% growth)

	// Negative growth (decline)
	let decline = try growthRate(from: 120_000, to: 100_000)
	print(decline)
	// Result: -0.1667 (-16.67% decline)

	// Revenue trajectory: $100k → $110k → $125k → $150k over 3 years
	let compoundGrowth = cagr(
		beginningValue: 100_000,
		endingValue: 150_000,
		years: 3
	)
	// Result: ~0.1447 (14.47% per year)

	// Verify: does 14.47% compound for 3 years give $150k?
	let verification = 100_000 * pow(1 + compoundGrowth, 3)
	print(verification)
	// Result: ~150,000 ✓

	// Project $100k base with 15% annual growth for 5 years
	let projection = applyGrowth(
		baseValue: 100_000,
		rate: 0.15,
		periods: 5,
		compounding: .annual
	)
	// Result: [100k, 115k, 132.25k, 152.09k, 174.90k, 201.14k]
	print(projection.map({"\($0.number(2))"}).joined(separator: ", "))

let base = 100_000.0
let rate = 0.12  // 12% annual rate
let years = 5

// Annual compounding
let annual = applyGrowth(baseValue: base, rate: rate, periods: years, compounding: .annual)
print(annual.last!.number(0))
// Final: ~176,234

// Quarterly compounding (12%/4 = 3% per quarter, 20 quarters)
let quarterly = applyGrowth(baseValue: base, rate: rate, periods: years * 4, compounding: .quarterly)
print(quarterly.last!.number(0))
// Final: ~180,611 (higher due to more frequent compounding)

// Monthly compounding (12%/12 = 1% per month, 60 months)
let monthly = applyGrowth(baseValue: base, rate: rate, periods: years * 12, compounding: .monthly)
print(monthly.last!.number(0))
// Final: ~181,670

// Daily compounding
let daily = applyGrowth(baseValue: base, rate: rate, periods: years * 365, compounding: .daily)
print(daily.last!.number(0))
// Final: ~182,194

// Continuous compounding (e^(rt))
let continuous = applyGrowth(baseValue: base, rate: rate, periods: years, compounding: .continuous)
print(continuous.last!.number(0))
// Final: ~182,212 (theoretical maximum)

	// Q1 2024: $500k, Q1 2025: $650k
	let quarterlyGrowth = try growthRate(from: 500_000, to: 650_000)
	// Result: 30% year-over-year growth

	// Project next 4 quarters at this rate
	let forecast = applyGrowth(
		baseValue: 650_000,
		rate: 0.30 / 4,  // Quarterly rate
		periods: 4,
		compounding: .quarterly
	)

	// City grew from 100k to 125k residents over 5 years
	let populationCAGR = cagr(beginningValue: 100_000, endingValue: 125_000, years: 5)
	// Result: ~4.56% per year

	// Project 10 years forward
	let population2035 = 125_000 * pow(1 + populationCAGR, 10)
	print(population2035.number(0))
	// Result: ~195,312 residents

	// Portfolio: $50k → $87k over 8 years
	let investmentReturn = cagr(beginningValue: 50_000, endingValue: 86_000, years: 8)
	print(investmentReturn)
	// Result: ~7.0% per year (good long-term return)
	
	// Historical revenue shows steady ~$5k/month increase
//	let periods = (1...12).map { Period.month(year: 2024, month: $0) }
//	let revenue: [Double] = [100, 105, 110, 108, 115, 120, 118, 125, 130, 128, 135, 140]
//
//	let historical = TimeSeries(periods: periods, values: revenue)
//
//	// Fit linear trend
//	var trend = LinearTrend<Double>()
//	try trend.fit(to: historical)
//
//	// Project 6 months forward
//	let linearForecast = try trend.project(periods: 6)
//	print(linearForecast.valuesArray.map({"\($0.number(0))"}).joined(separator: ", "))
//	// Result: [142, 145, 148, 152, 155, 159] (approximately)
//
//
//	// Revenue doubling every few years
//	let periods = (0..<10).map { Period.year(2015 + $0) }
//	let revenue: [Double] = [100, 115, 130, 155, 175, 200, 235, 265, 310, 350]
//
//	let historical = TimeSeries(periods: periods, values: revenue)
//
//	// Fit exponential trend
//	var trend = ExponentialTrend<Double>()
//	try trend.fit(to: historical)
//
//	// Project 5 years forward
//	let exponentialForecast = try trend.project(periods: 5)
//	print(exponentialForecast.valuesArray.map({"\($0.number(0))"}).joined(separator: ", "))
//	// Result: Continues exponential growth pattern

//	// User adoption starts slow, accelerates, then plateaus
//	let periods = (0..<24).map { Period.month(year: 2023 + $0/12, month: ($0 % 12) + 1) }
//	let users: [Double] = [100, 150, 250, 400, 700, 1200, 2000, 3500, 5500, 8000,
//							11000, 14000, 17000, 19500, 21500, 23000, 24000, 24500,
//							24800, 24900, 24950, 24970, 24985, 24990]
//
//	let historical = TimeSeries(periods: periods, values: users)
//
//	// Fit logistic trend with capacity of 25,000 users
//	var trend = LogisticTrend<Double>(capacity: 25_000)
//	try trend.fit(to: historical)
//
//	// Project 12 months forward
//	let logisticForecast = try trend.project(periods: 12)
//	print(logisticForecast.valuesArray.map({"\($0.number(0))"}).joined(separator: ", "))
//	// Result: Approaches but never exceeds 25,000

//	// Custom quadratic trend: y = 0.5x² + 10x + 100
//	// For playgrounds, define the closure separately with explicit type
//	let quadraticFunction: @Sendable (Double) -> Double = { x in
//		return 0.5 * x * x + 10.0 * x + 100.0
//	}
//
//	var trend = CustomTrend<Double>(trendFunction: quadraticFunction)
//
//	// Fit to historical data to set metadata
//	let historical = TimeSeries(
//		periods: [Period.month(year: 2025, month: 1)],
//		values: [100.0]
//	)
//	try trend.fit(to: historical)
//
//	// Project future values using the custom function
//	let customForecast = try trend.project(periods: 12)
//print(customForecast.valuesArray.map({"\($0.number(0))"}).joined(separator: ", "))

	// Quarterly revenue with Q4 holiday spike
	let periods = (0..<12).map { Period.quarter(year: 2022 + $0/4, quarter: ($0 % 4) + 1) }
	let revenue: [Double] = [100, 120, 110, 150,  // 2022
							 105, 125, 115, 160,  // 2023
							 110, 130, 120, 170]  // 2024

	let ts = TimeSeries(periods: periods, values: revenue)

	// Calculate seasonal indices (4 quarters per year)
	let indices = try seasonalIndices(timeSeries: ts, periodsPerYear: 4)
	// Result: [~0.85, ~1.00, ~0.91, ~1.24]
	// Q1: 16% below average
	// Q2: 1% above average
	// Q3: 7% below average
	// Q4: 22% above average (holiday season!)
	print(indices.map({"\($0.number(2))"}).joined(separator: ", "))

	// Remove seasonal effects
	let deseasonalized = try seasonallyAdjust(timeSeries: ts, indices: indices)
	print(deseasonalized.map({"\($0.number(0))"}).joined(separator: ", "))
	// Original: [100, 120, 110, 150, ...]
	// Deseasonalized: [~119, ~119, ~118, ~123, ...]
	// Now you can see the true trend without seasonal noise

var trend = LinearTrend<Double>()
try trend.fit(to: deseasonalized)
let trendForecast = try trend.project(periods: 4)

// Reapply seasonal pattern
let seasonalForecast = try applySeasonal(timeSeries: trendForecast, indices: indices)
print(seasonalForecast.map({"\($0.number(0))"}).joined(separator: ", "))
// Result: Trend forecast × seasonal indices = realistic forecast

let decomposition = try decomposeTimeSeries(
	timeSeries: ts,
	periodsPerYear: 4,
	method: .multiplicative
)

print("Trend:", decomposition.trend.valuesArray)
// Long-term direction (increasing, decreasing, flat)

print("Seasonal:", decomposition.seasonal.valuesArray)
// Recurring patterns (same each cycle)

print("Residual:", decomposition.residual.valuesArray)
// Random noise (what's left after removing trend and seasonal)

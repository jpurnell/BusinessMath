//
//  IntegrationTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Integration Tests")
struct IntegrationTests {

	let tolerance: Double = 0.01

	// MARK: - Complete Financial Model Workflows

	@Test("Build time series and calculate NPV end-to-end")
	func timeSeriesNPVWorkflow() throws {
		// Create quarterly periods
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3),
			Period.quarter(year: 2024, quarter: 4),
			Period.quarter(year: 2025, quarter: 1)
		]

		// Build time series with cash flows
		let cashFlows = [-100_000.0, 30_000.0, 35_000.0, 40_000.0, 45_000.0]
		let ts = TimeSeries(
			periods: periods,
			values: cashFlows,
			metadata: TimeSeriesMetadata(name: "Project Cash Flows", unit: "USD")
		)

		// Calculate NPV
		let npv = try calculateNPV(discountRate: 0.10, cashFlows: ts.valuesArray)

		// Should have positive NPV with these cash flows
		#expect(npv > 0)

		// Calculate IRR
		let irr = try irr(cashFlows: ts.valuesArray)

		// IRR should be greater than discount rate (10%)
		#expect(irr > 0.10)
	}

	@Test("Historical data to trend to forecast to NPV")
	func historicalToForecastWorkflow() throws {
		// Historical quarterly revenue
		let historicalPeriods = (1...8).map { Period.quarter(year: 2023 + ($0-1)/4, quarter: (($0-1) % 4) + 1) }
		let historicalRevenue = [100_000.0, 110_000.0, 121_000.0, 133_100.0,
								  146_410.0, 161_051.0, 177_156.0, 194_872.0]

		let historical = TimeSeries(
			periods: historicalPeriods,
			values: historicalRevenue,
			metadata: TimeSeriesMetadata(name: "Historical Revenue", unit: "USD")
		)

		// Fit trend model
		var trendModel = LinearTrend<Double>()
		try trendModel.fit(to: historical)

		// Project next 4 quarters
		let forecast = try trendModel.project(periods: 4)

		// Calculate growth rate
		let firstForecast = forecast.valuesArray.first!
		let lastForecast = forecast.valuesArray.last!
		let forecastGrowth = try growthRate(from: firstForecast, to: lastForecast)

		// Should project continued growth
		#expect(forecastGrowth > 0)

		// Convert forecast to cash flows (assume 20% operating margin)
		let operatingMargin = 0.20
		let projectedCashFlows = forecast.valuesArray.map { $0 * operatingMargin }

		// Calculate present value of forecast
		let discountRate = 0.12
		let pv = try calculateNPV(discountRate: discountRate, cashFlows: projectedCashFlows)

		#expect(pv > 0)
	}

	@Test("Complete revenue projection model with seasonality")
	func revenueProjectionModel() throws {
		// Historical quarterly revenue with seasonality (Q4 holiday spike)
		let periods = (1...12).map { Period.quarter(year: 2022 + ($0-1)/4, quarter: (($0-1) % 4) + 1) }
		let revenue = [
			100_000.0, 105_000.0, 110_000.0, 160_000.0,  // 2022: Q4 spike
			115_000.0, 120_000.0, 125_000.0, 180_000.0,  // 2023: growth + Q4 spike
			130_000.0, 135_000.0, 140_000.0, 200_000.0   // 2024: growth + Q4 spike
		]

		let historical = TimeSeries(
			periods: periods,
			values: revenue,
			metadata: TimeSeriesMetadata(name: "Quarterly Revenue", unit: "USD")
		)

		// Step 1: Extract seasonal pattern
		let seasonalIndices = try seasonalIndices(timeSeries: historical, periodsPerYear: 4)

		// Q4 should have highest seasonal index
		#expect(seasonalIndices[3] > seasonalIndices[0])
		#expect(seasonalIndices[3] > seasonalIndices[1])
		#expect(seasonalIndices[3] > seasonalIndices[2])

		// Step 2: Deseasonalize to see underlying trend
		let deseasonalized = try seasonallyAdjust(timeSeries: historical, indices: seasonalIndices)

		// Step 3: Fit trend to deseasonalized data
		var trend = LinearTrend<Double>()
		try trend.fit(to: deseasonalized)

		// Step 4: Project trend forward
		let trendForecast = try trend.project(periods: 4)

		// Step 5: Reapply seasonality
		let seasonalForecast = try applySeasonal(timeSeries: trendForecast, indices: seasonalIndices)

		// Forecast should show Q4 spike
		let q4Forecast = seasonalForecast.valuesArray[3]
		let q1Forecast = seasonalForecast.valuesArray[0]
		#expect(q4Forecast > q1Forecast)

		// Step 6: Calculate NPV of forecast
		let discountRate = 0.10
		let forecastNPV = try calculateNPV(discountRate: discountRate, cashFlows: seasonalForecast.valuesArray)

		#expect(forecastNPV > 0)
	}

	// MARK: - Aggregation Workflows

	@Test("Monthly to quarterly aggregation")
	func monthlyToQuarterlyAggregation() throws {
		// Monthly revenue data
		let monthlyPeriods = (1...12).map { Period.month(year: 2024, month: $0) }
		let monthlyRevenue = [
			10_000.0, 11_000.0, 12_000.0,  // Q1: 33,000
			13_000.0, 14_000.0, 15_000.0,  // Q2: 42,000
			16_000.0, 17_000.0, 18_000.0,  // Q3: 51,000
			19_000.0, 20_000.0, 21_000.0   // Q4: 60,000
		]

		let monthly = TimeSeries(
			periods: monthlyPeriods,
			values: monthlyRevenue,
			metadata: TimeSeriesMetadata(name: "Monthly Revenue", unit: "USD")
		)

		// Use the built-in aggregate method to sum monthly data to quarterly
		let quarterly = monthly.aggregate(to: .quarterly, method: .sum)

		// Check totals
		let quarterlyValues = quarterly.valuesArray
		#expect(abs(quarterlyValues[0] - 33_000.0) < tolerance)
		#expect(abs(quarterlyValues[1] - 42_000.0) < tolerance)
		#expect(abs(quarterlyValues[2] - 51_000.0) < tolerance)
		#expect(abs(quarterlyValues[3] - 60_000.0) < tolerance)

		// Calculate quarter-over-quarter growth
		let q1ToQ2Growth = try growthRate(from: quarterlyValues[0], to: quarterlyValues[1])
		let q2ToQ3Growth = try growthRate(from: quarterlyValues[1], to: quarterlyValues[2])

		// Should show consistent growth
		#expect(q1ToQ2Growth > 0.20)  // ~27% growth
		#expect(q2ToQ3Growth > 0.20)  // ~21% growth
	}

	@Test("Multi-year monthly data aggregation and analysis")
	func multiYearAggregation() throws {
		// 2 years of monthly data
		var periods: [Period] = []
		var values: [Double] = []

		for year in 2023...2024 {
			for month in 1...12 {
				periods.append(Period.month(year: year, month: month))
				// Growing monthly revenue with seasonality
				let baseRevenue = 10_000.0 * Double(year - 2022)
				let monthFactor = Double(month) / 12.0
				values.append(baseRevenue + baseRevenue * monthFactor)
			}
		}

		let monthly = TimeSeries(
			periods: periods,
			values: values,
			metadata: TimeSeriesMetadata(name: "Monthly Revenue")
		)

		// Aggregate to annual using the TimeSeries method
		let annual = monthly.aggregate(to: .annual, method: .sum)
		let annualValues = annual.valuesArray

		// Should have 2 years
		#expect(annualValues.count == 2)

		// Year 2 should be higher than year 1
		#expect(annualValues[1] > annualValues[0])

		// Calculate CAGR
		let years = 1.0
		let cagrValue = cagr(
			beginningValue: annualValues[0],
			endingValue: annualValues[1],
			years: years
		)

		#expect(cagrValue > 0)
	}
	// MARK: - Investment Analysis Workflows

	@Test("Complete investment analysis workflow")
	func investmentAnalysisWorkflow() throws {
		// Investment opportunity with irregular cash flows
		let dates = [
			date(2024, 1, 1),   // Initial investment
			date(2024, 6, 15),  // First return
			date(2024, 12, 31), // Second return
			date(2025, 6, 30),  // Third return
			date(2025, 12, 31)  // Final return
		]

		let cashFlows = [-100_000.0, 20_000.0, 25_000.0, 30_000.0, 50_000.0]

		// Calculate XNPV (irregular dates)
		let rate = 0.12
		let xnpvValue = try xnpv(rate: rate, dates: dates, cashFlows: cashFlows)

		// Calculate XIRR
		let xirrValue = try xirr(dates: dates, cashFlows: cashFlows)

		// Calculate payback period
		let payback = paybackPeriod(cashFlows: cashFlows)
		let discountedPayback = discountedPaybackPeriod(rate: rate, cashFlows: cashFlows)

		// Investment decision metrics
		let isPositiveNPV = xnpvValue > 0
		let beatsHurdleRate = xirrValue > rate

		// All criteria should be met for good investment
		#expect(isPositiveNPV)
		#expect(beatsHurdleRate)

		// Payback should occur (not nil)
		#expect(payback != nil)

		// Discounted payback may be nil if not reached within period
		// (these are irregular cash flows, so it's OK if one metric doesn't apply)
		if let pb = payback, let dpb = discountedPayback {
			#expect(dpb >= pb)  // Discounted is always longer than simple
		}
	}

	@Test("Loan amortization schedule generation")
	func loanAmortizationWorkflow() throws {
		// Loan parameters
		let principal = 200_000.0
		let annualRate = 0.06
		let years = 30.0
		let paymentsPerYear = 12.0

		// Calculate monthly payment
		let monthlyRate = annualRate / paymentsPerYear
		let totalPayments = Int(years * paymentsPerYear)
		let monthlyPayment = payment(
			presentValue: principal,
			rate: monthlyRate,
			periods: totalPayments,
			futureValue: 0.0,
			type: .ordinary
		)

		// Should be positive payment
		#expect(monthlyPayment > 0)

		// Generate amortization schedule for first year
		var balance = principal
		var totalInterest = 0.0
		var totalPrincipal = 0.0

		for _ in 1...12 {
			let interestPayment = balance * monthlyRate
			let principalPayment = monthlyPayment - interestPayment

			totalInterest += interestPayment
			totalPrincipal += principalPayment
			balance -= principalPayment
		}

		// After 1 year
		#expect(totalInterest + totalPrincipal - monthlyPayment * 12 < 0.01)
		#expect(balance < principal)  // Some principal paid down

		// Verify the payment amount is reasonable for a $200k, 30-year loan at 6%
		#expect(monthlyPayment > 1000.0)  // Should be >$1k payment
		#expect(monthlyPayment < 1500.0)  // But not too high (actual is ~$1,199)
	}

	// MARK: - Growth Analysis Workflows

	@Test("Multi-stage growth analysis")
	func multiStageGrowthAnalysis() throws {
		// Company with different growth phases
		// Phase 1: High growth (years 1-3)
		// Phase 2: Moderate growth (years 4-6)
		// Phase 3: Mature growth (years 7-10)

		let phase1Revenue = applyGrowth(baseValue: 1_000_000.0, rate: 0.50, periods: 3)
		let phase2Revenue = applyGrowth(baseValue: phase1Revenue.last!, rate: 0.20, periods: 3)
		let phase3Revenue = applyGrowth(baseValue: phase2Revenue.last!, rate: 0.05, periods: 4)

		// Combine all phases
		let allRevenue = Array(phase1Revenue.dropFirst()) +
						 Array(phase2Revenue.dropFirst()) +
						 Array(phase3Revenue.dropFirst())

		// Calculate overall CAGR
		let overallCAGR = cagr(
			beginningValue: allRevenue.first!,
			endingValue: allRevenue.last!,
			years: Double(allRevenue.count - 1)
		)

		// CAGR should be between lowest and highest phase rates
		#expect(overallCAGR > 0.05)
		#expect(overallCAGR < 0.50)

		// Create time series for valuation
		let periods = (0..<allRevenue.count).map { Period.year(2024 + $0) }
		let revenueSeries = TimeSeries(
			periods: periods,
			values: allRevenue,
			metadata: TimeSeriesMetadata(name: "Revenue Forecast")
		)

		// Apply operating margin to get cash flows
		let operatingMargin = 0.25
		let cashFlows = revenueSeries.valuesArray.map { $0 * operatingMargin }

		// Calculate DCF valuation
		let wacc = 0.12
		let terminalGrowth = 0.03
		let explicitPeriodNPV = try calculateNPV(discountRate: wacc, cashFlows: cashFlows)

		// Calculate terminal value
		let terminalCashFlow = cashFlows.last! * (1 + terminalGrowth)
		let terminalValue = terminalCashFlow / (wacc - terminalGrowth)
		let pvTerminalValue = terminalValue / pow(1 + wacc, Double(cashFlows.count))

		let enterpriseValue = explicitPeriodNPV + pvTerminalValue

		#expect(enterpriseValue > 0)
		#expect(enterpriseValue > explicitPeriodNPV)  // Terminal value adds significant value
	}

	@Test("Seasonal business with trend and forecasting")
	func seasonalBusinessForecasting() throws {
		// Ice cream shop with strong summer seasonality
		let quarters = (0..<12).map { Period.quarter(year: 2022 + $0/4, quarter: ($0 % 4) + 1) }

		// Q1 (winter): 60, Q2 (spring): 100, Q3 (summer): 140, Q4 (fall): 100
		// Growing at 10% per year
		var revenue: [Double] = []
		for year in 0..<3 {
			let yearMultiplier = pow(1.1, Double(year))
			revenue.append(contentsOf: [
				60.0 * yearMultiplier,
				100.0 * yearMultiplier,
				140.0 * yearMultiplier,
				100.0 * yearMultiplier
			])
		}

		let historical = TimeSeries(
			periods: quarters,
			values: revenue,
			metadata: TimeSeriesMetadata(name: "Ice Cream Revenue", unit: "k USD")
		)

		// Decompose to understand components
		let decomposition = try decomposeTimeSeries(
			timeSeries: historical,
			periodsPerYear: 4,
			method: .multiplicative
		)

		// Verify seasonality pattern
		let seasonalValues = decomposition.seasonal.valuesArray
		let q3Values = [seasonalValues[2], seasonalValues[6], seasonalValues[10]]
		let avgQ3 = q3Values.reduce(0.0, +) / Double(q3Values.count)

		// Q3 (summer) should be significantly above average
		#expect(avgQ3 > 1.2)

		// Instead of fitting to potentially NaN-containing trend,
		// fit directly to the deseasonalized data for cleaner trend
		let indices = try seasonalIndices(timeSeries: historical, periodsPerYear: 4)
		let deseasonalized = try seasonallyAdjust(timeSeries: historical, indices: indices)

		var trendModel = LinearTrend<Double>()
		try trendModel.fit(to: deseasonalized)

		// Project trend for next year
		let trendForecast = try trendModel.project(periods: 4)

		// Apply seasonality to forecast
		let seasonalForecast = try applySeasonal(timeSeries: trendForecast, indices: indices)

		// Verify Q3 forecast is highest
		let forecastValues = seasonalForecast.valuesArray
		let q3Forecast = forecastValues[2]
		#expect(q3Forecast > forecastValues[0])  // Higher than Q1
		#expect(q3Forecast > forecastValues[1])  // Higher than Q2
		#expect(q3Forecast > forecastValues[3])  // Higher than Q4
	}

	// MARK: - Real Estate Investment Analysis

	@Test("Real estate investment with rental income")
	func realEstateInvestmentAnalysis() throws {
		// Property purchase and rental analysis
		let purchasePrice = 500_000.0
		let downPayment = 100_000.0
		let loanAmount = purchasePrice - downPayment
		let annualRate = 0.045
		let loanYears = 30.0

		// Monthly mortgage payment
		let monthlyRate = annualRate / 12.0
		let totalPayments = Int(loanYears * 12.0)
		let monthlyMortgage = payment(
			presentValue: loanAmount,
			rate: monthlyRate,
			periods: totalPayments,
			futureValue: 0.0,
			type: .ordinary
		)

		// Monthly rental income and expenses
		let monthlyRent = 3_000.0
		let monthlyExpenses = 500.0  // Property tax, insurance, maintenance
		let monthlyCashFlow = monthlyRent - monthlyExpenses - monthlyMortgage

		// Should be positive cash flow
		#expect(monthlyCashFlow > 0)

		// Annual cash flows for 10-year hold period
		let annualCashFlow = monthlyCashFlow * 12.0
		var cashFlows = [-downPayment]  // Initial investment

		// Operating cash flows for 10 years
		for _ in 1...10 {
			cashFlows.append(annualCashFlow)
		}

		// Estimate property appreciation and sale
		let appreciationRate = 0.03
		let futureValue = purchasePrice * pow(1 + appreciationRate, 10.0)

		// Remaining loan balance after 10 years
		// Calculate using present value of remaining payments
		let paymentsRemaining = totalPayments - Int(10.0 * 12.0)
		let remainingBalance = presentValueAnnuity(
			payment: monthlyMortgage,
			rate: monthlyRate,
			periods: paymentsRemaining,
			type: .ordinary
		)

		// Net proceeds from sale
		let saleProceeds = futureValue - remainingBalance
		cashFlows[cashFlows.count - 1] += saleProceeds  // Add to final year

		// Calculate investment metrics
		let investmentIRR = try irr(cashFlows: cashFlows)
		let investmentNPV = try calculateNPV(discountRate: 0.10, cashFlows: cashFlows)

		#expect(investmentIRR > 0.10)  // Should beat 10% hurdle rate
		#expect(investmentNPV > 0)     // Positive NPV
	}

	// MARK: - Helper Functions

	func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = day
		components.timeZone = TimeZone(secondsFromGMT: 0)
		return Calendar.current.date(from: components)!
	}
}

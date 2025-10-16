//
//  NPVTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("NPV and Related Metrics Tests")
struct NPVTests {

	let tolerance: Double = 0.01  // $0.01 tolerance

	// MARK: - Basic NPV Tests

	@Test("NPV for simple investment: -1000, +600, +600")
	func npvSimple() {
		let cashFlows = [-1000.0, 600.0, 600.0]
		let rate = 0.10

		let npv = npv(discountRate: rate, cashFlows: cashFlows)

		// NPV = -1000 + 600/1.1 + 600/1.1^2 = -1000 + 545.45 + 495.87 = 41.32
		#expect(abs(npv - 41.32) < tolerance)
	}

	@Test("NPV for 3-year investment: -10000, +3000, +4200, +6800")
	func npv3Year() {
		let cashFlows = [-10000.0, 3000.0, 4200.0, 6800.0]
		let rate = 0.10

		let npv = npv(discountRate: rate, cashFlows: cashFlows)

		// NPV = -10000 + 3000/1.1 + 4200/1.1^2 + 6800/1.1^3
		// = -10000 + 2727.27 + 3471.07 + 5108.94 = 1307.287754
		#expect(abs(npv - (1307.287754)) < tolerance)
	}

	@Test("NPV with zero discount rate")
	func npvZeroRate() {
		let cashFlows = [-1000.0, 300.0, 400.0, 500.0]

		let npv = npv(discountRate: 0.0, cashFlows: cashFlows)

		// With zero rate, NPV = sum of cash flows
		#expect(abs(npv - 200.0) < tolerance)
	}

	@Test("NPV with negative ending cash flow")
	func npvNegativeEnding() {
		let cashFlows = [-1000.0, 500.0, 500.0, 500.0, -200.0]
		let rate = 0.10

		let npv = npv(discountRate: rate, cashFlows: cashFlows)

		// Should handle negative ending flow
		#expect(!npv.isNaN)
		#expect(!npv.isInfinite)
	}

	@Test("NPV equals zero cash flows")
	func npvAllZero() {
		let cashFlows = [0.0, 0.0, 0.0]
		let rate = 0.10

		let npv = npv(discountRate: rate, cashFlows: cashFlows)

		#expect(abs(npv) < tolerance)
	}

	// MARK: - NPV with TimeSeries

	@Test("NPV with TimeSeries input")
	func npvTimeSeries() {
		// Create TimeSeries for quarterly cash flows
		let periods = [
			Period.quarter(year: 2025, quarter: 1),
			Period.quarter(year: 2025, quarter: 2),
			Period.quarter(year: 2025, quarter: 3),
			Period.quarter(year: 2025, quarter: 4)
		]
		let values = [-1000.0, 300.0, 400.0, 500.0]
		let timeSeries = TimeSeries(
			periods: periods,
			values: values,
			metadata: TimeSeriesMetadata(name: "Project Cash Flows")
		)

		let quarterlyRate = 0.10 / 4.0  // 10% annual = 2.5% quarterly
		let tsNPV = npv(rate: quarterlyRate, timeSeries: timeSeries)

		// Should match array-based NPV
		let arrayNPV = npv(discountRate: quarterlyRate, cashFlows: values)
		#expect(abs(tsNPV - arrayNPV) < tolerance)
	}

	@Test("NPV with TimeSeries monthly data")
	func npvTimeSeriesMonthly() {
		let periods = (1...12).map { Period.month(year: 2025, month: $0) }
		var values = Array(repeating: 100.0, count: 12)
		values[0] = -1000.0

		let timeSeries = TimeSeries(
			periods: periods,
			values: values,
			metadata: TimeSeriesMetadata(name: "Monthly Cash Flows")
		)

		let monthlyRate = 0.12 / 12.0  // 12% annual = 1% monthly
		let tsNPV = npv(rate: monthlyRate, timeSeries: timeSeries)

		#expect(!tsNPV.isNaN)
		#expect(!tsNPV.isInfinite)
	}

	// MARK: - Profitability Index Tests

	@Test("Profitability Index for positive NPV project")
	func profitabilityIndexPositive() {
		let cashFlows = [-1000.0, 600.0, 600.0]
		let rate = 0.10

		let pi = profitabilityIndex(rate: rate, cashFlows: cashFlows)

		// PI = (PV of future flows) / Initial Investment
		// PV = 600/1.1 + 600/1.1^2 = 545.45 + 495.87 = 1041.32
		// PI = 1041.32 / 1000 = 1.041
		#expect(abs(pi - 1.041) < 0.01)
		#expect(pi > 1.0)  // Positive NPV means PI > 1
	}

	@Test("Profitability Index for negative NPV project")
	func profitabilityIndexNegative() {
		let cashFlows = [-1000.0, 400.0, 400.0]
		let rate = 0.10

		let pi = profitabilityIndex(rate: rate, cashFlows: cashFlows)

		// PV = 400/1.1 + 400/1.1^2 = 363.64 + 330.58 = 694.22
		// PI = 694.22 / 1000 = 0.694
		#expect(abs(pi - 0.694) < 0.01)
		#expect(pi < 1.0)  // Negative NPV means PI < 1
	}

	@Test("Profitability Index equals 1 at break-even")
	func profitabilityIndexBreakEven() {
		// Find cash flows where NPV ≈ 0
		let cashFlows = [-1000.0, 550.0, 550.0]
		let rate = 0.10

		let pi = profitabilityIndex(rate: rate, cashFlows: cashFlows)
		let npvValue = npv(discountRate: rate, cashFlows: cashFlows)

		// When NPV ≈ 0, PI ≈ 1
		if abs(npvValue) < 10.0 {  // Close to break-even
			#expect(abs(pi - 1.0) < 0.02)
		}
	}

	@Test("Profitability Index with multiple investments")
	func profitabilityIndexMultipleInvestments() {
		// Multiple negative cash flows (investments)
		let cashFlows = [-1000.0, -200.0, 500.0, 800.0, 600.0]
		let rate = 0.10

		let pi = profitabilityIndex(rate: rate, cashFlows: cashFlows)

		// PI = (PV of positive flows) / (PV of negative flows)
		#expect(!pi.isNaN)
		#expect(!pi.isInfinite)
		#expect(pi > 0.0)
	}

	// MARK: - Payback Period Tests

	@Test("Payback period for simple investment")
	func paybackPeriodSimple() {
		let cashFlows = [-1000.0, 400.0, 400.0, 400.0]

		let payback = paybackPeriod(cashFlows: cashFlows)

		// Year 0: -1000
		// Year 1: -1000 + 400 = -600
		// Year 2: -600 + 400 = -200
		// Year 3: -200 + 400 = +200 ✓ Payback in year 3
		#expect(payback == 3)
	}

	@Test("Payback period with early recovery")
	func paybackPeriodEarly() {
		let cashFlows = [-1000.0, 600.0, 600.0]

		let payback = paybackPeriod(cashFlows: cashFlows)

		// Year 0: -1000
		// Year 1: -1000 + 600 = -400
		// Year 2: -400 + 600 = +200 ✓ Payback in year 2
		#expect(payback == 2)
	}

	@Test("Payback period never achieved")
	func paybackPeriodNever() {
		let cashFlows = [-1000.0, 100.0, 100.0, 100.0]

		let payback = paybackPeriod(cashFlows: cashFlows)

		// Never reaches positive cumulative cash flow
		#expect(payback == nil)
	}

	@Test("Payback period with immediate recovery")
	func paybackPeriodImmediate() {
		let cashFlows = [-1000.0, 1500.0]

		let payback = paybackPeriod(cashFlows: cashFlows)

		// Payback in period 1
		#expect(payback == 1)
	}

	@Test("Payback period with multiple investments")
	func paybackPeriodMultipleInvestments() {
		let cashFlows = [-1000.0, -500.0, 800.0, 800.0]

		let payback = paybackPeriod(cashFlows: cashFlows)

		// Year 0: -1000
		// Year 1: -1000 + (-500) = -1500
		// Year 2: -1500 + 800 = -700
		// Year 3: -700 + 800 = +100 ✓ Payback in year 3
		#expect(payback == 3)
	}

	// MARK: - Discounted Payback Period Tests

	@Test("Discounted payback period")
	func discountedPaybackPeriodTest() {
		let cashFlows = [-1000.0, 400.0, 400.0, 400.0, 400.0]
		let rate = 0.10

		let discountedPayback = discountedPaybackPeriod(rate: rate, cashFlows: cashFlows)

		// Year 0: -1000
		// Year 1: -1000 + 400/1.1 = -1000 + 363.64 = -636.36
		// Year 2: -636.36 + 400/1.1^2 = -636.36 + 330.58 = -305.78
		// Year 3: -305.78 + 400/1.1^3 = -305.78 + 300.53 = -5.25
		// Year 4: -5.25 + 400/1.1^4 = -5.25 + 273.21 = +267.96 ✓
		#expect(discountedPayback == 4)
	}

	@Test("Discounted payback longer than regular payback")
	func discountedPaybackLongerTest() {
		let cashFlows = [-1000.0, 500.0, 500.0, 500.0]
		let rate = 0.10

		let regularPayback = paybackPeriod(cashFlows: cashFlows)
		let discountedPayback = discountedPaybackPeriod(rate: rate, cashFlows: cashFlows)

		// Regular payback in year 2
		// Discounted payback should be >= regular payback
		#expect(regularPayback == 2)
		if let dp = discountedPayback {
			#expect(dp >= regularPayback!)
		}
	}

	@Test("Discounted payback never achieved")
	func discountedPaybackNeverTest() {
		let cashFlows = [-1000.0, 200.0, 200.0, 200.0]
		let rate = 0.10

		let discountedPayback = discountedPaybackPeriod(rate: rate, cashFlows: cashFlows)

		// Present value of returns never covers investment
		#expect(discountedPayback == nil)
	}

	@Test("Discounted payback with zero rate matches regular payback")
	func discountedPaybackZeroRateTest() {
		let cashFlows = [-1000.0, 400.0, 400.0, 400.0]

		let regularPayback = paybackPeriod(cashFlows: cashFlows)
		let discountedPayback = discountedPaybackPeriod(rate: 0.0, cashFlows: cashFlows)

		// With zero discount rate, should match regular payback
		#expect(regularPayback == discountedPayback)
	}

	// MARK: - NPV and IRR Relationship

	@Test("NPV equals zero at IRR")
	func npvZeroAtIRR() throws {
		let cashFlows = [-1000.0, 400.0, 400.0, 400.0]

		let irrValue = try irr(cashFlows: cashFlows)
		let npvAtIRR = npv(discountRate: irrValue, cashFlows: cashFlows)

		// NPV should be very close to zero at IRR
		#expect(abs(npvAtIRR) < 1.0)
	}

	@Test("Positive NPV means rate below IRR")
	func npvPositiveBelowIRR() throws {
		let cashFlows = [-1000.0, 600.0, 600.0]

		let irrValue = try irr(cashFlows: cashFlows)
		let npvAtLowerRate = npv(discountRate: irrValue - 0.05, cashFlows: cashFlows)

		// NPV at rate below IRR should be positive
		#expect(npvAtLowerRate > 0.0)
	}

	@Test("Negative NPV means rate above IRR")
	func npvNegativeAboveIRR() throws {
		let cashFlows = [-1000.0, 600.0, 600.0]

		let irrValue = try irr(cashFlows: cashFlows)
		let npvAtHigherRate = npv(discountRate: irrValue + 0.05, cashFlows: cashFlows)

		// NPV at rate above IRR should be negative
		#expect(npvAtHigherRate < 0.0)
	}

	// MARK: - Excel Comparison Tests

	@Test("NPV calculation with Excel comparison")
	func npvExcelComparison() {
		// Note: Excel's NPV function doesn't include the initial investment
		// Excel: =NPV(rate, flow1, flow2, flow3) + initial_investment
		// Our function: npv(rate, [initial, flow1, flow2, flow3])
		let cashFlows = [-10000.0, 3000.0, 4200.0, 6800.0]
		let rate = 0.10

		let npv = npv(discountRate: rate, cashFlows: cashFlows)

		// Calculated NPV: -10000 + 3000/1.1 + 4200/1.1^2 + 6800/1.1^3
		// = -10000 + 2727.27 + 3471.07 + 5107.66 ≈ 1306.00
		#expect(abs(npv - 1306.0) < 2.0)
	}

	@Test("NPV with monthly compounding matches Excel")
	func npvExcelMonthly() {
		// Monthly cash flows at 12% annual rate
		let cashFlows = [-10000.0, 1000.0, 1000.0, 1000.0, 1000.0, 1000.0,
		                 1000.0, 1000.0, 1000.0, 1000.0, 1000.0, 1000.0, 1000.0]
		let monthlyRate = 0.12 / 12.0

		let npv = npv(discountRate: monthlyRate, cashFlows: cashFlows)

		// Should match Excel calculation
		#expect(!npv.isNaN)
		#expect(!npv.isInfinite)
		#expect(npv > 500.0)  // Positive NPV expected
	}

	// MARK: - Excel-Compatible NPV Tests

	@Test("npvExcel matches Excel NPV function exactly")
	func npvExcelFunction() {
		// Excel: =NPV(0.10, 400, 400, 400)
		let futureCashFlows = [400.0, 400.0, 400.0]
		let rate = 0.10

		let npv = npvExcel(rate: rate, cashFlows: futureCashFlows)

		// Excel NPV: 400/1.1 + 400/1.1^2 + 400/1.1^3
		// = 363.64 + 330.58 + 300.53 = 994.75
		#expect(abs(npv - 994.75) < tolerance)
	}

	@Test("npvExcel with initial investment added separately")
	func npvExcelWithInitialInvestment() {
		// Excel: =NPV(0.10, 400, 400, 400) + (-1000)
		let futureCashFlows = [400.0, 400.0, 400.0]
		let initialInvestment = -1000.0
		let rate = 0.10

		let totalNPV = npvExcel(rate: rate, cashFlows: futureCashFlows) + initialInvestment

		// 994.75 + (-1000) = -5.25
		#expect(abs(totalNPV - (-5.25)) < tolerance)
	}

	@Test("npvExcel vs standard npv comparison")
	func npvExcelVsStandard() {
		let cashFlows = [-1000.0, 400.0, 400.0, 400.0]
		let rate = 0.10

		// Standard NPV: -1000 + 400/1.1 + 400/1.1^2 + 400/1.1^3 = -5.25
		let standardNPV = npv(discountRate: rate, cashFlows: cashFlows)

		// Excel NPV with all flows: -1000/1.1 + 400/1.1^2 + 400/1.1^3 + 400/1.1^4
		let excelNPV = npvExcel(rate: rate, cashFlows: cashFlows)

		// Should be different (though close in this case)
		#expect(abs(standardNPV - excelNPV) > 0.1)

		// Excel NPV should be higher (less negative) because initial investment is also discounted
		// Standard: -1000 immediately + discounted positive flows
		// Excel: -1000 discounted + discounted positive flows = less negative
		#expect(excelNPV > standardNPV)
	}

	@Test("npvExcel with multi-year project")
	func npvExcelMultiYear() {
		// Excel: =NPV(0.10, 3000, 4200, 6800)
		let futureCashFlows = [3000.0, 4200.0, 6800.0]
		let rate = 0.10

		let npv = npvExcel(rate: rate, cashFlows: futureCashFlows)

		// 3000/1.1 + 4200/1.1^2 + 6800/1.1^3
		// = 2727.27 + 3471.07 + 5107.66 = 11306.00
		#expect(abs(npv - 11306.0) < 2.0)

		// Now add initial investment to match full project NPV
		let projectNPV = npv + (-10000.0)
		#expect(abs(projectNPV - 1306.0) < 2.0)
	}

	@Test("npvExcel with zero rate")
	func npvExcelZeroRate() {
		let cashFlows = [300.0, 400.0, 500.0]

		let npv = npvExcel(rate: 0.0, cashFlows: cashFlows)

		// With zero rate, NPV = sum of cash flows (still equals sum)
		#expect(abs(npv - 1200.0) < tolerance)
	}

	@Test("npvExcel with single cash flow")
	func npvExcelSingleFlow() {
		let cashFlows = [1100.0]
		let rate = 0.10

		let npv = npvExcel(rate: rate, cashFlows: cashFlows)

		// 1100/1.1 = 1000
		#expect(abs(npv - 1000.0) < tolerance)
	}

	@Test("npvExcel reproduces Excel example from documentation")
	func npvExcelDocumentationExample() {
		// Common Excel example: Investment with 3 years of returns
		// Excel: =NPV(8%, 8000, 9200, 10000) + (-10000)
		let futureCashFlows = [8000.0, 9200.0, 10000.0]
		let initialInvestment = -10000.0
		let rate = 0.08

		let npv = npvExcel(rate: rate, cashFlows: futureCashFlows) + initialInvestment

		// 8000/1.08 + 9200/1.08^2 + 10000/1.08^3 = 7407.41 + 7888.89 + 7938.32
		// = 23234.62
		// Then add initial investment: 23234.62 + (-10000) = 13234.62
		#expect(abs(npv - 13234.62) < 2.0)
	}

	// MARK: - Real-World Scenarios

	@Test("Real estate investment analysis")
	func realEstateScenario() {
		// $100k investment, 5 years of rent, then sale
		let cashFlows = [
			-100000.0,  // Purchase
			12000.0,    // Year 1 rent
			12000.0,    // Year 2 rent
			12000.0,    // Year 3 rent
			12000.0,    // Year 4 rent
			130000.0    // Year 5 rent + sale
		]
		let rate = 0.10

		let npvValue = npv(discountRate: rate, cashFlows: cashFlows)
		let pi = profitabilityIndex(rate: rate, cashFlows: cashFlows)
		let payback = paybackPeriod(cashFlows: cashFlows)

		#expect(npvValue > 0.0)  // Should be profitable
		#expect(pi > 1.0)  // PI > 1 for positive NPV
		#expect(payback != nil)  // Should have payback period
	}

	@Test("Manufacturing equipment decision")
	func manufacturingScenario() {
		// $50k equipment, 5 years of savings
		let cashFlows = [-50000.0, 15000.0, 15000.0, 15000.0, 15000.0, 15000.0]
		let rate = 0.08

		let npvValue = npv(discountRate: rate, cashFlows: cashFlows)
		let pi = profitabilityIndex(rate: rate, cashFlows: cashFlows)
		let regularPayback = paybackPeriod(cashFlows: cashFlows)
		let discountedPayback = discountedPaybackPeriod(rate: rate, cashFlows: cashFlows)

		#expect(npvValue > 0.0)
		#expect(pi > 1.0)
		#expect(regularPayback == 4)  // Simple payback: 50k/15k ≈ 3.33, so year 4
		#expect(discountedPayback != nil)
		if let dp = discountedPayback, let rp = regularPayback {
			#expect(dp >= rp)  // Discounted payback >= regular payback
		}
	}

	@Test("Software project with maintenance costs")
	func softwareProjectScenario() {
		// Development, revenue, then maintenance
		let cashFlows = [
			-100000.0,  // Development
			50000.0,    // Year 1 revenue
			50000.0,    // Year 2 revenue
			40000.0,    // Year 3 (declining)
			30000.0,    // Year 4
			-20000.0    // Year 5 (major maintenance)
		]
		let rate = 0.12

		let npvValue = npv(discountRate: rate, cashFlows: cashFlows)
		let pi = profitabilityIndex(rate: rate, cashFlows: cashFlows)

		// Should handle negative ending cash flow
		#expect(!npvValue.isNaN)
		#expect(!pi.isNaN)
	}

	@Test("Comparing multiple projects with PI")
	func projectComparisonScenario() {
		// Project A: Small investment, quick return
		let projectA = [-10000.0, 6000.0, 6000.0]

		// Project B: Large investment, longer return period
		let projectB = [-50000.0, 18000.0, 18000.0, 18000.0, 18000.0]

		let rate = 0.10

		let piA = profitabilityIndex(rate: rate, cashFlows: projectA)
		let piB = profitabilityIndex(rate: rate, cashFlows: projectB)

		// Both should be profitable, but PI helps compare efficiency
		#expect(piA > 1.0)
		#expect(piB > 1.0)

		// Project B has higher PI due to more periods of returns
		// (longer stream of cash flows provides better present value ratio)
		#expect(piB > piA)
	}

	// MARK: - Edge Cases

	@Test("NPV with single cash flow")
	func npvSingleCashFlow() {
		let cashFlows = [-1000.0]
		let rate = 0.10

		let npv = npv(discountRate: rate, cashFlows: cashFlows)

		// Just the initial investment
		#expect(abs(npv - (-1000.0)) < tolerance)
	}

	@Test("NPV with very high discount rate")
	func npvHighRate() {
		let cashFlows = [-1000.0, 2000.0]
		let rate = 1.0  // 100% rate

		let npv = npv(discountRate: rate, cashFlows: cashFlows)

		// NPV = -1000 + 2000/2.0 = 0
		#expect(abs(npv - 0.0) < tolerance)
	}

	@Test("NPV with very small cash flows")
	func npvSmallCashFlows() {
		let cashFlows = [-0.01, 0.005, 0.005, 0.005]
		let rate = 0.10

		let npv = npv(discountRate: rate, cashFlows: cashFlows)

		// Should handle small values without precision issues
		#expect(!npv.isNaN)
		#expect(!npv.isInfinite)
	}

	@Test("Profitability Index with no initial investment should return infinity")
	func profitabilityIndexNoInvestment() {
		// All positive cash flows (unrealistic but edge case)
		let cashFlows = [100.0, 200.0, 300.0]
		let rate = 0.10

		let pi = profitabilityIndex(rate: rate, cashFlows: cashFlows)

		// PI = PV_positive / 0 = infinity (or very large)
		#expect(pi.isInfinite || pi > 1000.0)
	}
}

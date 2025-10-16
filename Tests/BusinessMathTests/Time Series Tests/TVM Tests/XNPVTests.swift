//
//  XNPVTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("XNPV and XIRR Tests")
struct XNPVTests {

	let tolerance: Double = 0.01  // $0.01 or 0.01% tolerance

	// Helper to create dates
	func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = day
		return Calendar.current.date(from: components)!
	}

	// MARK: - XNPV Tests

	@Test("XNPV with regular intervals should match NPV")
	func xnpvRegularIntervals() throws {
		// Annual cash flows on Jan 1
		let dates = [
			date(2025, 1, 1),
			date(2026, 1, 1),
			date(2027, 1, 1)
		]
		let cashFlows = [-1000.0, 600.0, 600.0]
		let rate = 0.10

		let xnpv = try xnpv(rate: rate, dates: dates, cashFlows: cashFlows)

		// Should be close to regular NPV
		// NPV = -1000 + 600/1.1 + 600/1.1^2 = -1000 + 545.45 + 495.87 = 41.32
		#expect(abs(xnpv - 41.32) < tolerance)
	}

	@Test("XNPV with irregular intervals")
	func xnpvIrregularIntervals() throws {
		// Cash flows at irregular dates
		let dates = [
			date(2025, 1, 1),   // Initial investment
			date(2025, 4, 15),  // ~0.29 years later
			date(2025, 9, 20),  // ~0.72 years from start
			date(2026, 3, 10)   // ~1.19 years from start
		]
		let cashFlows = [-1000.0, 300.0, 400.0, 500.0]
		let rate = 0.10

		let xnpv = try xnpv(rate: rate, dates: dates, cashFlows: cashFlows)

		// XNPV accounts for exact timing
		#expect(!xnpv.isNaN)
		#expect(!xnpv.isInfinite)
		#expect(xnpv > -100.0 && xnpv < 200.0)  // Reasonable range
	}

	@Test("XNPV with zero rate")
	func xnpvZeroRate() throws {
		let dates = [
			date(2025, 1, 1),
			date(2025, 6, 1),
			date(2026, 1, 1)
		]
		let cashFlows = [-1000.0, 500.0, 600.0]

		let xnpv = try xnpv(rate: 0.0, dates: dates, cashFlows: cashFlows)

		// With zero rate, XNPV = sum of cash flows
		#expect(abs(xnpv - 100.0) < tolerance)
	}

	@Test("XNPV with all cash flows on same date")
	func xnpvSameDate() throws {
		let sameDate = date(2025, 1, 1)
		let dates = [sameDate, sameDate, sameDate]
		let cashFlows = [100.0, 200.0, 300.0]

		let xnpv = try xnpv(rate: 0.10, dates: dates, cashFlows: cashFlows)

		// All at time 0, no discounting
		#expect(abs(xnpv - 600.0) < tolerance)
	}

	// MARK: - XIRR Tests

	@Test("XIRR with regular intervals should match IRR")
	func xirrRegularIntervals() throws {
		// Annual cash flows
		let dates = [
			date(2025, 1, 1),
			date(2026, 1, 1),
			date(2027, 1, 1),
			date(2028, 1, 1)
		]
		let cashFlows = [-1000.0, 400.0, 400.0, 400.0]

		let xirr = try xirr(dates: dates, cashFlows: cashFlows)

		// Should be close to regular IRR ≈ 9.7%
		#expect(abs(xirr - 0.0970) < 0.01)
	}

	@Test("XIRR with irregular intervals")
	func xirrIrregularIntervals() throws {
		// Investment with irregular returns
		let dates = [
			date(2025, 1, 1),   // Initial investment
			date(2025, 5, 15),  // Early return
			date(2025, 11, 30), // Late return
			date(2026, 6, 1)    // Final return
		]
		let cashFlows = [-1000.0, 200.0, 300.0, 600.0]

		let xirr = try xirr(dates: dates, cashFlows: cashFlows)

		// Should converge to a reasonable rate
		#expect(!xirr.isNaN)
		#expect(!xirr.isInfinite)
		#expect(xirr > -0.5 && xirr < 1.0)  // Reasonable range
	}

	@Test("XIRR with monthly cash flows")
	func xirrMonthlyCashFlows() throws {
		// Monthly investment returns
		let dates = (0...12).map { months in
			Calendar.current.date(byAdding: .month, value: months, to: date(2025, 1, 1))!
		}
		var cashFlows = Array(repeating: 100.0, count: 13)
		cashFlows[0] = -1000.0  // Initial investment

		let xirr = try xirr(dates: dates, cashFlows: cashFlows)

		// Should converge
		#expect(!xirr.isNaN)
		#expect(!xirr.isInfinite)
	}

	@Test("XIRR with negative ending cash flow")
	func xirrNegativeEnding() throws {
		let dates = [
			date(2025, 1, 1),
			date(2025, 6, 1),
			date(2025, 12, 31)
		]
		let cashFlows = [-1000.0, 1500.0, -200.0]  // Profit minus cleanup cost

		let xirr = try xirr(dates: dates, cashFlows: cashFlows)

		// Should converge to a positive rate
		#expect(!xirr.isNaN)
		#expect(!xirr.isInfinite)
		#expect(xirr > -1.0 && xirr < 2.0)  // Reasonable range
	}

	// MARK: - Error Cases

	@Test("XNPV with mismatched dates and cash flows should throw")
	func xnpvMismatchedArrays() {
		let dates = [date(2025, 1, 1), date(2026, 1, 1)]
		let cashFlows = [-1000.0, 500.0, 600.0]  // One extra

		#expect(throws: XNPVError.self) {
			_ = try xnpv(rate: 0.10, dates: dates, cashFlows: cashFlows)
		}
	}

	@Test("XNPV with empty arrays should throw")
	func xnpvEmpty() {
		let dates: [Date] = []
		let cashFlows: [Double] = []

		#expect(throws: XNPVError.self) {
			_ = try xnpv(rate: 0.10, dates: dates, cashFlows: cashFlows)
		}
	}

	@Test("XIRR with all positive cash flows should throw")
	func xirrAllPositive() {
		let dates = [date(2025, 1, 1), date(2026, 1, 1)]
		let cashFlows = [100.0, 200.0]

		#expect(throws: XNPVError.self) {
			_ = try xirr(dates: dates, cashFlows: cashFlows)
		}
	}

	@Test("XIRR with all negative cash flows should throw")
	func xirrAllNegative() {
		let dates = [date(2025, 1, 1), date(2026, 1, 1)]
		let cashFlows = [-100.0, -200.0]

		#expect(throws: XNPVError.self) {
			_ = try xirr(dates: dates, cashFlows: cashFlows)
		}
	}

	// MARK: - Real-World Scenarios

	@Test("Real estate investment with irregular cash flows")
	func realEstateScenario() throws {
		// Purchase, irregular rent payments, sale
		let dates = [
			date(2025, 1, 15),   // Purchase
			date(2025, 3, 1),    // Rent
			date(2025, 5, 15),   // Rent
			date(2025, 8, 1),    // Rent
			date(2025, 11, 20),  // Rent
			date(2026, 2, 10)    // Sale + rent
		]
		let cashFlows = [-100000.0, 3000.0, 3000.0, 3000.0, 3000.0, 105000.0]

		let xirr = try xirr(dates: dates, cashFlows: cashFlows)

		// Should show positive return
		#expect(xirr > 0.0)
		#expect(xirr < 0.50)  // Reasonable upper bound
	}

	@Test("Business loan with irregular payments")
	func businessLoanScenario() throws {
		// Loan disbursement and irregular repayments
		let dates = [
			date(2025, 1, 1),    // Loan received
			date(2025, 3, 15),   // First payment
			date(2025, 7, 1),    // Second payment
			date(2025, 12, 31)   // Final payment
		]
		let cashFlows = [10000.0, -3500.0, -3500.0, -4000.0]

		let xirr = try xirr(dates: dates, cashFlows: cashFlows)

		// Effective borrowing cost
		#expect(xirr > 0.0)
		#expect(xirr < 0.30)
	}

	@Test("Venture capital investment with multiple rounds")
	func ventureCapitalScenario() throws {
		// Multiple investment rounds, eventual exit
		let dates = [
			date(2025, 1, 1),    // Seed round
			date(2025, 9, 1),    // Series A
			date(2026, 6, 1),    // Series B
			date(2028, 3, 1)     // Exit
		]
		let cashFlows = [-500000.0, -1000000.0, -2000000.0, 10000000.0]

		let xirr = try xirr(dates: dates, cashFlows: cashFlows)

		// Should show high return
		#expect(xirr > 0.0)
		#expect(xirr < 2.0)
	}

	@Test("Stock portfolio with irregular dividends")
	func stockPortfolioScenario() throws {
		// Initial investment, irregular dividends, final sale
		let dates = [
			date(2025, 1, 5),    // Purchase
			date(2025, 4, 1),    // Dividend
			date(2025, 7, 1),    // Dividend
			date(2025, 10, 1),   // Dividend
			date(2026, 1, 5)     // Sale
		]
		let cashFlows = [-10000.0, 150.0, 150.0, 150.0, 11000.0]

		let xirr = try xirr(dates: dates, cashFlows: cashFlows)

		// Should show positive return
		#expect(xirr > 0.0)
		#expect(xirr < 0.30)
	}

	// MARK: - Date Handling

	@Test("XNPV with dates spanning leap year")
	func xnpvLeapYear() throws {
		let dates = [
			date(2024, 1, 1),   // Leap year
			date(2024, 7, 1),
			date(2025, 1, 1)
		]
		let cashFlows = [-1000.0, 500.0, 600.0]

		let xnpv = try xnpv(rate: 0.10, dates: dates, cashFlows: cashFlows)

		// Should handle leap year correctly
		#expect(!xnpv.isNaN)
		#expect(!xnpv.isInfinite)
	}

	@Test("XNPV with dates in reverse order should handle gracefully")
	func xnpvReverseOrder() throws {
		// Dates not in chronological order
		let dates = [
			date(2025, 1, 1),
			date(2026, 1, 1),
			date(2024, 1, 1)   // Out of order
		]
		let cashFlows = [-1000.0, 600.0, 500.0]

		// Should either sort automatically or throw
		let result = try? xnpv(rate: 0.10, dates: dates, cashFlows: cashFlows)

		// If it doesn't throw, result should be valid
		if let xnpv = result {
			#expect(!xnpv.isNaN)
			#expect(!xnpv.isInfinite)
		}
	}

	@Test("XIRR with short time period (days)")
	func xirrShortPeriod() throws {
		let dates = [
			date(2025, 1, 1),
			date(2025, 1, 8),   // 7 days later
			date(2025, 1, 15)   // 14 days from start
		]
		let cashFlows = [-1000.0, 500.0, 600.0]

		let xirr = try xirr(dates: dates, cashFlows: cashFlows)

		// Should handle short periods (annualized rate)
		#expect(!xirr.isNaN)
		#expect(!xirr.isInfinite)
	}

	@Test("XIRR with long time period (decades)")
	func xirrLongPeriod() throws {
		let dates = [
			date(2025, 1, 1),
			date(2035, 1, 1),   // 10 years
			date(2045, 1, 1)    // 20 years
		]
		let cashFlows = [-1000.0, 500.0, 2000.0]

		let xirr = try xirr(dates: dates, cashFlows: cashFlows)

		// Should handle long periods
		#expect(!xirr.isNaN)
		#expect(!xirr.isInfinite)
	}
}

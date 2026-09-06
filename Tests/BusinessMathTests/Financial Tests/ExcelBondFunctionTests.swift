//
//  ExcelBondFunctionTests.swift
//  BusinessMathTests
//
//  PRICE, YIELD, DURATION and MDURATION against values Excel itself cached.
//
//  These are not LibreOffice's. They were read out of real workbooks by
//  SwiftExcelFunctions — every input a literal, no dependency chains — which makes them
//  the strongest oracle available for this family: Excel's own answer to Excel's own
//  formula.
//
//  Provenance: `Tuck/Academic/2011-2012/1. Fall/1.1 Fall A/CM/Homework/`,
//  files `Purnell, J.HW5.S3.xlsx` and `Purnell, J.HW4.S3.xlsx`, sheet1.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Excel bond functions — PRICE, YIELD, DURATION, MDURATION")
struct ExcelBondFunctionTests {

	static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
		var components = DateComponents()
		components.year = y; components.month = m; components.day = d
		guard let date = Calendar.current.date(from: components) else {
			preconditionFailure("\(y)-\(m)-\(d) is not a date")
		}
		return date
	}

	/// Excel writes about fifteen significant digits into a cached value.
	static let tolerance = 1e-10

	static func check(_ actual: Double, _ expected: Double, _ label: String,
					  sourceLocation: SourceLocation = #_sourceLocation) {
		let scale = Swift.max(abs(expected), 1.0)
		#expect(abs(actual - expected) / scale < tolerance,
			"\(label): ours \(actual), Excel \(expected), relative \(abs(actual - expected) / scale)",
			sourceLocation: sourceLocation)
	}

	// MARK: - The case that discriminates

	@Test("A mid-period settlement crossing a year boundary, basis 1")
	func midPeriodSettlementOnActualActual() throws {
		// E45–E47 of HW5. The only one of the twenty-eight cells whose settlement is not
		// on a coupon date: annual coupons fall on 15 August and settlement is 15
		// January, so the accrual fraction is genuine and the period straddles a year
		// boundary. Everywhere else A = 0 and DSC/E = 1, and the day count cannot affect
		// the answer at all.
		//
		// Zero coupon, so the accrual term drops out and the basis enters purely through
		// the discounting exponent — which is what makes this the one case that tests it.
		let settlement = Self.date(1998, 1, 15)
		let maturity = Self.date(2006, 8, 15)

		// Assert the property that makes this case worth having: the settlement really
		// is mid-period. If a future change put it on a coupon date the accrual fraction
		// would go to zero, the day count would stop mattering, and this test would keep
		// passing while checking nothing.
		let period = try CouponPeriod<Double>(settlement: settlement, maturity: maturity,
											  frequency: .annual, basis: .actualActual)
		#expect(period.accruedFraction > 0.4 && period.accruedFraction < 0.5,
			"settlement should sit mid-period; the accrued fraction is \(period.accruedFraction)")
		#expect(period.couponsRemaining == 9,
			"nine annual coupons should remain, found \(period.couponsRemaining)")

		let price = try bondPrice(settlement: settlement, maturity: maturity,
								  rate: 0.0, yield: 0.0639, redemption: 100,
								  frequency: .annual, basis: .actualActual)
		Self.check(price, 58.771794240682887, "PRICE")

		let duration = try bondDuration(settlement: settlement, maturity: maturity,
										rate: 0.0, yield: 0.0639,
										frequency: .annual, basis: .actualActual)
		Self.check(duration, 8.580821917808219, "DURATION")

		let modified = try bondModifiedDuration(settlement: settlement, maturity: maturity,
												rate: 0.0, yield: 0.0639,
												frequency: .annual, basis: .actualActual)
		Self.check(modified, 8.0654402836810029, "MDURATION")
	}

	// MARK: - Settlements on a coupon date

	@Test("PRICE, DURATION and MDURATION where settlement lands on a coupon")
	func settlementOnACouponDate() throws {
		// A = 0 and DSC/E = 1 throughout, so these verify the coupon counting and the
		// discounting rather than the day count. Still oracles; just not discriminating
		// ones, and worth saying so rather than letting a green suite imply more than it
		// checked.
		struct Case {
			let settlement: (Int, Int, Int), maturity: (Int, Int, Int)
			let rate: Double, yield: Double
			let frequency: PaymentFrequency
			let price: Double, duration: Double?, modified: Double?
		}
		let cases: [Case] = [
			.init(settlement: (2004, 1, 15), maturity: (2009, 1, 15), rate: 0.08, yield: 0.06,
				  frequency: .semiAnnual, price: 108.53020283677583,
				  duration: 4.2543451522297877, modified: 4.1304321866308618),
			.init(settlement: (1998, 1, 15), maturity: (1999, 1, 15), rate: 0.06, yield: 0.10,
				  frequency: .annual, price: 96.36363636363636,
				  duration: 1, modified: 0.90909090909090906),
			.init(settlement: (1998, 1, 15), maturity: (2002, 1, 15), rate: 0.08, yield: 0.10,
				  frequency: .annual, price: 93.660269107301403,
				  duration: 3.5616941835365497, modified: 3.2379038032150449),
			.init(settlement: (2011, 10, 16), maturity: (2012, 10, 16), rate: 0.08, yield: 0.10,
				  frequency: .annual, price: 98.181818181818173, duration: nil, modified: nil),
			.init(settlement: (2011, 10, 16), maturity: (2013, 10, 16), rate: 0.10, yield: 0.12,
				  frequency: .annual, price: 96.61989795918366, duration: nil, modified: nil),
			.init(settlement: (2011, 10, 16), maturity: (2014, 10, 16), rate: 0.12, yield: 0.09,
				  frequency: .annual, price: 107.5938839979645, duration: nil, modified: nil),
			.init(settlement: (2011, 10, 16), maturity: (2014, 10, 16), rate: 0.14, yield: 0.089,
				  frequency: .annual, price: 112.93264525401482, duration: nil, modified: nil),
			.init(settlement: (2009, 6, 30), maturity: (2019, 6, 30), rate: 0.08625, yield: 0.08,
				  frequency: .semiAnnual, price: 104.24697698280232, duration: nil, modified: nil)
		]

		#expect(cases.count == 8)
		for c in cases {
			let settlement = Self.date(c.settlement.0, c.settlement.1, c.settlement.2)
			let maturity = Self.date(c.maturity.0, c.maturity.1, c.maturity.2)
			let label = "\(c.settlement) → \(c.maturity) @ \(c.yield)"

			let price = try bondPrice(settlement: settlement, maturity: maturity,
									  rate: c.rate, yield: c.yield, redemption: 100,
									  frequency: c.frequency, basis: .actualActual)
			Self.check(price, c.price, "PRICE \(label)")

			if let expected = c.duration {
				let duration = try bondDuration(settlement: settlement, maturity: maturity,
												rate: c.rate, yield: c.yield,
												frequency: c.frequency, basis: .actualActual)
				Self.check(duration, expected, "DURATION \(label)")
			}
			if let expected = c.modified {
				let modified = try bondModifiedDuration(
					settlement: settlement, maturity: maturity, rate: c.rate,
					yield: c.yield, frequency: c.frequency, basis: .actualActual)
				Self.check(modified, expected, "MDURATION \(label)")
			}
		}
	}

	@Test("YIELD inverts PRICE, against Excel's own yields")
	func yieldMatchesExcel() throws {
		// E4, E15 and E30 of HW5: the same thirty-year bond at three prices.
		let settlement = Self.date(1996, 1, 15)
		let maturity = Self.date(2026, 1, 15)
		let cases: [(price: Double, yield: Double)] = [
			(94, 0.080320319635743306),
			(84.24, 0.090315756431543243),
			(105.82, 0.070318697369301977)
		]
		for c in cases {
			let actual = try bondYield(settlement: settlement, maturity: maturity,
									   rate: 0.075, price: c.price, redemption: 100,
									   frequency: .semiAnnual, basis: .actualActual)
			#expect(abs(actual - c.yield) / c.yield < 1e-9,
				"YIELD at \(c.price): ours \(actual), Excel \(c.yield)")
		}
	}

	// MARK: - Identities

	@Test("YIELD and PRICE are inverses")
	func priceAndYieldRoundTrip() throws {
		let settlement = Self.date(2004, 1, 15)
		let maturity = Self.date(2009, 1, 15)
		for yield in [0.02, 0.06, 0.09, 0.15] {
			let price = try bondPrice(settlement: settlement, maturity: maturity,
									  rate: 0.08, yield: yield, frequency: .semiAnnual,
									  basis: .actualActual)
			let recovered = try bondYield(settlement: settlement, maturity: maturity,
										  rate: 0.08, price: price, frequency: .semiAnnual,
										  basis: .actualActual)
			#expect(abs(recovered - yield) < 1e-10,
				"price \(price) at yield \(yield) recovered \(recovered)")
		}
	}

	@Test("Modified duration is Macaulay duration discounted one period")
	func modifiedIsMacaulayDiscounted() throws {
		let settlement = Self.date(2004, 1, 15)
		let maturity = Self.date(2009, 1, 15)
		for frequency in [PaymentFrequency.annual, .semiAnnual, .quarterly] {
			let macaulay = try bondDuration(settlement: settlement, maturity: maturity,
											rate: 0.08, yield: 0.06, frequency: frequency,
											basis: .actualActual)
			let modified = try bondModifiedDuration(settlement: settlement, maturity: maturity,
													rate: 0.08, yield: 0.06, frequency: frequency,
													basis: .actualActual)
			let expected = macaulay / (1 + 0.06 / Double(frequency.periodsPerYear))
			#expect(abs(modified - expected) < 1e-12, "\(frequency): \(modified) vs \(expected)")
		}
	}

	@Test("A par bond prices at par, and a zero-coupon bond at the discount factor")
	func limitingCases() throws {
		// Coupon equal to yield on a coupon date is par, by construction.
		let price = try bondPrice(settlement: Self.date(2004, 1, 15),
								  maturity: Self.date(2009, 1, 15),
								  rate: 0.06, yield: 0.06, frequency: .semiAnnual,
								  basis: .actualActual)
		#expect(abs(price - 100) < 1e-10, "a par bond priced at \(price)")

		// A zero-coupon bond is redemption discounted over its whole life: ten annual
		// periods at 5% is 100/1.05^10.
		let zero = try bondPrice(settlement: Self.date(2010, 1, 15),
								 maturity: Self.date(2020, 1, 15),
								 rate: 0.0, yield: 0.05, frequency: .annual,
								 basis: .actualActual)
		#expect(abs(zero - 100 / Double.pow(1.05, 10)) < 1e-9, "a zero priced at \(zero)")
	}

	@Test("EFFECT and RRI")
	func rateConversions() throws {
		// EFFECT inverts NOMINAL, which is the only property either needs.
		for nominal in [0.0525, 0.10, 0.20] {
			for periods in [1.0, 4.0, 12.0, 365.0] {
				let effective = try effectiveRate(nominalRate: nominal, periodsPerYear: periods)
				let back = try nominalRate(effectiveRate: effective, periodsPerYear: periods)
				#expect(abs(back - nominal) < 1e-12,
					"\(nominal) at \(periods) went to \(effective) and back to \(back)")
			}
		}
		// RRI is the geometric growth rate: 1000 → 2000 over 10 periods is 2^(1/10) − 1.
		let rate = try equivalentRate(periods: 10, presentValue: 1_000, futureValue: 2_000)
		#expect(abs(rate - (Double.pow(2, 0.1) - 1)) < 1e-15, "got \(rate)")
		// And it inverts compounding.
		let grown = 1_000 * Double.pow(1 + rate, 10)
		#expect(abs(grown - 2_000) < 1e-9)
	}
}

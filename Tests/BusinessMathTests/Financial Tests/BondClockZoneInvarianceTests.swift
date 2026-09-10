//
//  BondClockZoneInvarianceTests.swift
//  BusinessMathTests
//
//  The Excel bond path, swept across time zones.
//
//  `CouponPeriodCalendarTests` pins the grid to Microsoft's published values in one
//  zone. This file asserts the weaker but broader property those values depend on:
//  that the answer does not move when the machine does. The two together are what
//  the original suite lacked — it had values, built in the same zone the code read,
//  and so could not fail.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("The Excel bond path does not move with the machine's time zone", .serialized)
struct BondClockZoneInvarianceTests {

	/// Settlement and maturity, built once at UTC midnight and passed into the sweep
	/// rather than rebuilt inside it. See the note on ``ZoneInvariance``.
	struct Bond: Sendable {
		let settlement: Date
		let maturity: Date
	}

	/// Microsoft's worked example for all six `COUP*` functions.
	static let example = Bond(
		settlement: ZoneInvariance.utc(2011, 1, 25),
		maturity: ZoneInvariance.utc(2011, 11, 15))

	/// Everything the coupon grid carries, in one comparable value.
	struct Grid: Equatable, Sendable {
		let previous: Date
		let next: Date
		let accrued: Double
		let toNext: Double
		let inPeriod: Double
		let remaining: Int

		init(_ period: CouponPeriod<Double>) {
			previous = period.previousCouponDate
			next = period.nextCouponDate
			accrued = period.daysAccrued
			toNext = period.daysToNextCoupon
			inPeriod = period.daysInPeriod
			remaining = period.couponsRemaining
		}
	}

	// MARK: - The sweep has teeth

	/// Before trusting the sweep, show it fires.
	///
	/// A detector that has never been observed to fire is indistinguishable from one
	/// that cannot, and this entire file exists because a suite that *could not fail*
	/// was mistaken for a suite that passed. So: a function that plainly does read
	/// the zone must be reported as reading it.
	///
	/// 15 November at UTC midnight is the 14th in New York and Niue and the 15th in
	/// Tokyo, so the day-of-month alone disagrees across the probe set.
	@Test("A function that reads the zone is detected as reading it")
	func theSweepDetectsAKnownDependence() {
		let sweep = ZoneInvariance.sweep(input: Self.example.maturity) { date in
			Calendar.current.component(.day, from: date)
		}
		#expect(!sweep.isInvariant, "the sweep is not exercising what it claims to:\n\(sweep)")
	}

	// MARK: - The grid

	@Test("The coupon grid is the same in every zone", arguments: [
		DayCountConvention.thirty360,
		.actualActual,
		.actual360,
		.actual365,
		.thirty360European,
	])
	func theGridIsInvariant(basis: DayCountConvention) throws {
		let sweep = try ZoneInvariance.sweep(input: Self.example) { bond in
			Grid(try CouponPeriod<Double>(
				settlement: bond.settlement, maturity: bond.maturity,
				frequency: .semiAnnual, basis: basis))
		}
		#expect(sweep.isInvariant, "CouponPeriod on \(basis.rawValue):\n\(sweep)")
	}

	@Test("The grid is the same in every zone at every frequency Excel allows")
	func theGridIsInvariantAcrossFrequencies() throws {
		for frequency in [PaymentFrequency.annual, .semiAnnual, .quarterly] {
			let sweep = try ZoneInvariance.sweep(input: Self.example) { bond in
				Grid(try CouponPeriod<Double>(
					settlement: bond.settlement, maturity: bond.maturity,
					frequency: frequency, basis: .thirty360))
			}
			#expect(sweep.isInvariant, "CouponPeriod at \(frequency):\n\(sweep)")
		}
	}

	// MARK: - What is defined on the grid

	@Test("PRICE is the same in every zone")
	func priceIsInvariant() throws {
		let bond = Bond(settlement: ZoneInvariance.utc(2008, 2, 15),
						maturity: ZoneInvariance.utc(2017, 11, 15))
		let sweep = try ZoneInvariance.sweep(input: bond) { bond in
			try bondPrice(settlement: bond.settlement, maturity: bond.maturity,
						  rate: 0.0575, yield: 0.065, redemption: 100,
						  frequency: .semiAnnual, basis: .thirty360) as Double
		}
		#expect(sweep.isInvariant, "bondPrice:\n\(sweep)")
	}

	@Test("YIELD is the same in every zone")
	func yieldIsInvariant() throws {
		let bond = Bond(settlement: ZoneInvariance.utc(2008, 2, 15),
						maturity: ZoneInvariance.utc(2016, 11, 15))
		let sweep = try ZoneInvariance.sweep(input: bond) { bond in
			try bondYield(settlement: bond.settlement, maturity: bond.maturity,
						  rate: 0.0575, price: 95.04287, redemption: 100,
						  frequency: .semiAnnual, basis: .thirty360) as Double
		}
		#expect(sweep.isInvariant, "bondYield:\n\(sweep)")
	}

	@Test("DURATION and MDURATION are the same in every zone")
	func durationsAreInvariant() throws {
		let bond = Bond(settlement: ZoneInvariance.utc(2008, 1, 1),
						maturity: ZoneInvariance.utc(2016, 1, 1))
		let macaulay = try ZoneInvariance.sweep(input: bond) { bond in
			try bondDuration(settlement: bond.settlement, maturity: bond.maturity,
							 rate: 0.08, yield: 0.09,
							 frequency: .semiAnnual, basis: .actualActual) as Double
		}
		#expect(macaulay.isInvariant, "bondDuration:\n\(macaulay)")

		let modified = try ZoneInvariance.sweep(input: bond) { bond in
			try bondModifiedDuration(settlement: bond.settlement, maturity: bond.maturity,
									 rate: 0.08, yield: 0.09,
									 frequency: .semiAnnual, basis: .actualActual) as Double
		}
		#expect(modified.isInvariant, "bondModifiedDuration:\n\(modified)")
	}

	/// `ACCRINT` walks its own quasi-coupon grid in a different file, so it needs its
	/// own sweep rather than inheriting the one above.
	@Test("ACCRINT is the same in every zone")
	func accruedInterestIsInvariant() throws {
		struct Terms: Sendable {
			let issue: Date
			let firstInterest: Date
			let settlement: Date
		}
		let terms = Terms(issue: ZoneInvariance.utc(2008, 3, 1),
						  firstInterest: ZoneInvariance.utc(2008, 8, 31),
						  settlement: ZoneInvariance.utc(2008, 5, 1))
		let sweep = try ZoneInvariance.sweep(input: terms) { terms in
			try accruedInterest(issue: terms.issue, firstInterest: terms.firstInterest,
								settlement: terms.settlement, rate: 0.10, par: 1000,
								frequency: .semiAnnual, basis: .thirty360) as Double
		}
		#expect(sweep.isInvariant, "accruedInterest:\n\(sweep)")
	}

	// MARK: - Day counts

	/// `DayCountConvention` was fixed at three `actual/*` sites and then at 30/360,
	/// and the note on `gregorianUTC` records that fixing three of four left the
	/// fourth looking like a rule defect. This is the check that would have said so.
	@Test("Every day count is the same in every zone", arguments: DayCountConvention.allCases)
	func dayCountsAreInvariant(convention: DayCountConvention) {
		struct Span: Sendable {
			let start: Date
			let end: Date
		}
		// A February month end to a 31st: the pair both 30/360 rules turn on.
		let spans = [
			Span(start: ZoneInvariance.utc(2020, 2, 29), end: ZoneInvariance.utc(2020, 12, 31)),
			Span(start: ZoneInvariance.utc(2011, 1, 25), end: ZoneInvariance.utc(2011, 11, 15)),
			Span(start: ZoneInvariance.utc(2026, 1, 1), end: ZoneInvariance.utc(2026, 7, 1)),
		]
		for span in spans {
			let days = ZoneInvariance.sweep(input: span) { span in
				convention.days(from: span.start, to: span.end)
			}
			#expect(days.isInvariant, "\(convention.rawValue).days:\n\(days)")

			let fraction = ZoneInvariance.sweep(input: span) { span in
				convention.yearFraction(from: span.start, to: span.end) as Double
			}
			#expect(fraction.isInvariant, "\(convention.rawValue).yearFraction:\n\(fraction)")
		}
	}
}

//
//  ComparableInversionTests.swift
//  BusinessMath
//
//  The exception to the campaign's governing fact, and it fails in the opposite direction.
//
//  Everywhere else, every comparison against a NaN is false, so a guard falls through to its
//  fallback — bad, but the guard at least fires. Swift synthesises `>=` as `!(lhs < rhs)` and
//  `<=` as `!(rhs < lhs)` for a `Comparable` that supplies only `<`. On a NaN-backed `Date`
//  those negate a false and answer **true**, so a validation guard written `end >= start`
//  fails OPEN and admits the contaminated value as valid.
//
//  Measured:
//      raw Double : nan >= x            -> false
//      Date       : nanDate >= realDate -> TRUE
//      control    : Date(0) >= Date(1.7e9) -> false   (a real inversion is still rejected)
//
//  `Period.day(_:)` is deliberately not covered here: `Calendar.startOfDay(for:)` launders a
//  NaN-backed date into the real, finite 4713-01-01, so its periods behave correctly. The
//  damage was specific to `custom(start:end:)` and the decoder, which store the date verbatim.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("A Comparable wrapper's derived operators do not reject a NaN")
struct ComparableInversionTests {

	private static let realDate = Date(timeIntervalSinceReferenceDate: 1.7e9)
	private static let nanDate = Date(timeIntervalSinceReferenceDate: .nan)

	// MARK: - The mechanism, pinned

	@Test("Date's derived operators answer true where the raw Double answers false")
	func derivedOperatorsInvertOnANaN() {
		// If a future toolchain changes how Comparable is synthesised, this is where it shows.
		let rawAtLeast: Bool = Double.nan >= 1.7e9
		#expect(rawAtLeast == false, "the campaign's governing fact, on a bare Double")

		let dateAtLeast: Bool = Self.nanDate >= Self.realDate
		let dateAtMost: Bool = Self.nanDate <= Self.realDate
		#expect(dateAtLeast, "Date's >= is !(<), so it negates a false")
		#expect(dateAtMost, "and so is <=")

		// The strict operators are not derived, so they behave as expected.
		let strictlyGreater: Bool = Self.nanDate > Self.realDate
		#expect(strictlyGreater == false)
	}

	@Test("A NaN-backed Date is not equal to itself")
	func aContaminatedDateIsNotEqualToItself() {
		// This is what made a surviving Period unusable as a dictionary key: a Set gains a
		// duplicate on every insert, and `values[period]` cannot find the key just stored.
		#expect((Self.nanDate == Self.nanDate) == false)
	}

	// MARK: - The guards that used to fail open

	@Test("range(from:to:) no longer admits a period it cannot place")
	func rangeQueryExcludesAnUnplaceablePeriod() throws {
		// A contaminated period used to satisfy `>= start && <= end` for ANY bounds, then get
		// dropped by the value lookup — so the period and value arrays disagreed by one.
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let mar = Period.month(year: 2025, month: 3)
		let clean = TimeSeries(periods: [jan, feb, mar], values: [1.0, 2.0, 3.0])

		let subset = clean.range(from: jan, to: feb)
		#expect(subset.periods.count == 2)
		#expect(subset.valuesArray.count == subset.periods.count, "the two must not disagree")
		#expect(subset.valuesArray[0].isEqual(to: 1.0))
		#expect(subset.valuesArray[1].isEqual(to: 2.0))
	}

	// MARK: - Controls: the guards still do their original job

	@Test("A genuine inversion is still rejected")
	func realInversionStillRejected() {
		// The ordering check is unchanged; only the unevaluable case was passing it.
		let earlier = Date(timeIntervalSinceReferenceDate: 0)
		let atLeast: Bool = earlier >= Self.realDate
		#expect(atLeast == false)
	}

	@Test("A well-formed custom period is unchanged")
	func wellFormedCustomPeriodStillBuilds() {
		let start = Date(timeIntervalSinceReferenceDate: 1.0e9)
		let end = Date(timeIntervalSinceReferenceDate: 1.1e9)
		let span = Period.custom(start: start, end: end)
		#expect(span.type == .custom)
		#expect(span.startDate == start)
	}

	@Test("days() still enumerates an ordinary span and terminates")
	func daysStillEnumeratesACleanSpan() {
		// The loop's own precondition returns [] for an unusable bound rather than allocating
		// for ever; a real span is untouched. January 2025 has 31 days.
		let january = Period.month(year: 2025, month: 1)
		let enumerated = january.days()
		#expect(enumerated.count == 31, "got \(enumerated.count)")
	}

	@Test("Period.day launders a contaminated date, and is deliberately not guarded")
	func periodDayIsSafeByLaundering() {
		// `Calendar.startOfDay(for:)` maps a NaN-backed date to the real 4713-01-01, so the
		// resulting period has working equality and ordering. Pinned so nobody adds a guard
		// here on the assumption it has the same defect as `custom`.
		let laundered = Period.day(Self.nanDate)
		#expect(laundered == laundered, "a laundered period is equal to itself")
		#expect(laundered.startDate.timeIntervalSinceReferenceDate.isFinite)
	}

	// MARK: - The same shape, fixed at the source

	@Test("FormattedValue's inclusive operators answer what the wrapped number answers")
	func formattedValueDoesNotInvert() {
		// `FormattedValue` is constrained to `T: FloatingPoint`, so unlike `Date` every
		// instantiation wraps a float and the hazard is not conditional. It supplies `<=` and
		// `>=` explicitly rather than letting Swift synthesise them as negations of `<`.
		let unusable = FormattedValue(rawValue: Double.nan, formatted: "NaN")
		let real = FormattedValue(rawValue: 42.0, formatted: "42")

		let atLeast: Bool = unusable >= real
		let atMost: Bool = unusable <= real
		#expect(atLeast == false, "synthesised >= would answer true here")
		#expect(atMost == false, "and so would synthesised <=")

		// The strict operators were never wrong; pinned so a later edit cannot regress them.
		#expect((unusable > real) == false)
		#expect((unusable < real) == false)
	}

	@Test("FormattedValue still orders ordinary values")
	func formattedValueStillOrders() {
		// The control: the fix must not have broken comparison for the values it is for.
		let small = FormattedValue(rawValue: 1.0, formatted: "1")
		let large = FormattedValue(rawValue: 2.0, formatted: "2")
		#expect(small < large)
		#expect(small <= large)
		#expect(large >= small)
		#expect(large > small)
		#expect(small <= small, "a value is at most itself")
		#expect(small >= small, "and at least itself")
	}
}

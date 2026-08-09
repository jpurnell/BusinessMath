//
//  PeriodSemiannualAndCustomTests.swift
//  BusinessMath
//
//  Covers the two additions to `Period` driven by the possible move from
//  quarterly to semiannual public reporting:
//
//  1. `.semiannual` as a first-class rung on the granularity ladder.
//  2. `.custom` — an arbitrary date range, for the odd-length transition stub
//     a company emits when it switches reporting cadence or fiscal year-end.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Period Semiannual and Custom Range Tests")
struct PeriodSemiannualAndCustomTests {

	let tolerance: Double = 0.0001

	// MARK: - Decision 1: Ordering decoupled from raw value

	@Test("Raw values of the original eight cases are unchanged")
	func legacyRawValuesStable() {
		#expect(PeriodType.millisecond.rawValue == 0)
		#expect(PeriodType.second.rawValue == 1)
		#expect(PeriodType.minute.rawValue == 2)
		#expect(PeriodType.hourly.rawValue == 3)
		#expect(PeriodType.daily.rawValue == 4)
		#expect(PeriodType.monthly.rawValue == 5)
		#expect(PeriodType.quarterly.rawValue == 6)
		#expect(PeriodType.annual.rawValue == 7)
	}

	@Test("New cases append raw values without disturbing the old ones")
	func newRawValuesAppend() {
		#expect(PeriodType.semiannual.rawValue == 8)
		#expect(PeriodType.custom.rawValue == 9)
	}

	@Test("Granularity rank orders semiannual between quarterly and annual")
	func granularityRankOrdering() {
		#expect(PeriodType.quarterly.granularityRank < PeriodType.semiannual.granularityRank)
		#expect(PeriodType.semiannual.granularityRank < PeriodType.annual.granularityRank)
	}

	@Test("Comparable follows granularity, not raw value")
	func comparableUsesGranularity() {
		#expect(PeriodType.quarterly < PeriodType.semiannual)
		#expect(PeriodType.semiannual < PeriodType.annual)
		// Raw value would have put semiannual (8) above annual (7). It must not.
		#expect(!(PeriodType.annual < PeriodType.semiannual))
	}

	@Test("Sorting all regular cases yields the granularity ladder")
	func sortedLadder() {
		let regular = PeriodType.allCases.filter { $0.isRegular }
		#expect(regular.sorted() == [
			.millisecond, .second, .minute, .hourly, .daily,
			.monthly, .quarterly, .semiannual, .annual
		])
	}

	@Test("Custom is not a regular ladder rung and sorts last")
	func customSortsLast() {
		#expect(PeriodType.custom.isRegular == false)
		#expect(PeriodType.annual < PeriodType.custom)
		#expect(PeriodType.allCases.sorted().last == .custom)
	}

	@Test("All ten cases are iterable")
	func allCasesCount() {
		#expect(PeriodType.allCases.count == 10)
		#expect(PeriodType.allCases.contains(.semiannual))
		#expect(PeriodType.allCases.contains(.custom))
	}

	// MARK: - Decision 2: Semiannual conversion tables

	@Test("Semiannual answers all three conversion tables")
	func semiannualConversionTables() throws {
		#expect(abs(try #require(PeriodType.semiannual.daysApproximate) - 182.625) < tolerance)
		#expect(abs(try #require(PeriodType.semiannual.monthsEquivalent) - 6.0) < tolerance)
		#expect(abs(try #require(PeriodType.semiannual.millisecondsExact) - (182.625 * 86_400_000.0)) < 1.0)
	}

	@Test("Semiannual converts cleanly to annual and quarterly")
	func semiannualConverts() throws {
		#expect(abs(try #require(PeriodType.semiannual.convert(2.0, to: .annual)) - 1.0) < tolerance)
		#expect(abs(try #require(PeriodType.semiannual.convert(1.0, to: .quarterly)) - 2.0) < tolerance)
		#expect(abs(try #require(PeriodType.annual.convert(1.0, to: .semiannual)) - 2.0) < tolerance)
	}

	// MARK: - Decision 2: Semiannual periods

	@Test("Can create first-half period")
	func createFirstHalf() {
		let h1 = Period.semiannual(year: 2025, half: 1)
		#expect(h1.type == .semiannual)
		#expect(h1.year == 2025)
		#expect(h1.month == 1)
		#expect(h1.half == 1)
	}

	@Test("Can create second-half period")
	func createSecondHalf() {
		let h2 = Period.semiannual(year: 2025, half: 2)
		#expect(h2.type == .semiannual)
		#expect(h2.year == 2025)
		#expect(h2.month == 7)
		#expect(h2.half == 2)
	}

	@Test("Semiannual label is YYYY-HN")
	func semiannualLabel() {
		#expect(Period.semiannual(year: 2025, half: 1).label == "2025-H1")
		#expect(Period.semiannual(year: 2025, half: 2).label == "2025-H2")
	}

	@Test("Semiannual end date is the last instant of the sixth month")
	func semiannualEndDate() {
		let h1 = Period.semiannual(year: 2025, half: 1)
		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month, .day], from: h1.endDate)
		#expect(components.year == 2025)
		#expect(components.month == 6)
		#expect(components.day == 30)

		let h2 = Period.semiannual(year: 2025, half: 2)
		let endComponents = calendar.dateComponents([.year, .month, .day], from: h2.endDate)
		#expect(endComponents.year == 2025)
		#expect(endComponents.month == 12)
		#expect(endComponents.day == 31)
	}

	@Test("Semiannual next() steps by six months and rolls the year")
	func semiannualNext() {
		let h1 = Period.semiannual(year: 2025, half: 1)
		#expect(h1.next() == Period.semiannual(year: 2025, half: 2))
		#expect(h1.next().next() == Period.semiannual(year: 2026, half: 1))
	}

	@Test("Semiannual arithmetic advances in halves")
	func semiannualArithmetic() {
		let h1 = Period.semiannual(year: 2025, half: 1)
		#expect(h1 + 1 == Period.semiannual(year: 2025, half: 2))
		#expect(h1 + 2 == Period.semiannual(year: 2026, half: 1))
		#expect(h1 - 1 == Period.semiannual(year: 2024, half: 2))
	}

	@Test("Semiannual distance is measured in halves")
	func semiannualDistance() throws {
		let h1 = Period.semiannual(year: 2025, half: 1)
		let later = Period.semiannual(year: 2026, half: 2)
		#expect(try h1.distance(to: later) == 3)
		#expect(try later.distance(to: h1) == -3)
	}

	@Test("Semiannual ranges iterate")
	func semiannualRange() {
		let range = Period.semiannual(year: 2025, half: 1)...Period.semiannual(year: 2026, half: 2)
		let periods = Array(range)
		#expect(periods.count == 4)
		#expect(periods.first?.label == "2025-H1")
		#expect(periods.last?.label == "2026-H2")
	}

	@Test("Semiannual subdivides into months and quarters")
	func semiannualSubdivision() {
		let h1 = Period.semiannual(year: 2025, half: 1)
		#expect(h1.months().count == 6)
		#expect(h1.months().first?.label == "2025-01")
		#expect(h1.months().last?.label == "2025-06")

		#expect(h1.quarters().count == 2)
		#expect(h1.quarters().first?.label == "2025-Q1")
		#expect(h1.quarters().last?.label == "2025-Q2")

		let h2 = Period.semiannual(year: 2025, half: 2)
		#expect(h2.months().first?.label == "2025-07")
		#expect(h2.quarters().first?.label == "2025-Q3")
	}

	@Test("Annual subdivides into two halves")
	func annualToSemiannuals() {
		let year = Period.year(2025)
		let halves = year.semiannuals()
		#expect(halves.count == 2)
		#expect(halves[0].label == "2025-H1")
		#expect(halves[1].label == "2025-H2")

		#expect(Period.semiannual(year: 2025, half: 1).semiannuals().count == 1)
		#expect(Period.quarter(year: 2025, quarter: 1).semiannuals().isEmpty)
	}

	@Test("Semiannual periods sort between quarterly and annual")
	func semiannualPeriodOrdering() {
		let q = Period.quarter(year: 2025, quarter: 1)
		let h = Period.semiannual(year: 2025, half: 1)
		let y = Period.year(2025)
		#expect(q < h)
		#expect(h < y)
	}

	@Test("Fiscal calendar maps semiannual periods to fiscal halves")
	func fiscalSemiannual() {
		let standard = FiscalCalendar.standard
		#expect(standard.periodInFiscalYear(Period.semiannual(year: 2025, half: 1)) == 1)
		#expect(standard.periodInFiscalYear(Period.semiannual(year: 2025, half: 2)) == 2)

		// Apple: Oct 1 - Sep 30. Calendar H1 (Jan) is fiscal month 4 -> fiscal half 1.
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))
		#expect(apple.periodInFiscalYear(Period.semiannual(year: 2025, half: 1)) == 1)
		// Calendar H2 (Jul) is fiscal month 10 -> fiscal half 2.
		#expect(apple.periodInFiscalYear(Period.semiannual(year: 2025, half: 2)) == 2)
	}

	@Test("Aggregating quarterly data to semiannual sums the halves")
	func aggregateToSemiannual() {
		let series = TimeSeries<Double>(
			periods: [
				Period.quarter(year: 2025, quarter: 1),
				Period.quarter(year: 2025, quarter: 2),
				Period.quarter(year: 2025, quarter: 3),
				Period.quarter(year: 2025, quarter: 4)
			],
			values: [10.0, 20.0, 30.0, 40.0]
		)

		let halves = series.aggregate(to: .semiannual, method: .sum)
		#expect(halves.count == 2)
		#expect(abs((halves[Period.semiannual(year: 2025, half: 1)] ?? 0) - 30.0) < tolerance)
		#expect(abs((halves[Period.semiannual(year: 2025, half: 2)] ?? 0) - 70.0) < tolerance)
	}

	// MARK: - Decision 3: Arbitrary ranges

	private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = day
		guard let d = Calendar.current.date(from: components) else {
			preconditionFailure("bad test date")
		}
		return d
	}

	@Test("Custom period stores its own start and end verbatim")
	func customStoresEnd() {
		let start = date(2025, 1, 1)
		let end = date(2025, 8, 15)
		let stub = Period.custom(start: start, end: end)

		#expect(stub.type == .custom)
		#expect(stub.startDate == start)
		#expect(stub.endDate == end)
	}

	@Test("Custom period label shows the full interval")
	func customLabel() {
		let stub = Period.custom(start: date(2025, 1, 1), end: date(2025, 8, 15))
		#expect(stub.label == "2025-01-01/2025-08-15")
	}

	@Test("Custom periods with different ends are distinct values")
	func customEqualityUsesEnd() {
		let a = Period.custom(start: date(2025, 1, 1), end: date(2025, 6, 30))
		let b = Period.custom(start: date(2025, 1, 1), end: date(2025, 8, 15))
		#expect(a != b)
		#expect(a < b)  // same type, same start -> tie-break on end
		#expect(Set([a, b]).count == 2)
		#expect([b, a].sorted() == [a, b])
	}

	@Test("Calendar component properties describe a custom period's start, not its extent")
	func customComponentPropertiesDescribeStart() {
		// A stub spilling from Q2 into Q3 and from H1 into H2.
		let stub = Period.custom(start: date(2025, 4, 1), end: date(2025, 8, 31))
		#expect(stub.year == 2025)
		#expect(stub.month == 4)
		#expect(stub.day == 1)
		#expect(stub.quarter == 2)  // start's quarter, even though the range reaches Q3
		#expect(stub.half == 1)     // start's half, even though the range reaches H2
	}

	@Test("Custom periods order by start date first")
	func customOrdering() {
		let early = Period.custom(start: date(2025, 1, 1), end: date(2025, 12, 31))
		let late = Period.custom(start: date(2025, 7, 1), end: date(2025, 8, 1))
		#expect(early < late)
	}

	@Test("Custom period subdivides into the days it actually covers")
	func customDays() {
		// January 1 through January 10 inclusive of the end instant.
		let stub = Period.custom(start: date(2025, 1, 1), end: date(2025, 1, 10))
		let days = stub.days()
		#expect(days.count == 10)
		#expect(days.first?.label == "2025-01-01")
		#expect(days.last?.label == "2025-01-10")
	}

	@Test("Custom period refuses ladder subdivision")
	func customLadderSubdivisionEmpty() {
		let stub = Period.custom(start: date(2025, 1, 1), end: date(2025, 8, 15))
		#expect(stub.months().isEmpty)
		#expect(stub.quarters().isEmpty)
		#expect(stub.semiannuals().isEmpty)
	}

	// MARK: - Decision 4: Instance-level durations

	@Test("Instance duration for ladder periods matches the type table")
	func instanceDurationMatchesTypeTable() throws {
		#expect(abs(Period.month(year: 2025, month: 1).durationInDays - (try #require(PeriodType.monthly.daysApproximate))) < tolerance)
		#expect(abs(Period.quarter(year: 2025, quarter: 1).durationInDays - (try #require(PeriodType.quarterly.daysApproximate))) < tolerance)
		#expect(abs(Period.semiannual(year: 2025, half: 1).durationInDays - 182.625) < tolerance)
		#expect(abs(Period.year(2025).durationInDays - 365.25) < tolerance)

		#expect(abs(Period.quarter(year: 2025, quarter: 1).durationInMonths - 3.0) < tolerance)
		#expect(abs(Period.semiannual(year: 2025, half: 1).durationInMonths - 6.0) < tolerance)
		#expect(abs(Period.year(2025).durationInMilliseconds - (try #require(PeriodType.annual.millisecondsExact))) < 1.0)
	}

	@Test("Instance duration for a custom period comes from the interval")
	func customInstanceDuration() {
		// 2025-01-01 through 2025-07-01: 181 days (Jan 31 + Feb 28 + Mar 31 + Apr 30 + May 31 + Jun 30).
		// The duration is real elapsed time, so in a zone that observes DST the span is
		// an hour short of 181 exact days. The tolerance below allows for that shift.
		let oneHourInDays = 1.0 / 24.0
		let stub = Period.custom(start: date(2025, 1, 1), end: date(2025, 7, 1))
		#expect(abs(stub.durationInDays - 181.0) <= oneHourInDays)
		#expect(abs(stub.durationInMilliseconds - (181.0 * 86_400_000.0)) <= 3_600_000.0)
		#expect(abs(stub.durationInMonths - (181.0 / (365.25 / 12.0))) < 0.01)
	}

	@Test("A zero-length custom period has zero duration")
	func zeroLengthCustom() {
		let instant = date(2025, 1, 1)
		let stub = Period.custom(start: instant, end: instant)
		#expect(abs(stub.durationInDays) < tolerance)
	}

	@Test("Custom period cannot answer type-level durations")
	func customTypeIsIrregular() {
		#expect(PeriodType.custom.isRegular == false)
		#expect(PeriodType.semiannual.isRegular == true)
	}

	// MARK: - Refusals

	@Test("Distance between two custom periods is refused")
	func customDistanceRefused() {
		let a = Period.custom(start: date(2025, 1, 1), end: date(2025, 6, 30))
		let b = Period.custom(start: date(2025, 7, 1), end: date(2025, 12, 31))
		#expect(throws: PeriodError.unsupportedPeriodType(.custom, operation: "distance(to:)")) {
			_ = try a.distance(to: b)
		}
	}

	@Test("Distance still refuses mismatched types, including custom vs ladder")
	func customDistanceTypeMismatch() {
		let stub = Period.custom(start: date(2025, 1, 1), end: date(2025, 6, 30))
		let q = Period.quarter(year: 2025, quarter: 1)
		#expect(throws: PeriodError.typeMismatch(from: .custom, to: .quarterly)) {
			_ = try stub.distance(to: q)
		}
	}

	@Test("Stepping a custom period is refused")
	func customSteppingRefused() {
		let stub = Period.custom(start: date(2025, 1, 1), end: date(2025, 6, 30))
		#expect(stub.nextIfSteppable() == nil)
		#expect(stub.advancedIfSteppable(by: 1) == nil)
		// Stepping by zero is the identity and is allowed.
		#expect(stub.advancedIfSteppable(by: 0) == stub)
	}

	@Test("Ladder periods remain steppable")
	func ladderSteppable() {
		#expect(Period.semiannual(year: 2025, half: 1).nextIfSteppable() == Period.semiannual(year: 2025, half: 2))
		#expect(Period.month(year: 2025, month: 1).advancedIfSteppable(by: 3) == Period.month(year: 2025, month: 4))
	}

	@Test("Aggregating to a custom target yields nothing")
	func aggregateToCustomIsEmpty() {
		let series = TimeSeries<Double>(
			periods: [Period.quarter(year: 2025, quarter: 1)],
			values: [10.0]
		)
		#expect(series.aggregate(to: .custom, method: .sum).count == 0)
	}

	// MARK: - Codable compatibility

	/// Previously persisted JSON has only `type` and `date`. It must keep decoding,
	/// with the end date derived from the type exactly as before.
	@Test("Legacy two-key JSON still decodes and derives its end date")
	func decodeLegacyJSON() throws {
		// 757_382_400 seconds since the 2001 reference date; type 6 == .quarterly.
		let json = #"{"type":6,"date":757382400}"#
		let decoded = try JSONDecoder().decode(Period.self, from: Data(json.utf8))

		#expect(decoded.type == .quarterly)
		#expect(decoded.date == Date(timeIntervalSinceReferenceDate: 757_382_400))

		// The end date was not in the JSON, so it must come from type + date.
		let spanDays = decoded.endDate.timeIntervalSince(decoded.startDate) / 86_400.0
		#expect(spanDays > 88.0 && spanDays < 93.0)
	}

	@Test("Legacy JSON for every original type decodes to the right case")
	func decodeLegacyJSONAllTypes() throws {
		let expected: [(Int, PeriodType)] = [
			(0, .millisecond), (1, .second), (2, .minute), (3, .hourly),
			(4, .daily), (5, .monthly), (6, .quarterly), (7, .annual)
		]
		for (raw, type) in expected {
			let json = #"{"type":\#(raw),"date":757382400}"#
			let decoded = try JSONDecoder().decode(Period.self, from: Data(json.utf8))
			#expect(decoded.type == type)
		}
	}

	@Test("Encoding a ladder period emits no end key, so old readers still work")
	func encodeLadderPeriodOmitsEnd() throws {
		let q = Period.quarter(year: 2025, quarter: 1)
		let data = try JSONEncoder().encode(q)
		let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
		let keys = Set(object?.keys ?? [:].keys)
		#expect(keys == ["type", "date"])
	}

	@Test("Encoding a custom period emits the end key")
	func encodeCustomPeriodIncludesEnd() throws {
		let stub = Period.custom(start: date(2025, 1, 1), end: date(2025, 8, 15))
		let data = try JSONEncoder().encode(stub)
		let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
		let keys = Set(object?.keys ?? [:].keys)
		#expect(keys == ["type", "date", "end"])
		#expect((object?["type"] as? Int) == 9)
	}

	@Test("Custom period round-trips through Codable with its end intact")
	func customCodableRoundTrip() throws {
		let stub = Period.custom(start: date(2025, 1, 1), end: date(2025, 8, 15))
		let data = try JSONEncoder().encode(stub)
		let decoded = try JSONDecoder().decode(Period.self, from: data)
		#expect(decoded == stub)
		#expect(decoded.endDate == stub.endDate)
	}

	@Test("Pinned custom JSON decodes to the exact interval")
	func decodePinnedCustomJSON() throws {
		let json = #"{"type":9,"date":757382400,"end":776908800}"#
		let decoded = try JSONDecoder().decode(Period.self, from: Data(json.utf8))
		#expect(decoded.type == .custom)
		#expect(decoded.startDate == Date(timeIntervalSinceReferenceDate: 757_382_400))
		#expect(decoded.endDate == Date(timeIntervalSinceReferenceDate: 776_908_800))
		#expect(abs(decoded.durationInDays - ((776_908_800.0 - 757_382_400.0) / 86_400.0)) < tolerance)
	}

	@Test("A custom period with no end in the JSON is rejected, not guessed")
	func decodeCustomWithoutEndThrows() {
		let json = #"{"type":9,"date":757382400}"#
		#expect(throws: DecodingError.self) {
			_ = try JSONDecoder().decode(Period.self, from: Data(json.utf8))
		}
	}

	@Test("A custom period whose end precedes its start is rejected")
	func decodeCustomWithInvertedIntervalThrows() {
		let json = #"{"type":9,"date":776908800,"end":757382400}"#
		#expect(throws: DecodingError.self) {
			_ = try JSONDecoder().decode(Period.self, from: Data(json.utf8))
		}
	}

	@Test("Semiannual period round-trips through Codable")
	func semiannualCodableRoundTrip() throws {
		let h2 = Period.semiannual(year: 2025, half: 2)
		let data = try JSONEncoder().encode(h2)
		let decoded = try JSONDecoder().decode(Period.self, from: data)
		#expect(decoded == h2)
		#expect(decoded.label == "2025-H2")
	}

	@Test("PeriodType raw encoding is unchanged for legacy cases")
	func periodTypeCodableStable() throws {
		let data = try JSONEncoder().encode(PeriodType.quarterly)
		#expect(String(data: data, encoding: .utf8) == "6")
		let semi = try JSONEncoder().encode(PeriodType.semiannual)
		#expect(String(data: semi, encoding: .utf8) == "8")
	}

	// MARK: - Type-level conversion tables refuse without trapping
	//
	// `.custom` is a public case any caller can construct, so a library that traps
	// on it kills the host process over a legal input. The three tables answer with
	// `nil` instead; the instance-level accessors on `Period` remain non-optional.

	@Test("daysApproximate is nil for custom and unchanged for the ladder")
	func daysApproximateIsOptional() throws {
		#expect(PeriodType.custom.daysApproximate == nil)

		let monthly = try #require(PeriodType.monthly.daysApproximate)
		#expect(abs(monthly - 30.4375) < tolerance)
	}

	@Test("millisecondsExact is nil for custom and unchanged for the ladder")
	func millisecondsExactIsOptional() throws {
		#expect(PeriodType.custom.millisecondsExact == nil)

		let hourly = try #require(PeriodType.hourly.millisecondsExact)
		#expect(abs(hourly - 3_600_000.0) < tolerance)
	}

	@Test("monthsEquivalent is nil for custom and unchanged for the ladder")
	func monthsEquivalentIsOptional() throws {
		#expect(PeriodType.custom.monthsEquivalent == nil)

		let quarterly = try #require(PeriodType.quarterly.monthsEquivalent)
		#expect(abs(quarterly - 3.0) < tolerance)
	}

	@Test("convert propagates nil when either side is a custom range")
	func convertIsOptionalForCustom() throws {
		#expect(PeriodType.custom.convert(1.0, to: .monthly) == nil)
		#expect(PeriodType.monthly.convert(1.0, to: .custom) == nil)
		// Same-type shortcut must not smuggle a value out for custom either.
		#expect(PeriodType.custom.convert(1.0, to: .custom) == nil)

		let months = try #require(PeriodType.annual.convert(1.0, to: .monthly))
		#expect(abs(months - 12.0) < tolerance)
	}

	@Test("A custom period is still measurable through the instance accessors")
	func customMeasurableViaInstanceAccessors() {
		// The point of the change: the type has no answer, the instance does, and
		// asking the type no longer takes the process down.
		let stub = Period.custom(start: date(2025, 4, 1), end: date(2025, 8, 31))
		#expect(stub.type.daysApproximate == nil)
		#expect(stub.durationInDays > 150.0)
	}

	// MARK: - Ladder values pinned

	@Test("No ladder-case value moved when the tables became optional")
	func ladderConversionValuesUnchanged() throws {
		let expectedDays: [PeriodType: Double] = [
			.millisecond: 1.0 / 86_400_000.0,
			.second: 1.0 / 86_400.0,
			.minute: 1.0 / 1_440.0,
			.hourly: 1.0 / 24.0,
			.daily: 1.0,
			.monthly: 365.25 / 12.0,
			.quarterly: 365.25 / 4.0,
			.semiannual: 365.25 / 2.0,
			.annual: 365.25
		]
		for (type, expected) in expectedDays {
			let actual = try #require(type.daysApproximate, "\(type) must still answer daysApproximate")
			#expect(actual == expected, "daysApproximate moved for \(type)")
		}

		let expectedMilliseconds: [PeriodType: Double] = [
			.millisecond: 1.0,
			.second: 1_000.0,
			.minute: 60_000.0,
			.hourly: 3_600_000.0,
			.daily: 86_400_000.0,
			.monthly: 30.4375 * 86_400_000.0,
			.quarterly: 91.3125 * 86_400_000.0,
			.semiannual: 182.625 * 86_400_000.0,
			.annual: 365.25 * 86_400_000.0
		]
		for (type, expected) in expectedMilliseconds {
			let actual = try #require(type.millisecondsExact, "\(type) must still answer millisecondsExact")
			#expect(actual == expected, "millisecondsExact moved for \(type)")
		}

		let expectedMonths: [PeriodType: Double] = [
			.millisecond: 1.0 / (365.25 / 12.0 * 86_400_000.0),
			.second: 1.0 / (365.25 / 12.0 * 86_400.0),
			.minute: 1.0 / (365.25 / 12.0 * 1_440.0),
			.hourly: 1.0 / (365.25 / 12.0 * 24.0),
			.daily: 1.0 / (365.25 / 12.0),
			.monthly: 1.0,
			.quarterly: 3.0,
			.semiannual: 6.0,
			.annual: 12.0
		]
		for (type, expected) in expectedMonths {
			let actual = try #require(type.monthsEquivalent, "\(type) must still answer monthsEquivalent")
			#expect(actual == expected, "monthsEquivalent moved for \(type)")
		}
	}
}

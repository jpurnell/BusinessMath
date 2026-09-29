//
//  Phase4StatementsAndSeriesTests.swift
//  BusinessMath
//
//  Phase 4 of the contaminated-input sweep, for the four API-shape decisions that had been
//  deferred three times: the trapping custom amortization schedule, the covenant `Bool` with
//  no third state, the additive decomposition that was not computed additively, and the
//  period-gap semantics of `growthRate(lag:)` / `diff(lag:)` / `averageTimeSeries`.
//
//  Two of these deliberately change existing answers, so the tests pin the delta rather than
//  implying it: the additive seasonal component and the length of a gapped growth series.
//
//  Every expected value here is either exactly representable and derived by hand in rational
//  arithmetic (the decomposition numbers — the centred moving average of the fixture runs
//  116.25, 118.75, 121.25, 123.75, 126.25, 128.75, 131.25, 133.75, all quarters) or is a
//  structural property that needs no number at all.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Elementwise agreement that treats `nan` as equal to `nan`.
///
/// `isEqual(to:)` is IEEE equality, so `Double.nan.isEqual(to: .nan)` is **false** and a plain
/// zip-and-compare cannot assert that a position is unusable. `==` on `[Double]` is banned
/// outright.
private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
	lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) || ($0.isNaN && $1.isNaN) }
}

@Suite("Phase 4 — statements and series API decisions")
struct Phase4StatementsAndSeriesTests {

	// MARK: - Fixtures

	private func quarters(_ count: Int) -> [Period] {
		(0..<count).map { Period.quarter(year: 2024 + $0 / 4, quarter: $0 % 4 + 1) }
	}

	private func quarterly(_ values: [Double]) -> TimeSeries<Double> {
		TimeSeries(periods: quarters(values.count), values: values)
	}

	/// A twelve-quarter series with a rising level and a strong Q2.
	///
	/// The expected seasonal component is **not** taken from a generator: the centred moving
	/// average this library computes lags the underlying trend, so the measured offsets differ
	/// from any offsets one might claim to have planted. Every expected value is derived in the
	/// test that uses it, from the trend the library actually produces.
	private static let seasonalTwelve: [Double] = [
		110.0, 130.0, 110.0, 110.0,
		120.0, 140.0, 120.0, 120.0,
		130.0, 150.0, 130.0, 130.0
	]

	/// An exactly linear trend from −55 to +55 carrying the fixed offsets `[-5, 0, +5, +20]`,
	/// i.e. a business crossing from loss into profit with a seasonal swing that is constant in
	/// currency. Centred to sum zero the planted offsets are `[-10, -5, 0, +15]`.
	private static let zeroCrossingTrend: [Double] = [
		-60.0, -45.0, -30.0, -5.0,
		-20.0, -5.0, 10.0, 35.0,
		20.0, 35.0, 50.0, 75.0
	]

	// MARK: - 1. Additive decomposition is now computed additively

	/// RED before the change: the seasonal component was `seasonalIndices` re-centred, so it
	/// came back as roughly `[-0.009, +0.127, -0.048, -0.070]` — dimensionless ratios about
	/// 1/128th the size of the effect present — and the whole seasonal swing landed in the
	/// residual instead.
	///
	/// The expected values are derived, not recalled. The centred moving average of the fixture
	/// is defined at indices 3…10 and runs 116.25, 118.75, 121.25, 123.75, 126.25, 128.75,
	/// 131.25, 133.75, so `value - trend` is −6.25, 1.25, 18.75, −3.75 repeating. The per-season
	/// means are therefore 1.25, 18.75, −3.75, −6.25 (seasons 0…3), whose mean is 2.5, and
	/// centring gives −1.25, 16.25, −6.25, −8.75. Every one of those is a multiple of a quarter
	/// and so exactly representable.
	///
	/// These are deliberately **not** the offsets the fixture's generating formula names. A
	/// centred moving average smooths a step in the level, so part of the step is attributed to
	/// the season carrying it — classical decomposition's behaviour, and the reason the expected
	/// values here are derived from the trend the library computes rather than from the
	/// generator. The exactly-linear-trend fixture below is the one where the two agree, and it
	/// is the stronger oracle for that reason.
	@Test("AdditiveDecomposition_SeasonalComponent_CarriesTheSeriesOwnUnits")
	func additiveSeasonalComponentCarriesTheSeriesOwnUnits() throws {
		let series = quarterly(Self.seasonalTwelve)
		let decomposition = try decomposeTimeSeries(
			timeSeries: series,
			periodsPerYear: 4,
			method: .additive
		)

		let seasonal: [Double] = decomposition.seasonal.valuesArray
		let firstCycle: [Double] = Array(seasonal[0..<4])
		let expectedCycle: [Double] = [-1.25, 16.25, -6.25, -8.75]
		let cycleMatches: Bool = agree(firstCycle, expectedCycle)
		#expect(cycleMatches, "additive seasonal was \(firstCycle), expected \(expectedCycle)")

		// The component repeats with the cycle, and it sums to zero — the defining property of
		// a centred additive seasonal term. Summed exactly: -1.25 + 16.25 - 6.25 - 8.75 = 0.
		let cycleSum: Double = firstCycle.reduce(0.0, +)
		#expect(cycleSum.isEqual(to: 0.0), "centred additive indices must sum to zero, got \(cycleSum)")

		let thirdCycle: [Double] = Array(seasonal[8..<12])
		let cyclesRepeat: Bool = agree(firstCycle, thirdCycle)
		#expect(cyclesRepeat, "the seasonal component must repeat with the cycle")
	}

	/// The mechanism, not the numbers: an *additive* seasonal component is linear in the data
	/// and a *multiplicative* index is invariant under scaling. Multiplying every observation by
	/// ten must multiply the component by ten.
	///
	/// This is what the previous implementation could not do, and it is why the old figures
	/// cannot be converted into the new ones by any fixed factor — the factor was the level of
	/// the series. The control below shows the multiplicative path is unchanged and still
	/// scale-invariant, so the test discriminates rather than merely passing.
	@Test("AdditiveSeasonal_ScalesWithTheData_WhileTheMultiplicativeIndexDoesNot")
	func additiveSeasonalScalesWithTheDataWhileMultiplicativeDoesNot() throws {
		let plain = quarterly(Self.seasonalTwelve)
		let scaled = quarterly(Self.seasonalTwelve.map { $0 * 10.0 })

		let plainAdditive = try decomposeTimeSeries(timeSeries: plain, periodsPerYear: 4, method: .additive)
		let scaledAdditive = try decomposeTimeSeries(timeSeries: scaled, periodsPerYear: 4, method: .additive)

		let plainSeasonal: [Double] = Array(plainAdditive.seasonal.valuesArray[0..<4])
		let scaledSeasonal: [Double] = Array(scaledAdditive.seasonal.valuesArray[0..<4])
		let tenTimes: [Double] = plainSeasonal.map { $0 * 10.0 }
		let scalesLinearly: Bool = agree(scaledSeasonal, tenTimes)
		#expect(scalesLinearly, "additive seasonal must carry units: got \(scaledSeasonal), expected \(tenTimes)")

		// Control: the multiplicative index is a ratio and must NOT move.
		let plainMultiplicative = try decomposeTimeSeries(timeSeries: plain, periodsPerYear: 4, method: .multiplicative)
		let scaledMultiplicative = try decomposeTimeSeries(timeSeries: scaled, periodsPerYear: 4, method: .multiplicative)
		let plainIndex: [Double] = Array(plainMultiplicative.seasonal.valuesArray[0..<4])
		let scaledIndex: [Double] = Array(scaledMultiplicative.seasonal.valuesArray[0..<4])
		let indexIsInvariant: Bool = agree(plainIndex, scaledIndex)
		#expect(indexIsInvariant, "the multiplicative index is a ratio and must not scale")
	}

	/// The series the function now explains correctly and used to refuse outright.
	///
	/// A trend crossing zero makes `value / trend` meaningless, so `.multiplicative` still
	/// refuses. Nothing in the additive definition divides by the trend, so `.additive` now
	/// recovers the planted offsets exactly: the centred moving average is −30, −20, −10, 0, 10,
	/// 20, 30, 40 at indices 3…10, `value - trend` is 25, 0, 5, 10 repeating, the season means
	/// are 0, 5, 10, 25 with mean 10, and centring gives −10, −5, 0, +15 — which is the planted
	/// `[-5, 0, +5, +20]` centred on its own mean of 5.
	@Test("AdditiveDecomposition_AcrossAZeroCrossingTrend_RecoversThePlantedOffsets")
	func additiveDecompositionAcrossZeroCrossingRecoversPlantedOffsets() throws {
		let series = quarterly(Self.zeroCrossingTrend)

		let decomposition = try decomposeTimeSeries(timeSeries: series, periodsPerYear: 4, method: .additive)
		let seasonal: [Double] = Array(decomposition.seasonal.valuesArray[0..<4])
		let planted: [Double] = [-10.0, -5.0, 0.0, 15.0]
		let recovered: Bool = agree(seasonal, planted)
		#expect(recovered, "additive seasonal was \(seasonal), planted offsets centre to \(planted)")

		// Control, unchanged: the multiplicative model is undefined for this series and still
		// says so. If this ever passes, the refusal has been lifted for the wrong method.
		#expect(throws: SeasonalityError.self) {
			_ = try decomposeTimeSeries(timeSeries: series, periodsPerYear: 4, method: .multiplicative)
		}
	}

	/// The zero-crossing refusal was lifted for `.additive`; the contamination refusal was not.
	/// They arrived together through `seasonalIndices` and had to be separated by hand, so this
	/// pins that only one of them moved.
	@Test("AdditiveDecomposition_WithAContaminatedObservation_StillRefuses")
	func additiveDecompositionWithContaminatedObservationStillRefuses() {
		var values: [Double] = Self.seasonalTwelve
		values[5] = .nan
		let series = quarterly(values)

		#expect(throws: BusinessMathError.self) {
			_ = try decomposeTimeSeries(timeSeries: series, periodsPerYear: 4, method: .additive)
		}
	}

	/// `Value = Trend + Seasonal + Residual` is closed by construction and must stay closed —
	/// this is the control that passed before the change and must still pass after it. It is
	/// also the reason the old implementation looked correct: the identity held while the
	/// attribution between the seasonal and residual terms was wrong.
	@Test("Control_AdditiveDecomposition_StillReconstructsTheSeries")
	func controlAdditiveDecompositionStillReconstructsTheSeries() throws {
		let series = quarterly(Self.seasonalTwelve)
		let decomposition = try decomposeTimeSeries(timeSeries: series, periodsPerYear: 4, method: .additive)

		let trend: [Double] = decomposition.trend.valuesArray
		let seasonal: [Double] = decomposition.seasonal.valuesArray
		let residual: [Double] = decomposition.residual.valuesArray

		for index in trend.indices where !trend[index].isNaN {
			let modelled: Double = trend[index] + seasonal[index]
			let rebuilt: Double = modelled + residual[index]
			let gap: Double = abs(rebuilt - Self.seasonalTwelve[index])
			#expect(gap <= 1e-9, "index \(index): rebuilt \(rebuilt) from \(Self.seasonalTwelve[index])")
		}
	}

	// MARK: - 2. A gap in the period index is not a shorter list

	private func months(_ numbers: [Int]) -> [Period] {
		numbers.map { Period.month(year: 2024, month: $0) }
	}

	/// Jan, Feb, Apr, May — March was never recorded, so it is absent from `periods` rather
	/// than present and empty. `periods[2 - 1]` is February, and `(Apr - Feb) / Feb` labelled
	/// April is two months of growth in a series of one-month rates.
	@Test("GrowthRate_AcrossAPeriodGap_OmitsThePeriodItCannotDate")
	func growthRateAcrossAPeriodGapOmitsThePeriodItCannotDate() throws {
		let gapped = TimeSeries<Double>(
			periods: months([1, 2, 4, 5]),
			values: [100.0, 110.0, 130.0, 143.0]
		)

		// The fixture must actually contain the gap it claims to. Assert it rather than assume.
		#expect(gapped.periods.count == 4, "four observations, one missing month between them")

		let growth = gapped.growthRate(lag: 1)
		#expect(growth.count == 2, "February and May have one-month predecessors; April does not")

		let april = Period.month(year: 2024, month: 4)
		#expect(growth[april] == nil, "April's one-month growth rate is not answerable")

		let february = Period.month(year: 2024, month: 2)
		let februaryRate: Double = try #require(growth[february])
		#expect(februaryRate.isEqual(to: 0.1), "100 to 110 is 10%")

		// Control: the same four values with no gap keep all three rates, so the test is
		// measuring the gap and not the arithmetic.
		let dense = TimeSeries<Double>(
			periods: months([1, 2, 3, 4]),
			values: [100.0, 110.0, 130.0, 143.0]
		)
		#expect(dense.growthRate(lag: 1).count == 3, "a contiguous series keeps count - lag entries")
	}

	/// The two absences are answered differently on purpose, and this is the test that would
	/// catch them being collapsed into one rule. A zero base is an observation whose rate is
	/// undefined, so the position is kept and marked; a gap is the absence of the observation,
	/// so the position goes.
	@Test("GrowthRate_AZeroBase_IsStillMarkedRatherThanOmitted")
	func growthRateAZeroBaseIsStillMarkedRatherThanOmitted() throws {
		let series = TimeSeries<Double>(
			periods: months([1, 2, 3]),
			values: [0.0, 110.0, 121.0]
		)
		let growth = series.growthRate(lag: 1)
		#expect(growth.count == 2, "a zero base keeps its position; only a gap removes one")

		let february = Period.month(year: 2024, month: 2)
		let februaryRate: Double = try #require(growth[february])
		#expect(februaryRate.isNaN, "growth from zero is undefined, not unbounded and not zero")
	}

	@Test("Diff_AcrossAPeriodGap_OmitsThePeriodItCannotDate")
	func diffAcrossAPeriodGapOmitsThePeriodItCannotDate() throws {
		let gapped = TimeSeries<Double>(
			periods: months([1, 2, 4, 5]),
			values: [100.0, 110.0, 130.0, 143.0]
		)
		let differences = gapped.diff(lag: 1)
		#expect(differences.count == 2, "a two-month change must not be labelled a one-month change")

		let february = Period.month(year: 2024, month: 2)
		let februaryChange: Double = try #require(differences[february])
		#expect(februaryChange.isEqual(to: 10.0), "110 less 100")

		let april = Period.month(year: 2024, month: 4)
		#expect(differences[april] == nil, "April has no one-month predecessor in this series")
	}

	/// `averageTimeSeries` is internal and feeds every turnover and return ratio as their
	/// **denominator**, so a six-month average labelled as a quarterly one divides one quarter
	/// of flow by half a year of balance.
	@Test("AverageTimeSeries_AcrossAPeriodGap_OmitsThePeriodItCannotAverage")
	func averageTimeSeriesAcrossAPeriodGapOmitsThePeriodItCannotAverage() throws {
		let q1 = Period.quarter(year: 2024, quarter: 1)
		let q2 = Period.quarter(year: 2024, quarter: 2)
		let q4 = Period.quarter(year: 2024, quarter: 4)

		let gapped = TimeSeries<Double>(periods: [q1, q2, q4], values: [100.0, 120.0, 200.0])
		let averaged = averageTimeSeries(gapped)

		#expect(averaged[q4] == nil, "Q4 has no prior quarter in this series to average against")

		let q1Average: Double = try #require(averaged[q1])
		#expect(q1Average.isEqual(to: 100.0), "the first period keeps its own value")
		let q2Average: Double = try #require(averaged[q2])
		#expect(q2Average.isEqual(to: 110.0), "(100 + 120) / 2")

		// Control: contiguous quarters average every period after the first, as before.
		let q3 = Period.quarter(year: 2024, quarter: 3)
		let dense = TimeSeries<Double>(periods: [q1, q2, q3], values: [100.0, 120.0, 140.0])
		let denseAveraged = averageTimeSeries(dense)
		let q3Average: Double = try #require(denseAveraged[q3])
		#expect(q3Average.isEqual(to: 130.0), "(120 + 140) / 2")
	}

	// MARK: - 3. A custom amortization schedule must match its term

	private var loanStart: Date { Date(timeIntervalSince1970: 0) }
	private var loanMaturity: Date { Date(timeIntervalSince1970: 157_680_000) }  // ~5 years

	private func customLoan(_ payments: [Double]) -> DebtInstrument {
		DebtInstrument(
			principal: 100_000.0,
			interestRate: 0.06,
			startDate: loanStart,
			maturityDate: loanMaturity,
			paymentFrequency: .annual,
			amortizationType: .custom(schedule: payments)
		)
	}

	/// RED before the change: this **trapped** with "Index out of range" rather than failing,
	/// so the caller was told nothing at all — the process stopped inside a public method,
	/// reached from public input.
	@Test("CustomSchedule_ShorterThanTheTerm_RefusesInsteadOfTrapping")
	func customScheduleShorterThanTheTermRefusesInsteadOfTrapping() throws {
		#expect(throws: BusinessMathError.self) {
			_ = try customLoan([10_000.0, 10_000.0, 10_000.0]).schedule()
		}
	}

	/// The other half of the same disagreement, and the one that was silent rather than fatal:
	/// the tail was discarded, so payments the caller specified never reached `payment`, and
	/// `totalPayments` was short by exactly those amounts with nothing saying so.
	@Test("CustomSchedule_LongerThanTheTerm_RefusesInsteadOfDroppingTheTail")
	func customScheduleLongerThanTheTermRefusesInsteadOfDroppingTheTail() throws {
		#expect(throws: BusinessMathError.self) {
			_ = try customLoan([10_000.0, 10_000.0, 10_000.0, 10_000.0, 10_000.0, 10_000.0, 10_000.0]).schedule()
		}
	}

	/// Control: a schedule of exactly the right length is unaffected, and so are the three
	/// amortization types that cannot carry one.
	@Test("Control_CustomSchedule_MatchingTheTerm_StillBuilds")
	func controlCustomScheduleMatchingTheTermStillBuilds() throws {
		let payments: [Double] = [10_000.0, 15_000.0, 20_000.0, 25_000.0, 30_000.0]
		let schedule = try customLoan(payments).schedule()
		#expect(schedule.periods.count == 5, "five annual periods between start and maturity")

		let firstPeriod = try #require(schedule.periods.first)
		let firstPayment: Double = try #require(schedule.payment[firstPeriod])
		#expect(firstPayment.isEqual(to: 10_000.0), "the caller's own first payment, unaltered")

		let level = DebtInstrument(
			principal: 100_000.0,
			interestRate: 0.06,
			startDate: loanStart,
			maturityDate: loanMaturity,
			paymentFrequency: .annual,
			amortizationType: .levelPayment
		)
		let levelSchedule = try level.schedule()
		#expect(levelSchedule.periods.count == 5, "the non-custom types cannot throw and are unchanged")
	}

	// MARK: - 4. A covenant has three outcomes, not two

	private func covenant() -> FinancialCovenant {
		FinancialCovenant(
			name: "Max Leverage",
			requirement: .maximumRatio(metric: .debtToEBITDA, threshold: 3.0)
		)
	}

	/// The conflation this closes: after the Phase 2 fix a `.nan` metric made `isCompliant`
	/// `false`, which is the right *default* but reads as "we tested this and you failed" when
	/// the truth is "we could not test this". One starts a cure period; the other starts a
	/// request for the missing statements.
	@Test("CovenantStatus_SeparatesAMeasuredBreachFromAnUntestableCovenant")
	func covenantStatusSeparatesMeasuredBreachFromUntestableCovenant() throws {
		let passed = CovenantComplianceResult(
			covenant: covenant(), isCompliant: true, actualValue: 2.0, requiredValue: 3.0
		)
		let breached = CovenantComplianceResult(
			covenant: covenant(), isCompliant: false, actualValue: 4.5, requiredValue: 3.0
		)
		let untested = CovenantComplianceResult(
			covenant: covenant(), isCompliant: false, actualValue: .nan, requiredValue: 3.0
		)

		#expect(passed.status == .compliant)
		#expect(breached.status == .breach)
		#expect(untested.status == .notAnswerable, "a nan metric is silence, not non-compliance")

		// `isCompliant` stays conservative for both failures, so no existing caller is newly
		// certified from data that is not there.
		#expect(untested.isCompliant == false, "nothing is certified from an absent period")

		let results: [CovenantComplianceResult] = [passed, breached, untested]
		#expect(results.allCompliant == false)
		#expect(results.breaches.count == 1, "one measured breach")
		#expect(results.untestable.count == 1, "one covenant nobody could test")
		// Both still appear on the exception report: an untestable covenant is something to
		// chase, not something to filter away.
		#expect(results.violations.count == 2, "violations remains the union of the two")
		#expect(results.compliant.count == 1)
	}

	/// The report must not call an untestable covenant a violation, because the reader's next
	/// action differs.
	@Test("CovenantReport_DistinguishesNotTestedFromViolated")
	func covenantReportDistinguishesNotTestedFromViolated() throws {
		let untested = CovenantComplianceResult(
			covenant: covenant(), isCompliant: false, actualValue: .nan, requiredValue: 3.0
		)
		let report: String = [untested].generateReport()
		#expect(report.contains("NOT TESTED"), "report was:\n\(report)")
		#expect(report.contains("VIOLATIONS DETECTED") == false, "no default has been established")
	}

	// MARK: - 5. Interpolation — a contaminated query and a contaminated knot

	/// RED before the fix, and the worst shape in the directory: `nan >= xs[0]` is false, so the
	/// in-range test failed, the clamp arm fired, `nan < xs[0]` was also false, and the **else**
	/// branch returned `ys.last`. Measured: a query of `.nan` on knots 0…4 with `ys` 0, 1, 4, 9,
	/// 16 returned **16.0** — the most recent observation, and the one a caller is likeliest to
	/// trust. `extrapolatedValue` is called first by every interpolator in the directory.
	@Test("Interpolation_AContaminatedQuery_AnswersNaNRatherThanTheLastObservation")
	func interpolationContaminatedQueryAnswersNaNRatherThanTheLastObservation() throws {
		let xs: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0]
		let ys: [Double] = [0.0, 1.0, 4.0, 9.0, 16.0]
		let interpolator = try LinearInterpolator(xs: xs, ys: ys)

		let contaminated: Double = interpolator(Double.nan)
		#expect(contaminated.isNaN, "a nan query returned \(contaminated); 16.0 is the old answer")

		// Controls that must pass on both sides of the fix, because they look identical to the
		// defect under a grep: the clamp is legitimate for a *finite* out-of-range query, and an
		// in-range query is untouched.
		let aboveRange: Double = interpolator(9.0)
		#expect(aboveRange.isEqual(to: 16.0), "a finite query past the last knot still clamps")
		let belowRange: Double = interpolator(-3.0)
		#expect(belowRange.isEqual(to: 0.0), "and still clamps at the other end")
		let inRange: Double = interpolator(1.5)
		#expect(inRange.isEqual(to: 2.5), "midpoint of 1 and 4")
	}

	/// RED before the fix: a `nan` abscissa passed validation, because `xs[i] < xs[i-1]` and
	/// `xs[i] == xs[i-1]` are both false at the bad knot and at the one after it. With the `nan`
	/// at either end the interpolator silently became the constant function `f(x) = ys.last` —
	/// measured 16.0 at queries of 0.5, 2.5 and 3.5 — while `xs.count` still reported five knots.
	@Test("Interpolation_AContaminatedKnot_IsRefusedAtConstruction")
	func interpolationContaminatedKnotIsRefusedAtConstruction() throws {
		let ys: [Double] = [0.0, 1.0, 4.0, 9.0, 16.0]

		#expect(throws: BusinessMathError.self) {
			_ = try LinearInterpolator(xs: [Double.nan, 1.0, 2.0, 3.0, 4.0], ys: ys)
		}
		#expect(throws: BusinessMathError.self) {
			_ = try LinearInterpolator(xs: [0.0, 1.0, Double.nan, 3.0, 4.0], ys: ys)
		}
		#expect(throws: BusinessMathError.self) {
			_ = try LinearInterpolator(xs: [0.0, 1.0, 2.0, 3.0, Double.infinity], ys: ys)
		}

		// Controls: the ordering diagnoses the caller already relied on must still be the ones
		// they get, rather than being swallowed by the new guard.
		#expect(throws: InterpolationError.self) {
			_ = try LinearInterpolator(xs: [0.0, 2.0, 1.0, 3.0, 4.0], ys: ys)
		}
		#expect(throws: InterpolationError.self) {
			_ = try LinearInterpolator(xs: [0.0, 1.0, 1.0, 3.0, 4.0], ys: ys)
		}
	}

	// MARK: - 6. The equity ratio's missing sibling guard

	/// `debtRatio` screened a non-finite total and `equityRatio`, four lines away, did not, so
	/// the same object answered "unknown" and "certainly zero" in the same breath. `nan > 0` is
	/// false, so the fall-through reported **zero equity — financed entirely by debt**, which is
	/// the most alarming reading on any solvency screen, as a measurement.
	@Test("EquityRatio_WithAnUnvaluableCapitalStructure_AnswersNaNLikeItsSibling")
	func equityRatioWithUnvaluableCapitalStructureAnswersNaNLikeItsSibling() throws {
		let unvaluable = CapitalStructure(
			debtValue: Double.nan,
			equityValue: 400_000.0,
			costOfDebt: 0.06,
			costOfEquity: 0.12,
			taxRate: 0.21
		)
		#expect(unvaluable.equityRatio.isNaN, "an unvaluable capital structure has no equity share to report")
		#expect(unvaluable.debtRatio.isNaN, "its sibling already said so")

		// Control, unchanged and deliberately NOT tidied into agreement with the above: a firm
		// with genuinely no capital at all is a measurement, and both ratios really are zero.
		let empty = CapitalStructure(
			debtValue: 0.0,
			equityValue: 0.0,
			costOfDebt: 0.06,
			costOfEquity: 0.12,
			taxRate: 0.21
		)
		#expect(empty.equityRatio.isEqual(to: 0.0), "no capital of either kind is a real zero")
		#expect(empty.debtRatio.isEqual(to: 0.0))

		// And an ordinary structure is untouched.
		let ordinary = CapitalStructure(
			debtValue: 600_000.0,
			equityValue: 400_000.0,
			costOfDebt: 0.06,
			costOfEquity: 0.12,
			taxRate: 0.21
		)
		#expect(ordinary.equityRatio.isEqual(to: 0.4), "400k of 1.0m")
	}

	// MARK: - 7. The `DateComponents ?? 0` class is empty, and this is why

	/// `Period.swift` (61), `PeriodArithmetic.swift` (9) and `FiscalCalendar.swift` (4) carry 74
	/// `components.year ?? 0` / `.month ?? 0` / `.hour ?? 0` unwraps. The class was scoped three
	/// times in this campaign and never resolved, on the assumption that a missing calendar
	/// component silently becomes year 0.
	///
	/// It cannot. `Calendar.dateComponents` populates **every requested component** and answers
	/// `nil` only for one that was not requested — and every one of those 74 sites unwraps a
	/// component its own request set contains, checked by variable name. The fallbacks are
	/// structurally dead.
	///
	/// This test pins the Foundation invariant the argument rests on, because a comment
	/// asserting an invariant is a claim and not evidence. The `nil` control at the end is what
	/// makes it discriminating: without it, a probe that could never observe a `nil` would look
	/// exactly like one proving `nil` never happens.
	@Test("DateComponents_PopulatesEveryRequestedField_EvenForAPathologicalDate")
	func dateComponentsPopulatesEveryRequestedFieldEvenForAPathologicalDate() throws {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
		let requested: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second, .nanosecond]

		let pathological: [(String, Date)] = [
			("epoch", Date(timeIntervalSince1970: 0)),
			("distantPast", Date.distantPast),
			("distantFuture", Date.distantFuture),
			("nan", Date(timeIntervalSince1970: Double.nan)),
			("+infinity", Date(timeIntervalSince1970: Double.infinity)),
			("-infinity", Date(timeIntervalSince1970: -Double.infinity)),
			("greatestFinite", Date(timeIntervalSince1970: Double.greatestFiniteMagnitude))
		]

		for (name, date) in pathological {
			let parts = calendar.dateComponents(requested, from: date)
			let optionals: [Int?] = [parts.year, parts.month, parts.day, parts.hour,
									 parts.minute, parts.second, parts.nanosecond]
			let allPresent: Bool = optionals.allSatisfy { $0 != nil }
			#expect(allPresent, "\(name): a requested component came back nil")

			// The difference form too — `PeriodArithmetic`'s nine sites use it, and a
			// fabricated elapsed duration of zero is a different wrong answer from a year-0
			// date, with a zero denominator waiting in any per-unit-time rate.
			let span = calendar.dateComponents(requested, from: Date(timeIntervalSince1970: 0), to: date)
			let spanOptionals: [Int?] = [span.year, span.month, span.day, span.hour,
										 span.minute, span.second, span.nanosecond]
			let allSpansPresent: Bool = spanOptionals.allSatisfy { $0 != nil }
			#expect(allSpansPresent, "\(name): a requested difference component came back nil")
		}

		// The control. `nil` is reachable — it means "you did not ask for this".
		let partial = calendar.dateComponents([.year], from: Date(timeIntervalSince1970: 0))
		#expect(partial.month == nil, "an unrequested component is the only source of nil")
		#expect(partial.year == 1970, "and the requested one is still there")
	}

	/// The finding the same probe produced that **is** live, recorded so it is not mistaken for
	/// part of the class above. A non-finite `TimeInterval` does not fail to build a `Date`, it
	/// clamps — so the wrong answer is manufactured at construction, where no `??` can see it,
	/// and the year that comes out is a real number two and a half millennia adrift.
	@Test("ANonFiniteTimeInterval_ClampsToAJulianDate_RatherThanFailing")
	func aNonFiniteTimeIntervalClampsToAJulianDateRatherThanFailing() throws {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = try #require(TimeZone(identifier: "UTC"))

		let fromNaN = calendar.dateComponents([.year], from: Date(timeIntervalSince1970: Double.nan))
		let nanYear: Int = try #require(fromNaN.year)
		#expect(nanYear == 4713, "a nan interval clamps to the Julian epoch, not to nil and not to 0")

		let fromInfinity = calendar.dateComponents([.year], from: Date(timeIntervalSince1970: Double.infinity))
		let infinityYear: Int = try #require(fromInfinity.year)
		#expect(infinityYear > 9999, "an infinite interval clamps to a far-future year, got \(infinityYear)")
	}
}

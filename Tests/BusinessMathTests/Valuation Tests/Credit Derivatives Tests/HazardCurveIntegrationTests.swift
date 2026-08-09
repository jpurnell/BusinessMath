//
//  HazardCurveIntegrationTests.swift
//  BusinessMath
//
//  Integration of a hazard curve against the calendar its periods actually span,
//  and the day count convention that decides what a year is.
//

import Testing
import TestSupport  // Cross-platform math functions
import Foundation
@testable import BusinessMath

@Suite("Hazard Curve Integration Tests")
struct HazardCurveIntegrationTests {

    // MARK: - Fixtures

    /// Twelve monthly periods covering 2025 — 365 actual days, no leap day.
    static let monthsOf2025: [Period] = (1...12).map { Period.month(year: 2025, month: $0) }

    /// Actual days in each month of 2025, written out rather than computed, so the
    /// expected values below are independent of the code under test.
    static let daysPerMonth2025: [Double] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    /// Actual days in each quarter of 2025: 31+28+31, 30+31+30, 31+31+30, 31+30+31.
    static let daysPerQuarter2025: [Double] = [90, 91, 92, 92]

    /// Bit-for-bit equality between two `Double` values.
    ///
    /// Several assertions below are claims of *exactness*, not of closeness: that
    /// ACT/365 makes a common calendar year worth precisely 1.0, that January is
    /// precisely the ratio 31/365, that an annual curve produces the identical bits
    /// the hardcoded one-year step produced. A tolerance would let every one of them
    /// pass while being quietly wrong by a fraction of a percent — which is the exact
    /// failure mode this change exists to remove. Comparing bit patterns states the
    /// claim being made and keeps it off floating-point `==`.
    static func identical(_ lhs: Double, _ rhs: Double) -> Bool {
        return lhs.bitPattern == rhs.bitPattern
    }

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = Calendar.current.date(from: components) else {
            fatalError("Unable to build \(year)-\(month)-\(day)")
        }
        return date
    }

    /// The trapezoidal integral the model should produce, written out independently:
    /// first period a rectangle at its own rate, each later period a trapezoid.
    static func expectedIntegral(rates: [Double], widths: [Double]) -> Double {
        var total = 0.0
        for i in rates.indices {
            let averageRate = i == 0 ? rates[0] : (rates[i - 1] + rates[i]) / 2.0
            total += averageRate * widths[i]
        }
        return total
    }

    // MARK: - The defect: a curve integrated as though every point spanned a year

    @Test("A monthly curve spans one year, not twelve")
    func monthlyCurveSpansOneYear() {
        // A distressed name whose monthly hazard ramps from 2% to 24% across 2025.
        let rates = (1...12).map { 0.02 * Double($0) }
        let curve = TimeSeries(periods: Self.monthsOf2025, values: rates)
        let model = TimeVaryingHazardRate(hazardRates: curve)

        let widths = Self.daysPerMonth2025.map { $0 / 365.0 }
        let expected = Self.expectedIntegral(rates: rates, widths: widths)  // 0.12136986...

        // Stepping a year per point consumed only January before reaching the one-year
        // horizon, and reported the January rate as the whole year's hazard.
        let oneYearPerPoint = 0.02

        let survival = model.survivalProbability(time: 1.0)
        let cumulativeHazard = -log(survival)

        #expect(abs(cumulativeHazard - expected) < 1e-12,
                "H(1) = \(cumulativeHazard), expected \(expected); one-year-per-point gives \(oneYearPerPoint)")

        // The scale of what was wrong: a 2.0% one-year default probability against 11.4%.
        #expect(abs(model.defaultProbability(time: 1.0) - (1.0 - exp(-expected))) < 1e-12)
        #expect(model.defaultProbability(time: 1.0) > 0.11)
    }

    @Test("The whole monthly curve's cumulative hazard is not twelve years' worth")
    func monthlyCurveTotalHazard() {
        let rates = (1...12).map { 0.02 * Double($0) }
        let curve = TimeSeries(periods: Self.monthsOf2025, values: rates)
        let model = TimeVaryingHazardRate(hazardRates: curve)

        let widths = Self.daysPerMonth2025.map { $0 / 365.0 }
        let overTheCurve = Self.expectedIntegral(rates: rates, widths: widths)

        // Stepping a year per point spread the same twelve rates over twelve years:
        // 0.02×1 + 0.03×1 + … + 0.23×1 = 1.45, against a true 0.1214.
        let oneYearPerPoint = Self.expectedIntegral(rates: rates, widths: Array(repeating: 1.0, count: 12))
        #expect(abs(oneYearPerPoint - 1.45) < 1e-12)
        #expect(oneYearPerPoint / overTheCurve > 11.0)
        #expect(oneYearPerPoint / overTheCurve < 12.0)

        // The curve is exhausted at one year, so a longer horizon extrapolates flat at
        // the last rate rather than continuing to walk the curve.
        let atFiveYears = -log(model.survivalProbability(time: 5.0))
        #expect(abs(atFiveYears - (overTheCurve + 0.24 * 4.0)) < 1e-12)
    }

    @Test("A flat monthly curve is the constant-hazard model")
    func monthlyFlatCurveMatchesConstantHazard() {
        let rate = 0.05
        let curve = TimeSeries(
            periods: Self.monthsOf2025,
            values: Array(repeating: rate, count: 12)
        )
        let timeVarying = TimeVaryingHazardRate(hazardRates: curve)
        let constant = ConstantHazardRate(hazardRate: rate)

        for t in [0.25, 0.5, 1.0] {
            #expect(abs(timeVarying.survivalProbability(time: t) - constant.survivalProbability(time: t)) < 1e-12,
                    "monthly curve and constant hazard disagree at t = \(t)")
        }
    }

    // MARK: - The case the old code got right by accident

    @Test("An annual curve of common years is bit-for-bit what it was")
    func annualCurveUnchanged() {
        // 2025, 2026 and 2027 are 365 actual days each, so ACT/365 gives T(365)/T(365)
        // — exactly 1.0, the same value the hardcoded step used, fed into the same
        // multiplications in the same order. Equality, not a tolerance.
        let curve = TimeSeries(
            periods: [Period.year(2025), Period.year(2026), Period.year(2027)],
            values: [0.01, 0.02, 0.03]
        )
        let model = TimeVaryingHazardRate(hazardRates: curve)

        let integral = 0.01 * 1.0 + 0.015 * 1.0 + 0.025 * 1.0
        #expect(Self.identical(model.survivalProbability(time: 3.0), exp(-integral)))

        // And at a horizon inside the curve, where the last step is a partial year.
        let partial = 0.01 * 1.0 + 0.015 * 1.0 + 0.025 * 0.5
        #expect(Self.identical(model.survivalProbability(time: 2.5), exp(-partial)))

        // Beyond the curve, extrapolating flat at the last rate.
        let extrapolated = integral + 0.03 * 2.0
        #expect(Self.identical(model.survivalProbability(time: 5.0), exp(-extrapolated)))

        // A width of exactly one year is what makes that true.
        let width: Double = DayCountConvention.actual365.yearFraction(of: Period.year(2025))
        #expect(Self.identical(width, 1.0))
    }

    @Test("A leap year is 366/365 of a year, which the old code also got wrong")
    func leapYearIsLongerUnderActual365() {
        let leap: Double = DayCountConvention.actual365.yearFraction(of: Period.year(2024))
        #expect(Self.identical(leap, 366.0 / 365.0))
        #expect(leap > 1.0)

        // 30/360 is the convention under which a leap year is still exactly one year.
        let bondBasis: Double = DayCountConvention.thirty360.yearFraction(of: Period.year(2024))
        #expect(Self.identical(bondBasis, 1.0))
    }

    // MARK: - Mixed frequency

    @Test("A curve that is quarterly at the short end and annual further out")
    func mixedQuarterlyThenAnnual() {
        let periods = (1...4).map { Period.quarter(year: 2025, quarter: $0) }
            + [Period.year(2026), Period.year(2027)]
        let rates = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06]
        let curve = TimeSeries(periods: periods, values: rates)
        let model = TimeVaryingHazardRate(hazardRates: curve)

        // Periods sort type-first, so the four quarters precede the two years — which
        // here is also chronological order.
        #expect(curve.periods.map(\.type) == [.quarterly, .quarterly, .quarterly, .quarterly, .annual, .annual])

        let widths = Self.daysPerQuarter2025.map { $0 / 365.0 } + [1.0, 1.0]
        #expect(abs(widths.reduce(0, +) - 3.0) < 1e-12)

        // Through 2026: all four quarters plus the whole of the annual point.
        let throughTwoYears = Self.expectedIntegral(
            rates: Array(rates.prefix(5)),
            widths: Array(widths.prefix(5))
        )
        #expect(abs(-log(model.survivalProbability(time: 2.0)) - throughTwoYears) < 1e-12)

        // The whole curve.
        let throughThreeYears = Self.expectedIntegral(rates: rates, widths: widths)
        #expect(abs(-log(model.survivalProbability(time: 3.0)) - throughThreeYears) < 1e-12)

        // A flat curve of the same shape must reproduce the constant-hazard model
        // exactly, whatever the mix of frequencies.
        let flat = TimeSeries(periods: periods, values: Array(repeating: 0.07, count: 6))
        let flatModel = TimeVaryingHazardRate(hazardRates: flat)
        let constant = ConstantHazardRate(hazardRate: 0.07)
        for t in [0.5, 1.0, 2.0, 3.0] {
            #expect(abs(flatModel.survivalProbability(time: t) - constant.survivalProbability(time: t)) < 1e-12)
        }
    }

    @Test("A coarse point before a fine one is not put in chronological order")
    func coarsePointBeforeFineOneIsMisordered() {
        // `Period` is Comparable by granularity first and start date second, so a
        // TimeSeries sorts every quarterly point ahead of every annual one whatever
        // their dates. That is fine for the usual short-end-fine, long-end-coarse
        // curve above, and wrong for the reverse. The integration walks the periods in
        // the order the series holds them and assumes each begins where the last
        // ended, so it cannot detect this — the caveat is pinned here rather than
        // silently relied on.
        let periods = [Period.year(2025), Period.quarter(year: 2026, quarter: 1)]
        let curve = TimeSeries(periods: periods, values: [0.01, 0.02])

        #expect(curve.periods.first?.type == .quarterly)
        #expect(curve.periods.first?.startDate == Self.date(2026, 1, 1))
        #expect(curve.periods.last?.type == .annual)
        #expect(curve.periods.last?.startDate == Self.date(2025, 1, 1))
    }

    // MARK: - A transition stub

    @Test("A curve containing a custom stub period")
    func curveWithCustomStub() {
        // A company moving from quarterly to semiannual reporting mid-2025 emits one
        // odd-length period at the boundary: 1 July to 1 January is 184 actual days.
        let stub = Period.custom(start: Self.date(2025, 7, 1), end: Self.date(2026, 1, 1))
        #expect(stub.type == .custom)

        let stubWidth: Double = DayCountConvention.actual365.yearFraction(of: stub)
        #expect(abs(stubWidth - 184.0 / 365.0) < 1e-12)
        // Not a year, which is what the old integration assumed of every point...
        #expect(stubWidth < 1.0)
        // ...and not the granularity ladder's answer either, which has none for a
        // custom range: Period.durationInDays consults the interval directly.
        #expect(abs(DayCountConvention.actual365.days(in: stub) - 184.0) < 1e-9)

        let periods = [
            Period.quarter(year: 2025, quarter: 1),
            Period.quarter(year: 2025, quarter: 2),
            stub
        ]
        let rates = [0.02, 0.03, 0.06]
        let model = TimeVaryingHazardRate(hazardRates: TimeSeries(periods: periods, values: rates))

        // Custom periods sort last, which here is also chronological.
        #expect(model.hazardRates.periods.last == stub)

        let widths = [90.0 / 365.0, 91.0 / 365.0, 184.0 / 365.0]
        #expect(abs(widths.reduce(0, +) - 1.0) < 1e-12)

        let expected = Self.expectedIntegral(rates: rates, widths: widths)
        #expect(abs(-log(model.survivalProbability(time: 1.0)) - expected) < 1e-12)

        // 30/360 counts the same stub as 180 days: 30 × 6 months, ignoring July's and
        // August's 31sts.
        #expect(Self.identical(DayCountConvention.thirty360.days(in: stub), 180.0))
    }

    // MARK: - Conventions

    @Test("Each convention divides by the days it calls a year")
    func conventionDivisors() {
        #expect(DayCountConvention.actual365.daysInYear == 365)
        #expect(DayCountConvention.actual360.daysInYear == 360)
        #expect(DayCountConvention.thirty360.daysInYear == 360)

        // January 2025 — 31 actual days, 30 under the bond basis. All three differ.
        let january = Period.month(year: 2025, month: 1)
        let act365: Double = DayCountConvention.actual365.yearFraction(of: january)
        let act360: Double = DayCountConvention.actual360.yearFraction(of: january)
        let bond: Double = DayCountConvention.thirty360.yearFraction(of: january)

        #expect(Self.identical(act365, 31.0 / 365.0))
        #expect(Self.identical(act360, 31.0 / 360.0))
        #expect(Self.identical(bond, 30.0 / 360.0))
        #expect(act360 > act365)
        #expect(act365 > bond)

        // February — where the actual conventions are short and the bond basis is not.
        let february = Period.month(year: 2025, month: 2)
        #expect(Self.identical(DayCountConvention.actual365.days(in: february), 28.0))
        #expect(Self.identical(DayCountConvention.thirty360.days(in: february), 30.0))
        let bondFebruary: Double = DayCountConvention.thirty360.yearFraction(of: february)
        #expect(Self.identical(bondFebruary, 1.0 / 12.0))

        // A quarter: 90 actual days in Q1 2025, 90 under 30/360 in every quarter.
        let firstQuarter = Period.quarter(year: 2025, quarter: 1)
        #expect(Self.identical(DayCountConvention.actual365.days(in: firstQuarter), 90.0))
        #expect(Self.identical(DayCountConvention.thirty360.days(in: firstQuarter), 90.0))
        let bondQuarter: Double = DayCountConvention.thirty360.yearFraction(of: firstQuarter)
        #expect(Self.identical(bondQuarter, 0.25))

        // Every calendar year is exactly one year under 30/360, leap or not.
        for year in 2023...2028 {
            let fraction: Double = DayCountConvention.thirty360.yearFraction(of: Period.year(year))
            #expect(Self.identical(fraction, 1.0), "30/360 made \(year) worth \(fraction) years")
        }

        // A day count convention survives a daylight-saving transition: March 2025 is
        // 31 days, not the 30.958 that dividing elapsed seconds by 86,400 would give.
        #expect(Self.identical(DayCountConvention.actual365.days(in: Period.month(year: 2025, month: 3)), 31.0))
        #expect(Self.identical(DayCountConvention.actual365.days(in: Period.month(year: 2025, month: 11)), 30.0))
    }

    @Test("ACT/365 against ACT/360 is a real difference, not rounding")
    func actual365VersusActual360IsMaterial() {
        // As an accrual: the same calendar year is 1.389% longer on ACT/360.
        let onActual365: Double = DayCountConvention.actual365.yearFraction(of: Period.year(2025))
        let onActual360: Double = DayCountConvention.actual360.yearFraction(of: Period.year(2025))
        let stretch = onActual360 / onActual365 - 1.0
        #expect(abs(stretch - (365.0 / 360.0 - 1.0)) < 1e-15)
        #expect(stretch > 0.013)

        // And in a survival probability. A steep curve, integrated to three years.
        let periods = (2025...2029).map { Period.year($0) }
        let rates = [0.01, 0.05, 0.10, 0.20, 0.40]
        let curve = TimeSeries(periods: periods, values: rates)

        let act365 = TimeVaryingHazardRate(hazardRates: curve, dayCount: .actual365)
        let act360 = TimeVaryingHazardRate(hazardRates: curve, dayCount: .actual360)
        let bond = TimeVaryingHazardRate(hazardRates: curve, dayCount: .thirty360)

        let hazard365 = -log(act365.survivalProbability(time: 3.0))
        let hazard360 = -log(act360.survivalProbability(time: 3.0))

        // Stretching the calendar defers the curve's rise, so less of it is reached by
        // year three: 0.11347 against 0.11500.
        #expect(hazard360 < hazard365)
        let relative = (hazard365 - hazard360) / hazard365
        #expect(relative > 0.01, "ACT/365 vs ACT/360 differed by only \(relative * 100)%")

        // Expressed the way a desk would see it: the one-in-nine chance of default over
        // three years moves by more than ten basis points.
        let defaultProbabilityGap = act365.defaultProbability(time: 3.0) - act360.defaultProbability(time: 3.0)
        #expect(defaultProbabilityGap > 0.0010,
                "only \(defaultProbabilityGap * 10_000) bp between ACT/365 and ACT/360")

        // 30/360 makes every one of these years exactly 1.0, so on an annual curve of
        // common years it agrees with ACT/365 exactly — and the agreement is a fact
        // about annual periods, not about the two conventions.
        #expect(Self.identical(bond.survivalProbability(time: 3.0), act365.survivalProbability(time: 3.0)))
        let monthly = TimeSeries(periods: Self.monthsOf2025, values: (1...12).map { 0.02 * Double($0) })
        #expect(!Self.identical(
            TimeVaryingHazardRate(hazardRates: monthly, dayCount: .thirty360).survivalProbability(time: 0.5),
            TimeVaryingHazardRate(hazardRates: monthly, dayCount: .actual365).survivalProbability(time: 0.5)
        ))
    }

    @Test("The default is ACT/365")
    func defaultConventionIsActual365() {
        let curve = TimeSeries(periods: Self.monthsOf2025, values: (1...12).map { 0.02 * Double($0) })
        let implicit = TimeVaryingHazardRate(hazardRates: curve)
        let explicitDefault = TimeVaryingHazardRate(hazardRates: curve, dayCount: .actual365)

        #expect(implicit.dayCount == .actual365)
        #expect(Self.identical(implicit.survivalProbability(time: 1.0), explicitDefault.survivalProbability(time: 1.0)))
    }

    // MARK: - Degenerate curves

    @Test("An empty curve integrates to nothing")
    func emptyCurve() {
        let model = TimeVaryingHazardRate(hazardRates: TimeSeries<Double>(periods: [], values: []))
        #expect(Self.identical(model.survivalProbability(time: 5.0), 1.0))
        #expect(Self.identical(model.defaultProbability(time: 5.0), 0.0))
    }

    @Test("A zero-length stub contributes nothing and does not stall the walk")
    func zeroLengthStub() {
        let instant = Self.date(2025, 7, 1)
        let empty = Period.custom(start: instant, end: instant)
        #expect(Self.identical(DayCountConvention.actual365.days(in: empty), 0.0))

        let periods = [Period.quarter(year: 2025, quarter: 1), empty]
        let model = TimeVaryingHazardRate(hazardRates: TimeSeries(periods: periods, values: [0.02, 0.05]))

        // Q1 alone, then flat extrapolation at the last rate for the remaining time.
        let quarter = 90.0 / 365.0
        let expected = 0.02 * quarter + 0.05 * (1.0 - quarter)
        #expect(abs(-log(model.survivalProbability(time: 1.0)) - expected) < 1e-12)
    }

    // MARK: - hazardRateFromSpread

    @Test("A hazard rate cannot be extracted when there is no loss to compensate")
    func hazardFromSpreadRefusesFullRecovery() {
        // 1 - R is zero: the old code returned +infinity, which then produced a
        // survival probability of exactly zero at every horizon.
        #expect(hazardRateFromSpread(spread: 0.0150, recoveryRate: 1.0) == nil)
    }

    @Test("A hazard rate is never negative")
    func hazardFromSpreadRefusesNegativeIntensity() {
        // 1 - R is negative: the old code returned -0.075, and exp(-λt) with λ < 0 is a
        // survival probability above one.
        #expect(hazardRateFromSpread(spread: 0.0150, recoveryRate: 1.20) == nil)
        #expect(hazardRateFromSpread(spread: 0.0150, recoveryRate: 2.0) == nil)

        // A recovery below zero is not a recovery rate.
        #expect(hazardRateFromSpread(spread: 0.0150, recoveryRate: -0.10) == nil)

        // Nor is a negative quote a credit spread.
        #expect(hazardRateFromSpread(spread: -0.0150, recoveryRate: 0.40) == nil)
    }

    @Test("Non-finite inputs are refused rather than propagated")
    func hazardFromSpreadRefusesNonFinite() {
        #expect(hazardRateFromSpread(spread: Double.nan, recoveryRate: 0.40) == nil)
        #expect(hazardRateFromSpread(spread: Double.infinity, recoveryRate: 0.40) == nil)
        #expect(hazardRateFromSpread(spread: 0.0150, recoveryRate: Double.nan) == nil)
        #expect(hazardRateFromSpread(spread: 0.0150, recoveryRate: Double.infinity) == nil)
    }

    @Test("Well-formed inputs are unchanged")
    func hazardFromSpreadStillWorks() throws {
        #expect(Self.identical(try #require(hazardRateFromSpread(spread: 0.0150, recoveryRate: 0.40)), 0.0150 / 0.60))
        // The documented default recovery of 40%.
        #expect(Self.identical(try #require(hazardRateFromSpread(spread: 0.0150)), 0.0150 / (1.0 - 0.40)))
        // Zero recovery is a legitimate assumption, not a degenerate one.
        #expect(Self.identical(try #require(hazardRateFromSpread(spread: 0.0150, recoveryRate: 0.0)), 0.0150))
        // A zero spread implies a zero intensity, which is a real answer.
        #expect(Self.identical(try #require(hazardRateFromSpread(spread: 0.0, recoveryRate: 0.40)), 0.0))
    }
}

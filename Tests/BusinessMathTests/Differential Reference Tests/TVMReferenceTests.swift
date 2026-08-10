//
//  TVMReferenceTests.swift
//  BusinessMath
//
//  Differential tests for the time-value-of-money core against published worked
//  examples. TrustPlan §2.2.
//

import Foundation
import Testing
import Numerics
import TestSupport  // identical, exactlyEqual, approximatelyEqual

@testable import BusinessMath

/// `npv`, `npvExcel`, `irr`, `xnpv`, `xirr`, `payment` and the amortisation
/// helpers against published worked examples.
///
/// ## Where the reference values come from
///
/// - **Microsoft Excel function documentation**, which publishes both the inputs
///   and the expected outputs for `NPV`, `PMT`, `XNPV` and `XIRR`. These are the
///   right references for this library because three of the functions here name
///   Excel compatibility in their own doc comments, so Excel's published answer is
///   the specification, not a second opinion.
///   - `NPV(10%, 3000, 4200, 6800) - 10000 = 1188.44`
///   - `PMT(8%/12, 10, 10000) = -1037.03`
///   - `XNPV(9%, …) = 2086.6476`, `XIRR(…) = 0.373362535`
/// - **The standard finance-textbook IRR example** — cash flows
///   `[-1000, 500, 400, 300, 100]`, IRR ≈ 14.49%, which appears in Brealey &
///   Myers and in most corporate-finance courses.
/// - **The 30-year mortgage**, `$200,000` at 6% nominal, monthly: `$1,199.10`.
///   Printed by every amortisation calculator and by Excel's own PMT help.
/// - **Extended digits** for each of the above come from an independent
///   arbitrary-precision evaluation of the same closed form (mpmath 1.4.1 at 40
///   decimal digits), whose leading digits match the published figure.
/// - **Identities** — `npv(irr) == 0`, `Σ principal == PV - FV`,
///   `payment × n - PV == Σ interest`, `payment(r = 0) == (PV - FV)/n` — need no
///   source and cannot be tuned.
///
/// ## Where the tolerances come from
///
/// | tolerance | used for | justification |
/// |---|---|---|
/// | `1e-10` rel | `npv`, `npvExcel`, `xnpv`, `payment` | each is a short sum of `pow` calls; the error is a few ulp times the number of terms. Measured worst case: **1.2e-15 relative** (`npvExcel`, 4 terms). 1e-10 is five orders looser than measured, deliberately: these are the assertions that must not fail on a platform whose `pow` rounds differently. |
/// | `1e-2` abs | published two-decimal figures | `1188.44`, `1037.03`, `1199.10` and `4.76` are printed to the cent. Asserting more precision than the reference has would be asserting against nothing. |
/// | `2.5e-10` abs | `irr` at its default tolerance | measured; see `irrDefaultToleranceIsAbsoluteInCurrency` for why it is not smaller. |
/// | `1e-14` abs | `irr` / `xirr` with an explicit tight tolerance | measured worst case **5.6e-17** once the stopping rule is tightened. |
@Suite("Time value of money vs published worked examples")
struct TVMReferenceTests {

	/// The textbook IRR example: an initial outlay and four declining inflows.
	static let textbookCashFlows: [Double] = [-1000, 500, 400, 300, 100]

	/// Its IRR, to 20 significant digits, from the arbitrary-precision root of the
	/// same polynomial. Published as 14.49%.
	static let textbookIRR = 0.14488844278585600

	/// The dates from Microsoft's published `XIRR`/`XNPV` example.
	///
	/// Built from components rather than parsed, so the test does not depend on a
	/// locale or a date format, and pinned to UTC so the day offsets — 0, 60, 303,
	/// 411, 456 — are the same everywhere.
	static var excelExampleDates: [Date] {
		var components = DateComponents()
		components.calendar = Calendar(identifier: .gregorian)
		components.timeZone = TimeZone(identifier: "UTC")
		func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
			var parts = components
			parts.year = year
			parts.month = month
			parts.day = day
			// The Gregorian calendar always resolves these; the fallback keeps the
			// helper total rather than trapping inside a test.
			return parts.date ?? Date(timeIntervalSince1970: 0)
		}
		return [date(2008, 1, 1), date(2008, 3, 1), date(2008, 10, 30), date(2009, 2, 15), date(2009, 4, 1)]
	}

	static let excelExampleFlows: [Double] = [-10000, 2750, 4250, 3250, 2750]

	// MARK: - NPV

	@Test("npv against the textbook worked example")
	func npvTextbook() {
		// -1000 + 500/1.1 + 400/1.1² + 300/1.1³ + 100/1.1⁴, first flow at t = 0.
		let got = npv(discountRate: 0.10, cashFlows: Self.textbookCashFlows)
		let reference = 78.819752749129158
		#expect(
			abs(got - reference) / reference < 1e-10,
			"npv(0.10, \(Self.textbookCashFlows)) = \(got), reference \(reference)"
		)
	}

	@Test("npvExcel against Microsoft's published NPV example")
	func npvExcelPublished() {
		// Excel help: NPV(10%, -10000, 3000, 4200, 6800) = 1188.44. Every flow is
		// end-of-period, which is what npvExcel means and what `npv` deliberately
		// does not. Getting these two confused is a one-period discounting error of
		// 10% on the whole result, so both conventions are pinned.
		let got = npvExcel(rate: 0.10, cashFlows: [-10000, 3000, 4200, 6800])
		#expect(
			approximatelyEqual(got, 1188.44, tolerance: 1e-2),
			"npvExcel = \(got), Excel documentation gives 1188.44"
		)
		let reference = 1188.4434123352230
		#expect(
			abs(got - reference) / reference < 1e-10,
			"npvExcel = \(got), extended reference \(reference)"
		)
		// The two conventions differ by exactly one period of discounting.
		let plain = npv(discountRate: 0.10, cashFlows: [-10000, 3000, 4200, 6800])
		#expect(
			abs(got - plain / 1.10) / abs(got) < 1e-12,
			"npvExcel should equal npv discounted one further period: \(got) vs \(plain / 1.10)"
		)
	}

	@Test("npv is linear in the cash flows and monotone in the rate")
	func npvStructuralProperties() {
		// Two exact claims that need no reference. Linearity catches a misplaced
		// exponent; monotonicity catches a sign error in the discount factor.
		let flows = Self.textbookCashFlows
		let doubled = flows.map { $0 * 2 }
		#expect(
			abs(npv(discountRate: 0.08, cashFlows: doubled) - 2 * npv(discountRate: 0.08, cashFlows: flows)) < 1e-12
		)
		var previous = Double.infinity
		for step in 0...50 {
			let rate = 0.01 * Double(step)
			let value = npv(discountRate: rate, cashFlows: flows)
			#expect(value < previous, "npv rose from \(previous) to \(value) at rate \(rate)")
			previous = value
		}
		// At a zero rate NPV is the plain sum, exactly.
		#expect(approximatelyEqual(npv(discountRate: 0.0, cashFlows: flows), 300.0, tolerance: 1e-12))
	}

	// MARK: - IRR

	@Test("irr against the textbook worked example")
	func irrTextbook() throws {
		let got = try irr(cashFlows: Self.textbookCashFlows)
		// The published figure is 14.49%; asserting to the published precision.
		#expect(
			approximatelyEqual(got, 0.1449, tolerance: 5e-5),
			"irr = \(got), published 14.49%"
		)
		// And to the measured precision of the default stopping rule.
		#expect(
			approximatelyEqual(got, Self.textbookIRR, tolerance: 2.5e-10),
			"irr = \(got), extended reference \(Self.textbookIRR), differs by \(abs(got - Self.textbookIRR))"
		)
	}

	@Test("irr's default tolerance is absolute in currency, so precision tracks scale")
	func irrDefaultToleranceIsAbsoluteInCurrency() throws {
		// Not a wrong answer, but a property a caller would not guess: `irr`'s
		// stopping rule compares |NPV| against the tolerance, and NPV is in the
		// cash flows' own units. The default tolerance is 1e-4 — one hundredth of a
		// cent — so the *rate* it delivers is accurate in proportion to how large
		// the cash flows are.
		//
		// Measured on the textbook flows, error in the returned rate:
		//
		//   flows × 1        2.2e-10
		//   flows × 1000     1.1e-16
		//   flows × 1e6      1.1e-16
		//
		// Same problem, same true IRR, seven orders of magnitude of difference in
		// the answer's precision. Worth knowing before quoting an IRR to six places.
		let atUnitScale = try irr(cashFlows: Self.textbookCashFlows)
		#expect(abs(atUnitScale - Self.textbookIRR) < 2.5e-10)
		#expect(abs(atUnitScale - Self.textbookIRR) > 1e-12, "recorded: unit-scale IRR is only good to ~2e-10")

		let scaled = try irr(cashFlows: Self.textbookCashFlows.map { $0 * 1000 })
		#expect(
			abs(scaled - Self.textbookIRR) < 1e-15,
			"at 1000× scale irr = \(scaled), reference \(Self.textbookIRR)"
		)

		// Asking for the precision directly gets it, at unit scale, in the same
		// iteration budget.
		let tightened = try irr(cashFlows: Self.textbookCashFlows, tolerance: 1e-12, maxIterations: 200)
		#expect(
			approximatelyEqual(tightened, Self.textbookIRR, tolerance: 1e-14),
			"irr(tolerance: 1e-12) = \(tightened), reference \(Self.textbookIRR)"
		)
	}

	@Test("npv at the irr is zero")
	func npvAtIRRIsZero() throws {
		// The defining identity, and the one test of `irr` that needs no reference
		// at all. The residual is bounded by the stopping tolerance, so it is
		// asserted against the tolerance actually requested rather than against a
		// number pulled from a run.
		for tolerance in [1e-4, 1e-8, 1e-12] {
			let rate = try irr(cashFlows: Self.textbookCashFlows, tolerance: tolerance, maxIterations: 200)
			let residual = abs(npv(discountRate: rate, cashFlows: Self.textbookCashFlows))
			#expect(
				residual <= tolerance,
				"irr(tolerance: \(tolerance)) left an NPV residual of \(residual)"
			)
		}
	}

	@Test("irr rejects cash flows that cannot have one")
	func irrRejectsSingleSignFlows() throws {
		// All-positive and all-negative flows have no root; the function must say
		// so rather than return whatever Newton-Raphson wandered to.
		#expect(throws: BusinessMathError.self) {
			_ = try irr(cashFlows: [100.0, 200.0, 300.0])
		}
		#expect(throws: BusinessMathError.self) {
			_ = try irr(cashFlows: [-100.0, -200.0, -300.0])
		}
		#expect(throws: BusinessMathError.self) {
			_ = try irr(cashFlows: [-100.0])
		}
	}

	// MARK: - XNPV and XIRR

	@Test("xnpv against Microsoft's published example")
	func xnpvPublished() throws {
		// Excel help for XNPV: rate 9%, five dated flows, result 2086.6476.
		let got = try xnpv(rate: 0.09, dates: Self.excelExampleDates, cashFlows: Self.excelExampleFlows)
		#expect(
			approximatelyEqual(got, 2086.6476, tolerance: 1e-4),
			"xnpv = \(got), Excel documentation gives 2086.6476"
		)
		let reference = 2086.6476020315366
		#expect(
			abs(got - reference) / reference < 1e-10,
			"xnpv = \(got), extended reference \(reference), relative error \(abs(got - reference) / reference)"
		)
	}

	@Test("xirr against Microsoft's published example")
	func xirrPublished() throws {
		// Excel help for XIRR on the same flows: 0.373362535, i.e. 37.34%.
		//
		// The tolerance here is 1e-8, and it is set by the *reference*, not by the
		// code. Excel's XIRR is itself an iterative solver with a documented
		// stopping accuracy of 0.000001%, and its published figure sits **1.48e-9**
		// away from the exact root of the same equation (0.37336253351883151,
		// solved at 40 decimal digits). BusinessMath lands 9.3e-12 from that root
		// at its default tolerance — about 160 times closer to the truth than the
		// number being compared against. Asserting to 1e-9 against Excel's figure
		// would be asserting that this library reproduces Excel's convergence
		// error, which is not the claim worth making.
		let got = try xirr(dates: Self.excelExampleDates, cashFlows: Self.excelExampleFlows)
		#expect(
			approximatelyEqual(got, 0.373362535, tolerance: 1e-8),
			"xirr = \(got), Excel documentation gives 0.373362535"
		)
		let reference = 0.37336253351883151
		#expect(
			approximatelyEqual(got, reference, tolerance: 1e-10),
			"xirr = \(got), extended reference \(reference), differs by \(abs(got - reference))"
		)
		// Tightening the stopping rule recovers the last few digits, the same way
		// it does for `irr`.
		let tightened = try xirr(dates: Self.excelExampleDates, cashFlows: Self.excelExampleFlows, tolerance: 1e-8, maxIterations: 200)
		#expect(approximatelyEqual(tightened, reference, tolerance: 1e-14))
	}

	@Test("xnpv at the xirr is zero, and xnpv reduces to npv on annual dates")
	func xnpvIdentities() throws {
		let rate = try xirr(dates: Self.excelExampleDates, cashFlows: Self.excelExampleFlows, tolerance: 1e-8, maxIterations: 200)
		let residual = try xnpv(rate: rate, dates: Self.excelExampleDates, cashFlows: Self.excelExampleFlows)
		#expect(abs(residual) < 1e-7, "xnpv at the xirr is \(residual)")

		// Dates exactly 365 days apart must reproduce the undated `npv`, because
		// `xnpv` divides the day count by 365. This is the assertion that would
		// catch a day-count convention drifting to 360 or to actual/actual.
		let day: TimeInterval = 24 * 60 * 60
		let base = Date(timeIntervalSince1970: 0)
		let annualDates = (0..<5).map { base.addingTimeInterval(Double($0) * 365 * day) }
		let viaDates = try xnpv(rate: 0.10, dates: annualDates, cashFlows: Self.textbookCashFlows)
		let viaPeriods = npv(discountRate: 0.10, cashFlows: Self.textbookCashFlows)
		#expect(
			abs(viaDates - viaPeriods) / abs(viaPeriods) < 1e-12,
			"xnpv over 365-day steps = \(viaDates) but npv = \(viaPeriods)"
		)
	}

	// MARK: - Payment and amortisation

	@Test("payment against Microsoft's published PMT example")
	func paymentPublished() {
		// Excel help: PMT(8%/12, 10, 10000) = -1037.03. The sign convention differs
		// — Excel returns the payment as an outflow — so the magnitude is compared.
		let got = payment(presentValue: 10000.0, rate: 0.08 / 12, periods: 10)
		#expect(
			approximatelyEqual(got, 1037.03, tolerance: 1e-2),
			"payment = \(got), Excel documentation gives 1037.03"
		)
		let reference = 1037.0320893591522
		#expect(abs(got - reference) / reference < 1e-10, "payment = \(got), extended reference \(reference)")
	}

	@Test("payment against the standard 30-year mortgage")
	func paymentMortgage() {
		// $200,000 at 6% nominal, monthly, 360 payments: $1,199.10. The figure every
		// amortisation table opens with.
		let got = payment(presentValue: 200000.0, rate: 0.06 / 12, periods: 360)
		#expect(approximatelyEqual(got, 1199.10, tolerance: 1e-2), "payment = \(got), published 1199.10")
		let reference = 1199.1010503055048
		#expect(abs(got - reference) / reference < 1e-10, "payment = \(got), extended reference \(reference)")

		// $100,000 at 8%, 30 years: $733.76.
		#expect(approximatelyEqual(payment(presentValue: 100000.0, rate: 0.08 / 12, periods: 360), 733.76, tolerance: 1e-2))
		// $25,000 at 7%, 4 years: $598.66.
		#expect(approximatelyEqual(payment(presentValue: 25000.0, rate: 0.07 / 12, periods: 48), 598.66, tolerance: 1e-2))
	}

	@Test("payment with a balloon")
	func paymentWithBalloon() {
		// The example in `payment`'s own doc comment: $10,000 at 5%/12 over 60
		// months with a $2,000 balloon, quoted there as $151.04. That figure is
		// wrong — the closed form gives $159.30 — and the discrepancy is in the
		// documentation, not the code, so the code is checked against the
		// closed form and the doc example is recorded here.
		//
		//   PMT = [PV·r·(1+r)ⁿ - FV·r] / [(1+r)ⁿ - 1]
		//       = [10000·0.0041667·1.283359 - 2000·0.0041667] / 0.283359
		//       = 159.30320248542080
		let got = payment(presentValue: 10000.0, rate: 0.05 / 12, periods: 60, futureValue: 2000.0)
		let reference = 159.30320248542080
		#expect(abs(got - reference) / reference < 1e-10, "payment with balloon = \(got), closed form \(reference)")
		// A balloon lowers the payment relative to full amortisation, which is the
		// qualitative claim the doc comment was making.
		#expect(got < payment(presentValue: 10000.0, rate: 0.05 / 12, periods: 60))
	}

	@Test("payment at a zero rate is the plain division")
	func paymentZeroRate() {
		// Exact by definition — no interest, so the principal is split evenly. A
		// bit comparison, because there is no rounding to allow for.
		#expect(identical(payment(presentValue: 1200.0, rate: 0.0, periods: 12), 100.0))
		#expect(identical(payment(presentValue: 1200.0, rate: 0.0, periods: 12, futureValue: 200.0), 1000.0 / 12.0))
		#expect(identical(payment(presentValue: 1000.0, rate: 0.05, periods: 0), 0.0))
	}

	@Test("An annuity due payment is the ordinary payment discounted one period")
	func annuityDueRelation() {
		// Exact identity: paying at the start of each period is worth one period of
		// interest more, so the payment is divided by (1 + r).
		let rate = 0.06 / 12
		let ordinary = payment(presentValue: 200000.0, rate: rate, periods: 360, type: .ordinary)
		let due = payment(presentValue: 200000.0, rate: rate, periods: 360, type: .due)
		#expect(
			abs(due - ordinary / (1 + rate)) / due < 1e-14,
			"due \(due) should equal ordinary \(ordinary) / (1 + \(rate))"
		)
	}

	@Test("The first amortisation split is exact")
	func firstPaymentSplit() {
		// The one row of an amortisation table that can be written down without a
		// schedule: interest on the full principal, principal the remainder.
		//
		//   interest₁  = 200000 × 0.06/12 = 1000 exactly
		//   principal₁ = 1199.1010503055048 - 1000 = 199.10105030550479
		let rate = 0.06 / 12
		let interest = interestPayment(rate: rate, period: 1, totalPeriods: 360, presentValue: 200000.0)
		#expect(identical(interest, 1000.0), "first interest payment is \(interest), must be exactly 1000")

		let principal = principalPayment(rate: rate, period: 1, totalPeriods: 360, presentValue: 200000.0)
		let reference = 199.10105030550479
		#expect(abs(principal - reference) / reference < 1e-10, "first principal payment \(principal)")

		// And the two must reconstruct the payment, exactly — they are defined as a
		// difference from it.
		#expect(
			abs(interest + principal - payment(presentValue: 200000.0, rate: rate, periods: 360)) < 1e-12
		)
	}

	@Test("The schedule closes: principal sums to the loan and interest to the excess")
	func amortisationClosureIdentity() {
		// Two exact claims about any amortisation schedule, needing no reference:
		//
		//   Σ principal over all periods == PV - FV
		//   Σ interest  over all periods == n · PMT - (PV - FV)
		//
		// The implementation computes each period's split from a closed-form
		// remaining balance rather than by iterating a running balance, so these
		// identities are not automatic — they are the check that the closed form is
		// the right one.
		//
		// Tolerance 1e-8 absolute on a $200,000 principal, i.e. 5e-14 relative:
		// 360 independent balance computations each carrying a few ulp. Measured:
		// **4.1e-9** on the principal sum.
		let rate = 0.06 / 12
		let principalTotal = cumulativePrincipal(
			rate: rate, startPeriod: 1, endPeriod: 360, totalPeriods: 360, presentValue: 200000.0
		)
		#expect(
			approximatelyEqual(principalTotal, 200000.0, tolerance: 1e-8),
			"principal payments sum to \(principalTotal), loan is 200000, off by \(abs(principalTotal - 200000))"
		)

		let interestTotal = cumulativeInterest(
			rate: rate, startPeriod: 1, endPeriod: 360, totalPeriods: 360, presentValue: 200000.0
		)
		let expectedInterest = 360 * payment(presentValue: 200000.0, rate: rate, periods: 360) - 200000
		#expect(
			approximatelyEqual(interestTotal, expectedInterest, tolerance: 1e-8),
			"interest payments sum to \(interestTotal), n·PMT - PV is \(expectedInterest)"
		)

		// With a balloon the same identity must hold against PV - FV.
		let withBalloon = cumulativePrincipal(
			rate: 0.05 / 12, startPeriod: 1, endPeriod: 60, totalPeriods: 60,
			presentValue: 10000.0, futureValue: 2000.0
		)
		#expect(
			approximatelyEqual(withBalloon, 8000.0, tolerance: 1e-9),
			"principal repaid with a 2000 balloon is \(withBalloon), should be 8000"
		)
	}

	@Test("Interest falls and principal rises across the schedule")
	func amortisationShape() {
		// The qualitative claim the doc comments make, asserted so that a sign or
		// index error in the balance formula cannot pass.
		let rate = 0.06 / 12
		var previousInterest = Double.infinity
		var previousPrincipal = -Double.infinity
		for period in stride(from: 1, through: 360, by: 12) {
			let interest = interestPayment(rate: rate, period: period, totalPeriods: 360, presentValue: 200000.0)
			let principal = principalPayment(rate: rate, period: period, totalPeriods: 360, presentValue: 200000.0)
			#expect(interest < previousInterest, "interest rose at period \(period)")
			#expect(principal > previousPrincipal, "principal fell at period \(period)")
			#expect(interest > 0 && principal > 0, "period \(period) split is \(interest) / \(principal)")
			previousInterest = interest
			previousPrincipal = principal
		}
	}
}

//
//  LeasePresentValueRateTests.swift
//  BusinessMath
//
//  `Lease.presentValue()` returned a plausible number for a discount rate that has no
//  present value, and said nothing.
//
//  The loop guarded its divisor with `guard discountFactor != 0 else { continue }`. At a
//  periodic rate of exactly -100% every factor is `pow(0, n) = 0`, so every payment was
//  skipped; the residual block did the same with `return pv`. Below -100% the compounding
//  base is negative and `pow` alternates sign across the integer periods, so the sum is an
//  alternating series that happens to land somewhere finite. `!= 0` is also true of NaN.
//
//  Measured before the fix, on three payments of 1,000 against a residual of 500:
//
//  | discount rate | present value |
//  |---|---|
//  | 5% | 3,134.5992667664195 |
//  | 0% | 3,500.0 |
//  | -50% | 22,000.0 |
//  | **-100%** | **0.0** — every cash flow dropped |
//  | **-150%** | **2,000.0** |
//  | **-200%** | **-500.0** — a negative present value for positive payments |
//
//  `DCFModel` was given `precondition(waccRate > -1)` earlier in this sweep for exactly this
//  arithmetic. This is the same class, in a second file, which is the shape the ICC(1,1)
//  defect had.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Lease present value rejects rates that have no present value")
struct LeasePresentValueRateTests {

	private static func threePayments(at rate: Double) -> Lease {
		Lease(payments: [1000, 1000, 1000], discountRate: rate, residualValue: 500)
	}

	// MARK: - The rates that used to return a number

	/// Exactly -100%: every discount factor is zero, and every payment used to be skipped.
	@Test("MinusOneHundredPercent_Traps", .requiresUnsanitizedRuntime)
	func minusOneHundredPercentTraps() async {
		await #expect(processExitsWith: .failure) {
			_ = Self.threePayments(at: -1.0).presentValue()
		}
	}

	/// Below -100%: the compounding base is negative and the sum alternates.
	@Test("BelowMinusOneHundredPercent_Traps", .requiresUnsanitizedRuntime)
	func belowMinusOneHundredPercentTraps() async {
		await #expect(processExitsWith: .failure) {
			_ = Self.threePayments(at: -1.5).presentValue()
		}
		await #expect(processExitsWith: .failure) {
			_ = Self.threePayments(at: -2.0).presentValue()
		}
	}

	/// `!= 0` was true of NaN, so a NaN rate reached the sum untouched. `NaN > -1` is false,
	/// so the precondition catches it.
	@Test("NaNRate_Traps", .requiresUnsanitizedRuntime)
	func nanRateTraps() async {
		await #expect(processExitsWith: .failure) {
			_ = Self.threePayments(at: .nan).presentValue()
		}
	}

	// MARK: - Every rate that has a present value still gets the same one

	/// The three sound rates from the table, to the bit. These are the numbers the unguarded
	/// code produced, so the precondition is provably not reaching any of them.
	@Test("SoundRates_Unchanged") func soundRatesUnchanged() {
		#expect(Self.threePayments(at: 0.05).presentValue().isEqual(to: 3134.5992667664195),
				"5% discounting is untouched")
		#expect(Self.threePayments(at: 0.0).presentValue().isEqual(to: 3500.0),
				"a zero rate is the undiscounted total")
		#expect(Self.threePayments(at: -0.5).presentValue().isEqual(to: 22000.0),
				"a negative rate above -100% still has a present value, and keeps it")
	}

	/// The boundary is open on one side only: just above -100% is a real, enormous number.
	@Test("JustAboveMinusOneHundredPercent_HasAPresentValue") func justAboveTheBoundary() {
		let pv = Self.threePayments(at: -0.999).presentValue()
		#expect(pv.isFinite, "a periodic rate of -99.9% still compounds")
		#expect(pv > 0, "and to a positive present value")
	}

	/// `rightOfUseAsset` reads the same present value, so it inherits the guard rather than
	/// needing its own.
	@Test("RightOfUseAsset_TracksPresentValue") func rightOfUseAssetTracksPresentValue() {
		let lease = Self.threePayments(at: 0.05)
		#expect(lease.rightOfUseAsset().isEqual(to: lease.presentValue()),
				"the right-of-use asset is the same discounting")
	}
}

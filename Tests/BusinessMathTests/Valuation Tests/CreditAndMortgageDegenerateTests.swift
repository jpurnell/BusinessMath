//
//  CreditAndMortgageDegenerateTests.swift
//  BusinessMathTests
//
//  Two divisors reached by ordinary inputs, both found by grepping for divisors the
//  fp-safety checker cannot see — `spread / (T(1) - recovery)` and `… / (factor - 1)`.
//
//  ## The credit one had a correct implementation sitting next to it
//
//  `hazardRateFromSpread(spread:recoveryRate:)` guards this exact conversion and documents
//  that it returns nil at a recovery rate of 1. `survivalProbabilitiesFromSpreads` wrote the
//  formula out a second time without the guard — the same shape as `CapitalStructure.wacc`,
//  which documented a delegation it did not perform. `CreditCurve.init` validates nothing,
//  so both bad inputs were reachable. Measured before the fix, on a flat 2% spread:
//
//  | recovery | survival returned | what that claims |
//  |---|---|---|
//  | 0.40 | 0.9917, 0.9835, 0.9753, 0.9672 | correct |
//  | **1.0** | **0.0, 0.0, 0.0, 0.0** | certain immediate default, for a **fully recovering** bond |
//  | **1.5** | **1.0100, 1.0202, 1.0304, 1.0408** | probabilities **above 1**, rising with time |
//
//  The 1.0 row is inverted rather than merely wrong: full recovery is the safest credit there
//  is, and the model reported it as the most distressed.
//
//  ## The mortgage one broke both branches at once
//
//  `calculateMonthlyPayment` already guarded `monthlyRate == 0`. A term of zero years defeats
//  that guard *and* the branch it protects: `numberOfPayments` is zero, and
//  `pow(1 + monthlyRate, 0)` is exactly 1, so `factor - 1` is zero too. Both paths returned
//  **+infinity**, which multiplied out through `annualMortgagePayment` and everything built
//  on it.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Credit curves and mortgages reject inputs they cannot price")
struct CreditAndMortgageDegenerateTests {

	// MARK: - Credit

	private static let quarters = (1...4).map { Period.quarter(year: 2025, quarter: $0) }

	private static func survival(recovery: Double, spread: Double = 0.02) -> [Double] {
		let spreads = TimeSeries(periods: quarters, values: Array(repeating: spread, count: 4))
		let discount = TimeSeries(periods: quarters, values: Array(repeating: 1.0, count: 4))
		let curve = CreditCurve(spreads: spreads, recoveryRate: recovery)
		return survivalProbabilitiesFromSpreads(creditCurve: curve, discountCurve: discount).valuesArray
	}

	/// The sound path, to the bit. These are the values the unguarded code produced, so
	/// delegating to the guarded sibling is provably not moving any of them.
	@Test("Credit_SoundRecovery_BitIdentical") func creditSoundRecoveryBitIdentical() {
		let values = Self.survival(recovery: 0.40)
		#expect(values.count == 4)
		#expect(values[0].isEqual(to: 0.991701292638876))
		#expect(values[1].isEqual(to: 0.9834714538216175))
		#expect(values[2].isEqual(to: 0.9753099120283326))
		#expect(values[3].isEqual(to: 0.9672161004820059))
	}

	@Test("Credit_ZeroRecovery_BitIdentical") func creditZeroRecoveryBitIdentical() {
		let values = Self.survival(recovery: 0.0)
		#expect(values[0].isEqual(to: 0.9950124791926823), "no recovery is still a priceable credit")
	}

	/// Full recovery means a loss given default of zero, so a positive spread is not a quote
	/// that can be inverted — it is an inconsistent one.
	@Test("Credit_FullRecovery_Traps", .requiresUnsanitizedRuntime)
	func creditFullRecoveryTraps() async {
		await #expect(processExitsWith: .failure) {
			let quarters = (1...4).map { Period.quarter(year: 2025, quarter: $0) }
			let spreads = TimeSeries(periods: quarters, values: Array(repeating: 0.02, count: 4))
			let discount = TimeSeries(periods: quarters, values: Array(repeating: 1.0, count: 4))
			let curve = CreditCurve(spreads: spreads, recoveryRate: 1.0)
			_ = survivalProbabilitiesFromSpreads(creditCurve: curve, discountCurve: discount)
		}
	}

	/// Above 1 the divisor turns negative, which is what produced survival probabilities
	/// greater than one.
	@Test("Credit_RecoveryAboveOne_Traps", .requiresUnsanitizedRuntime)
	func creditRecoveryAboveOneTraps() async {
		await #expect(processExitsWith: .failure) {
			let quarters = (1...4).map { Period.quarter(year: 2025, quarter: $0) }
			let spreads = TimeSeries(periods: quarters, values: Array(repeating: 0.02, count: 4))
			let discount = TimeSeries(periods: quarters, values: Array(repeating: 1.0, count: 4))
			let curve = CreditCurve(spreads: spreads, recoveryRate: 1.5)
			_ = survivalProbabilitiesFromSpreads(creditCurve: curve, discountCurve: discount)
		}
	}

	/// The two implementations now agree by construction, which is the point of delegating.
	@Test("Credit_SiblingAgrees") func creditSiblingAgrees() throws {
		let hazard = try #require(hazardRateFromSpread(spread: 0.02, recoveryRate: 0.40))
		#expect(hazard.isEqual(to: 0.03333333333333333))
		// exp(-hazard * 0.25) is the first quarter's survival.
		let firstQuarter = Foundation.exp(-hazard * 0.25)
		#expect(firstQuarter.isEqual(to: Self.survival(recovery: 0.40)[0]))
		#expect(hazardRateFromSpread(spread: 0.02, recoveryRate: 1.0) == nil,
				"the sibling has always refused this")
	}

	// MARK: - Mortgage

	private static func model(rate: Double, years: Int) -> RealEstateModel {
		RealEstateModel(purchasePrice: 400_000, downPaymentPercentage: 0.20,
						interestRate: rate, loanTermYears: years,
						annualRent: 36_000, annualOperatingExpenses: 12_000,
						annualAppreciationRate: 0.03)
	}

	/// Both sound branches, to the bit — the interest-bearing one and the zero-rate one the
	/// existing guard already handled.
	@Test("Mortgage_SoundTerms_BitIdentical") func mortgageSoundTermsBitIdentical() {
		#expect(Self.model(rate: 0.06, years: 30).monthlyMortgagePayment
			.isEqual(to: 1918.5616804888223), "320,000 over 30 years at 6%")
		#expect(Self.model(rate: 0.0, years: 30).monthlyMortgagePayment
			.isEqual(to: 888.8888888888889), "320,000 over 360 interest-free payments")
	}

	/// A term of zero defeats the zero-rate guard and the branch it protects alike.
	@Test("Mortgage_ZeroTerm_Traps", .requiresUnsanitizedRuntime)
	func mortgageZeroTermTraps() async {
		await #expect(processExitsWith: .failure) {
			_ = RealEstateModel(purchasePrice: 400_000, downPaymentPercentage: 0.20,
								interestRate: 0.06, loanTermYears: 0,
								annualRent: 36_000, annualOperatingExpenses: 12_000,
								annualAppreciationRate: 0.03).monthlyMortgagePayment
		}
		// The zero-rate branch reached the same infinity by a different route.
		await #expect(processExitsWith: .failure) {
			_ = RealEstateModel(purchasePrice: 400_000, downPaymentPercentage: 0.20,
								interestRate: 0.0, loanTermYears: 0,
								annualRent: 36_000, annualOperatingExpenses: 12_000,
								annualAppreciationRate: 0.03).monthlyMortgagePayment
		}
	}
}

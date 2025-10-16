//
//  FutureValue.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - Future Value Functions

/// Calculates the future value of a present sum.
///
/// Future Value (FV) is the value of a current amount after earning interest over time.
/// The formula is:
///
/// FV = PV × (1 + r)^n
///
/// Where:
/// - PV = Present Value
/// - r = Interest rate per period
/// - n = Number of periods
///
/// - Parameters:
///   - presentValue: The current value to grow.
///   - rate: The interest rate per period (e.g., 0.10 for 10%).
///   - periods: The number of periods.
/// - Returns: The future value.
///
/// ## Example
/// ```swift
/// // What will $1000 grow to in 5 years at 10% interest?
/// let fv = futureValue(presentValue: 1000.0, rate: 0.10, periods: 5)
/// // Result: $1,610.51
/// ```
///
/// ## Edge Cases
/// - If `rate` is 0, returns the present value unchanged.
/// - If `periods` is 0, returns the present value unchanged.
/// - If `presentValue` is 0, returns 0.
/// - Negative rates are allowed (representing deflation or negative interest).
public func futureValue<T: Real>(presentValue: T, rate: T, periods: Int) -> T {
	guard presentValue != T.zero else { return T.zero }
	guard periods > 0 else { return presentValue }

	// FV = PV * (1 + r)^n
	let growthFactor = T.pow(T(1) + rate, T(periods))
	return presentValue * growthFactor
}

/// Calculates the future value of an annuity (stream of equal payments).
///
/// An annuity is a series of equal payments made at regular intervals.
/// The future value is the sum of all payments plus their accumulated interest.
///
/// **Ordinary Annuity** (payments at end of period):
/// ```
/// FV = PMT × [((1 + r)^n - 1) / r]
/// ```
///
/// **Annuity Due** (payments at beginning of period):
/// ```
/// FV = FV_ordinary × (1 + r)
/// ```
///
/// Where:
/// - PMT = Payment per period
/// - r = Interest rate per period
/// - n = Number of periods
///
/// - Parameters:
///   - payment: The payment amount per period.
///   - rate: The interest rate per period (e.g., 0.10 for 10%).
///   - periods: The number of payment periods.
///   - type: The timing of payments (`.ordinary` or `.due`).
/// - Returns: The future value of the annuity.
///
/// ## Examples
/// ```swift
/// // Ordinary annuity: $100/year for 5 years at 10%
/// let fvOrdinary = futureValueAnnuity(
///     payment: 100.0,
///     rate: 0.10,
///     periods: 5,
///     type: .ordinary
/// )
/// // Result: $610.51
///
/// // Annuity due: Same payments at beginning of period
/// let fvDue = futureValueAnnuity(
///     payment: 100.0,
///     rate: 0.10,
///     periods: 5,
///     type: .due
/// )
/// // Result: $671.56 (higher because payments grow longer)
/// ```
///
/// ## Real-World Applications
///
/// **Retirement Savings:**
/// ```swift
/// // 401k: $500/month for 30 years at 7% annual return
/// let monthlyRate = 0.07 / 12.0
/// let periods = 30 * 12
/// let retirementFV = futureValueAnnuity(
///     payment: 500.0,
///     rate: monthlyRate,
///     periods: periods,
///     type: .ordinary
/// )
/// // Result: ~$607,438
/// ```
///
/// **College Savings:**
/// ```swift
/// // Monthly contributions for 18 years at 6% annual return
/// let monthlyRate = 0.06 / 12.0
/// let periods = 18 * 12
/// let collegeFV = futureValueAnnuity(
///     payment: 300.0,
///     rate: monthlyRate,
///     periods: periods,
///     type: .ordinary
/// )
/// // Result: ~$131,067
/// ```
///
/// **Savings Account:**
/// ```swift
/// // $200/month deposits at 0.5%/month interest
/// let savingsFV = futureValueAnnuity(
///     payment: 200.0,
///     rate: 0.005,
///     periods: 60,
///     type: .ordinary
/// )
/// // Result: ~$13,954
/// ```
///
/// ## Relationship with Present Value
///
/// Future Value and Present Value are reciprocal:
/// ```swift
/// let fv = futureValue(presentValue: pv, rate: rate, periods: periods)
/// let backToPV = presentValue(futureValue: fv, rate: rate, periods: periods)
/// // backToPV ≈ pv
/// ```
///
/// ## Edge Cases
/// - If `rate` is 0, FV = payment × periods for both ordinary and due.
/// - If `periods` is 0, returns 0.
/// - If `payment` is 0, returns 0.
/// - For a single period:
///   - Ordinary annuity: FV = payment (no growth)
///   - Due annuity: FV = payment × (1 + rate) (grows for one period)
public func futureValueAnnuity<T: Real>(
	payment: T,
	rate: T,
	periods: Int,
	type: AnnuityType = .ordinary
) -> T {
	guard payment != T.zero else { return T.zero }
	guard periods > 0 else { return T.zero }

	// Special case: zero interest rate
	// FV = payment * periods (no growth)
	if rate == T.zero {
		return payment * T(periods)
	}

	// Calculate ordinary annuity future value
	// FV = PMT * [((1 + r)^n - 1) / r]
	let onePlusRate = T(1) + rate
	let growthFactor = T.pow(onePlusRate, T(periods))
	let numerator = growthFactor - T(1)
	let fvOrdinary = payment * (numerator / rate)

	// For annuity due, multiply by (1 + rate)
	// This accounts for payments occurring at the start of each period
	switch type {
	case .ordinary:
		return fvOrdinary
	case .due:
		return fvOrdinary * onePlusRate
	}
}

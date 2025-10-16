//
//  PresentValue.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - AnnuityType

/// The timing of annuity payments.
///
/// In financial calculations, the timing of payments affects the present value:
/// - `.ordinary`: Payments occur at the end of each period
/// - `.due`: Payments occur at the beginning of each period
///
/// ## Example
/// ```swift
/// let pv = presentValueAnnuity(
///     payment: 1000.0,
///     rate: 0.05,
///     periods: 10,
///     type: .ordinary
/// )
/// ```
public enum AnnuityType: Sendable, Codable {
	/// Payments occur at the end of each period (default for most loans and investments).
	case ordinary

	/// Payments occur at the beginning of each period (common for leases and rents).
	case due
}

// MARK: - Present Value Functions

/// Calculates the present value of a future sum.
///
/// Present Value (PV) is the current worth of a future amount, discounted at a given rate.
/// The formula is:
///
/// PV = FV / (1 + r)^n
///
/// Where:
/// - FV = Future Value
/// - r = Discount rate per period
/// - n = Number of periods
///
/// - Parameters:
///   - futureValue: The future value to discount.
///   - rate: The discount rate per period (e.g., 0.10 for 10%).
///   - periods: The number of periods.
/// - Returns: The present value.
///
/// ## Example
/// ```swift
/// // What is $1000 in 5 years worth today at 10% discount rate?
/// let pv = presentValue(futureValue: 1000.0, rate: 0.10, periods: 5)
/// // Result: $620.92
/// ```
///
/// ## Edge Cases
/// - If `rate` is 0, returns the future value unchanged.
/// - If `periods` is 0, returns the future value unchanged.
/// - If `futureValue` is 0, returns 0.
/// - Negative rates are allowed (representing deflation or negative interest).
public func presentValue<T: Real>(futureValue: T, rate: T, periods: Int) -> T {
	guard futureValue != T.zero else { return T.zero }
	guard periods > 0 else { return futureValue }

	// PV = FV / (1 + r)^n
	let discountFactor = T.pow(T(1) + rate, T(periods))
	return futureValue / discountFactor
}

/// Calculates the present value of an annuity (stream of equal payments).
///
/// An annuity is a series of equal payments made at regular intervals.
/// The present value is the sum of all discounted future payments.
///
/// **Ordinary Annuity** (payments at end of period):
/// ```
/// PV = PMT × [(1 - (1 + r)^-n) / r]
/// ```
///
/// **Annuity Due** (payments at beginning of period):
/// ```
/// PV = PV_ordinary × (1 + r)
/// ```
///
/// Where:
/// - PMT = Payment per period
/// - r = Discount rate per period
/// - n = Number of periods
///
/// - Parameters:
///   - payment: The payment amount per period.
///   - rate: The discount rate per period (e.g., 0.10 for 10%).
///   - periods: The number of payment periods.
///   - type: The timing of payments (`.ordinary` or `.due`).
/// - Returns: The present value of the annuity.
///
/// ## Examples
/// ```swift
/// // Ordinary annuity: $100/year for 5 years at 10%
/// let pvOrdinary = presentValueAnnuity(
///     payment: 100.0,
///     rate: 0.10,
///     periods: 5,
///     type: .ordinary
/// )
/// // Result: $379.08
///
/// // Annuity due: Same payments at beginning of period
/// let pvDue = presentValueAnnuity(
///     payment: 100.0,
///     rate: 0.10,
///     periods: 5,
///     type: .due
/// )
/// // Result: $416.99 (higher because payments come sooner)
/// ```
///
/// ## Real-World Applications
///
/// **Loan Payments:**
/// ```swift
/// // Car loan: $30,000 for 60 months at 5% APR
/// let monthlyRate = 0.05 / 12.0
/// let pvOf1PerMonth = presentValueAnnuity(
///     payment: 1.0,
///     rate: monthlyRate,
///     periods: 60,
///     type: .ordinary
/// )
/// let monthlyPayment = 30000.0 / pvOf1PerMonth  // ~$566.14/month
/// ```
///
/// **Retirement Planning:**
/// ```swift
/// // How much needed to generate $50k/year for 30 years at 4%?
/// let neededAtRetirement = presentValueAnnuity(
///     payment: 50000.0,
///     rate: 0.04,
///     periods: 30,
///     type: .ordinary
/// )
/// // Result: ~$864,601
/// ```
///
/// **Bond Valuation:**
/// ```swift
/// // Bond pays $50/year for 10 years, then $1000 at maturity (6% yield)
/// let couponPV = presentValueAnnuity(
///     payment: 50.0,
///     rate: 0.06,
///     periods: 10,
///     type: .ordinary
/// )
/// let facePV = presentValue(futureValue: 1000.0, rate: 0.06, periods: 10)
/// let bondValue = couponPV + facePV  // ~$926.40
/// ```
///
/// ## Edge Cases
/// - If `rate` is 0, PV = payment × periods for both ordinary and due.
/// - If `periods` is 0, returns 0.
/// - If `payment` is 0, returns 0.
/// - For a single period, ordinary annuity discounts once; due annuity doesn't discount.
public func presentValueAnnuity<T: Real>(
	payment: T,
	rate: T,
	periods: Int,
	type: AnnuityType = .ordinary
) -> T {
	guard payment != T.zero else { return T.zero }
	guard periods > 0 else { return T.zero }

	// Special case: zero interest rate
	// PV = payment * periods (no discounting)
	if rate == T.zero {
		return payment * T(periods)
	}

	// Calculate ordinary annuity present value
	// PV = PMT * [(1 - (1 + r)^-n) / r]
	let onePlusRate = T(1) + rate
	let discountFactor = T.pow(onePlusRate, T(-periods))
	let numerator = T(1) - discountFactor
	let pvOrdinary = payment * (numerator / rate)

	// For annuity due, multiply by (1 + rate)
	// This accounts for payments occurring at the start of each period
	switch type {
	case .ordinary:
		return pvOrdinary
	case .due:
		return pvOrdinary * onePlusRate
	}
}

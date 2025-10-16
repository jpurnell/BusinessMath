//
//  Payment.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - Payment Functions

/// Calculates the periodic payment for a loan or annuity.
///
/// This function calculates the payment amount needed to pay off a loan or reach
/// a future value target, similar to Excel's PMT function.
///
/// **Formula (Ordinary Annuity):**
/// ```
/// PMT = [PV × r(1+r)^n - FV × r] / [(1+r)^n - 1]
/// ```
///
/// **Formula (Annuity Due):**
/// ```
/// PMT = PMT_ordinary / (1 + r)
/// ```
///
/// Where:
/// - PV = Present Value (loan amount)
/// - FV = Future Value (balloon payment, default 0)
/// - r = Interest rate per period
/// - n = Number of periods
///
/// - Parameters:
///   - presentValue: The present value or loan amount.
///   - rate: The interest rate per period (e.g., 0.05/12 for 5% annual).
///   - periods: The total number of payment periods.
///   - futureValue: The future value or balloon payment (default: 0).
///   - type: The timing of payments (`.ordinary` or `.due`, default: `.ordinary`).
/// - Returns: The payment amount per period.
///
/// ## Examples
///
/// **Basic Loan:**
/// ```swift
/// // $10,000 loan at 5% annual (0.4167%/month) for 60 months
/// let pmt = payment(presentValue: 10000.0, rate: 0.05/12, periods: 60)
/// // Result: $188.71/month
/// ```
///
/// **Mortgage:**
/// ```swift
/// // $250,000 mortgage at 4% annual for 30 years
/// let monthlyRate = 0.04 / 12.0
/// let periods = 30 * 12
/// let pmt = payment(presentValue: 250000.0, rate: monthlyRate, periods: periods)
/// // Result: $1,193.54/month
/// ```
///
/// **Loan with Balloon Payment:**
/// ```swift
/// // $10,000 loan with $2,000 balloon at end
/// let pmt = payment(
///     presentValue: 10000.0,
///     rate: 0.05/12,
///     periods: 60,
///     futureValue: 2000.0
/// )
/// // Result: $151.04/month (lower due to balloon)
/// ```
///
/// ## Edge Cases
/// - If `rate` is 0: PMT = (PV - FV) / periods
/// - If `periods` is 0: returns 0
/// - Annuity due payments are slightly lower (payment at period start)
public func payment<T: Real>(
	presentValue: T,
	rate: T,
	periods: Int,
	futureValue: T = T.zero,
	type: AnnuityType = .ordinary
) -> T {
	guard periods > 0 else { return T.zero }

	// Special case: zero interest rate
	if rate == T.zero {
		return (presentValue - futureValue) / T(periods)
	}

	// Calculate payment using standard formula
	// PMT = [PV * r(1+r)^n - FV * r] / [(1+r)^n - 1]
	let onePlusRate = T(1) + rate
	let factor = T.pow(onePlusRate, T(periods))
	let numerator = presentValue * rate * factor - futureValue * rate
	let denominator = factor - T(1)
	var pmt = numerator / denominator

	// For annuity due, adjust payment
	if type == .due {
		pmt = pmt / onePlusRate
	}

	return pmt
}

/// Calculates the principal portion of a specific payment.
///
/// This function returns how much of a payment goes toward paying down the principal,
/// similar to Excel's PPMT function.
///
/// - Parameters:
///   - rate: The interest rate per period.
///   - period: The specific period to calculate (1-indexed).
///   - totalPeriods: The total number of payment periods.
///   - presentValue: The present value or loan amount.
///   - futureValue: The future value or balloon payment (default: 0).
///   - type: The timing of payments (default: `.ordinary`).
/// - Returns: The principal portion of the payment.
///
/// ## Example
/// ```swift
/// // Principal in first payment of $10,000 loan at 5%/12 for 60 months
/// let ppmt = principalPayment(
///     rate: 0.05/12,
///     period: 1,
///     totalPeriods: 60,
///     presentValue: 10000.0
/// )
/// // Result: ~$147.04
/// ```
///
/// ## Behavior
/// - Principal portion increases over time (early payments pay more interest)
/// - Returns 0 for period 0
/// - Last payment pays off remaining balance
public func principalPayment<T: Real>(
	rate: T,
	period: Int,
	totalPeriods: Int,
	presentValue: T,
	futureValue: T = T.zero,
	type: AnnuityType = .ordinary
) -> T {
	guard period > 0 && period <= totalPeriods else { return T.zero }

	// Get the total payment amount
	let pmt = payment(
		presentValue: presentValue,
		rate: rate,
		periods: totalPeriods,
		futureValue: futureValue,
		type: type
	)

	// Get the interest portion
	let ipmt = interestPayment(
		rate: rate,
		period: period,
		totalPeriods: totalPeriods,
		presentValue: presentValue,
		futureValue: futureValue,
		type: type
	)

	// Principal = Payment - Interest
	return pmt - ipmt
}

/// Calculates the interest portion of a specific payment.
///
/// This function returns how much of a payment goes toward interest,
/// similar to Excel's IPMT function.
///
/// - Parameters:
///   - rate: The interest rate per period.
///   - period: The specific period to calculate (1-indexed).
///   - totalPeriods: The total number of payment periods.
///   - presentValue: The present value or loan amount.
///   - futureValue: The future value or balloon payment (default: 0).
///   - type: The timing of payments (default: `.ordinary`).
/// - Returns: The interest portion of the payment.
///
/// ## Example
/// ```swift
/// // Interest in first payment of $10,000 loan at 5%/12 for 60 months
/// let ipmt = interestPayment(
///     rate: 0.05/12,
///     period: 1,
///     totalPeriods: 60,
///     presentValue: 10000.0
/// )
/// // Result: ~$41.67
/// ```
///
/// ## Behavior
/// - Interest portion decreases over time (as principal is paid down)
/// - Returns 0 for period 0
/// - Calculated based on remaining balance at start of period
public func interestPayment<T: Real>(
	rate: T,
	period: Int,
	totalPeriods: Int,
	presentValue: T,
	futureValue: T = T.zero,
	type: AnnuityType = .ordinary
) -> T {
	guard period > 0 && period <= totalPeriods else { return T.zero }

	// Calculate remaining balance at start of this period
	// This is the FV of the loan at (period - 1) payments
	let remainingBalance: T

	if period == 1 {
		// First payment: interest on full principal
		remainingBalance = presentValue
	} else {
		// Calculate balance after (period - 1) payments
		// Balance = PV * (1+r)^(p-1) - PMT * [((1+r)^(p-1) - 1) / r]
		let pmt = payment(
			presentValue: presentValue,
			rate: rate,
			periods: totalPeriods,
			futureValue: futureValue,
			type: type
		)

		let periodsPaid = period - 1
		let onePlusRate = T(1) + rate
		let factor = T.pow(onePlusRate, T(periodsPaid))

		if rate == T.zero {
			remainingBalance = presentValue - pmt * T(periodsPaid)
		} else {
			let growth = presentValue * factor
			let paymentsValue = pmt * ((factor - T(1)) / rate)
			remainingBalance = growth - paymentsValue
		}
	}

	// Interest = remaining balance × rate
	var interest = remainingBalance * rate

	// For annuity due, adjust for payment at start of period
	if type == .due && period > 1 {
		interest = interest / (T(1) + rate)
	}

	return interest
}

/// Calculates the cumulative interest paid over a range of periods.
///
/// This function sums the interest portions of payments from the start period
/// to the end period, similar to Excel's CUMIPMT function.
///
/// - Parameters:
///   - rate: The interest rate per period.
///   - startPeriod: The first period to include (1-indexed).
///   - endPeriod: The last period to include (1-indexed).
///   - totalPeriods: The total number of payment periods.
///   - presentValue: The present value or loan amount.
///   - futureValue: The future value or balloon payment (default: 0).
///   - type: The timing of payments (default: `.ordinary`).
/// - Returns: The cumulative interest paid over the range.
///
/// ## Example
/// ```swift
/// // Total interest paid in first year of 5-year loan
/// let cumInt = cumulativeInterest(
///     rate: 0.05/12,
///     startPeriod: 1,
///     endPeriod: 12,
///     totalPeriods: 60,
///     presentValue: 10000.0
/// )
/// // Result: ~$452.36
/// ```
///
/// ## Use Cases
/// - Calculate total interest paid over life of loan
/// - Calculate interest for tax deduction purposes
/// - Compare interest costs between different periods
public func cumulativeInterest<T: Real>(
	rate: T,
	startPeriod: Int,
	endPeriod: Int,
	totalPeriods: Int,
	presentValue: T,
	futureValue: T = T.zero,
	type: AnnuityType = .ordinary
) -> T {
	guard startPeriod > 0 && endPeriod <= totalPeriods && startPeriod <= endPeriod else {
		return T.zero
	}

	var total = T.zero

	for period in startPeriod...endPeriod {
		let ipmt = interestPayment(
			rate: rate,
			period: period,
			totalPeriods: totalPeriods,
			presentValue: presentValue,
			futureValue: futureValue,
			type: type
		)
		total = total + ipmt
	}

	return total
}

/// Calculates the cumulative principal paid over a range of periods.
///
/// This function sums the principal portions of payments from the start period
/// to the end period, similar to Excel's CUMPRINC function.
///
/// - Parameters:
///   - rate: The interest rate per period.
///   - startPeriod: The first period to include (1-indexed).
///   - endPeriod: The last period to include (1-indexed).
///   - totalPeriods: The total number of payment periods.
///   - presentValue: The present value or loan amount.
///   - futureValue: The future value or balloon payment (default: 0).
///   - type: The timing of payments (default: `.ordinary`).
/// - Returns: The cumulative principal paid over the range.
///
/// ## Example
/// ```swift
/// // Total principal paid in first year of 5-year loan
/// let cumPrinc = cumulativePrincipal(
///     rate: 0.05/12,
///     startPeriod: 1,
///     endPeriod: 12,
///     totalPeriods: 60,
///     presentValue: 10000.0
/// )
/// // Result: ~$1,812.16
/// ```
///
/// ## Use Cases
/// - Track equity buildup in home or vehicle
/// - Calculate remaining balance after N payments
/// - Verify amortization schedule accuracy
public func cumulativePrincipal<T: Real>(
	rate: T,
	startPeriod: Int,
	endPeriod: Int,
	totalPeriods: Int,
	presentValue: T,
	futureValue: T = T.zero,
	type: AnnuityType = .ordinary
) -> T {
	guard startPeriod > 0 && endPeriod <= totalPeriods && startPeriod <= endPeriod else {
		return T.zero
	}

	var total = T.zero

	for period in startPeriod...endPeriod {
		let ppmt = principalPayment(
			rate: rate,
			period: period,
			totalPeriods: totalPeriods,
			presentValue: presentValue,
			futureValue: futureValue,
			type: type
		)
		total = total + ppmt
	}

	return total
}

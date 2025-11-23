//
//  GrowthRate.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - Compounding Frequency

/// The frequency at which growth compounds.
public enum CompoundingFrequency: Sendable {
	/// Annual compounding (once per year).
	case annual

	/// Semiannual compounding (twice per year).
	case semiannual

	/// Quarterly compounding (four times per year).
	case quarterly

	/// Monthly compounding (twelve times per year).
	case monthly

	/// Daily compounding (365 times per year).
	case daily

	/// Continuous compounding (infinite periods using e^rt).
	case continuous

	/// The number of compounding periods per year.
	public var periodsPerYear: Int {
		switch self {
		case .annual: return 1
		case .semiannual: return 2
		case .quarterly: return 4
		case .monthly: return 12
		case .daily: return 365
		case .continuous: return Int.max  // Marker for continuous
		}
	}
}

// MARK: - Growth Rate Functions

/// Calculates the simple growth rate between two values.
///
/// The growth rate represents the percentage change from an initial value to a final value.
///
/// **Formula:**
/// ```
/// Growth Rate = (To - From) / From
/// ```
///
/// - Parameters:
///   - from: The initial (starting) value.
///   - to: The final (ending) value.
/// - Returns: The growth rate as a decimal (e.g., 0.10 for 10% growth).
///
/// ## Examples
///
/// **Positive Growth:**
/// ```swift
/// let growth = growthRate(from: 100.0, to: 110.0)
/// // Result: 0.10 (10% growth)
/// ```
///
/// **Negative Growth:**
/// ```swift
/// let decline = growthRate(from: 100.0, to: 80.0)
/// // Result: -0.20 (-20% decline)
/// ```
///
/// **No Change:**
/// ```swift
/// let noGrowth = growthRate(from: 100.0, to: 100.0)
/// // Result: 0.0 (0% growth)
/// ```
///
/// ## Use Cases
/// - Calculating period-over-period growth
/// - Revenue or profit margin changes
/// - Price appreciation/depreciation
/// - Performance metrics
///
/// ## Important Notes
/// - Returns infinity if `from` is zero
/// - Use `cagr()` for multi-period annualized growth rates
public func growthRate<T: Real>(from: T, to: T) -> T {
	guard from != T.zero else {
		return T.infinity
	}

	return (to - from) / from
}

/// Calculates the Compound Annual Growth Rate (CAGR).
///
/// CAGR represents the annual growth rate over a period of time, assuming the growth
/// compounds annually. It smooths out volatility to provide a constant rate that would
/// produce the same final value.
///
/// **Formula:**
/// ```
/// CAGR = (Ending Value / Beginning Value)^(1 / Years) - 1
/// ```
///
/// - Parameters:
///   - beginningValue: The initial value at the start of the period.
///   - endingValue: The final value at the end of the period.
///   - years: The number of years between beginning and ending values.
/// - Returns: The annualized growth rate as a decimal.
///
/// ## Examples
///
/// **Investment Growth:**
/// ```swift
/// // Investment grows from $10,000 to $15,000 over 5 years
/// let cagr = cagr(beginningValue: 10_000.0, endingValue: 15_000.0, years: 5.0)
/// // Result: ~0.0845 (8.45% annual growth)
/// ```
///
/// **Revenue Growth:**
/// ```swift
/// // Revenue from $1M to $2M over 3 years
/// let growth = cagr(beginningValue: 1_000_000.0, endingValue: 2_000_000.0, years: 3.0)
/// // Result: ~0.2599 (25.99% annual growth)
/// ```
///
/// **Population Decline:**
/// ```swift
/// // Population from 100,000 to 90,000 over 10 years
/// let decline = cagr(beginningValue: 100_000.0, endingValue: 90_000.0, years: 10.0)
/// // Result: ~-0.0105 (-1.05% annual decline)
/// ```
///
/// ## Use Cases
/// - Investment performance measurement
/// - Business growth analysis
/// - Market size projections
/// - Economic indicators
/// - Demographic trends
///
/// ## Advantages Over Simple Average
/// - Accounts for compounding effects
/// - Single metric for multi-year performance
/// - Comparable across different time periods
/// - Industry standard for reporting returns
///
/// ## Important Notes
/// - Returns 0 if ending value equals beginning value
/// - Returns NaN or infinity if years is zero
/// - Negative CAGR indicates decline
/// - Can be applied to any metric (revenue, users, etc.)
public func cagr<T: Real>(beginningValue: T, endingValue: T, years: T) -> T {
	guard years != T.zero else {
		return T.infinity
	}

	guard beginningValue != T.zero else {
		return T.infinity
	}

	if endingValue == beginningValue {
		return T.zero
	}

	let ratio = endingValue / beginningValue
	let exponent = T(1) / years
	return T.pow(ratio, exponent) - T(1)
}

/// Applies a growth rate over multiple periods to generate a projection series.
///
/// This function projects how a value grows over time given a growth rate and
/// compounding frequency. It returns an array with the base value plus all projected
/// future values.
///
/// **Formulas:**
///
/// For **discrete compounding** (annual, monthly, etc.):
/// ```
/// Value = Base × (1 + r/n)^(n×t)
/// ```
///
/// For **continuous compounding**:
/// ```
/// Value = Base × e^(r×t)
/// ```
///
/// Where:
/// - r = annual growth rate
/// - n = compounding periods per year
/// - t = time in years
///
/// - Parameters:
///   - baseValue: The starting value at time 0.
///   - rate: The annual growth rate as a decimal (e.g., 0.08 for 8%).
///   - periods: The number of periods to project.
///   - compounding: The compounding frequency (default: annual).
/// - Returns: Array of values starting with base value, followed by projected values.
///
/// ## Examples
///
/// **Annual Compounding:**
/// ```swift
/// let projection = applyGrowth(baseValue: 1000.0, rate: 0.10, periods: 3, compounding: .annual)
/// // Result: [1000, 1100, 1210, 1331]
/// ```
///
/// **Monthly Compounding:**
/// ```swift
/// // Project 12 months at 12% annual rate
/// let monthly = applyGrowth(baseValue: 1000.0, rate: 0.12, periods: 12, compounding: .monthly)
/// // Monthly rate = 0.12/12 = 0.01
/// // Result: [1000, 1010, 1020.1, ..., 1126.83]
/// ```
///
/// **Continuous Compounding:**
/// ```swift
/// let continuous = applyGrowth(baseValue: 1000.0, rate: 0.05, periods: 10, compounding: .continuous)
/// // Result: Values following exponential curve e^(0.05t)
/// ```
///
/// ## Use Cases
///
/// **Revenue Projections:**
/// ```swift
/// let currentRevenue = 1_000_000.0
/// let growthRate = 0.15  // 15% annual growth
/// let projection = applyGrowth(baseValue: currentRevenue, rate: growthRate, periods: 5, compounding: .annual)
/// // 5-year revenue forecast
/// ```
///
/// **Investment Growth:**
/// ```swift
/// let principal = 10_000.0
/// let annualReturn = 0.07
/// let growth = applyGrowth(baseValue: principal, rate: annualReturn, periods: 10, compounding: .annual)
/// // See how investment grows over 10 years
/// ```
///
/// **Inflation Adjustment:**
/// ```swift
/// let currentCost = 100.0
/// let inflation = 0.03
/// let futureCosts = applyGrowth(baseValue: currentCost, rate: inflation, periods: 20, compounding: .annual)
/// // Future purchasing power
/// ```
///
/// ## Compounding Frequency Impact
///
/// Higher compounding frequency leads to higher final values:
/// - Annual: Simplest, compounds once per year
/// - Quarterly: Common for investments
/// - Monthly: Used for loans and savings
/// - Daily: Bank accounts
/// - Continuous: Theoretical maximum, uses natural exponential
///
/// ## Important Notes
/// - Returns array of length `periods + 1` (includes base value)
/// - Negative rates produce declining values
/// - Zero periods returns array with only base value
/// - Continuous compounding uses Euler's number (e)
public func applyGrowth<T: Real>(
	baseValue: T,
	rate: T,
	periods: Int,
	compounding: CompoundingFrequency = .annual
) -> [T] {
	var values: [T] = [baseValue]

	guard periods > 0 else {
		return values
	}

	if compounding == .continuous {
		// Continuous compounding: A = P * e^(rt)
		// Use e ≈ 2.718281828459045
		let e = T.exp(1)  // Precise approximation of e

		for period in 1...periods {
			let t = T(period)
			let exponent = rate * t
			let eToX = T.pow(e, exponent)
			let value = baseValue * eToX
			values.append(value)
		}
	} else {
		// Discrete compounding: A = P * (1 + r/n)^(nt)
		let periodsPerYear = T(compounding.periodsPerYear)
		let periodRate = rate / periodsPerYear
		let onePlusPeriodRate = T(1) + periodRate

		for period in 1...periods {
			let value = baseValue * T.pow(onePlusPeriodRate, T(period))
			values.append(value)
		}
	}

	return values
}

//
//  NPV.swift
//  BusinessMath
//
//  Created by Justin Purnell on 5/24/23.
//  Refined by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - Net Present Value (NPV) Functions

/// Calculates the Net Present Value (NPV) for a series of cash flows.
///
/// NPV is the sum of the present values of all cash flows, both positive and negative,
/// discounted at a specified rate. It's used to evaluate the profitability of an investment
/// or project.
///
/// **Formula:**
/// ```
/// NPV = Σ(CF_t / (1+r)^t)
/// ```
///
/// Where:
/// - CF_t = Cash flow at period t
/// - r = Discount rate (per period)
/// - t = Time period (0, 1, 2, ...)
///
/// - Parameters:
///   - r: The discount rate per period (e.g., 0.10 for 10%).
///   - c: Array of cash flows where index represents the period.
///     First element (period 0) is typically the initial investment (negative).
/// - Returns: The net present value.
///
/// ## Examples
///
/// **Simple Investment:**
/// ```swift
/// let cashFlows = [-1000.0, 600.0, 600.0]
/// let npv = npv(discountRate: 0.10, cashFlows: cashFlows)
/// // Result: ~41.32
/// // Interpretation: Project adds $41.32 in value at 10% discount rate
/// ```
///
/// **Multi-Year Project:**
/// ```swift
/// let cashFlows = [-10000.0, 3000.0, 4200.0, 6800.0]
/// let npv = npv(discountRate: 0.10, cashFlows: cashFlows)
/// // Result: ~1188.44
/// ```
///
/// ## Decision Rules
/// - **NPV > 0:** Accept project (adds value)
/// - **NPV < 0:** Reject project (destroys value)
/// - **NPV = 0:** Indifferent (break-even)
///
/// ## Use Cases
/// - Capital budgeting decisions
/// - Investment analysis
/// - Project evaluation
/// - Comparing mutually exclusive projects
///
/// ## Excel Compatibility
///
/// **Important:** This function differs from Excel's `NPV()` function.
///
/// - **This function:** First cash flow is at time 0 (today, undiscounted)
///   - `npv(rate: 0.10, cashFlows: [-1000, 400, 400, 400])`
///   - Calculates: `-1000 + 400/1.1 + 400/1.1² + 400/1.1³`
///
/// - **Excel's NPV:** All cash flows are end-of-period (all discounted)
///   - `=NPV(0.10, 400, 400, 400) + (-1000)`
///   - Calculates: `400/1.1 + 400/1.1² + 400/1.1³ + (-1000)`
///
/// For Excel-compatible NPV, use `npvExcel(rate:cashFlows:)` instead.
///
/// ## Important Notes
/// - Cash flows should be in consistent time periods (all annual, all monthly, etc.)
/// - Discount rate must match the cash flow period
/// - First cash flow (t=0) is not discounted
/// - More reliable than IRR for comparing projects
/// - Consistent with finance textbooks and IRR calculations
public func npv<T: Real>(discountRate r: T, cashFlows c: [T]) -> T {
	var presentValue = T.zero
	for (period, flow) in c.enumerated() {
		let discountFactor = T.pow(T(1) + r, T(period))
		presentValue = presentValue + flow / discountFactor
	}

	return presentValue
}

/// Calculates the Net Present Value (NPV) with input validation.
///
/// This is a validated wrapper around ``npv(discountRate:cashFlows:)`` that throws errors
/// for invalid inputs instead of returning incorrect results.
///
/// - Parameters:
///   - r: Discount rate (must be ≥ 0)
///   - c: Array of cash flows over time (must not be empty)
/// - Returns: Net present value of the cash flows
/// - Throws: ``BusinessMathError`` if discount rate is negative or cash flows array is empty
public func calculateNPV<T: Real>(discountRate r: T, cashFlows c: [T]) throws -> T {
	guard r >= 0 else {
		throw BusinessMathError.invalidInput(message: "Invalid input parameter - discountRate must be non-negative.", value: "\(r)", expectedRange: "≥ 0.0")
	}
	guard !c.isEmpty else {
		throw BusinessMathError.insufficientData(required: 1, actual: 0, context: "At least one cash flow value is needed to calculate NPV. 0 cash flow values provided. ,npv(\(r), \(c))")
	}
	return npv(discountRate: r, cashFlows: c)
}

/// Calculates the derivative of NPV with respect to the discount rate.
///
/// This is used in the Newton-Raphson method:
/// ```
/// dNPV/dr = -Σ(t × CF_t / (1+r)^(t+1))
/// ```
public func calculateNPVDerivative<T: Real>(discountRate: T, cashFlows: [T]) -> T {
	var derivative = T.zero

	for (period, cashFlow) in cashFlows.enumerated() {
		if period > 0 {  // Skip period 0 (derivative term is 0)
			let numerator = T(period) * cashFlow
			let denominator = T.pow(T(1) + discountRate, T(period + 1))
			derivative = derivative - numerator / denominator
		}
	}
	return derivative
}


/// Calculates the Net Present Value (NPV) for a TimeSeries.
///
/// This variant accepts a `TimeSeries` object and calculates NPV from its values.
/// The periods are treated sequentially (0, 1, 2, ...) regardless of their actual
/// period types.
///
/// - Parameters:
///   - rate: The discount rate per period.
///   - timeSeries: TimeSeries containing the cash flows.
/// - Returns: The net present value.
///
/// ## Example
///
/// ```swift
/// let periods = [
///     Period(year: 2025, quarter: 1),
///     Period(year: 2025, quarter: 2),
///     Period(year: 2025, quarter: 3),
///     Period(year: 2025, quarter: 4)
/// ]
/// let cashFlows = [-10000.0, 3000.0, 4000.0, 5000.0]
/// let ts = TimeSeries(periods: periods, values: cashFlows, metadata: ...)
///
/// let quarterlyRate = 0.10 / 4.0  // Convert annual to quarterly
/// let npv = npv(rate: quarterlyRate, timeSeries: ts)
/// ```
public func npv<T: Real>(rate: T, timeSeries: TimeSeries<T>) -> T {
	return npv(discountRate: rate, cashFlows: timeSeries.valuesArray)
}

/// Calculates the Net Present Value (NPV) using Excel's methodology.
///
/// This function replicates Excel's `NPV()` function behavior, where **all** cash flows
/// are treated as occurring at the end of periods and are discounted by at least one period.
///
/// **Formula:**
/// ```
/// NPV_Excel = Σ(CF_t / (1+r)^(t+1))  for t = 0, 1, 2, ...
/// ```
///
/// Or equivalently:
/// ```
/// NPV_Excel = CF₀/(1+r) + CF₁/(1+r)² + CF₂/(1+r)³ + ...
/// ```
///
/// - Parameters:
///   - rate: The discount rate per period (e.g., 0.10 for 10%).
///   - cashFlows: Array of cash flows. Unlike standard NPV, the first element
///     is **also discounted** by one period.
/// - Returns: The Excel-compatible net present value.
///
/// ## Examples
///
/// **Matching Excel's NPV Function:**
/// ```swift
/// // Excel: =NPV(0.10, 400, 400, 400)
/// let cashFlows = [400.0, 400.0, 400.0]
/// let npv = npvExcel(rate: 0.10, cashFlows: cashFlows)
/// // Result: ~994.74
///
/// // To include initial investment (typical use):
/// let totalNPV = npvExcel(rate: 0.10, cashFlows: [400, 400, 400]) + (-1000)
/// // This matches: =NPV(0.10, 400, 400, 400) + (-1000)
/// ```
///
/// **Full Project Analysis:**
/// ```swift
/// // Method 1: Separate initial investment
/// let futureCashFlows = [3000.0, 4200.0, 6800.0]
/// let initialInvestment = -10000.0
/// let projectNPV = npvExcel(rate: 0.10, cashFlows: futureCashFlows) + initialInvestment
///
/// // Method 2: Include all cash flows (but note first is still discounted)
/// let allCashFlows = [-10000.0, 3000.0, 4200.0, 6800.0]
/// let npv = npvExcel(rate: 0.10, cashFlows: allCashFlows)
/// // Different result than Method 1 because initial investment is discounted!
/// ```
///
/// ## Difference from Standard NPV
///
/// | Function | First Cash Flow Treatment | Formula |
/// |----------|--------------------------|---------|
/// | `npv()` | Not discounted (t=0, today) | `CF₀ + CF₁/(1+r) + CF₂/(1+r)² + ...` |
/// | `npvExcel()` | Discounted (end of period 1) | `CF₀/(1+r) + CF₁/(1+r)² + CF₂/(1+r)³ + ...` |
///
/// ## When to Use
///
/// Use `npvExcel()` when:
/// - Matching Excel spreadsheets exactly
/// - All cash flows occur at period ends (no initial investment at t=0)
/// - Converting existing Excel-based financial models
///
/// Use standard `npv()` when:
/// - Following finance textbook definitions
/// - Initial investment occurs today (t=0)
/// - Consistency with IRR calculations is needed
/// - Working with financial calculators or academic literature
///
/// ## Important Notes
/// - This function is provided for Excel compatibility
/// - Most finance theory uses standard NPV (where t=0 is undiscounted)
/// - If you have an initial investment at t=0, **do not** include it in the cashFlows
///   array; add it separately after calling this function
public func npvExcel<T: Real>(rate: T, cashFlows: [T]) -> T {
	var presentValue = T.zero

	for (index, flow) in cashFlows.enumerated() {
		// Excel discounts all cash flows by at least one period
		// So period 0 becomes (1+r)^1, period 1 becomes (1+r)^2, etc.
		let period = index + 1
		let discountFactor = T.pow(T(1) + rate, T(period))
		presentValue = presentValue + flow / discountFactor
	}

	return presentValue
}

// MARK: - Profitability Index (PI)

/// Calculates the Profitability Index (PI) for a series of cash flows.
///
/// PI measures the value created per unit of investment. It's the ratio of the present
/// value of future cash flows to the present value of investments.
///
/// **Formula:**
/// ```
/// PI = PV(positive flows) / |PV(negative flows)|
/// ```
///
/// - Parameters:
///   - rate: The discount rate per period.
///   - cashFlows: Array of cash flows (negative for investments, positive for returns).
/// - Returns: The profitability index.
///
/// ## Examples
///
/// **Positive NPV Project:**
/// ```swift
/// let cashFlows = [-1000.0, 600.0, 600.0]
/// let pi = profitabilityIndex(rate: 0.10, cashFlows: cashFlows)
/// // Result: ~1.041
/// // Interpretation: $1.04 of value per $1 invested
/// ```
///
/// **Negative NPV Project:**
/// ```swift
/// let cashFlows = [-1000.0, 400.0, 400.0]
/// let pi = profitabilityIndex(rate: 0.10, cashFlows: cashFlows)
/// // Result: ~0.694
/// // Interpretation: Only $0.69 returned per $1 invested
/// ```
///
/// ## Decision Rules
/// - **PI > 1:** Accept project (positive NPV)
/// - **PI < 1:** Reject project (negative NPV)
/// - **PI = 1:** Break-even (NPV = 0)
///
/// ## Advantages Over NPV
/// - Useful for ranking projects when capital is limited
/// - Shows efficiency of capital use
/// - Better for comparing projects of different sizes
///
/// ## Use Cases
/// - Capital rationing decisions
/// - Ranking multiple projects
/// - Efficiency comparison between investments
public func profitabilityIndex<T: Real>(rate: T, cashFlows: [T]) -> T {
	var pvPositive = T.zero
	var pvNegative = T.zero

	for (period, flow) in cashFlows.enumerated() {
		let discountFactor = T.pow(T(1) + rate, T(period))
		let presentValue = flow / discountFactor

		if flow > T.zero {
			pvPositive = pvPositive + presentValue
		} else if flow < T.zero {
			pvNegative = pvNegative + presentValue
		}
	}

	// PI = PV of inflows / |PV of outflows|
	guard pvNegative < T.zero else {
		// No investments, return infinity or very large number
		return T(1000000)
	}

	return pvPositive / (-pvNegative)
}

// MARK: - Payback Period Functions

/// Calculates the payback period for a series of cash flows (undiscounted).
///
/// The payback period is the number of periods required for cumulative cash flows
/// to become positive (i.e., recover the initial investment).
///
/// - Parameter cashFlows: Array of cash flows. First element is typically negative (investment).
/// - Returns: The period number when cumulative cash flow becomes positive, or `nil` if
///   payback is never achieved.
///
/// ## Examples
///
/// **Simple Payback:**
/// ```swift
/// let cashFlows = [-1000.0, 400.0, 400.0, 400.0]
/// let payback = paybackPeriod(cashFlows: cashFlows)
/// // Result: 3 (payback in year 3)
/// ```
///
/// **Early Payback:**
/// ```swift
/// let cashFlows = [-1000.0, 1500.0]
/// let payback = paybackPeriod(cashFlows: cashFlows)
/// // Result: 1 (payback in year 1)
/// ```
///
/// **No Payback:**
/// ```swift
/// let cashFlows = [-1000.0, 100.0, 100.0, 100.0]
/// let payback = paybackPeriod(cashFlows: cashFlows)
/// // Result: nil (never recovers investment)
/// ```
///
/// ## Decision Rules
/// - Shorter payback period is better (less risk)
/// - Set maximum acceptable payback period threshold
/// - Projects exceeding threshold are rejected
///
/// ## Limitations
/// - Ignores time value of money
/// - Ignores cash flows after payback
/// - Doesn't measure profitability
/// - Use `discountedPaybackPeriod` for more accurate analysis
///
/// ## Use Cases
/// - Quick risk assessment
/// - Liquidity-constrained decisions
/// - High-risk or uncertain environments
/// - Preliminary project screening
public func paybackPeriod<T: Real>(cashFlows: [T]) -> Int? {
	var cumulativeCashFlow = T.zero

	for (period, flow) in cashFlows.enumerated() {
		cumulativeCashFlow = cumulativeCashFlow + flow

		// Check if we've recovered the investment
		if cumulativeCashFlow >= T.zero && period > 0 {
			return period
		}
	}

	// Never achieved positive cumulative cash flow
	return nil
}

/// Calculates the discounted payback period for a series of cash flows.
///
/// Similar to regular payback period, but accounts for the time value of money
/// by discounting cash flows before calculating cumulative total.
///
/// - Parameters:
///   - rate: The discount rate per period.
///   - cashFlows: Array of cash flows. First element is typically negative (investment).
/// - Returns: The period number when cumulative discounted cash flow becomes positive,
///   or `nil` if discounted payback is never achieved.
///
/// ## Examples
///
/// **Discounted vs Regular Payback:**
/// ```swift
/// let cashFlows = [-1000.0, 500.0, 500.0, 500.0]
///
/// let regularPayback = paybackPeriod(cashFlows: cashFlows)
/// // Result: 2 (simple payback)
///
/// let discountedPayback = discountedPaybackPeriod(rate: 0.10, cashFlows: cashFlows)
/// // Result: 3 (discounted payback takes longer)
/// ```
///
/// **High Discount Rate Impact:**
/// ```swift
/// let cashFlows = [-1000.0, 400.0, 400.0, 400.0, 400.0]
/// let payback = discountedPaybackPeriod(rate: 0.15, cashFlows: cashFlows)
/// // Higher rates increase payback period
/// ```
///
/// ## Decision Rules
/// - Shorter discounted payback is better
/// - More conservative than regular payback
/// - Better accounts for opportunity cost
///
/// ## Advantages Over Regular Payback
/// - Considers time value of money
/// - More accurate risk assessment
/// - Better aligns with NPV/IRR methods
///
/// ## Limitations
/// - Still ignores cash flows after payback
/// - Doesn't measure overall profitability
/// - Use NPV or PI for profitability analysis
///
/// ## Use Cases
/// - Capital budgeting with time value consideration
/// - Risk-adjusted project evaluation
/// - Comparing investments with different timing
public func discountedPaybackPeriod<T: Real>(rate: T, cashFlows: [T]) -> Int? {
	var cumulativePV = T.zero

	for (period, flow) in cashFlows.enumerated() {
		let discountFactor = T.pow(T(1) + rate, T(period))
		let presentValue = flow / discountFactor
		cumulativePV = cumulativePV + presentValue

		// Check if we've recovered the investment (in present value terms)
		if cumulativePV >= T.zero && period > 0 {
			return period
		}
	}

	// Never achieved positive cumulative present value
	return nil
}

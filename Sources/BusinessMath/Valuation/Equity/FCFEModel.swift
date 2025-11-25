//
//  FCFEModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-24.
//

import Foundation
import Numerics

// MARK: - FCFE Model

/// Free Cash Flow to Equity (FCFE) Model for equity valuation.
///
/// The FCFE Model values equity by discounting the cash flows available to equity holders
/// after accounting for operating expenses, capital expenditures, and debt financing activities.
/// This is the most comprehensive equity valuation approach as it directly models the cash
/// available to shareholders.
///
/// ## Overview
///
/// FCFE represents the cash flow available to equity shareholders after:
/// - Operating expenses
/// - Capital expenditures
/// - Debt principal repayments
/// - Plus: New debt issuance
///
/// ## Formula
///
/// ```
/// FCFE = Operating Cash Flow - Capital Expenditures + Net Borrowing
/// Equity Value = Σ PV(FCFE) + PV(Terminal Value)
/// ```
///
/// Where:
/// - Operating Cash Flow = Cash from operations
/// - Capital Expenditures = Investments in assets
/// - Net Borrowing = New Debt - Debt Repayment
/// - Terminal Value = Final FCFE × (1 + g) / (r - g)
///
/// ## When to Use
///
/// The FCFE Model is appropriate for:
/// - Companies with stable or predictable capital structures
/// - Firms where debt policy affects equity value
/// - Valuing companies with changing leverage
/// - Comparing companies with different debt levels
///
/// ## Advantages Over DDM
///
/// - Does not require dividend assumptions
/// - Captures debt financing effects
/// - More comprehensive than dividend-based models
/// - Better for companies that don't pay dividends
///
/// ## Usage Example
///
/// ```swift
/// // Project 5 years of cash flows
/// let periods = (2024...2028).map { Period.year($0) }
///
/// let operatingCF = TimeSeries(
///     periods: periods,
///     values: [500.0, 575.0, 661.0, 760.0, 874.0]
/// )
///
/// let capEx = TimeSeries(
///     periods: periods,
///     values: [100.0, 115.0, 132.0, 152.0, 175.0]
/// )
///
/// let model = FCFEModel(
///     operatingCashFlow: operatingCF,
///     capitalExpenditures: capEx,
///     netBorrowing: nil,  // No debt changes
///     costOfEquity: 0.12,
///     terminalGrowthRate: 0.04
/// )
///
/// let equityValue = model.equityValue()
/// let sharePrice = model.valuePerShare(sharesOutstanding: 100.0)
/// ```
///
/// ## Important Notes
///
/// - Terminal growth rate must be less than cost of equity (g < r)
/// - Operating cash flow should be actual cash, not accounting earnings
/// - Net borrowing can be negative (debt repayment) or positive (new debt)
/// - Model is sensitive to terminal growth rate assumptions
///
/// - SeeAlso:
///   - ``GordonGrowthModel`` for dividend-based valuation
///   - ``EnterpriseValueBridge`` for converting from FCFF to equity value
///   - ``ResidualIncomeModel`` for alternative equity valuation approach
public struct FCFEModel<T: Real> where T: Sendable {

    /// Operating cash flow for each projection period
    public let operatingCashFlow: TimeSeries<T>

    /// Capital expenditures (investments in assets) for each period
    public let capitalExpenditures: TimeSeries<T>

    /// Net borrowing (new debt - repayments) for each period
    /// - Note: Positive values represent new debt issuance, negative values represent net repayment
    public let netBorrowing: TimeSeries<T>?

    /// Cost of equity / required return on equity (as decimal, e.g., 0.12 for 12%)
    public let costOfEquity: T

    /// Terminal growth rate for perpetuity calculation (as decimal, e.g., 0.03 for 3%)
    public let terminalGrowthRate: T

    /// Initialize a Free Cash Flow to Equity Model
    ///
    /// - Parameters:
    ///   - operatingCashFlow: Time series of operating cash flows
    ///   - capitalExpenditures: Time series of capital expenditures
    ///   - netBorrowing: Optional time series of net borrowing (new debt - repayments)
    ///   - costOfEquity: Required return on equity (as decimal)
    ///   - terminalGrowthRate: Perpetual growth rate (as decimal, must be < costOfEquity)
    ///
    /// - Precondition: `operatingCashFlow` and `capitalExpenditures` must have the same periods
    /// - Precondition: If provided, `netBorrowing` must have the same periods as cash flows
    /// - Precondition: `terminalGrowthRate` must be less than `costOfEquity`
    public init(
        operatingCashFlow: TimeSeries<T>,
        capitalExpenditures: TimeSeries<T>,
        netBorrowing: TimeSeries<T>?,
        costOfEquity: T,
        terminalGrowthRate: T
    ) {
        self.operatingCashFlow = operatingCashFlow
        self.capitalExpenditures = capitalExpenditures
        self.netBorrowing = netBorrowing
        self.costOfEquity = costOfEquity
        self.terminalGrowthRate = terminalGrowthRate
    }

    /// Calculate Free Cash Flow to Equity for each period
    ///
    /// Formula: `FCFE = Operating CF - CapEx + Net Borrowing`
    ///
    /// - Returns: Time series of FCFE values for each projection period
    ///
    /// ## Interpretation
    ///
    /// - **Positive FCFE**: Cash available for distribution to equity holders
    /// - **Negative FCFE**: Company requires additional equity financing
    ///
    /// ## Example
    ///
    /// ```swift
    /// let fcfe = model.fcfe()
    /// for (period, value) in zip(fcfe.periods, fcfe.values) {
    ///     print("\(period): $\(value)M")
    /// }
    /// ```
    ///
    /// - Complexity: O(n) where n is the number of periods
    public func fcfe() -> TimeSeries<T> {
        // Calculate FCFE = Operating CF - CapEx + Net Borrowing
        var fcfeValues: [T] = []

        let opCFArray = operatingCashFlow.valuesArray
        let capexArray = capitalExpenditures.valuesArray
        let borrowingArray = netBorrowing?.valuesArray

        for i in 0..<opCFArray.count {
            let opCF = opCFArray[i]
            let capex = capexArray[i]
            let borrowing = borrowingArray?[i] ?? T(0)

            let fcfe = opCF - capex + borrowing
            fcfeValues.append(fcfe)
        }

        return TimeSeries(
            periods: operatingCashFlow.periods,
            values: fcfeValues
        )
    }

    /// Calculate the total equity value (present value of all FCFE plus terminal value)
    ///
    /// Calculates the sum of:
    /// 1. Present value of projected FCFE for each explicit forecast period
    /// 2. Present value of terminal value (perpetuity growth model)
    ///
    /// ## Formula
    ///
    /// ```
    /// Equity Value = Σ(FCFE_t / (1 + r)^t) + Terminal Value / (1 + r)^n
    /// Terminal Value = FCFE_n × (1 + g) / (r - g)
    /// ```
    ///
    /// Where:
    /// - FCFE_t = Free cash flow to equity in period t
    /// - r = Cost of equity
    /// - g = Terminal growth rate
    /// - n = Number of projection periods
    ///
    /// - Returns: Total equity value in the same units as FCFE (e.g., millions of dollars)
    ///
    /// ## Important Notes
    ///
    /// - Returns `NaN` if `terminalGrowthRate >= costOfEquity` (invalid model)
    /// - Terminal value typically represents 60-80% of total value
    /// - Highly sensitive to terminal growth rate assumption
    ///
    /// ## Example
    ///
    /// ```swift
    /// let equityValue = model.equityValue()
    /// print("Total equity value: $\(equityValue)M")
    /// ```
    ///
    /// - Complexity: O(n) where n is the number of projection periods
    public func equityValue() -> T {
        let fcfeTimeSeries = fcfe()
        let fcfeArray = fcfeTimeSeries.valuesArray
        var presentValue = T(0)

        // Phase 1: Present value of explicit forecast period FCFE
        for (index, fcfeValue) in fcfeArray.enumerated() {
            let period = index + 1
            let discountFactor = T.pow(T(1) + costOfEquity, T(period))
            presentValue += fcfeValue / discountFactor
        }

        // Phase 2: Terminal value (perpetuity growth model)
        guard !fcfeArray.isEmpty else {
            return T(0)
        }

        let finalFCFE = fcfeArray[fcfeArray.count - 1]
        let terminalFCFE = finalFCFE * (T(1) + terminalGrowthRate)
        let denominator = costOfEquity - terminalGrowthRate

        // Guard against invalid terminal growth rate
        guard denominator > T(0) else {
            return T.nan
        }

        let terminalValue = terminalFCFE / denominator

        // Discount terminal value to present
        let numberOfPeriods = fcfeArray.count
        let terminalDiscountFactor = T.pow(T(1) + costOfEquity, T(numberOfPeriods))
        let pvTerminal = terminalValue / terminalDiscountFactor

        return presentValue + pvTerminal
    }

    /// Calculate value per share
    ///
    /// Divides total equity value by number of shares outstanding to determine
    /// intrinsic value per share.
    ///
    /// - Parameter sharesOutstanding: Number of shares outstanding (in millions if equity value is in millions)
    ///
    /// - Returns: Intrinsic value per share
    ///
    /// ## Example
    ///
    /// ```swift
    /// // If equity value is $5,000M and 100M shares outstanding
    /// let sharePrice = model.valuePerShare(sharesOutstanding: 100.0)
    /// // Returns: $50 per share
    /// ```
    ///
    /// ## Important Notes
    ///
    /// - Ensure units are consistent (e.g., equity value in millions, shares in millions)
    /// - Use fully diluted shares for conservative valuation
    /// - Consider employee stock options and convertible securities
    ///
    /// ## Comparison to Market Price
    ///
    /// - If intrinsic value > market price: Potentially undervalued
    /// - If intrinsic value < market price: Potentially overvalued
    /// - Market price reflects expectations; intrinsic value reflects fundamentals
    ///
    /// - Complexity: O(1) after equity value calculation
    public func valuePerShare(sharesOutstanding: T) -> T {
        let totalEquityValue = equityValue()
        return totalEquityValue / sharesOutstanding
    }
}

// MARK: - TODO: Convenience Initializers
// Future enhancement: Add initializer from CashFlowStatement
// Requires aggregation of accounts into time series

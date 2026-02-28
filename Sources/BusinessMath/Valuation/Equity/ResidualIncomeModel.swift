//
//  ResidualIncomeModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-25.
//

import Foundation
import Numerics

// MARK: - Residual Income Model

/// Residual Income (RI) Model for equity valuation
///
/// The Residual Income Model values equity by starting with book value and adding
/// the present value of expected future residual income (also called economic profit
/// or abnormal earnings). This approach explicitly links accounting data to market value.
///
/// ## Overview
///
/// Residual income represents earnings above the cost of equity capital. It measures
/// whether a company creates or destroys value from an accounting perspective.
///
/// ## Formulas
///
/// ```
/// Residual Income = Net Income - Equity Charge
/// Equity Charge = Cost of Equity × Beginning Book Value
///
/// Equity Value = Current Book Value + Σ PV(Residual Income) + PV(Terminal Value)
/// Terminal Value = Final RI × (1 + g) / (r - g)
/// ```
///
/// Where:
/// - Net Income = Accounting earnings available to common shareholders
/// - Book Value = Shareholders' equity (assets - liabilities)
/// - Cost of Equity = Required return on equity
/// - g = Terminal growth rate
/// - r = Cost of equity
///
/// ## Key Concepts
///
/// ### Residual Income (Economic Profit)
/// - **Positive RI**: Company earns above its cost of capital (value creation)
/// - **Zero RI**: Company earns exactly its cost of capital (value = book value)
/// - **Negative RI**: Company earns below its cost of capital (value destruction)
///
/// ### ROE Spread
/// The difference between ROE and cost of equity determines residual income:
/// - ROE > Cost of Equity → Positive RI → Premium to book value
/// - ROE = Cost of Equity → Zero RI → Value equals book value
/// - ROE < Cost of Equity → Negative RI → Discount to book value
///
/// ## When to Use
///
/// The RI Model is particularly appropriate for:
/// - Financial institutions (banks, insurance companies)
/// - Companies where book value is meaningful
/// - Firms with negative free cash flows but positive earnings
/// - Comparing companies across different accounting regimes
/// - Understanding the "value premium" or "value destruction" relative to book
///
/// ## Advantages
///
/// 1. **Accounting-Based**: Uses readily available financial statement data
/// 2. **Book Value Anchor**: Provides a concrete starting point for valuation
/// 3. **Terminal Value**: Less sensitive to terminal value than DCF models
/// 4. **Clean Surplus**: Works well under clean surplus accounting
/// 5. **Economic Profit**: Explicitly shows value creation/destruction
///
/// ## Disadvantages
///
/// 1. **Accounting Quality**: Dependent on accounting standards and choices
/// 2. **Clean Surplus Violation**: Requires adjustments for non-owner equity changes
/// 3. **Book Value Relevance**: Less useful when book value is distorted
/// 4. **ROE Persistence**: Assumes some persistence in ROE spread
///
/// ## Usage Example
///
/// ```swift
/// // Project 5 years of earnings and book value
/// let periods = (2024...2028).map { Period.year($0) }
///
/// let netIncome = TimeSeries(
///     periods: periods,
///     values: [120.0, 132.0, 145.0, 160.0, 176.0]
/// )
///
/// let bookValue = TimeSeries(
///     periods: periods,
///     values: [1000.0, 1100.0, 1210.0, 1331.0, 1464.0]
/// )
///
/// let model = ResidualIncomeModel(
///     currentBookValue: 1000.0,
///     netIncome: netIncome,
///     bookValue: bookValue,
///     costOfEquity: 0.10,
///     terminalGrowthRate: 0.03
/// )
///
/// // Calculate residual income for each period
/// let ri = model.residualIncome()
/// for (period, value) in zip(ri.periods, ri.valuesArray) {
///     print("\(period): RI = $\(value)M")
/// }
///
/// // Calculate total equity value
/// let equityValue = model.equityValue()
/// let sharePrice = model.valuePerShare(sharesOutstanding: 100.0)
///
/// print("Book Value: $1,000M")
/// print("Equity Value: $\(equityValue)M")
/// print("Premium to Book: \((equityValue/1000.0 - 1.0) * 100)%")
/// ```
///
/// ## Important Notes
///
/// - Requires clean surplus accounting (NI - Dividends = Change in Book Value)
/// - Adjustments may be needed for goodwill, intangibles, off-balance sheet items
/// - Terminal growth rate must be less than cost of equity
/// - Book value should be adjusted to reflect economic (not accounting) reality
/// - Works best for firms with stable accounting policies
///
/// ## Clean Surplus Relation
///
/// The model assumes:
/// ```
/// Book Value_t = Book Value_(t-1) + Net Income_t - Dividends_t
/// ```
///
/// Violations include:
/// - Foreign currency translation adjustments
/// - Unrealized gains/losses on securities
/// - Pension adjustments
/// - Other comprehensive income items
///
/// These should be added back to ensure clean surplus holds.
///
/// - SeeAlso:
///   - ``GordonGrowthModel`` for dividend-based equity valuation
///   - ``FCFEModel`` for cash flow-based equity valuation
///   - ``EnterpriseValueBridge`` for converting from enterprise value
public struct ResidualIncomeModel<T: Real> where T: Sendable {

    /// Current book value of equity (starting point for valuation)
    public let currentBookValue: T

    /// Projected net income for each forecast period
    public let netIncome: TimeSeries<T>

    /// Projected book value of equity for each period
    public let bookValue: TimeSeries<T>

    /// Cost of equity / required return (as decimal, e.g., 0.10 for 10%)
    public let costOfEquity: T

    /// Terminal growth rate for residual income (as decimal, must be < costOfEquity)
    public let terminalGrowthRate: T

    /// Initialize a Residual Income Model
    ///
    /// - Parameters:
    ///   - currentBookValue: Current book value of equity
    ///   - netIncome: Time series of projected net income
    ///   - bookValue: Time series of projected book value
    ///   - costOfEquity: Required return on equity (as decimal)
    ///   - terminalGrowthRate: Perpetual growth rate for RI (as decimal, must be < costOfEquity)
    ///
    /// - Precondition: `netIncome` and `bookValue` must have the same periods
    /// - Precondition: `terminalGrowthRate` must be less than `costOfEquity`
    ///
    /// ## Example
    ///
    /// ```swift
    /// let model = ResidualIncomeModel(
    ///     currentBookValue: 1000.0,
    ///     netIncome: netIncomeSeries,
    ///     bookValue: bookValueSeries,
    ///     costOfEquity: 0.10,
    ///     terminalGrowthRate: 0.03
    /// )
    /// ```
    public init(
        currentBookValue: T,
        netIncome: TimeSeries<T>,
        bookValue: TimeSeries<T>,
        costOfEquity: T,
        terminalGrowthRate: T
    ) {
        self.currentBookValue = currentBookValue
        self.netIncome = netIncome
        self.bookValue = bookValue
        self.costOfEquity = costOfEquity
        self.terminalGrowthRate = terminalGrowthRate
    }

    /// Calculate residual income for each projection period
    ///
    /// Residual income (also called economic profit or abnormal earnings) measures
    /// earnings above the cost of equity capital.
    ///
    /// ## Formula
    ///
    /// ```
    /// RI_t = Net Income_t - (Cost of Equity × Book Value_(t-1))
    /// ```
    ///
    /// - Returns: Time series of residual income for each period
    ///
    /// ## Interpretation
    ///
    /// - **Positive RI**: Company earns above its cost of capital (creating value)
    /// - **Zero RI**: Company earns exactly its cost of capital (fair return)
    /// - **Negative RI**: Company earns below its cost of capital (destroying value)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let ri = model.residualIncome()
    /// for (period, value) in zip(ri.periods, ri.valuesArray) {
    ///     if value > 0 {
    ///         print("\(period): Creating $\(value)M in value")
    ///     } else {
    ///         print("\(period): Destroying $\(-value)M in value")
    ///     }
    /// }
    /// ```
    ///
    /// ## ROE Connection
    ///
    /// Residual income can also be expressed as:
    /// ```
    /// RI = (ROE - Cost of Equity) × Book Value
    /// ```
    ///
    /// Where ROE = Net Income / Book Value
    ///
    /// - Complexity: O(n) where n is the number of projection periods
    public func residualIncome() -> TimeSeries<T> {
        var riValues: [T] = []

        let niArray = netIncome.valuesArray
        let bvArray = bookValue.valuesArray

        // Calculate residual income for each period
        // RI_t = NI_t - (Cost of Equity × BV_t)
        // Note: Using beginning-of-period book value for equity charge
        for i in 0..<niArray.count {
            let ni = niArray[i]
            let bv = bvArray[i]
            let equityCharge = costOfEquity * bv
            let ri = ni - equityCharge
            riValues.append(ri)
        }

        return TimeSeries(
            periods: netIncome.periods,
            values: riValues
        )
    }

    /// Calculate total equity value
    ///
    /// The equity value is the sum of:
    /// 1. Current book value (starting anchor)
    /// 2. Present value of projected residual income
    /// 3. Present value of terminal value (perpetuity of RI growth)
    ///
    /// ## Formula
    ///
    /// ```
    /// Equity Value = BV_0 + Σ(RI_t / (1 + r)^t) + Terminal Value / (1 + r)^n
    /// Terminal Value = RI_n × (1 + g) / (r - g)
    /// ```
    ///
    /// Where:
    /// - BV_0 = Current book value
    /// - RI_t = Residual income in period t
    /// - r = Cost of equity
    /// - g = Terminal growth rate
    /// - n = Number of projection periods
    ///
    /// - Returns: Total equity value
    /// - Throws: ``ValuationError/invalidModelAssumptions(_:)`` if `terminalGrowthRate >= costOfEquity`
    ///
    /// ## Important Notes
    ///
    /// - Less sensitive to terminal value than DCF models (due to book value anchor)
    /// - Value > Book means positive NPV projects expected
    /// - Value < Book means value destruction expected
    ///
    /// ## Interpretation
    ///
    /// The difference between equity value and book value represents the present
    /// value of all expected future value creation (or destruction):
    ///
    /// ```
    /// Market Value Added (MVA) = Equity Value - Book Value
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// let equityValue = try model.equityValue()
    /// let bookValue = model.currentBookValue
    /// let mva = equityValue - bookValue
    ///
    /// print("Book Value: $\(bookValue)M")
    /// print("Equity Value: $\(equityValue)M")
    /// print("Market Value Added: $\(mva)M")
    /// print("Premium/Discount: \((mva/bookValue) * 100)%")
    /// ```
    ///
    /// - Complexity: O(n) where n is the number of projection periods
    public func equityValue() throws -> T {
        let riTimeSeries = residualIncome()
        let riArray = riTimeSeries.valuesArray

        // Start with current book value
        var presentValue = currentBookValue

        // Phase 1: Add PV of projected residual income
        for (index, riValue) in riArray.enumerated() {
            let period = index + 1
            let discountFactor = T.pow(T(1) + costOfEquity, T(period))
            presentValue += riValue / discountFactor
        }

        // Phase 2: Add PV of terminal value
        guard !riArray.isEmpty else {
            return currentBookValue
        }

        let finalRI = riArray[riArray.count - 1]
        let terminalRI = finalRI * (T(1) + terminalGrowthRate)
        let denominator = costOfEquity - terminalGrowthRate

        // Guard against invalid terminal growth rate
        guard denominator > T(0) else {
            throw ValuationError.invalidModelAssumptions(
                "Terminal growth rate (\(terminalGrowthRate)) must be less than cost of equity (\(costOfEquity)). " +
                "Residual income model requires g < r for terminal value calculation."
            )
        }

        let terminalValue = terminalRI / denominator

        // Discount terminal value to present
        let numberOfPeriods = riArray.count
        let terminalDiscountFactor = T.pow(T(1) + costOfEquity, T(numberOfPeriods))
        let pvTerminal = terminalValue / terminalDiscountFactor

        return presentValue + pvTerminal
    }

    /// Calculate value per share
    ///
    /// Divides total equity value by shares outstanding to determine
    /// intrinsic value per share.
    ///
    /// - Parameter sharesOutstanding: Number of shares outstanding (in millions if values are in millions)
    ///
    /// - Returns: Intrinsic value per share
    /// - Throws: ``ValuationError/invalidModelAssumptions(_:)`` if terminal growth rate >= cost of equity
    ///
    /// ## Example
    ///
    /// ```swift
    /// // If equity value is $1,714M and 100M shares outstanding
    /// let sharePrice = model.valuePerShare(sharesOutstanding: 100.0)
    /// // Returns: $17.14 per share
    /// ```
    ///
    /// ## Book Value Per Share Comparison
    ///
    /// Compare intrinsic value per share to book value per share:
    /// ```swift
    /// let bookValuePerShare = model.currentBookValue / sharesOutstanding
    /// let intrinsicValuePerShare = try model.valuePerShare(sharesOutstanding: sharesOutstanding)
    /// let priceToBook = intrinsicValuePerShare / bookValuePerShare
    ///
    /// // P/B > 1.0: Market expects value creation
    /// // P/B = 1.0: Market expects fair returns
    /// // P/B < 1.0: Market expects value destruction
    /// ```
    ///
    /// ## Important Notes
    ///
    /// - Ensure units are consistent (e.g., equity value in millions, shares in millions)
    /// - Use fully diluted shares for conservative valuation
    /// - Compare to book value per share to assess valuation
    ///
    /// - Complexity: O(1) after equity value calculation
    public func valuePerShare(sharesOutstanding: T) throws -> T {
        let totalEquityValue = try equityValue()
        return totalEquityValue / sharesOutstanding
    }
}

// MARK: - Convenience Calculations

extension ResidualIncomeModel {

    /// Calculate Return on Equity (ROE) for each projection period
    ///
    /// ROE measures accounting profitability relative to book value.
    ///
    /// ## Formula
    ///
    /// ```
    /// ROE = Net Income / Book Value
    /// ```
    ///
    /// - Returns: Time series of ROE for each period (as decimal, not percentage)
    ///
    /// ## Relationship to Residual Income
    ///
    /// ```
    /// RI = (ROE - Cost of Equity) × Book Value
    /// ```
    ///
    /// - If ROE > Cost of Equity: Positive RI (value creation)
    /// - If ROE = Cost of Equity: Zero RI (fair return)
    /// - If ROE < Cost of Equity: Negative RI (value destruction)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let roe = model.returnOnEquity()
    /// for (period, roeValue) in zip(roe.periods, roe.valuesArray) {
    ///     print("\(period): ROE = \(roeValue * 100)%")
    /// }
    /// ```
    public func returnOnEquity() -> TimeSeries<T> {
        let niArray = netIncome.valuesArray
        let bvArray = bookValue.valuesArray

        var roeValues: [T] = []
        for i in 0..<niArray.count {
            let roe = niArray[i] / bvArray[i]
            roeValues.append(roe)
        }

        return TimeSeries(
            periods: netIncome.periods,
            values: roeValues
        )
    }

    /// Calculate the spread between ROE and cost of equity
    ///
    /// The ROE spread directly determines residual income:
    /// ```
    /// Spread = ROE - Cost of Equity
    /// RI = Spread × Book Value
    /// ```
    ///
    /// - Returns: Time series of ROE spreads for each period
    ///
    /// ## Interpretation
    ///
    /// - **Positive Spread**: Value creation (company earns above cost of capital)
    /// - **Zero Spread**: Fair return (company earns exactly cost of capital)
    /// - **Negative Spread**: Value destruction (company earns below cost of capital)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let spread = model.roeSpread()
    /// for (period, spreadValue) in zip(spread.periods, spread.valuesArray) {
    ///     if spreadValue > 0 {
    ///         print("\(period): Creating value (spread = \(spreadValue * 100)%)")
    ///     } else {
    ///         print("\(period): Destroying value (spread = \(spreadValue * 100)%)")
    ///     }
    /// }
    /// ```
    public func roeSpread() -> TimeSeries<T> {
        let roeTimeSeries = returnOnEquity()
        let roeArray = roeTimeSeries.valuesArray

        var spreadValues: [T] = []
        for roe in roeArray {
            let spread = roe - costOfEquity
            spreadValues.append(spread)
        }

        return TimeSeries(
            periods: netIncome.periods,
            values: spreadValues
        )
    }
}

//
//  EnterpriseValueBridge.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-25.
//

import Foundation
import Numerics

// MARK: - Enterprise Value Bridge

/// Bridge from Enterprise Value to Equity Value
///
/// The Enterprise Value Bridge connects the value of a firm's operations (Enterprise Value)
/// to the value of its equity by accounting for non-operating assets and claims on the firm.
///
/// ## Overview
///
/// Enterprise Value represents the value of a company's core operations, which belongs to
/// all providers of capital (both debt and equity). To arrive at equity value, we must:
/// - Subtract claims with priority over equity (debt, preferred stock, minority interest)
/// - Add assets not reflected in operations (cash, non-operating assets)
///
/// ## Formula
///
/// ```
/// Equity Value = Enterprise Value
///                - Net Debt (Total Debt - Cash)
///                + Non-Operating Assets
///                - Minority Interest
///                - Preferred Stock
/// ```
///
/// ## Components
///
/// - **Enterprise Value (EV)**: Value of operating assets
/// - **Total Debt**: All interest-bearing obligations
/// - **Cash & Equivalents**: Liquid assets available to pay down debt
/// - **Net Debt**: Total Debt - Cash (can be negative if cash > debt)
/// - **Non-Operating Assets**: Marketable securities, investments not in operations
/// - **Minority Interest**: Value attributable to minority shareholders of subsidiaries
/// - **Preferred Stock**: Value of preferred equity claims
///
/// ## When to Use
///
/// The EV Bridge is essential when:
/// - Converting FCFF-based valuations to equity value
/// - Comparing companies with different capital structures
/// - Analyzing M&A scenarios (EV is purchase price, equity value is to common shareholders)
/// - Understanding the impact of leverage on equity value
///
/// ## Usage Example
///
/// ```swift
/// // Calculate enterprise value from FCFF
/// let fcff = TimeSeries(
///     periods: [Period.year(2024), Period.year(2025)],
///     values: [150.0, 165.0]
/// )
///
/// let ev = enterpriseValueFromFCFF(
///     freeCashFlowToFirm: fcff,
///     wacc: 0.09,
///     terminalGrowthRate: 0.03
/// )
///
/// // Bridge to equity value
/// let bridge = EnterpriseValueBridge(
///     enterpriseValue: ev,
///     totalDebt: 500.0,
///     cash: 100.0,
///     nonOperatingAssets: 50.0,
///     minorityInterest: 0.0,
///     preferredStock: 0.0
/// )
///
/// let equityValue = bridge.equityValue()
/// let sharePrice = bridge.valuePerShare(sharesOutstanding: 100.0)
///
/// // Get detailed breakdown
/// let breakdown = bridge.breakdown()
/// print("Net Debt: $\(breakdown.netDebt)M")
/// print("Equity Value: $\(breakdown.equityValue)M")
/// ```
///
/// ## Important Notes
///
/// - Net debt can be negative (net cash position) when cash > debt
/// - Non-operating assets should be valued at fair market value, not book value
/// - Minority interest represents the value of subsidiaries owned by others
/// - Preferred stock is treated as a debt-like claim on equity value
/// - The order of adjustments matters for accurate valuation
///
/// ## Real-World Applications
///
/// 1. **LBO Analysis**: Calculate equity value available to sponsors
/// 2. **M&A Valuation**: Understand what buyers pay vs. what equity receives
/// 3. **Credit Analysis**: Assess debt capacity relative to enterprise value
/// 4. **Capital Structure**: Evaluate impact of leverage on equity value
///
/// - SeeAlso:
///   - ``FCFEModel`` for direct equity valuation without the EV bridge
///   - ``enterpriseValueFromFCFF(_:wacc:terminalGrowthRate:)`` for calculating EV from cash flows
///   - ``GordonGrowthModel`` for alternative equity valuation approach
public struct EnterpriseValueBridge<T: Real> where T: Sendable {

    /// Enterprise value (value of operating assets)
    public let enterpriseValue: T

    /// Total debt (all interest-bearing obligations)
    public let totalDebt: T

    /// Cash and cash equivalents
    public let cash: T

    /// Non-operating assets (investments, marketable securities)
    public let nonOperatingAssets: T

    /// Minority interest (value attributable to minority shareholders)
    public let minorityInterest: T

    /// Preferred stock (value of preferred equity claims)
    public let preferredStock: T

    /// Initialize an Enterprise Value Bridge
    ///
    /// - Parameters:
    ///   - enterpriseValue: Value of operating assets (from FCFF valuation)
    ///   - totalDebt: All interest-bearing debt
    ///   - cash: Cash and cash equivalents
    ///   - nonOperatingAssets: Non-operating assets at fair value
    ///   - minorityInterest: Value attributable to minority shareholders
    ///   - preferredStock: Value of preferred equity
    ///
    /// ## Example
    ///
    /// ```swift
    /// let bridge = EnterpriseValueBridge(
    ///     enterpriseValue: 5000.0,
    ///     totalDebt: 1500.0,
    ///     cash: 300.0,
    ///     nonOperatingAssets: 200.0,
    ///     minorityInterest: 150.0,
    ///     preferredStock: 250.0
    /// )
    /// ```
    public init(
        enterpriseValue: T,
        totalDebt: T,
        cash: T,
        nonOperatingAssets: T,
        minorityInterest: T,
        preferredStock: T
    ) {
        self.enterpriseValue = enterpriseValue
        self.totalDebt = totalDebt
        self.cash = cash
        self.nonOperatingAssets = nonOperatingAssets
        self.minorityInterest = minorityInterest
        self.preferredStock = preferredStock
    }

    /// Calculate net debt (Total Debt - Cash)
    ///
    /// Net debt can be negative, indicating a net cash position where
    /// cash exceeds total debt.
    ///
    /// - Returns: Net debt (positive) or net cash (negative)
    ///
    /// ## Interpretation
    ///
    /// - **Positive Net Debt**: Company has more debt than cash
    /// - **Negative Net Debt**: Company has net cash position (cash > debt)
    /// - **Zero Net Debt**: Cash exactly equals debt
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Company with $500M debt and $100M cash
    /// let netDebt = bridge.netDebt()  // Returns 400.0
    ///
    /// // Tech company with $100M debt and $500M cash
    /// let netCash = techBridge.netDebt()  // Returns -400.0 (net cash)
    /// ```
    public func netDebt() -> T {
        return totalDebt - cash
    }

    /// Calculate common equity value
    ///
    /// Applies the enterprise value bridge formula to derive the value
    /// available to common equity shareholders.
    ///
    /// ## Formula
    ///
    /// ```
    /// Equity Value = EV - Net Debt + Non-Op Assets - Minority Int. - Preferred
    /// ```
    ///
    /// - Returns: Common equity value
    ///
    /// ## Waterfall Logic
    ///
    /// 1. Start with Enterprise Value (value of operations)
    /// 2. Subtract Net Debt (debt holders' claim)
    /// 3. Add Non-Operating Assets (not in EV but belong to shareholders)
    /// 4. Subtract Minority Interest (belongs to minority shareholders)
    /// 5. Subtract Preferred Stock (senior claim on equity)
    /// 6. Result = Common Equity Value
    ///
    /// ## Important Notes
    ///
    /// - Can be negative if claims exceed enterprise value and assets
    /// - Negative equity value indicates financial distress
    /// - Net cash positions increase equity value
    ///
    /// ## Example
    ///
    /// ```swift
    /// let bridge = EnterpriseValueBridge(
    ///     enterpriseValue: 1000.0,
    ///     totalDebt: 200.0,
    ///     cash: 50.0,
    ///     nonOperatingAssets: 0.0,
    ///     minorityInterest: 0.0,
    ///     preferredStock: 0.0
    /// )
    ///
    /// let equity = bridge.equityValue()
    /// // = 1000 - (200 - 50) = 1000 - 150 = 850
    /// ```
    public func equityValue() -> T {
        let nd = netDebt()
        return enterpriseValue - nd + nonOperatingAssets - minorityInterest - preferredStock
    }

    /// Calculate value per common share
    ///
    /// Divides total common equity value by shares outstanding to determine
    /// intrinsic value per share.
    ///
    /// - Parameter sharesOutstanding: Number of common shares outstanding
    ///
    /// - Returns: Intrinsic value per common share
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // If equity value is $850M and 100M shares outstanding
    /// let sharePrice = bridge.valuePerShare(sharesOutstanding: 100.0)
    /// // Returns: $8.50 per share
    /// ```
    ///
    /// ## Important Considerations
    ///
    /// - Use fully diluted share count for conservative valuation
    /// - Include effect of options, warrants, convertibles
    /// - Ensure unit consistency (e.g., both in millions)
    ///
    /// ## Comparison to Market Price
    ///
    /// - Intrinsic value > Market price: Potentially undervalued
    /// - Intrinsic value < Market price: Potentially overvalued
    /// - Intrinsic value reflects fundamentals; market reflects expectations
    public func valuePerShare(sharesOutstanding: T) -> T {
        let equity = equityValue()
        return equity / sharesOutstanding
    }

    /// Get detailed breakdown of the enterprise value bridge
    ///
    /// Provides a comprehensive view of all components in the bridge
    /// from enterprise value to equity value.
    ///
    /// - Returns: Breakdown structure with all components
    ///
    /// ## Example
    ///
    /// ```swift
    /// let breakdown = bridge.breakdown()
    /// print("Enterprise Value: $\(breakdown.enterpriseValue)M")
    /// print("Total Debt: $\(breakdown.totalDebt)M")
    /// print("Cash: $\(breakdown.cash)M")
    /// print("Net Debt: $\(breakdown.netDebt)M")
    /// print("Non-Operating Assets: $\(breakdown.nonOperatingAssets)M")
    /// print("Minority Interest: $\(breakdown.minorityInterest)M")
    /// print("Preferred Stock: $\(breakdown.preferredStock)M")
    /// print("Equity Value: $\(breakdown.equityValue)M")
    /// ```
    public func breakdown() -> EnterpriseValueBreakdown<T> {
        return EnterpriseValueBreakdown(
            enterpriseValue: enterpriseValue,
            totalDebt: totalDebt,
            cash: cash,
            netDebt: netDebt(),
            nonOperatingAssets: nonOperatingAssets,
            minorityInterest: minorityInterest,
            preferredStock: preferredStock,
            equityValue: equityValue()
        )
    }
}

// MARK: - Breakdown Structure

/// Detailed breakdown of enterprise value bridge components
///
/// Provides a complete waterfall view from enterprise value to equity value,
/// showing all intermediate calculations.
public struct EnterpriseValueBreakdown<T: Real> where T: Sendable {
    /// Enterprise value (operating asset value)
    public let enterpriseValue: T

    /// Total debt outstanding
    public let totalDebt: T

    /// Cash and equivalents
    public let cash: T

    /// Net debt (calculated as Total Debt - Cash)
    public let netDebt: T

    /// Non-operating assets
    public let nonOperatingAssets: T

    /// Minority interest
    public let minorityInterest: T

    /// Preferred stock
    public let preferredStock: T

    /// Resulting common equity value
    public let equityValue: T
}

// MARK: - Enterprise Value from FCFF

/// Calculate Enterprise Value from Free Cash Flow to Firm
///
/// Discounts projected FCFF at the weighted average cost of capital (WACC)
/// to determine the present value of the firm's operations.
///
/// ## Formula
///
/// ```
/// EV = Σ(FCFF_t / (1 + WACC)^t) + Terminal Value / (1 + WACC)^n
/// Terminal Value = FCFF_n × (1 + g) / (WACC - g)
/// ```
///
/// Where:
/// - FCFF_t = Free cash flow to firm in period t
/// - WACC = Weighted average cost of capital
/// - g = Terminal growth rate
/// - n = Number of projection periods
///
/// - Parameters:
///   - freeCashFlowToFirm: Time series of projected FCFF
///   - wacc: Weighted average cost of capital (as decimal, e.g., 0.09 for 9%)
///   - terminalGrowthRate: Perpetual growth rate (as decimal, must be < WACC)
///
/// - Returns: Enterprise value (present value of all FCFF)
///
/// ## When to Use
///
/// Use this function when:
/// - You have projected FCFF (not FCFE)
/// - You want to value the entire firm (operations)
/// - You need to compare companies with different capital structures
/// - You're performing an LBO or M&A analysis
///
/// ## Important Notes
///
/// - Returns `NaN` if `terminalGrowthRate >= wacc` (invalid model)
/// - Terminal value typically represents 60-80% of total EV
/// - WACC should reflect the firm's target capital structure
/// - Terminal growth rate should not exceed long-term GDP growth
///
/// ## Usage Example
///
/// ```swift
/// // Project 5 years of FCFF
/// let periods = (2024...2028).map { Period.year($0) }
/// let fcff = TimeSeries(
///     periods: periods,
///     values: [100.0, 110.0, 121.0, 133.0, 146.0]
/// )
///
/// let ev = enterpriseValueFromFCFF(
///     freeCashFlowToFirm: fcff,
///     wacc: 0.09,
///     terminalGrowthRate: 0.03
/// )
///
/// print("Enterprise Value: $\(ev)M")
/// ```
///
/// ## Typical Workflow
///
/// 1. Project explicit forecast period FCFF (5-10 years)
/// 2. Calculate terminal value using perpetuity growth model
/// 3. Discount all cash flows to present at WACC
/// 4. Use ``EnterpriseValueBridge`` to convert EV to equity value
///
/// - SeeAlso:
///   - ``EnterpriseValueBridge`` for converting EV to equity value
///   - ``FCFEModel`` for direct equity valuation approach
public func enterpriseValueFromFCFF<T: Real>(
    freeCashFlowToFirm: TimeSeries<T>,
    wacc: T,
    terminalGrowthRate: T
) -> T where T: Sendable {
    let fcffArray = freeCashFlowToFirm.valuesArray
    var presentValue = T(0)

    // Phase 1: Present value of explicit forecast period FCFF
    for (index, fcffValue) in fcffArray.enumerated() {
        let period = index + 1
        let discountFactor = T.pow(T(1) + wacc, T(period))
        presentValue += fcffValue / discountFactor
    }

    // Phase 2: Terminal value (perpetuity growth model)
    guard !fcffArray.isEmpty else {
        return T(0)
    }

    let finalFCFF = fcffArray[fcffArray.count - 1]
    let terminalFCFF = finalFCFF * (T(1) + terminalGrowthRate)
    let denominator = wacc - terminalGrowthRate

    // Guard against invalid terminal growth rate
    guard denominator > T(0) else {
        return T.nan
    }

    let terminalValue = terminalFCFF / denominator

    // Discount terminal value to present
    let numberOfPeriods = fcffArray.count
    let terminalDiscountFactor = T.pow(T(1) + wacc, T(numberOfPeriods))
    let pvTerminal = terminalValue / terminalDiscountFactor

    return presentValue + pvTerminal
}

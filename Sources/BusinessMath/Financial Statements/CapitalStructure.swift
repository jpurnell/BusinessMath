import Foundation

/// Calculates the Weighted Average Cost of Capital (WACC).
///
/// WACC represents the average rate a company pays to finance its assets, weighted by
/// the proportion of debt and equity in its capital structure. It accounts for the tax
/// deductibility of interest payments.
///
/// ## Formula
///
/// ```
/// WACC = (E/(E+D)) × Re + (D/(E+D)) × Rd × (1-T)
/// ```
///
/// Where:
/// - E = Market value of equity
/// - D = Market value of debt
/// - Re = Cost of equity
/// - Rd = Cost of debt
/// - T = Corporate tax rate
///
/// ## Usage Example
///
/// ```swift
/// let waccRate = wacc(
///     equityValue: 600_000,
///     debtValue: 400_000,
///     costOfEquity: 0.12,
///     costOfDebt: 0.06,
///     taxRate: 0.25
/// )
/// print("WACC: \(waccRate * 100)%")  // 9.0%
/// ```
///
/// - Parameters:
///   - equityValue: Market value of equity
///   - debtValue: Market value of debt
///   - costOfEquity: Cost of equity capital (as decimal, e.g., 0.12 for 12%)
///   - costOfDebt: Cost of debt capital before tax (as decimal)
///   - taxRate: Corporate tax rate (as decimal, e.g., 0.25 for 25%)
///
/// - Returns: The weighted average cost of capital as a decimal
///
/// ## Related Topics
///
/// - ``CapitalStructure``
/// - ``capm(riskFreeRate:beta:marketReturn:)``
public func wacc(
    equityValue: Double,
    debtValue: Double,
    costOfEquity: Double,
    costOfDebt: Double,
    taxRate: Double
) -> Double {
    let totalValue = equityValue + debtValue

    // Handle edge case of zero total value
    guard totalValue > 0 else { return 0.0 }

    let equityWeight = equityValue / totalValue
    let debtWeight = debtValue / totalValue

    // WACC = E/(E+D) * Re + D/(E+D) * Rd * (1-T)
    return equityWeight * costOfEquity + debtWeight * costOfDebt * (1.0 - taxRate)
}

/// Calculates the cost of equity using the Capital Asset Pricing Model (CAPM).
///
/// CAPM estimates the expected return on equity based on systematic risk (beta)
/// and the market risk premium.
///
/// ## Formula
///
/// ```
/// Re = Rf + β × (Rm - Rf)
/// ```
///
/// Where:
/// - Re = Expected return on equity (cost of equity)
/// - Rf = Risk-free rate
/// - β (beta) = Measure of systematic risk
/// - Rm = Expected market return
/// - (Rm - Rf) = Market risk premium
///
/// ## Usage Example
///
/// ```swift
/// let costOfEquity = capm(
///     riskFreeRate: 0.03,
///     beta: 1.2,
///     marketReturn: 0.10
/// )
/// print("Cost of Equity: \(costOfEquity * 100)%")  // 11.4%
/// ```
///
/// - Parameters:
///   - riskFreeRate: The risk-free rate (typically long-term government bonds)
///   - beta: The stock's beta (systematic risk relative to market)
///   - marketReturn: Expected return of the overall market
///
/// - Returns: The expected cost of equity as a decimal
///
/// ## Related Topics
///
/// - ``wacc(equityValue:debtValue:costOfEquity:costOfDebt:taxRate:)``
/// - ``unleverBeta(leveredBeta:debtToEquityRatio:taxRate:)``
/// - ``leverBeta(unleveredBeta:debtToEquityRatio:taxRate:)``
public func capm(
    riskFreeRate: Double,
    beta: Double,
    marketReturn: Double
) -> Double {
    // CAPM: Re = Rf + β(Rm - Rf)
    return riskFreeRate + beta * (marketReturn - riskFreeRate)
}

/// Removes financial leverage from a beta to get the unlevered (asset) beta.
///
/// Unlevered beta represents the systematic risk of a company's assets without
/// the effect of financial leverage (debt).
///
/// ## Formula
///
/// ```
/// βU = βL / [1 + (1-T) × (D/E)]
/// ```
///
/// Where:
/// - βU = Unlevered beta
/// - βL = Levered beta
/// - T = Tax rate
/// - D/E = Debt-to-equity ratio
///
/// ## Usage Example
///
/// ```swift
/// let assetBeta = unleverBeta(
///     leveredBeta: 1.5,
///     debtToEquityRatio: 0.5,
///     taxRate: 0.30
/// )
/// print("Asset Beta: \(assetBeta)")  // ~1.11
/// ```
///
/// - Parameters:
///   - leveredBeta: The beta with financial leverage
///   - debtToEquityRatio: Debt-to-equity ratio (D/E)
///   - taxRate: Corporate tax rate
///
/// - Returns: The unlevered (asset) beta
///
/// ## Related Topics
///
/// - ``leverBeta(unleveredBeta:debtToEquityRatio:taxRate:)``
/// - ``capm(riskFreeRate:beta:marketReturn:)``
public func unleverBeta(
    leveredBeta: Double,
    debtToEquityRatio: Double,
    taxRate: Double
) -> Double {
    // βU = βL / [1 + (1-T)(D/E)]
    return leveredBeta / (1.0 + (1.0 - taxRate) * debtToEquityRatio)
}

/// Adds financial leverage to an unlevered beta to get the levered (equity) beta.
///
/// Levered beta represents the systematic risk of a company's equity, including
/// the amplifying effect of financial leverage (debt).
///
/// ## Formula
///
/// ```
/// βL = βU × [1 + (1-T) × (D/E)]
/// ```
///
/// Where:
/// - βL = Levered beta
/// - βU = Unlevered beta
/// - T = Tax rate
/// - D/E = Debt-to-equity ratio
///
/// ## Usage Example
///
/// ```swift
/// let equityBeta = leverBeta(
///     unleveredBeta: 1.0,
///     debtToEquityRatio: 0.5,
///     taxRate: 0.30
/// )
/// print("Equity Beta: \(equityBeta)")  // 1.35
/// ```
///
/// - Parameters:
///   - unleveredBeta: The beta without financial leverage (asset beta)
///   - debtToEquityRatio: Debt-to-equity ratio (D/E)
///   - taxRate: Corporate tax rate
///
/// - Returns: The levered (equity) beta
///
/// ## Related Topics
///
/// - ``unleverBeta(leveredBeta:debtToEquityRatio:taxRate:)``
/// - ``capm(riskFreeRate:beta:marketReturn:)``
public func leverBeta(
    unleveredBeta: Double,
    debtToEquityRatio: Double,
    taxRate: Double
) -> Double {
    // βL = βU × [1 + (1-T)(D/E)]
    return unleveredBeta * (1.0 + (1.0 - taxRate) * debtToEquityRatio)
}

/// Represents a company's capital structure and provides computed financial metrics.
///
/// `CapitalStructure` models how a company finances its operations through a mix
/// of debt and equity, and calculates key metrics like WACC, leverage ratios,
/// and component costs.
///
/// ## Overview
///
/// Capital structure decisions affect a company's:
/// - Cost of capital (WACC)
/// - Financial risk (leverage)
/// - Tax shield from debt
/// - Return on equity
///
/// ## Usage Example
///
/// ```swift
/// let structure = CapitalStructure(
///     debtValue: 400_000,
///     equityValue: 600_000,
///     costOfDebt: 0.06,
///     costOfEquity: 0.12,
///     taxRate: 0.25
/// )
///
/// print("WACC: \(structure.wacc * 100)%")
/// print("Debt Ratio: \(structure.debtRatio * 100)%")
/// print("D/E Ratio: \(structure.debtToEquityRatio)")
/// print("After-tax Cost of Debt: \(structure.afterTaxCostOfDebt * 100)%")
/// ```
///
/// ## Related Topics
///
/// - ``wacc(equityValue:debtValue:costOfEquity:costOfDebt:taxRate:)``
/// - ``capm(riskFreeRate:beta:marketReturn:)``
public struct CapitalStructure {
    /// Market value of debt
    public let debtValue: Double

    /// Market value of equity
    public let equityValue: Double

    /// Cost of debt before tax (as decimal)
    public let costOfDebt: Double

    /// Cost of equity (as decimal)
    public let costOfEquity: Double

    /// Corporate tax rate (as decimal)
    public let taxRate: Double

    /// Creates a capital structure with the specified components.
    ///
    /// - Parameters:
    ///   - debtValue: Market value of debt
    ///   - equityValue: Market value of equity
    ///   - costOfDebt: Cost of debt before tax (as decimal, e.g., 0.06 for 6%)
    ///   - costOfEquity: Cost of equity (as decimal, e.g., 0.12 for 12%)
    ///   - taxRate: Corporate tax rate (as decimal, e.g., 0.25 for 25%)
    public init(
        debtValue: Double,
        equityValue: Double,
        costOfDebt: Double,
        costOfEquity: Double,
        taxRate: Double
    ) {
        self.debtValue = debtValue
        self.equityValue = equityValue
        self.costOfDebt = costOfDebt
        self.costOfEquity = costOfEquity
        self.taxRate = taxRate
    }

    /// Total enterprise value (debt + equity)
    public var totalValue: Double {
        return debtValue + equityValue
    }

    /// Proportion of financing from debt (D / (D+E))
    public var debtRatio: Double {
        guard totalValue > 0 else { return 0.0 }
        return debtValue / totalValue
    }

    /// Proportion of financing from equity (E / (D+E))
    public var equityRatio: Double {
        guard totalValue > 0 else { return 0.0 }
        return equityValue / totalValue
    }

    /// Debt-to-equity ratio (D / E)
    public var debtToEquityRatio: Double {
        guard equityValue > 0 else { return Double.infinity }
        return debtValue / equityValue
    }

    /// Equity-to-debt ratio (E / D)
    public var equityToDebtRatio: Double {
        guard debtValue > 0 else { return Double.infinity }
        return equityValue / debtValue
    }

    /// Cost of debt after accounting for tax deductibility of interest
    public var afterTaxCostOfDebt: Double {
        return costOfDebt * (1.0 - taxRate)
    }

    /// Weighted Average Cost of Capital
    public var wacc: Double {
        // Call the global wacc function
        let equityW = equityRatio
        let debtW = debtRatio
        return equityW * costOfEquity + debtW * costOfDebt * (1.0 - taxRate)
    }

    /// The tax shield provided by debt (tax rate × debt value)
    ///
    /// Represents the present value of tax savings from interest deductibility
    /// assuming constant debt level.
    public var taxShieldValue: Double {
        return taxRate * debtValue
    }

    /// Annual interest expense (debt value × cost of debt)
    public var annualInterestExpense: Double {
        return debtValue * costOfDebt
    }

    /// Annual tax savings from debt (interest expense × tax rate)
    public var annualTaxShield: Double {
        return annualInterestExpense * taxRate
    }

    /// Creates a new capital structure with modified debt level.
    ///
    /// Useful for analyzing the impact of leverage changes on WACC and other metrics.
    ///
    /// - Parameter newDebtValue: The new debt value
    /// - Returns: A new `CapitalStructure` with the modified debt level
    public func withDebtValue(_ newDebtValue: Double) -> CapitalStructure {
        return CapitalStructure(
            debtValue: newDebtValue,
            equityValue: equityValue,
            costOfDebt: costOfDebt,
            costOfEquity: costOfEquity,
            taxRate: taxRate
        )
    }

    /// Creates a new capital structure with modified equity level.
    ///
    /// - Parameter newEquityValue: The new equity value
    /// - Returns: A new `CapitalStructure` with the modified equity level
    public func withEquityValue(_ newEquityValue: Double) -> CapitalStructure {
        return CapitalStructure(
            debtValue: debtValue,
            equityValue: newEquityValue,
            costOfDebt: costOfDebt,
            costOfEquity: costOfEquity,
            taxRate: taxRate
        )
    }

    /// Calculates the adjustment needed to reach a target debt ratio.
    ///
    /// Returns the changes in debt and equity values needed to achieve the target
    /// debt ratio while maintaining the same total enterprise value.
    ///
    /// - Parameter targetDebtRatio: The desired debt ratio (D / (D+E))
    /// - Returns: A `CapitalStructureAdjustment` showing required changes
    public func adjustmentToTarget(targetDebtRatio: Double) -> CapitalStructureAdjustment {
        let currentTotal = totalValue
        let targetDebtValue = currentTotal * targetDebtRatio
        let targetEquityValue = currentTotal * (1.0 - targetDebtRatio)

        let debtChange = targetDebtValue - debtValue
        let equityChange = targetEquityValue - equityValue

        return CapitalStructureAdjustment(
            debtChange: debtChange,
            equityChange: equityChange,
            currentDebtRatio: debtRatio,
            targetDebtRatio: targetDebtRatio
        )
    }
}

/// Represents the changes needed to adjust to a target capital structure.
public struct CapitalStructureAdjustment {
    /// The change in debt value (positive = increase, negative = decrease)
    public let debtChange: Double

    /// The change in equity value (positive = increase, negative = decrease)
    public let equityChange: Double

    /// The current debt ratio
    public let currentDebtRatio: Double

    /// The target debt ratio
    public let targetDebtRatio: Double
	
	/// Creates an adjustment to the capital structure with the specified components.
	///
	/// - Parameters:
	///   - debtChange: The change in debt value (positive = increase, negative = decrease)
	///   - equityChange: The change in equity value (positive = increase, negative = decrease)
	///   - currentDebtRatio: The current debt ratio
	///   - targetDebtRatio: The target debt ratio
    public init(debtChange: Double, equityChange: Double, currentDebtRatio: Double, targetDebtRatio: Double) {
        self.debtChange = debtChange
        self.equityChange = equityChange
        self.currentDebtRatio = currentDebtRatio
        self.targetDebtRatio = targetDebtRatio
    }
}

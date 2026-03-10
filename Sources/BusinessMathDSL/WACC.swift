//
//  WACC.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation

// MARK: - WACC Components

/// Cost of equity (return required by equity investors).
public struct CostOfEquity {
    /// The cost of equity rate as a decimal (e.g., 0.10 for 10%).
    public let rate: Double

    /// Creates a cost of equity with the specified rate.
    ///
    /// - Parameter rate: The required return rate (must be between 0 and 1).
    public init(_ rate: Double) {
        guard rate >= 0 && rate <= 1.0 else {
            fatalError("Cost of equity must be between 0 and 1: \(rate)")
        }
        self.rate = rate
    }
}

/// Cost of debt (pre-tax interest rate on debt).
public struct CostOfDebt {
    /// The pre-tax interest rate as a decimal (e.g., 0.05 for 5%).
    public let rate: Double

    /// Creates a cost of debt with the specified rate.
    ///
    /// - Parameter rate: The pre-tax interest rate (must be between 0 and 1).
    public init(_ rate: Double) {
        guard rate >= 0 && rate <= 1.0 else {
            fatalError("Cost of debt must be between 0 and 1: \(rate)")
        }
        self.rate = rate
    }
}

/// After-tax cost of debt (already accounts for tax shield).
public struct AfterTaxCostOfDebt {
    /// The after-tax cost of debt as a decimal.
    public let rate: Double

    /// Creates an after-tax cost of debt with the specified rate.
    ///
    /// - Parameter rate: The after-tax interest rate (must be between 0 and 1).
    public init(_ rate: Double) {
        guard rate >= 0 && rate <= 1.0 else {
            fatalError("After-tax cost of debt must be between 0 and 1: \(rate)")
        }
        self.rate = rate
    }
}

/// Corporate tax rate for debt tax shield calculation.
public struct TaxRate {
    /// The corporate tax rate as a decimal (e.g., 0.21 for 21%).
    public let rate: Double

    /// Creates a tax rate with the specified value.
    ///
    /// - Parameter rate: The tax rate (must be between 0 and 1).
    public init(_ rate: Double) {
        guard rate >= 0 && rate <= 1.0 else {
            fatalError("Tax rate must be between 0 and 1: \(rate)")
        }
        self.rate = rate
    }
}

/// Debt-to-equity ratio (D/(D+E)).
public struct DebtToEquity {
    /// The debt ratio as D/(D+E), between 0 and 1.
    public let ratio: Double

    /// Creates a debt-to-equity configuration with the specified ratio.
    ///
    /// - Parameter ratio: The debt weight (must be between 0 and 1).
    public init(_ ratio: Double) {
        guard ratio >= 0 && ratio <= 1.0 else {
            fatalError("Debt to equity ratio must be between 0 and 1: \(ratio)")
        }
        self.ratio = ratio
    }
}

/// Custom WACC rate (for when you want to specify directly).
public struct CustomRate {
    /// The custom WACC rate as a decimal.
    public let rate: Double

    /// Creates a custom WACC rate.
    ///
    /// - Parameter rate: The WACC rate (must be between 0 and 1).
    public init(_ rate: Double) {
        guard rate > 0 && rate <= 1.0 else {
            fatalError("WACC rate must be between 0 and 1: \(rate)")
        }
        self.rate = rate
    }
}

// MARK: - WACC Model

/// Weighted Average Cost of Capital.
///
/// WACC = E/(D+E) × Re + D/(D+E) × Rd × (1-T)
public struct WACC {
    /// The required return on equity capital.
    public let costOfEquity: CostOfEquity?
    /// The pre-tax cost of debt financing.
    public let costOfDebt: CostOfDebt?
    /// The after-tax cost of debt (alternative to costOfDebt + taxRate).
    public let afterTaxCostOfDebt: AfterTaxCostOfDebt?
    /// The corporate tax rate for computing the debt tax shield.
    public let taxRate: TaxRate?
    /// The proportion of debt in the capital structure.
    public let debtToEquity: DebtToEquity?
    /// A directly specified WACC rate (bypasses calculation).
    public let customRate: CustomRate?

    internal init(
        costOfEquity: CostOfEquity? = nil,
        costOfDebt: CostOfDebt? = nil,
        afterTaxCostOfDebt: AfterTaxCostOfDebt? = nil,
        taxRate: TaxRate? = nil,
        debtToEquity: DebtToEquity? = nil,
        customRate: CustomRate? = nil
    ) {
        self.costOfEquity = costOfEquity
        self.costOfDebt = costOfDebt
        self.afterTaxCostOfDebt = afterTaxCostOfDebt
        self.taxRate = taxRate
        self.debtToEquity = debtToEquity
        self.customRate = customRate
    }

    /// Create WACC using result builder
    public init(@WACCBuilder content: () -> WACC) {
        self = content()
    }

    /// Calculate the weighted average cost of capital
    public var rate: Double {
        // If custom rate is provided, use it directly
        if let custom = customRate {
            return custom.rate
        }

        // Otherwise calculate from components
        guard let costOfEquity = costOfEquity,
              let debtRatio = debtToEquity else {
            fatalError("WACC calculation requires cost of equity and debt ratio")
        }

        let equityWeight = 1.0 - debtRatio.ratio
        let debtWeight = debtRatio.ratio

        // Calculate after-tax cost of debt
        let afterTaxDebtCost: Double
        if let afterTax = afterTaxCostOfDebt {
            afterTaxDebtCost = afterTax.rate
        } else if let costOfDebt = costOfDebt, let taxRate = taxRate {
            afterTaxDebtCost = costOfDebt.rate * (1.0 - taxRate.rate)
        } else {
            fatalError("WACC calculation requires either after-tax cost of debt or (cost of debt + tax rate)")
        }

        return equityWeight * costOfEquity.rate + debtWeight * afterTaxDebtCost
    }
}

// MARK: - WACC Result Builder

/// Result builder for constructing `WACC` instances declaratively.
///
/// Allows composing cost of equity, cost of debt, tax rate, and capital structure components.
@resultBuilder
public struct WACCBuilder {
    /// Builds a WACC configuration from the provided components.
    ///
    /// - Parameter components: The cost of equity, debt, tax, and capital structure components.
    /// - Returns: A configured `WACC`.
    public static func buildBlock(_ components: WACCComponent...) -> WACC {
        var costOfEquity: CostOfEquity? = nil
        var costOfDebt: CostOfDebt? = nil
        var afterTaxCostOfDebt: AfterTaxCostOfDebt? = nil
        var taxRate: TaxRate? = nil
        var debtToEquity: DebtToEquity? = nil
        var customRate: CustomRate? = nil

        for component in components {
            switch component {
            case .costOfEquity(let ce):
                costOfEquity = ce
            case .costOfDebt(let cd):
                costOfDebt = cd
            case .afterTaxCostOfDebt(let atcd):
                afterTaxCostOfDebt = atcd
            case .taxRate(let tr):
                taxRate = tr
            case .debtToEquity(let de):
                debtToEquity = de
            case .customRate(let cr):
                customRate = cr
            }
        }

        return WACC(
            costOfEquity: costOfEquity,
            costOfDebt: costOfDebt,
            afterTaxCostOfDebt: afterTaxCostOfDebt,
            taxRate: taxRate,
            debtToEquity: debtToEquity,
            customRate: customRate
        )
    }

    /// Converts a `CostOfEquity` to a WACC component.
    public static func buildExpression(_ expression: CostOfEquity) -> WACCComponent {
        .costOfEquity(expression)
    }

    /// Converts a `CostOfDebt` to a WACC component.
    public static func buildExpression(_ expression: CostOfDebt) -> WACCComponent {
        .costOfDebt(expression)
    }

    /// Converts an `AfterTaxCostOfDebt` to a WACC component.
    public static func buildExpression(_ expression: AfterTaxCostOfDebt) -> WACCComponent {
        .afterTaxCostOfDebt(expression)
    }

    /// Converts a `TaxRate` to a WACC component.
    public static func buildExpression(_ expression: TaxRate) -> WACCComponent {
        .taxRate(expression)
    }

    /// Converts a `DebtToEquity` to a WACC component.
    public static func buildExpression(_ expression: DebtToEquity) -> WACCComponent {
        .debtToEquity(expression)
    }

    /// Converts a `CustomRate` to a WACC component.
    public static func buildExpression(_ expression: CustomRate) -> WACCComponent {
        .customRate(expression)
    }
}

// MARK: - WACC Component Protocol

/// Represents a component that can be used in a WACC builder.
///
/// Cases correspond to cost of equity, cost of debt, tax rate, and capital structure.
public enum WACCComponent {
    case costOfEquity(CostOfEquity)
    case costOfDebt(CostOfDebt)
    case afterTaxCostOfDebt(AfterTaxCostOfDebt)
    case taxRate(TaxRate)
    case debtToEquity(DebtToEquity)
    case customRate(CustomRate)
}

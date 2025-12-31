//
//  Taxes.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-29.
//

import Foundation
import Numerics

/// # Tax Components
///
/// Tax modeling with support for corporate and state tax rates.
/// Taxes are calculated on EBIT (Earnings Before Interest and Taxes).
///
/// ## Usage Examples
///
/// ### Corporate Tax Only
/// ```swift
/// let federalTax = Taxes {
///     CorporateRate(0.21)  // 21% federal corporate tax
/// }
/// let taxOn1M = federalTax.value(on: 1_000_000)  // 210,000
/// ```
///
/// ### State Tax Only
/// ```swift
/// let stateTax = Taxes {
///     StateRate(0.06)  // 6% state tax
/// }
/// let taxOn500k = stateTax.value(on: 500_000)  // 30,000
/// ```
///
/// ### Combined Federal and State Taxes
/// ```swift
/// let combinedTax = Taxes {
///     CorporateRate(0.21)
///     StateRate(0.06)
/// }
/// // Effective rate: 21% + 6% = 27%
/// print(combinedTax.effectiveRate)  // 0.27
///
/// let taxOn1M = combinedTax.value(on: 1_000_000)  // 270,000
/// ```
///
/// ### Integration with Cash Flow Model
/// ```swift
/// let projection = CashFlowModel(
///     revenue: Revenue {
///         Base(1_000_000)
///     },
///     expenses: Expenses {
///         Variable(percentage: 0.60)
///     },
///     depreciation: Depreciation {
///         StraightLine(asset: 500_000, years: 5)
///     },
///     taxes: Taxes {
///         CorporateRate(0.21)
///         StateRate(0.06)
///     }
/// )
///
/// let year1 = projection.calculate(year: 1)
/// // Revenue: 1,000,000
/// // Expenses: 600,000
/// // EBITDA: 400,000
/// // Depreciation: 100,000
/// // EBIT: 300,000
/// // Taxes: 81,000 (27% of 300k)
/// // Net Income: 219,000
/// ```
///
/// ## Tax Calculation Flow
///
/// The cash flow model calculates taxes on EBIT:
/// 1. **Revenue** - Gross income
/// 2. **Expenses** - Operating costs (subtracted)
/// 3. **EBITDA** - Earnings Before Interest, Taxes, Depreciation, Amortization
/// 4. **Depreciation** - Non-cash expense (subtracted)
/// 5. **EBIT** - Taxable income
/// 6. **Taxes** - Calculated on EBIT using effective rate
/// 7. **Net Income** - After-tax profit
///
/// ## Notes on Negative Income
///
/// When EBIT is negative (losses), `value(on:)` returns 0 (no tax owed).
/// Tax loss carryforwards are not modeled in this version.

// MARK: - Tax Components

/// Corporate tax rate
public struct CorporateRate {
    public let rate: Double

    public init(_ rate: Double) {
        guard rate >= 0, rate <= 1.0 else {
            fatalError("Corporate tax rate must be between 0 and 1: \(rate)")
        }
        self.rate = rate
    }
}

/// State tax rate
public struct StateRate {
    public let rate: Double

    public init(_ rate: Double) {
        guard rate >= 0, rate <= 1.0 else {
            fatalError("State tax rate must be between 0 and 1: \(rate)")
        }
        self.rate = rate
    }
}

// MARK: - Taxes Model

/// Tax model with corporate and state rates
public struct Taxes {
    public let corporateRate: Double
    public let stateRate: Double

    internal init(
        corporateRate: Double = 0,
        stateRate: Double = 0
    ) {
        self.corporateRate = corporateRate
        self.stateRate = stateRate
    }

    /// Calculate effective tax rate
    public var effectiveRate: Double {
        corporateRate + stateRate
    }

    /// Calculate tax on taxable income
    /// - Parameter income: Taxable income
    /// - Returns: Total tax owed
    public func value(on income: Double) -> Double {
        guard income > 0 else { return 0 }
        return income * effectiveRate
    }

    /// Create taxes model using result builder
    public init(@CashFlowTaxesBuilder content: () -> Taxes) {
        self = content()
    }
}

// MARK: - Taxes Result Builder

@resultBuilder
public struct CashFlowTaxesBuilder {
    public static func buildBlock(_ components: CashFlowTaxComponent...) -> Taxes {
        var corporateRate: Double = 0
        var stateRate: Double = 0

        for component in components {
            switch component {
            case .corporateRate(let rate):
                corporateRate = rate.rate
            case .stateRate(let rate):
                stateRate = rate.rate
            }
        }

        return Taxes(
            corporateRate: corporateRate,
            stateRate: stateRate
        )
    }
}

// MARK: - Tax Component Protocol

public enum CashFlowTaxComponent {
    case corporateRate(CorporateRate)
    case stateRate(StateRate)
}

extension CorporateRate: CashFlowTaxComponentConvertible {
    public var cashFlowTaxComponent: CashFlowTaxComponent { .corporateRate(self) }
}

extension StateRate: CashFlowTaxComponentConvertible {
    public var cashFlowTaxComponent: CashFlowTaxComponent { .stateRate(self) }
}

public protocol CashFlowTaxComponentConvertible {
    var cashFlowTaxComponent: CashFlowTaxComponent { get }
}

extension CashFlowTaxesBuilder {
    public static func buildExpression(_ expression: CashFlowTaxComponentConvertible) -> CashFlowTaxComponent {
        expression.cashFlowTaxComponent
    }
}

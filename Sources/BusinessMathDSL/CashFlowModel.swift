//
//  CashFlowModel.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-29.
//

import Foundation
import Numerics

/// # Cash Flow Model - Declarative Financial Projections
///
/// The Cash Flow Model provides a Swift result builder DSL for creating financial projections
/// using a declarative, type-safe syntax. This module is separate from the main BusinessMath
/// fluent API and can be imported independently.
///
/// ## Basic Usage
///
/// ```swift
/// import BusinessMathDSL
///
/// let projection = CashFlowModel(
///     revenue: Revenue {
///         Base(1_000_000)
///         GrowthRate(0.15)
///     },
///     expenses: Expenses {
///         Fixed(100_000)
///         Variable(percentage: 0.40)
///     },
///     taxes: Taxes {
///         CorporateRate(0.21)
///     }
/// )
///
/// let year1Results = projection.calculate(year: 1)
/// print("Year 1 Net Income: \(year1Results.netIncome)")
/// ```
///
/// ## Advanced Example with All Components
///
/// ```swift
/// let fullProjection = CashFlowModel(
///     revenue: Revenue {
///         Base(5_000_000)
///         GrowthRate(0.20)
///         Seasonality([1.5, 1.0, 0.75, 0.75])  // Q1 strong, Q3-Q4 weak
///     },
///     expenses: Expenses {
///         Fixed(500_000)              // Annual fixed costs
///         Variable(percentage: 0.35)  // 35% of revenue
///         OneTime(1_000_000, in: 2)   // Capital investment in year 2
///     },
///     depreciation: Depreciation {
///         StraightLine(asset: 2_000_000, years: 10)
///         StraightLine(asset: 500_000, years: 5)
///     },
///     taxes: Taxes {
///         CorporateRate(0.21)
///         StateRate(0.06)
///     }
/// )
///
/// // Calculate multi-year projections
/// let fiveYearResults = fullProjection.calculateYears(1...5)
///
/// // Calculate free cash flow
/// let year1FCF = fullProjection.freeCashFlow(year: 1)
///
/// // Calculate quarterly results with seasonality
/// let year1Quarters = fullProjection.calculateQuarters(year: 1)
/// ```
///
/// ## Property Wrapper Syntax
///
/// For stored properties, you can use the `@CashFlowProjection` property wrapper:
///
/// ```swift
/// struct FinancialPlan {
///     @CashFlowProjection
///     var projection = CashFlowModel(
///         revenue: Revenue {
///             Base(1_000_000)
///             GrowthRate(0.15)
///         },
///         expenses: Expenses {
///             Variable(percentage: 0.50)
///         }
///     )
/// }
/// ```

// MARK: - Cash Flow Calculation Result

/// Result of cash flow calculation for a period.
///
/// Contains all key financial metrics computed from revenue through net income.
public struct CashFlowResult {
    /// Total revenue for the period.
    public let revenue: Double
    /// Total expenses (fixed and variable) for the period.
    public let expenses: Double
    /// Earnings Before Interest, Taxes, Depreciation, and Amortization.
    public let ebitda: Double
    /// Depreciation expense for the period.
    public let depreciation: Double
    /// Earnings Before Interest and Taxes (EBITDA minus depreciation).
    public let ebit: Double
    /// Tax expense computed on EBIT.
    public let taxes: Double
    /// Final net income after all expenses and taxes.
    public let netIncome: Double

    /// Creates a new cash flow result with all computed metrics.
    ///
    /// - Parameters:
    ///   - revenue: Total revenue for the period.
    ///   - expenses: Total expenses for the period.
    ///   - ebitda: Earnings before interest, taxes, depreciation, and amortization.
    ///   - depreciation: Depreciation expense.
    ///   - ebit: Earnings before interest and taxes.
    ///   - taxes: Tax expense.
    ///   - netIncome: Final net income.
    public init(
        revenue: Double,
        expenses: Double,
        ebitda: Double,
        depreciation: Double,
        ebit: Double,
        taxes: Double,
        netIncome: Double
    ) {
        self.revenue = revenue
        self.expenses = expenses
        self.ebitda = ebitda
        self.depreciation = depreciation
        self.ebit = ebit
        self.taxes = taxes
        self.netIncome = netIncome
    }
}

// MARK: - Cash Flow Model

/// Complete financial model combining revenue, expenses, depreciation, and taxes.
///
/// Use the DSL builder syntax to create models declaratively.
public struct CashFlowModel {
    /// The revenue configuration for the model.
    public let revenue: Revenue?
    /// The expense configuration for the model.
    public let expenses: Expenses?
    /// The depreciation schedule for the model.
    public let depreciation: Depreciation?
    /// The tax rates applied to earnings.
    public let taxes: Taxes?

    /// Creates a new cash flow model with the specified components.
    ///
    /// - Parameters:
    ///   - revenue: Revenue configuration with base amount and growth rate.
    ///   - expenses: Expense configuration with fixed and variable costs.
    ///   - depreciation: Depreciation schedule for capital assets.
    ///   - taxes: Tax rate configuration.
    public init(
        revenue: Revenue? = nil,
        expenses: Expenses? = nil,
        depreciation: Depreciation? = nil,
        taxes: Taxes? = nil
    ) {
        self.revenue = revenue
        self.expenses = expenses
        self.depreciation = depreciation
        self.taxes = taxes
    }

    /// Calculate cash flow for a specific year
    /// - Parameter year: The year number (1-based)
    /// - Returns: Cash flow result for the year
    public func calculate(year: Int) -> CashFlowResult {
        // Get revenue
        let revenueValue = revenue?.value(forYear: year) ?? 0

        // Get expenses (depends on revenue)
        let expensesValue = expenses?.value(forYear: year, revenue: revenueValue) ?? 0

        // Calculate EBITDA
        let ebitda = revenueValue - expensesValue

        // Get depreciation
        let depreciationValue = depreciation?.value(forYear: year) ?? 0

        // Calculate EBIT
        let ebit = ebitda - depreciationValue

        // Calculate taxes (on EBIT)
        let taxesValue = taxes?.value(on: ebit) ?? 0

        // Calculate net income
        let netIncome = ebit - taxesValue

        return CashFlowResult(
            revenue: revenueValue,
            expenses: expensesValue,
            ebitda: ebitda,
            depreciation: depreciationValue,
            ebit: ebit,
            taxes: taxesValue,
            netIncome: netIncome
        )
    }

    /// Calculate cash flow for multiple years
    /// - Parameter years: Range of years to calculate
    /// - Returns: Array of cash flow results
    public func calculateYears(_ years: ClosedRange<Int>) -> [CashFlowResult] {
        years.map { calculate(year: $0) }
    }

    /// Calculate free cash flow (Net Income + Depreciation)
    /// - Parameter year: The year number (1-based)
    /// - Returns: Free cash flow for the year
    public func freeCashFlow(year: Int) -> Double {
        let result = calculate(year: year)
        // FCF = Net Income + Depreciation (add back non-cash expense)
        return result.netIncome + result.depreciation
    }

    /// Calculate quarterly results for a year
    /// - Parameter year: The year number (1-based)
    /// - Returns: Array of 4 quarterly results
    public func calculateQuarters(year: Int) -> [CashFlowResult] {
        guard let revenue = revenue else {
            return Array(repeating: CashFlowResult(
                revenue: 0, expenses: 0, ebitda: 0,
                depreciation: 0, ebit: 0, taxes: 0, netIncome: 0
            ), count: 4)
        }

        return (1...4).map { quarter in
            let quarterRevenue = revenue.value(forYear: year, quarter: quarter)
            let quarterExpenses = expenses?.value(forYear: year, revenue: quarterRevenue) ?? 0
            let quarterEbitda = quarterRevenue - quarterExpenses

            // Depreciation is annual, divide by 4 for quarterly
            let annualDepreciation = depreciation?.value(forYear: year) ?? 0
            let quarterDepreciation = annualDepreciation / 4.0

            let quarterEbit = quarterEbitda - quarterDepreciation
            let quarterTaxes = taxes?.value(on: quarterEbit) ?? 0
            let quarterNetIncome = quarterEbit - quarterTaxes

            return CashFlowResult(
                revenue: quarterRevenue,
                expenses: quarterExpenses,
                ebitda: quarterEbitda,
                depreciation: quarterDepreciation,
                ebit: quarterEbit,
                taxes: quarterTaxes,
                netIncome: quarterNetIncome
            )
        }
    }
}

// MARK: - Cash Flow Model Result Builder

/// Result builder for constructing `CashFlowModel` instances declaratively.
///
/// Allows composing revenue, expenses, depreciation, and tax components
/// using Swift's result builder syntax.
@resultBuilder
public struct CashFlowModelBuilder {
    /// Builds a cash flow model from the provided components.
    ///
    /// - Parameter components: The revenue, expense, depreciation, and tax components.
    /// - Returns: A configured `CashFlowModel`.
    public static func buildBlock(_ components: CashFlowModelComponent...) -> CashFlowModel {
        var revenue: Revenue?
        var expenses: Expenses?
        var depreciation: Depreciation?
        var taxes: Taxes?

        for component in components {
            switch component {
            case .revenue(let r):
                revenue = r
            case .expenses(let e):
                expenses = e
            case .depreciation(let d):
                depreciation = d
            case .taxes(let t):
                taxes = t
            }
        }

        return CashFlowModel(
            revenue: revenue,
            expenses: expenses,
            depreciation: depreciation,
            taxes: taxes
        )
    }

    /// Handles optional components in `if` statements without an `else`.
    public static func buildOptional(_ component: CashFlowModelComponent?) -> CashFlowModelComponent? {
        component
    }

    /// Handles the first branch of an `if-else` statement.
    public static func buildEither(first component: CashFlowModelComponent) -> CashFlowModelComponent {
        component
    }

    /// Handles the second branch of an `if-else` statement.
    public static func buildEither(second component: CashFlowModelComponent) -> CashFlowModelComponent {
        component
    }

    /// Handles `for` loops by collecting components into an array.
    public static func buildArray(_ components: [CashFlowModelComponent]) -> CashFlowModelComponent {
        // For array support, just take first component
        components.first ?? .revenue(Revenue(baseValue: 0))
    }
}

// MARK: - Cash Flow Model Component Protocol

/// Represents a component that can be used in a cash flow model builder.
///
/// Cases correspond to the four major financial model components:
/// revenue, expenses, depreciation, and taxes.
public enum CashFlowModelComponent {
    case revenue(Revenue)
    case expenses(Expenses)
    case depreciation(Depreciation)
    case taxes(Taxes)
}

extension Revenue: CashFlowModelComponentConvertible {
    /// Converts this revenue configuration to a cash flow model component.
    public var cashFlowModelComponent: CashFlowModelComponent { .revenue(self) }
}

extension Expenses: CashFlowModelComponentConvertible {
    /// Converts this expense configuration to a cash flow model component.
    public var cashFlowModelComponent: CashFlowModelComponent { .expenses(self) }
}

extension Depreciation: CashFlowModelComponentConvertible {
    /// Converts this depreciation schedule to a cash flow model component.
    public var cashFlowModelComponent: CashFlowModelComponent { .depreciation(self) }
}

extension Taxes: CashFlowModelComponentConvertible {
    /// Converts this tax configuration to a cash flow model component.
    public var cashFlowModelComponent: CashFlowModelComponent { .taxes(self) }
}

/// Protocol for types that can be converted to a `CashFlowModelComponent`.
///
/// Conforming types can be used directly within the `CashFlowModelBuilder` DSL.
public protocol CashFlowModelComponentConvertible {
    /// The cash flow model component representation of this type.
    var cashFlowModelComponent: CashFlowModelComponent { get }
}

extension CashFlowModelBuilder {
    /// Converts a conforming expression to a cash flow model component.
    public static func buildExpression(_ expression: CashFlowModelComponentConvertible) -> CashFlowModelComponent {
        expression.cashFlowModelComponent
    }
}

// MARK: - @CashFlowProjection Property Wrapper

/// Property wrapper for declarative cash flow projection creation
///
/// Use this to create cash flow models with a declarative result builder syntax:
///
/// ```swift
/// @CashFlowProjection
/// var projection: CashFlowModel {
///     Revenue {
///         Base(1_000_000)
///         GrowthRate(0.15)
///     }
///     Expenses {
///         Fixed(100_000)
///         Variable(percentage: 0.40)
///     }
/// }
/// ```
@propertyWrapper
public struct CashFlowProjection {
    /// The underlying cash flow model.
    public var wrappedValue: CashFlowModel

    /// Creates a projection from an existing cash flow model.
    ///
    /// - Parameter wrappedValue: The cash flow model to wrap.
    public init(wrappedValue: CashFlowModel) {
        self.wrappedValue = wrappedValue
    }

    /// Creates a projection using the result builder DSL.
    ///
    /// - Parameter builder: A closure that builds the cash flow model.
    public init(@CashFlowModelBuilder builder: () -> CashFlowModel) {
        self.wrappedValue = builder()
    }
}

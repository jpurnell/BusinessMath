//
//  Expenses.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-29.
//

import Foundation
import Numerics

/// # Expense Components
///
/// Expense modeling with three types of costs:
/// - **Fixed**: Constant expenses each year (rent, salaries, etc.)
/// - **Variable**: Expenses that scale with revenue (COGS, sales commissions, etc.)
/// - **OneTime**: One-off expenses in specific years (capital investments, restructuring, etc.)
///
/// ## Usage Examples
///
/// ### Fixed Expenses
/// ```swift
/// let fixedOnly = Expenses {
///     Fixed(500_000)  // $500k per year
/// }
/// let year1 = fixedOnly.value(forYear: 1, revenue: 1_000_000)  // 500,000
/// let year2 = fixedOnly.value(forYear: 2, revenue: 2_000_000)  // 500,000 (same)
/// ```
///
/// ### Variable Expenses (% of Revenue)
/// ```swift
/// let variableOnly = Expenses {
///     Variable(percentage: 0.40)  // 40% of revenue
/// }
/// let expenses1M = variableOnly.value(forYear: 1, revenue: 1_000_000)  // 400,000
/// let expenses2M = variableOnly.value(forYear: 1, revenue: 2_000_000)  // 800,000
/// ```
///
/// ### One-Time Expenses
/// ```swift
/// let capex = Expenses {
///     OneTime(1_000_000, in: 2)  // $1M capital expense in year 2
/// }
/// let year1 = capex.oneTimeValue(forYear: 1)  // 0
/// let year2 = capex.oneTimeValue(forYear: 2)  // 1,000,000
/// let year3 = capex.oneTimeValue(forYear: 3)  // 0
/// ```
///
/// ### Combined Expense Model
/// ```swift
/// let fullExpenses = Expenses {
///     Fixed(100_000)              // Base overhead
///     Variable(percentage: 0.35)  // 35% COGS
///     OneTime(500_000, in: 2)     // Year 2 expansion
///     OneTime(200_000, in: 4)     // Year 4 equipment upgrade
/// }
/// let year1Total = fullExpenses.value(forYear: 1, revenue: 1_000_000)
/// // = 100,000 (fixed) + 350,000 (35% of 1M) + 0 (no one-time) = 450,000
///
/// let year2Total = fullExpenses.value(forYear: 2, revenue: 1_200_000)
/// // = 100,000 + 420,000 (35% of 1.2M) + 500,000 (one-time) = 1,020,000
/// ```
///
/// ## Multiple Fixed or Variable Expenses
///
/// You can specify multiple fixed or variable expenses - they will be summed:
/// ```swift
/// let multipleExpenses = Expenses {
///     Fixed(200_000)              // Rent
///     Fixed(300_000)              // Salaries
///     Variable(percentage: 0.30)  // COGS
///     Variable(percentage: 0.05)  // Sales commissions
/// }
/// // Total fixed: 500,000
/// // Total variable: 35% of revenue
/// ```

// MARK: - Expense Components

/// Fixed expense amount (constant each year)
public struct Fixed {
    public let amount: Double

    public init(_ amount: Double) {
        guard amount >= 0 else {
            fatalError("Fixed expenses cannot be negative: \(amount)")
        }
        self.amount = amount
    }
}

/// Variable expense as percentage of revenue
public struct Variable {
    public let percentage: Double

    public init(percentage: Double) {
        guard percentage >= 0, percentage <= 1.0 else {
            fatalError("Variable expense percentage must be between 0 and 1: \(percentage)")
        }
        self.percentage = percentage
    }
}

/// One-time expense in a specific year
public struct OneTime {
    public let amount: Double
    public let year: Int

    public init(_ amount: Double, in year: Int) {
        guard amount >= 0 else {
            fatalError("One-time expense cannot be negative: \(amount)")
        }
        guard year > 0 else {
            fatalError("Year must be positive: \(year)")
        }
        self.amount = amount
        self.year = year
    }
}

// MARK: - Expenses Model

/// Expense model with fixed, variable, and one-time components
public struct Expenses {
    public let fixedAmount: Double
    public let variablePercentage: Double
    public let oneTimeExpenses: [(amount: Double, year: Int)]

    internal init(
        fixedAmount: Double = 0,
        variablePercentage: Double = 0,
        oneTimeExpenses: [(amount: Double, year: Int)] = []
    ) {
        self.fixedAmount = fixedAmount
        self.variablePercentage = variablePercentage
        self.oneTimeExpenses = oneTimeExpenses
    }

    /// Calculate total expenses for a specific year
    /// - Parameters:
    ///   - year: The year number (1-based)
    ///   - revenue: Revenue for the year (needed for variable expenses)
    /// - Returns: Total expenses
    public func value(forYear year: Int, revenue: Double) -> Double {
        guard year > 0 else { return 0 }

        let fixed = fixedAmount
        let variable = revenue * variablePercentage
        let oneTime = oneTimeValue(forYear: year)

        return fixed + variable + oneTime
    }

    /// Calculate one-time expenses for a specific year
    /// - Parameter year: The year number (1-based)
    /// - Returns: Sum of all one-time expenses for the year
    public func oneTimeValue(forYear year: Int) -> Double {
        oneTimeExpenses
            .filter { $0.year == year }
            .reduce(0) { $0 + $1.amount }
    }

    /// Create expenses model using result builder
    public init(@ExpensesBuilder content: () -> Expenses) {
        self = content()
    }
}

// MARK: - Expenses Result Builder

@resultBuilder
public struct ExpensesBuilder {
    public static func buildBlock(_ components: ExpenseComponent...) -> Expenses {
        var fixedAmount: Double = 0
        var variablePercentage: Double = 0
        var oneTimeExpenses: [(amount: Double, year: Int)] = []

        for component in components {
            switch component {
            case .fixed(let fixed):
                fixedAmount += fixed.amount
            case .variable(let variable):
                variablePercentage += variable.percentage
            case .oneTime(let oneTime):
                oneTimeExpenses.append((oneTime.amount, oneTime.year))
            }
        }

        return Expenses(
            fixedAmount: fixedAmount,
            variablePercentage: variablePercentage,
            oneTimeExpenses: oneTimeExpenses
        )
    }
}

// MARK: - Expense Component Protocol

public enum ExpenseComponent {
    case fixed(Fixed)
    case variable(Variable)
    case oneTime(OneTime)
}

extension Fixed: ExpenseComponentConvertible {
    public var expenseComponent: ExpenseComponent { .fixed(self) }
}

extension Variable: ExpenseComponentConvertible {
    public var expenseComponent: ExpenseComponent { .variable(self) }
}

extension OneTime: ExpenseComponentConvertible {
    public var expenseComponent: ExpenseComponent { .oneTime(self) }
}

public protocol ExpenseComponentConvertible {
    var expenseComponent: ExpenseComponent { get }
}

extension ExpensesBuilder {
    public static func buildExpression(_ expression: ExpenseComponentConvertible) -> ExpenseComponent {
        expression.expenseComponent
    }
}

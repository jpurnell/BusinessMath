//
//  ValidationMacrosExample.swift
//  BusinessMath Examples
//
//  Demonstrates using Swift macros for validation (Phase 4.3)
//  Learn how @Validated adds compile-time validation infrastructure
//
//  Created on December 30, 2025.
//

import Foundation
import BusinessMath
import BusinessMathMacros

// MARK: - Example 1: Basic Validation

print("=== Example 1: Basic Validation ===\n")

/// Loan calculation with automatic validation
@Validated
struct LoanCalculation {
    var principal: Double
    var interestRate: Double
    var years: Int

    // Custom validation logic (called by generated validate() method)
    mutating func performValidation() throws {
        guard principal > 0 else {
            throw ValidationError.invalidValue("Principal must be positive")
        }

        guard interestRate >= 0 && interestRate <= 1 else {
            throw ValidationError.invalidValue("Interest rate must be between 0 and 1")
        }

        guard years > 0 else {
            throw ValidationError.invalidValue("Years must be positive")
        }
    }
}

enum ValidationError: Error, LocalizedError {
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .invalidValue(let message):
            return message
        }
    }
}

// The @Validated macro automatically generates:
// - func validate() throws
// - var isValid: Bool

let goodLoan = LoanCalculation(principal: 100_000, interestRate: 0.05, years: 30)
let badLoan = LoanCalculation(principal: -1000, interestRate: 0.05, years: 30)

print("Good loan configuration:")
print("  Principal: $\(String(format: "%.0f", goodLoan.principal))")
print("  Rate: \(String(format: "%.1f%%", goodLoan.interestRate * 100))")
print("  Years: \(goodLoan.years)")
print("  Is Valid: \(goodLoan.isValid)")

print("\nBad loan configuration (negative principal):")
print("  Principal: $\(String(format: "%.0f", badLoan.principal))")
print("  Is Valid: \(badLoan.isValid)")

print("\n")

// MARK: - Example 2: Portfolio Validation

print("=== Example 2: Portfolio Validation ===\n")

@Validated
struct Portfolio {
    var stocks: Double
    var bonds: Double
    var cash: Double

    var totalAllocation: Double {
        return stocks + bonds + cash
    }

    mutating func performValidation() throws {
        // Each allocation must be non-negative
        guard stocks >= 0 else {
            throw ValidationError.invalidValue("Stock allocation cannot be negative")
        }

        guard bonds >= 0 else {
            throw ValidationError.invalidValue("Bond allocation cannot be negative")
        }

        guard cash >= 0 else {
            throw ValidationError.invalidValue("Cash allocation cannot be negative")
        }

        // Total must equal 100%
        guard abs(totalAllocation - 1.0) < 0.001 else {
            throw ValidationError.invalidValue("Allocations must sum to 100%")
        }
    }
}

let validPortfolio = Portfolio(stocks: 0.6, bonds: 0.3, cash: 0.1)
let invalidPortfolio = Portfolio(stocks: 0.7, bonds: 0.5, cash: 0.1)  // Sums to 130%

print("Valid portfolio:")
print("  Stocks: \(String(format: "%.0f%%", validPortfolio.stocks * 100))")
print("  Bonds: \(String(format: "%.0f%%", validPortfolio.bonds * 100))")
print("  Cash: \(String(format: "%.0f%%", validPortfolio.cash * 100))")
print("  Total: \(String(format: "%.0f%%", validPortfolio.totalAllocation * 100))")
print("  Is Valid: \(validPortfolio.isValid)")

print("\nInvalid portfolio:")
print("  Stocks: \(String(format: "%.0f%%", invalidPortfolio.stocks * 100))")
print("  Bonds: \(String(format: "%.0f%%", invalidPortfolio.bonds * 100))")
print("  Cash: \(String(format: "%.0f%%", invalidPortfolio.cash * 100))")
print("  Total: \(String(format: "%.0f%%", invalidPortfolio.totalAllocation * 100))")
print("  Is Valid: \(invalidPortfolio.isValid)")

print("\n")

// MARK: - Example 3: Financial Model Validation

print("=== Example 3: Financial Model Validation ===\n")

@Validated
struct DCFModel {
    var revenue: Double
    var growthRate: Double
    var discountRate: Double
    var terminalGrowth: Double

    mutating func performValidation() throws {
        guard revenue > 0 else {
            throw ValidationError.invalidValue("Revenue must be positive")
        }

        guard discountRate > terminalGrowth else {
            throw ValidationError.invalidValue("Discount rate must exceed terminal growth")
        }

        guard terminalGrowth >= 0 && terminalGrowth <= 0.05 else {
            throw ValidationError.invalidValue("Terminal growth should be 0-5%")
        }

        guard discountRate > 0 && discountRate < 1 else {
            throw ValidationError.invalidValue("Discount rate should be 0-100%")
        }
    }

    func calculateNPV() -> Double {
        // Simplified NPV calculation
        let cashFlow = revenue * (1 + growthRate)
        let terminalValue = cashFlow / (discountRate - terminalGrowth)
        return terminalValue / (1 + discountRate)
    }
}

var validModel = DCFModel(revenue: 1_000_000, growthRate: 0.10, discountRate: 0.12, terminalGrowth: 0.03)

print("DCF Model:")
print("  Revenue: $\(String(format: "%.0f", validModel.revenue))")
print("  Growth Rate: \(String(format: "%.1f%%", validModel.growthRate * 100))")
print("  Discount Rate: \(String(format: "%.1f%%", validModel.discountRate * 100))")
print("  Terminal Growth: \(String(format: "%.1f%%", validModel.terminalGrowth * 100))")
print("  Is Valid: \(validModel.isValid)")

if validModel.isValid {
    let npv = validModel.calculateNPV()
    print("  NPV: $\(String(format: "%.0f", npv))")
}

print("\n")

// MARK: - Example 4: Benefits of Validation Macros

print("=== Example 4: Benefits of Validation Macros ===\n")

print("✨ Benefits:")
print("  1. Consistent validation interface - Every @Validated struct gets validate() and isValid")
print("  2. Compile-time guarantee - Can't forget to add validation infrastructure")
print("  3. Reduced boilerplate - No manual implementation of isValid property")
print("  4. Clear contracts - @Validated signals \"this struct validates its state\"")
print("  5. Easy testing - isValid property simplifies validation testing")

print("\n📝 Without Macros (Old Way):")
print("""
struct LoanCalculation {
    var principal: Double
    var interestRate: Double
    var years: Int

    func validate() throws {
        // Validation logic
    }

    var isValid: Bool {
        do {
            try validate()
            return true
        } catch {
            return false
        }
    }
}
""")

print("\n✨ With Macros (New Way):")
print("""
@Validated
struct LoanCalculation {
    var principal: Double
    var interestRate: Double
    var years: Int

    mutating func performValidation() throws {
        // Validation logic
    }
}
""")

print("\n🎯 Key Advantages:")
print("  • @Validated automatically adds validate() and isValid")
print("  • No boilerplate for validation infrastructure")
print("  • Self-documenting - clear that struct supports validation")
print("  • Consistent pattern across all financial models")

print("\n")

// MARK: - Example 5: Validation in Practice

print("=== Example 5: Validation in Practice ===\n")

@Validated
struct TradingOrder {
    var symbol: String
    var quantity: Int
    var price: Double
    var orderType: String

    var totalValue: Double {
        return Double(quantity) * price
    }

    mutating func performValidation() throws {
        guard !symbol.isEmpty else {
            throw ValidationError.invalidValue("Symbol cannot be empty")
        }

        guard quantity > 0 else {
            throw ValidationError.invalidValue("Quantity must be positive")
        }

        guard price > 0 else {
            throw ValidationError.invalidValue("Price must be positive")
        }

        let validOrderTypes = ["market", "limit", "stop"]
        guard validOrderTypes.contains(orderType.lowercased()) else {
            throw ValidationError.invalidValue("Invalid order type")
        }
    }
}

let validOrder = TradingOrder(symbol: "AAPL", quantity: 100, price: 175.50, orderType: "limit")
let invalidOrder = TradingOrder(symbol: "", quantity: 100, price: 175.50, orderType: "limit")

print("Valid order:")
print("  Symbol: \(validOrder.symbol)")
print("  Quantity: \(validOrder.quantity)")
print("  Price: $\(String(format: "%.2f", validOrder.price))")
print("  Type: \(validOrder.orderType)")
print("  Total Value: $\(String(format: "%.2f", validOrder.totalValue))")
print("  Is Valid: \(validOrder.isValid)")

print("\nInvalid order (empty symbol):")
print("  Is Valid: \(invalidOrder.isValid)")

// Attempting to validate manually
do {
    var order = invalidOrder
    try order.performValidation()
    print("  Order validated successfully")
} catch {
    print("  Validation error: \(error.localizedDescription)")
}

print("\n")

// MARK: - Summary

print(String(repeating: "=", count: 60))
print("✅ Validation Macros Examples Complete!")
print(String(repeating: "=", count: 60))

print("\nKey Takeaways:")
print("  • @Validated adds validation infrastructure automatically")
print("  • Generates validate() and isValid members")
print("  • Reduces boilerplate for data validation")
print("  • Provides consistent validation pattern")
print("  • Makes validation explicit in type signatures")

print("\nNext Steps:")
print("  • Explore builder generation macros (Phase 4.4)")
print("  • Learn async wrapper macros (Phase 4.5)")
print("  • Combine with @Variable for validated optimization problems")

print("\nHappy validating! 🚀\n")

//
//  BusinessMathErrorTests.swift
//  BusinessMath
//
//  Created on December 2, 2025.
//  Phase 3: Enhanced Error Handling Tests
//

import Testing
import Foundation
@testable import BusinessMath

/// Comprehensive tests for BusinessMathError
///
/// Verifies that:
/// - Error messages are clear and informative
/// - Recovery suggestions are actionable and helpful
/// - Error codes are unique and well-organized
/// - Context information is properly included
/// - Error aggregation works correctly
/// - Multiple error reporting is formatted properly
@Suite("BusinessMathError Tests")
struct BusinessMathErrorTests {

    // MARK: - Calculation Errors (E001-E099)

    @Test("Invalid input error - basic message")
    func invalidInputBasic() {
        let error = BusinessMathError.invalidInput(message: "Discount rate cannot be negative")

        #expect(error.code == "E001")
        #expect(error.errorDescription?.contains("Invalid input") == true)
        #expect(error.errorDescription?.contains("Discount rate cannot be negative") == true)
        #expect(error.recoverySuggestion?.contains("check your input") == true)
    }

    @Test("Invalid input error - with value and range")
    func invalidInputWithContext() {
        let error = BusinessMathError.invalidInput(
            message: "Discount rate out of range",
            value: "-0.5",
            expectedRange: "0.0 to 1.0"
        )

        #expect(error.errorDescription?.contains("provided: -0.5") == true)
        #expect(error.errorDescription?.contains("expected: 0.0 to 1.0") == true)
        #expect(error.recoverySuggestion?.contains("within the range: 0.0 to 1.0") == true)
    }

    @Test("Calculation failed error - basic")
    func calculationFailedBasic() {
        let error = BusinessMathError.calculationFailed(
            operation: "IRR",
            reason: "Failed to converge after 100 iterations"
        )

        #expect(error.code == "E002")
        #expect(error.errorDescription?.contains("IRR calculation failed") == true)
        #expect(error.errorDescription?.contains("Failed to converge") == true)
    }

    @Test("Calculation failed error - with suggestions")
    func calculationFailedWithSuggestions() {
        let error = BusinessMathError.calculationFailed(
            operation: "NPV",
            reason: "Negative discount rate",
            suggestions: [
                "Use a positive discount rate",
                "Check input data for errors"
            ]
        )

        #expect(error.errorDescription?.contains("Suggestions:") == true)
        #expect(error.errorDescription?.contains("Use a positive discount rate") == true)
        #expect(error.recoverySuggestion?.contains("Possible solutions:") == true)
        #expect(error.recoverySuggestion?.contains("• Use a positive discount rate") == true)
    }

    @Test("Division by zero error")
    func divisionByZero() {
        let error = BusinessMathError.divisionByZero(context: "revenue growth calculation")

        #expect(error.code == "E003")
        #expect(error.errorDescription?.contains("Division by zero") == true)
        #expect(error.errorDescription?.contains("revenue growth calculation") == true)
        #expect(error.recoverySuggestion?.contains("Zero revenue") == true)
        #expect(error.recoverySuggestion?.contains("zero base values") == true)
    }

    @Test("Numerical instability error")
    func numericalInstability() {
        let error = BusinessMathError.numericalInstability(
            message: "Values too large for calculation",
            suggestions: ["Scale inputs to smaller range", "Use logarithmic transformation"]
        )

        #expect(error.code == "E004")
        #expect(error.errorDescription?.contains("Numerical instability") == true)
        #expect(error.recoverySuggestion?.contains("Scale inputs") == true)
    }

    // MARK: - Data Errors (E100-E199)

    @Test("Mismatched dimensions error - basic")
    func mismatchedDimensionsBasic() {
        let error = BusinessMathError.mismatchedDimensions(
            message: "Time series have different lengths"
        )

        #expect(error.code == "E100")
        #expect(error.errorDescription?.contains("Mismatched dimensions") == true)
        #expect(error.recoverySuggestion?.contains("matching periods") == true)
    }

    @Test("Mismatched dimensions error - with expected/actual")
    func mismatchedDimensionsWithContext() {
        let error = BusinessMathError.mismatchedDimensions(
            message: "Array size mismatch",
            expected: "12 periods",
            actual: "10 periods"
        )

        #expect(error.errorDescription?.contains("expected: 12 periods") == true)
        #expect(error.errorDescription?.contains("got: 10 periods") == true)
    }

    @Test("Data quality error")
    func dataQuality() {
        let error = BusinessMathError.dataQuality(
            message: "Missing or invalid values detected",
            context: ["count": "5", "percentage": "10%"]
        )

        #expect(error.code == "E101")
        #expect(error.errorDescription?.contains("Data quality issue") == true)
        #expect(error.errorDescription?.contains("count: 5") == true)
        #expect(error.errorDescription?.contains("percentage: 10%") == true)
        #expect(error.recoverySuggestion?.contains("Clean or interpolate") == true)
    }

    @Test("Missing data error")
    func missingData() {
        let error = BusinessMathError.missingData(
            account: "Revenue",
            period: "2024-Q1"
        )

        #expect(error.code == "E102")
        #expect(error.errorDescription?.contains("Missing data for 'Revenue'") == true)
        #expect(error.errorDescription?.contains("2024-Q1") == true)
        #expect(error.recoverySuggestion?.contains("Adding a driver") == true)
        #expect(error.recoverySuggestion?.contains("fillMissing()") == true)
    }

    @Test("Insufficient data error")
    func insufficientData() {
        let error = BusinessMathError.insufficientData(
            required: 10,
            actual: 5,
            context: "Regression analysis"
        )

        #expect(error.code == "E103")
        #expect(error.errorDescription?.contains("need 10, got 5") == true)
        #expect(error.errorDescription?.contains("Regression analysis") == true)
        #expect(error.recoverySuggestion?.contains("at least 10 data points") == true)
        #expect(error.recoverySuggestion?.contains("more historical data") == true)
    }

    // MARK: - Model Errors (E200-E299)

    @Test("Invalid driver error")
    func invalidDriver() {
        let error = BusinessMathError.invalidDriver(
            name: "RevenueGrowth",
            reason: "Growth rate cannot be negative"
        )

        #expect(error.code == "E200")
        #expect(error.errorDescription?.contains("Invalid driver 'RevenueGrowth'") == true)
        #expect(error.errorDescription?.contains("Growth rate cannot be negative") == true)
        #expect(error.recoverySuggestion?.contains("driver values are positive") == true)
    }

    @Test("Circular dependency error")
    func circularDependency() {
        let error = BusinessMathError.circularDependency(
            path: ["Revenue", "COGS", "GrossProfit", "Revenue"]
        )

        #expect(error.code == "E201")
        #expect(error.errorDescription?.contains("Circular dependency detected") == true)
        #expect(error.errorDescription?.contains("Revenue → COGS → GrossProfit → Revenue") == true)
        #expect(error.recoverySuggestion?.contains("Reordering calculations") == true)
        #expect(error.recoverySuggestion?.contains("iterative solver") == true)
        #expect(error.recoverySuggestion?.contains("intermediate value") == true)
    }

    @Test("Inconsistent data error")
    func inconsistentData() {
        let error = BusinessMathError.inconsistentData(
            description: "Total revenue does not equal sum of segments"
        )

        #expect(error.code == "E202")
        #expect(error.errorDescription?.contains("Data inconsistency") == true)
        #expect(error.errorDescription?.contains("Total revenue") == true)
        #expect(error.recoverySuggestion?.contains("logical consistency") == true)
    }

    // MARK: - Validation Errors (E300-E399)

    @Test("Validation failed error - single error")
    func validationFailedSingle() {
        let error = BusinessMathError.validationFailed(
            errors: ["Revenue must be positive"]
        )

        #expect(error.code == "E300")
        #expect(error.errorDescription?.contains("Validation failed with 1 error") == true)
        #expect(error.errorDescription?.contains("• Revenue must be positive") == true)
    }

    @Test("Validation failed error - multiple errors")
    func validationFailedMultiple() {
        let error = BusinessMathError.validationFailed(
            errors: [
                "Revenue must be positive",
                "Discount rate must be between 0 and 1",
                "Cash flows array cannot be empty"
            ]
        )

        #expect(error.errorDescription?.contains("Validation failed with 3 error") == true)
        #expect(error.errorDescription?.contains("• Revenue must be positive") == true)
        #expect(error.errorDescription?.contains("• Discount rate must be between 0 and 1") == true)
        #expect(error.errorDescription?.contains("• Cash flows array cannot be empty") == true)
        #expect(error.recoverySuggestion?.contains("Fix the validation errors") == true)
    }

    @Test("Negative value error")
    func negativeValue() {
        let error = BusinessMathError.negativeValue(
            name: "Price",
            value: -50.0,
            context: "Product pricing calculation"
        )

        #expect(error.code == "E301")
        #expect(error.errorDescription?.contains("Negative value for 'Price'") == true)
        #expect(error.errorDescription?.contains("(-50.0)") == true)
        #expect(error.errorDescription?.contains("Product pricing calculation") == true)
        #expect(error.recoverySuggestion?.contains("should not be negative") == true)
        #expect(error.recoverySuggestion?.contains("Input data is correct") == true)
    }

    @Test("Out of range error")
    func outOfRange() {
        let error = BusinessMathError.outOfRange(
            value: 1.5,
            min: 0.0,
            max: 1.0,
            context: "Discount rate validation"
        )

        #expect(error.code == "E302")
        #expect(error.errorDescription?.contains("Value 1.5 out of range") == true)
        #expect(error.errorDescription?.contains("[0.0, 1.0]") == true)
        #expect(error.errorDescription?.contains("Discount rate validation") == true)
        #expect(error.recoverySuggestion?.contains("within the valid range [0.0, 1.0]") == true)
    }

    // MARK: - Error Code Uniqueness

    @Test("All error codes are unique")
    func errorCodesUnique() {
        let allErrors: [BusinessMathError] = [
            .invalidInput(message: "test"),
            .calculationFailed(operation: "test", reason: "test"),
            .divisionByZero(context: "test"),
            .numericalInstability(message: "test"),
            .mismatchedDimensions(message: "test"),
            .dataQuality(message: "test"),
            .missingData(account: "test", period: "test"),
            .insufficientData(required: 1, actual: 0, context: "test"),
            .invalidDriver(name: "test", reason: "test"),
            .circularDependency(path: ["test"]),
            .inconsistentData(description: "test"),
            .validationFailed(errors: ["test"]),
            .negativeValue(name: "test", value: 0, context: "test"),
            .outOfRange(value: 0, min: 0, max: 1, context: "test")
        ]

        let codes = allErrors.map { $0.code }
        let uniqueCodes = Set(codes)

        #expect(codes.count == uniqueCodes.count, "All error codes should be unique")
        #expect(codes.count == 14, "Should have 14 distinct error types")
    }

    @Test("Error codes follow categorization scheme")
    func errorCodeCategorization() {
        // Calculation errors: E001-E099
        #expect(BusinessMathError.invalidInput(message: "").code.hasPrefix("E0"))
        #expect(BusinessMathError.calculationFailed(operation: "", reason: "").code.hasPrefix("E0"))

        // Data errors: E100-E199
        #expect(BusinessMathError.mismatchedDimensions(message: "").code.hasPrefix("E1"))
        #expect(BusinessMathError.dataQuality(message: "").code.hasPrefix("E1"))

        // Model errors: E200-E299
        #expect(BusinessMathError.invalidDriver(name: "", reason: "").code.hasPrefix("E2"))
        #expect(BusinessMathError.circularDependency(path: []).code.hasPrefix("E2"))

        // Validation errors: E300-E399
        #expect(BusinessMathError.validationFailed(errors: []).code.hasPrefix("E3"))
        #expect(BusinessMathError.negativeValue(name: "", value: 0, context: "").code.hasPrefix("E3"))
    }

    // MARK: - Help Anchor

    @Test("Help anchor URLs are generated")
    func helpAnchorGeneration() {
        let error = BusinessMathError.invalidInput(message: "test")

        #expect(error.helpAnchor?.contains("businessmath.com/errors/E001") == true)
    }

    // MARK: - Error Aggregator

    @Test("Error aggregator - empty")
    func errorAggregatorEmpty() throws {
        let aggregator = ErrorAggregator()

        #expect(aggregator.hasErrors == false)
        #expect(aggregator.count == 0)
        #expect(aggregator.allErrors.isEmpty)

        // Should not throw
        try aggregator.throwIfNeeded()
    }

    @Test("Error aggregator - single error")
    func errorAggregatorSingle() throws {
        var aggregator = ErrorAggregator()

        let error = BusinessMathError.invalidInput(message: "Test error")
        aggregator.add(error)

        #expect(aggregator.hasErrors == true)
        #expect(aggregator.count == 1)

        do {
            try aggregator.throwIfNeeded()
            Issue.record("Should have thrown")
        } catch let thrownError as BusinessMathError {
            #expect(thrownError.errorDescription?.contains("Test error") == true)
        }
    }

    @Test("Error aggregator - multiple errors")
    func errorAggregatorMultiple() throws {
        var aggregator = ErrorAggregator()

        aggregator.add(BusinessMathError.invalidInput(message: "Error 1"))
        aggregator.add(BusinessMathError.divisionByZero(context: "Error 2"))
        aggregator.add(BusinessMathError.missingData(account: "Revenue", period: "Q1"))

        #expect(aggregator.hasErrors == true)
        #expect(aggregator.count == 3)

        do {
            try aggregator.throwIfNeeded()
            Issue.record("Should have thrown")
        } catch let thrownError as BusinessMathError {
            // Should throw validationFailed with all errors
            if case .validationFailed(let errors) = thrownError {
                #expect(errors.count == 3)
                #expect(errors[0].contains("Error 1"))
            } else {
                Issue.record("Expected validationFailed error")
            }
        }
    }

    @Test("Error aggregator - addMany")
    func errorAggregatorAddMany() {
        var aggregator = ErrorAggregator()

        let errors: [Error] = [
            BusinessMathError.invalidInput(message: "Error 1"),
            BusinessMathError.invalidInput(message: "Error 2")
        ]

        aggregator.addMany(errors)

        #expect(aggregator.count == 2)
        #expect(aggregator.hasErrors == true)
    }

    @Test("Error aggregator - allErrors property")
    func errorAggregatorAllErrors() {
        var aggregator = ErrorAggregator()

        let error1 = BusinessMathError.invalidInput(message: "First")
        let error2 = BusinessMathError.divisionByZero(context: "Second")

        aggregator.add(error1)
        aggregator.add(error2)

        let allErrors = aggregator.allErrors
        #expect(allErrors.count == 2)
    }

    // MARK: - LocalizedError Protocol

    @Test("LocalizedError conformance")
    func localizedErrorConformance() {
        let error = BusinessMathError.calculationFailed(
            operation: "IRR",
            reason: "Non-convergent"
        )

        // Test as LocalizedError
        let localizedError: LocalizedError = error

        #expect(localizedError.errorDescription != nil)
        #expect(localizedError.recoverySuggestion != nil)
        #expect(localizedError.helpAnchor != nil)
    }

    // MARK: - Real-world Scenarios

    @Test("Financial model validation scenario")
    func financialModelValidation() throws {
        var aggregator = ErrorAggregator()

        // Simulate multiple validation errors in a financial model
        let revenue = -100.0
        if revenue < 0 {
            aggregator.add(BusinessMathError.negativeValue(
                name: "Revenue",
                value: revenue,
                context: "Income Statement"
            ))
        }

        let discountRate = 1.5
        if discountRate < 0 || discountRate > 1 {
            aggregator.add(BusinessMathError.outOfRange(
                value: discountRate,
                min: 0.0,
                max: 1.0,
                context: "DCF Valuation"
            ))
        }

        #expect(aggregator.count == 2)

        do {
            try aggregator.throwIfNeeded()
            Issue.record("Should have thrown validation error")
        } catch let error as BusinessMathError {
            if case .validationFailed(let errors) = error {
                #expect(errors.count == 2)
            } else {
                Issue.record("Expected validationFailed error")
            }
        }
    }

    @Test("Circular dependency detection scenario")
    func circularDependencyScenario() {
        let dependencyChain = ["Revenue", "Cost", "Margin", "Revenue"]
        let error = BusinessMathError.circularDependency(path: dependencyChain)

        let description = error.errorDescription ?? ""
        let recovery = error.recoverySuggestion ?? ""

        // Verify the full dependency path is shown
        #expect(description.contains("Revenue → Cost → Margin → Revenue"))

        // Verify recovery suggestions include multiple options
        #expect(recovery.contains("Reordering calculations"))
        #expect(recovery.contains("iterative solver"))
        #expect(recovery.contains("intermediate value"))
    }
}

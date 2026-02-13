//
//  ErrorHandlingExamples.swift
//  BusinessMath
//
//  Documentation examples for ErrorHandlingGuide.md
//  All examples in this file MUST compile and pass tests.
//  Update ErrorHandlingGuide.md from these examples, not vice versa.
//

import Testing
import Foundation
@testable import BusinessMath

// MARK: - Test Suite

@Suite("Error Handling Documentation Examples")
struct ErrorHandlingExamples {

    // MARK: - Calculation Errors (E001-E099)

    @Test("E001: Invalid Input - Negative discount rate")
    func invalidInputNegativeRate() throws {
        // Source: ErrorHandlingGuide.md - Invalid Input section
        let cashFlows = [-1000.0, 300.0, 400.0, 500.0]

        #expect(throws: BusinessMathError.self) {
			_ = try calculateNPV(discountRate: -0.5, cashFlows: cashFlows)
        }

        // Verify error details
        do {
            _ = try calculateNPV(discountRate: -0.5, cashFlows: cashFlows)
            Issue.record("Should have thrown")
        } catch let error as BusinessMathError {
            if case .invalidInput = error {
                #expect(error.code == "E001")
                #expect(error.errorDescription != nil)
                #expect(error.recoverySuggestion != nil)
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("E001: Invalid Input - Empty cash flows")
    func invalidInputEmptyCashFlows() throws {
        #expect(throws: BusinessMathError.self) {
            _ = try calculateNPV(discountRate: 0.10, cashFlows: [])
        }
    }

    @Test("E002: Calculation Failed - IRR with all positive flows")
    func calculationFailedIRR() throws {
        // Source: ErrorHandlingGuide.md - Calculation Failed section
        let allPositiveFlows = [100.0, 100.0, 100.0]

        // IRR requires both negative and positive cash flows
        do {
            _ = try irr(cashFlows: allPositiveFlows)
            Issue.record("Should have thrown")
        } catch let error as BusinessMathError {
            if case .calculationFailed(let operation, let reason, let suggestions) = error {
                #expect(operation.contains("IRR"))
				#expect(!reason.isEmpty)
                #expect(!suggestions.isEmpty)
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("E003: Division by Zero")
    func divisionByZero() throws {
        // Source: ErrorHandlingGuide.md - Division by Zero section
        #expect(throws: BusinessMathError.self) {
            _ = try growthRate(from: 0, to: 100)
        }

        do {
            _ = try growthRate(from: 0, to: 100)
        } catch let error as BusinessMathError {
            if case .divisionByZero = error {
                #expect(error.code == "E003")
            }
        }
    }

    // MARK: - Data Errors (E100-E199)

    @Test("E100: Mismatched Dimensions - TimeSeries")
    func mismatchedDimensionsTimeSeries() throws {
        // Source: ErrorHandlingGuide.md - Mismatched Dimensions section
        let periods = [
            Period.month(year: 2025, month: 1),
            Period.month(year: 2025, month: 2),
            Period.month(year: 2025, month: 3)
        ]
        let values = [100.0, 110.0]  // Only 2 values for 3 periods!

        #expect(throws: BusinessMathError.self) {
            _ = try TimeSeries(validating: periods, values: values)
        }

        do {
            _ = try TimeSeries(validating: periods, values: values)
        } catch let error as BusinessMathError {
            if case .mismatchedDimensions(let message, let expected, let actual) = error {
				#expect(!message.isEmpty)
                #expect(expected == "3")
                #expect(actual == "2")
                #expect(error.code == "E100")
            }
        }
    }

    @Test("E101: Data Quality - NaN in TimeSeries")
    func dataQualityNaN() throws {
        // Source: ErrorHandlingGuide.md - Data Quality section
        let periods = [
            Period.month(year: 2025, month: 1),
            Period.month(year: 2025, month: 2),
            Period.month(year: 2025, month: 3)
        ]
        let values = [100.0, Double.nan, 120.0]

        let timeSeries = TimeSeries(periods: periods, values: values)

        // Validate should catch NaN
        #expect(throws: BusinessMathError.self) {
            try timeSeries.validateAndThrow()
        }

        // Non-throwing version returns detailed results
        let result = timeSeries.validate()
        #expect(!result.isValid)
        #expect(!result.errors.isEmpty)
    }

    @Test("E102: Missing Data - Account not found")
    func missingDataAccount() throws {
        // Source: ErrorHandlingGuide.md - Missing Data section
		let model = FinancialModel {
			RevenueComponent(name: "Product Sales", amount: 100_000)
        }

        #expect(throws: BusinessMathError.self) {
            let period = Period.quarter(year: 2025, quarter: 1)
            _ = try model.getValue(account: "Marketing Expenses", period: period)
        }

        do {
            let period = Period.quarter(year: 2025, quarter: 1)
            _ = try model.getValue(account: "Marketing Expenses", period: period)
        } catch let error as BusinessMathError {
            if case .missingData(let account, let period) = error {
				#expect(period.description == Period.quarter(year: 2025, quarter: 1).description)
                #expect(account == "Marketing Expenses")
                #expect(error.code == "E102")
            }
        }
    }

    @Test("E103: Insufficient Data - Linear Regression")
    func insufficientDataRegression() throws {
        // Source: ErrorHandlingGuide.md - Insufficient Data section
        // Linear regression requires at least 2 points
        let xValues = [1.0]
        let yValues = [2.0]

        #expect(throws: Error.self) {
            _ = try linearRegression(xValues, yValues)
        }
    }

    // MARK: - Validation Examples

    @Test("Validation with BMValidationResult")
    func validationWithResult() throws {
        // Source: ErrorHandlingGuide.md - showing non-throwing validation
        let periods = [
            Period.month(year: 2025, month: 1),
            Period.month(year: 2025, month: 2)
        ]
        let values = [100.0, Double.infinity]  // Infinite value

        let timeSeries = TimeSeries(periods: periods, values: values)
        let result = timeSeries.validate()

        #expect(!result.isValid)
        #expect(!result.errors.isEmpty)

        // Check that we can inspect specific error types
        let hasNumericalIssue = result.errors.contains { $0.type == .numericalIssue }
        #expect(hasNumericalIssue)
    }

    @Test("Error Aggregation Pattern")
    func errorAggregation() throws {
        // Source: ErrorHandlingGuide.md - Error Aggregation section
        var aggregator = ErrorAggregator()

        let revenue = -100.0
        let discountRate = 1.5
        let cashFlows: [Double] = []

        // Collect multiple errors
        if revenue < 0 {
            aggregator.add(BusinessMathError.negativeValue(
                name: "Revenue",
                value: revenue,
                context: "Income Statement"
            ))
        }

        if discountRate < 0 || discountRate > 1 {
            aggregator.add(BusinessMathError.outOfRange(
                value: discountRate,
                min: 0.0,
                max: 1.0,
                context: "DCF Valuation"
            ))
        }

        if cashFlows.isEmpty {
            aggregator.add(BusinessMathError.invalidInput(
                message: "Cash flows cannot be empty"
            ))
        }

        // Should throw with all collected errors
        #expect(throws: BusinessMathError.self) {
            try aggregator.throwIfNeeded()
        }

        do {
            try aggregator.throwIfNeeded()
        } catch let error as BusinessMathError {
            if case .validationFailed(let errors) = error {
                #expect(errors.count == 3)
            }
        }
    }

    // MARK: - Recovery Patterns

    @Test("Recovery with optional chaining")
    func recoveryWithOptional() throws {
        // Source: ErrorHandlingGuide.md - Recovery Strategies section
        let model = FinancialModel {
            RevenueAmount("Sales", 100_000)
        }

        let period = Period.quarter(year: 2025, quarter: 1)

        // Graceful fallback to default value
        let revenue = (try? model.getValue(account: "Sales", period: period)) ?? 0.0
        #expect(revenue > 0)

        let marketing = (try? model.getValue(account: "Marketing", period: period)) ?? 0.0
        #expect(marketing == 0.0)  // Falls back to default
    }

    @Test("Recovery with retry different parameters")
    func recoveryWithRetry() throws {
        // Source: ErrorHandlingGuide.md - showing retry with different guess
        let cashFlows = [-1000.0, 300.0, 400.0, 500.0]

        // Try with first guess
        var result = try? irr(cashFlows: cashFlows, guess: 0.1)

        // If fails, try different guess
        if result == nil {
            result = try? irr(cashFlows: cashFlows, guess: 0.5)
        }

        #expect(result != nil)
    }
}

// MARK: - Working Examples for Documentation

extension ErrorHandlingExamples {

    /// Complete working example for NPV error handling
    /// Source tag: npvErrorHandlingExample
    static func npvErrorHandlingExample() {
        do {
            // Use calculateNPV which validates inputs and throws errors
            let result = try calculateNPV(discountRate: 0.10, cashFlows: [-1000, 300, 400, 500])
			print("NPV: \(result.currency())")
        } catch let error as BusinessMathError {
            print(error.errorDescription!)
            print(error.recoverySuggestion!)
            print("Error Code: \(error.code)")
        } catch {
            print("Unexpected error: \(error)")
        }
    }

    /// Complete working example for TimeSeries validation
    /// Source tag: timeSeriesValidationExample
    static func timeSeriesValidationExample() {
        let periods = [
            Period.month(year: 2025, month: 1),
            Period.month(year: 2025, month: 2),
            Period.month(year: 2025, month: 3)
        ]
        let values = [100.0, 110.0, 120.0]

        do {
            let ts = try TimeSeries(validating: periods, values: values)
            try ts.validateAndThrow()
            print("TimeSeries is valid")
        } catch let error as BusinessMathError {
            print("Validation failed: \(error.errorDescription!)")
        } catch {
            print("Unexpected error: \(error)")
        }
    }

    /// Complete working example for model getValue
    /// Source tag: modelGetValueExample
    static func modelGetValueExample() {
        let model = FinancialModel {
            RevenueAmount("Product Sales", 100_000)
            CostAmount("COGS", 60_000)
        }

        do {
            let period = Period.quarter(year: 2025, quarter: 1)
            let revenue = try model.getValue(account: "Product Sales", period: period)
            print("Q1 Revenue: $\(revenue)")
        } catch let error as BusinessMathError {
            if case .missingData(let account, let period) = error {
                print("Missing data for '\(account)' in period \(period)")
                // Recovery: provide data or use default
            }
        } catch {
            print("Unexpected error: \(error)")
        }
    }
}

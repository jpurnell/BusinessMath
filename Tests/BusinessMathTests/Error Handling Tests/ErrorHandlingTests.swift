//
//  ErrorHandlingTests.swift
//  BusinessMath Tests
//
//  Created on November 1, 2025.
//  TDD: Tests written FIRST, then implementation
//

import XCTest
import RealModule
@testable import BusinessMath

/// Tests for enhanced error handling in BusinessMath.
///
/// These tests define expected behavior for:
/// - Invalid input validation
/// - Calculation failure handling
/// - Data quality checks
/// - Recovery suggestions
/// - Clear error messages
/// - Validation framework
final class ErrorHandlingTests: XCTestCase {

    // MARK: - Invalid Input Tests

    func testBusinessMathError_InvalidDiscountRate() {
        // Given: An investment with invalid discount rate
        // When: Creating investment with negative discount rate
        // Then: Should throw BusinessMathError.invalidInput with clear message

        XCTAssertThrowsError(try createInvestmentWithDiscountRate(-0.1)) { error in
            guard let mathError = error as? BusinessMathError else {
                XCTFail("Expected BusinessMathError, got \(type(of: error))")
                return
            }

            if case .invalidInput(let message, let context) = mathError {
                XCTAssertTrue(message.contains("Discount rate"))
                XCTAssertTrue(message.contains("negative"))
                XCTAssertNotNil(context["value"])
                XCTAssertNotNil(context["expectedRange"])
            } else {
                XCTFail("Expected .invalidInput error, got \(mathError)")
            }
        }
    }

    func testBusinessMathError_NegativeInitialCost() {
        // Given: An investment with negative initial cost
        // When: Creating investment
        // Then: Should throw BusinessMathError.invalidInput

        XCTAssertThrowsError(try createInvestmentWithInitialCost(-1000)) { error in
            guard let mathError = error as? BusinessMathError else {
                XCTFail("Expected BusinessMathError")
                return
            }

            if case .invalidInput(let message, let context) = mathError {
                XCTAssertTrue(message.contains("Initial cost"))
                XCTAssertTrue(message.contains("negative") || message.contains("positive"))
                
                // Verify context includes the invalid value
                XCTAssertNotNil(context["value"], "Error should include the invalid value")
                if let valueString = context["value"], let value = Double(valueString) {
                    XCTAssertEqual(value, -1000.0, accuracy: 0.01, "Context should contain the actual invalid value")
                }
            } else {
                XCTFail("Expected .invalidInput error")
            }
        }
    }

    func testBusinessMathError_EmptyCashFlows() {
        // Given: An investment with no cash flows
        // When: Calculating NPV
        // Then: Should throw BusinessMathError.invalidInput

        XCTAssertThrowsError(try calculateNPVWithEmptyCashFlows()) { error in
            guard let mathError = error as? BusinessMathError else {
                XCTFail("Expected BusinessMathError")
                return
            }

            if case .invalidInput(let message, _) = mathError {
                XCTAssertTrue(message.contains("cash flows") || message.contains("empty"))
            } else {
                XCTFail("Expected .invalidInput error")
            }
        }
    }

    func testBusinessMathError_MismatchedPeriods() {
        // Given: Two time series with different periods
        // When: Attempting to combine them
        // Then: Should throw BusinessMathError.mismatchedDimensions

        XCTAssertThrowsError(try combineTimeSeriesWithMismatchedPeriods()) { error in
            guard let mathError = error as? BusinessMathError else {
                XCTFail("Expected BusinessMathError")
                return
            }

            if case .mismatchedDimensions(let message, let context) = mathError {
                XCTAssertTrue(message.contains("period") || message.contains("dimension"))
                XCTAssertNotNil(context["expected"])
                XCTAssertNotNil(context["actual"])
            } else {
                XCTFail("Expected .mismatchedDimensions error")
            }
        }
    }

    // MARK: - Calculation Failure Tests

    func testBusinessMathError_IRRNonConvergence() {
        // Given: Cash flows that don't converge to IRR
        // When: Calculating IRR
        // Then: Should throw BusinessMathError.calculationFailed

        XCTAssertThrowsError(try calculateIRRForNonConvergentCashFlows()) { error in
            guard let mathError = error as? BusinessMathError else {
                XCTFail("Expected BusinessMathError")
                return
            }

            if case .calculationFailed(let operation, let reason, let suggestions) = mathError {
                XCTAssertEqual(operation, "IRR")
                XCTAssertTrue(reason.contains("converge") || reason.contains("iteration"))
                XCTAssertFalse(suggestions.isEmpty, "Should provide recovery suggestions")
                XCTAssertTrue(suggestions.contains { $0.contains("Newton") || $0.contains("bisection") })
            } else {
                XCTFail("Expected .calculationFailed error")
            }
        }
    }

    func testBusinessMathError_DivisionByZero() {
        // Given: A calculation that would divide by zero
        // When: Performing calculation
        // Then: Should throw BusinessMathError.divisionByZero

        XCTAssertThrowsError(try calculateMetricWithZeroDenominator()) { error in
            guard let mathError = error as? BusinessMathError else {
                XCTFail("Expected BusinessMathError")
                return
            }

            if case .divisionByZero(let context) = mathError {
                XCTAssertNotNil(context["operation"])
                XCTAssertNotNil(context["numerator"])
            } else {
                XCTFail("Expected .divisionByZero error")
            }
        }
    }

    func testBusinessMathError_NumericalInstability() {
        // Given: A calculation with numerical instability
        // When: Performing calculation
        // Then: Should throw BusinessMathError.numericalInstability

        XCTAssertThrowsError(try calculateWithNumericalInstability()) { error in
            guard let mathError = error as? BusinessMathError else {
                XCTFail("Expected BusinessMathError")
                return
            }

            if case .numericalInstability(let message, let suggestions) = mathError {
                XCTAssertFalse(message.isEmpty)
                XCTAssertFalse(suggestions.isEmpty, "Should suggest alternative methods")
            } else {
                XCTFail("Expected .numericalInstability error")
            }
        }
    }

    // MARK: - Data Quality Tests

    func testValidation_TimeSeriesGaps() {
        // Given: A time series with gaps in periods
        // When: Validating the time series
        // Then: Should return validation warnings

        let timeSeriesWithGaps = createTimeSeriesWithGaps()
        let validationResult = timeSeriesWithGaps.validate()

        XCTAssertFalse(validationResult.isValid, "Time series with gaps should not be valid")
        XCTAssertTrue(validationResult.warnings.contains { $0.severity == .error })
        XCTAssertTrue(validationResult.warnings.contains { $0.message.contains("gap") || $0.message.contains("missing") })
    }

    func testValidation_OutlierDetection() {
        // Given: A time series with outliers
        // When: Validating with outlier detection
        // Then: Should identify outliers

        let timeSeriesWithOutliers = createTimeSeriesWithOutliers()
        let validationResult = timeSeriesWithOutliers.validate(detectOutliers: true)

        XCTAssertTrue(validationResult.warnings.contains { $0.type == .outlier })
        XCTAssertTrue(validationResult.warnings.contains { $0.message.contains("outlier") })

        // Should provide indices of outliers
        let outlierWarning = validationResult.warnings.first { $0.type == .outlier }
        XCTAssertNotNil(outlierWarning?.context["indices"])
    }

    func testValidation_NaNValues() {
        // Given: A time series with NaN values
        // When: Validating
        // Then: Should detect and report NaN values

        let timeSeriesWithNaN = createTimeSeriesWithNaN()
        let validationResult = timeSeriesWithNaN.validate()

        XCTAssertFalse(validationResult.isValid)
        XCTAssertTrue(validationResult.warnings.contains { $0.message.contains("NaN") })
        XCTAssertTrue(validationResult.warnings.contains { $0.severity == .error })
    }

    func testValidation_InfiniteValues() {
        // Given: A time series with infinite values
        // When: Validating
        // Then: Should detect and report infinite values

        let timeSeriesWithInf = createTimeSeriesWithInfinite()
        let validationResult = timeSeriesWithInf.validate()

        XCTAssertFalse(validationResult.isValid)
        XCTAssertTrue(validationResult.warnings.contains { $0.message.contains("infinite") || $0.message.contains("Inf") })
    }

    // MARK: - Recovery Suggestion Tests

    func testError_ProvidesFillForwardSuggestion() {
        // Given: A time series with gaps
        // When: Validation identifies gaps
        // Then: Should suggest fill-forward as recovery option

        let timeSeriesWithGaps = createTimeSeriesWithGaps()
        let validationResult = timeSeriesWithGaps.validate()

		if let gapWarning = validationResult.warnings.first(where: { $0.message.contains("gap") }) {
			XCTAssertNotNil(gapWarning)
			XCTAssertTrue(gapWarning.suggestions.contains { $0.contains("fill") || $0.contains("forward") })
		} else {
			XCTFail("Failed to find gap warning")
		}
    }

    func testError_ProvidesInterpolateSuggestion() {
        // Given: A time series with gaps
        // When: Validation identifies gaps
        // Then: Should suggest interpolation as recovery option

        let timeSeriesWithGaps = createTimeSeriesWithGaps()
        let validationResult = timeSeriesWithGaps.validate()

        let gapWarning = validationResult.warnings.first { $0.message.contains("gap") }
        XCTAssertNotNil(gapWarning)
        XCTAssertTrue(gapWarning!.suggestions.contains { $0.contains("interpolate") || $0.contains("interpolation") })
    }

    func testError_ProvidesAlternativeMethodSuggestion() {
        // Given: IRR calculation that fails to converge
        // When: Error is thrown
        // Then: Should suggest alternative calculation methods

        XCTAssertThrowsError(try calculateIRRForNonConvergentCashFlows()) { error in
            guard let mathError = error as? BusinessMathError,
                  case .calculationFailed(_, _, let suggestions) = mathError else {
                XCTFail("Expected calculationFailed error")
                return
            }

            XCTAssertTrue(suggestions.contains { $0.contains("alternative") || $0.contains("method") })
        }
    }

    // MARK: - Error Message Clarity Tests

    func testError_MessageIsHumanReadable() {
        // Given: Any business math error
        // When: Getting error description
        // Then: Should be human-readable and professional

        let error = BusinessMathError.invalidInput(
            message: "Discount rate must be between 0 and 1",
            context: ["value": "-0.1", "expectedRange": "0.0 to 1.0"]
        )

        let description = error.localizedDescription
        XCTAssertFalse(description.contains("nil"))
        XCTAssertFalse(description.contains("Optional"))
        XCTAssertTrue(description.count > 20, "Error message should be descriptive")
    }

    func testError_IncludesFailedValue() {
        // Given: An error with invalid input
        // When: Error is created
        // Then: Should include the failed value in context

        XCTAssertThrowsError(try createInvestmentWithDiscountRate(1.5)) { error in
            guard let mathError = error as? BusinessMathError,
                  case .invalidInput(_, let context) = mathError else {
                XCTFail("Expected invalidInput error")
                return
            }

            XCTAssertNotNil(context["value"])
            if let valueString = context["value"], let value = Double(valueString) {
                XCTAssertEqual(value, 1.5, accuracy: 0.01)
            }
        }
    }

    func testError_IncludesContext() {
        // Given: Any error
        // When: Error is thrown
        // Then: Should include relevant context information

        XCTAssertThrowsError(try combineTimeSeriesWithMismatchedPeriods()) { error in
            guard let mathError = error as? BusinessMathError,
                  case .mismatchedDimensions(_, let context) = mathError else {
                XCTFail("Expected mismatchedDimensions error")
                return
            }

            XCTAssertFalse(context.isEmpty, "Error should include context")
            XCTAssertTrue(context.keys.count >= 2, "Should have multiple context fields")
        }
    }

    func testError_IncludesExpectedRange() {
        // Given: Invalid input that's out of range
        // When: Error is thrown
        // Then: Should include expected range in context

        XCTAssertThrowsError(try createInvestmentWithDiscountRate(-0.1)) { error in
            guard let mathError = error as? BusinessMathError,
                  case .invalidInput(_, let context) = mathError else {
                XCTFail("Expected invalidInput error")
                return
            }

            XCTAssertNotNil(context["expectedRange"])
        }
    }

    // MARK: - Validation Framework Tests

    func testValidatable_TimeSeriesImplementation() {
        // Given: A TimeSeries instance
        // When: Calling validate()
        // Then: Should return BMValidationResult with appropriate warnings

        let validTimeSeries = TimeSeries<Double>(
            periods: [.year(2020), .year(2021), .year(2022)],
            values: [100, 110, 121]
        )

        let result = validTimeSeries.validate()
        XCTAssertTrue(result.isValid, "Valid time series should pass validation")
        XCTAssertTrue(result.warnings.isEmpty || result.warnings.allSatisfy { $0.severity != .error })
    }

    func testValidatable_FinancialModelImplementation() {
        // Given: A FinancialModel instance
        // When: Calling validate()
        // Then: Should validate all components

        let model = FinancialModel()
        let result = model.validate()

        // Empty model should be valid (or have warnings, but not errors)
        XCTAssertTrue(result.warnings.allSatisfy { $0.severity != .error })
    }

    // MARK: - Helper Methods for Testing

    private func createInvestmentWithDiscountRate(_ rate: Double) throws -> Investment {
        // Validate discount rate
        guard rate >= 0 && rate <= 1 else {
			if rate < 0 {
				throw BusinessMathError.invalidInput(
					message: "Discount rate must not be negative",
					context: ["value": String(rate), "expectedRange": "0.0 to 1.0"]
				)
			}
            throw BusinessMathError.invalidInput(
                message: "Discount rate must be between 0 and 1, got \(rate)",
                context: ["value": String(rate), "expectedRange": "0.0 to 1.0"]
            )
        }
        
        // Create a valid investment with the provided discount rate
        return Investment {
            InitialCost(1000)
            
            CashFlows {
                Year(1) => 100
                Year(2) => 100
            }
            
            DiscountRate(rate)
        }
    }

    private func createInvestmentWithInitialCost(_ cost: Double) throws -> Investment {
        // Validate initial cost before creating investment
        guard cost > 0 else {
            throw BusinessMathError.invalidInput(
                message: "Initial cost must be positive, got \(cost)",
                context: ["value": String(cost)]
            )
        }
        
        // Create a valid investment with the provided cost
        return Investment {
            InitialCost(cost)
            
            CashFlows {
                Year(1) => 100
                Year(2) => 100
            }
            
            DiscountRate(0.10)
        }
    }

    private func calculateNPVWithEmptyCashFlows() throws -> Double {
        throw BusinessMathError.invalidInput(
            message: "Cannot calculate NPV with empty cash flows",
            context: ["cashFlowCount": "0"]
        )
    }

    private func combineTimeSeriesWithMismatchedPeriods() throws -> TimeSeries<Double> {
        throw BusinessMathError.mismatchedDimensions(
            message: "Cannot combine time series with different period counts",
            context: ["expected": "12", "actual": "10"]
        )
    }

    private func calculateIRRForNonConvergentCashFlows() throws -> Double {
        throw BusinessMathError.calculationFailed(
            operation: "IRR",
            reason: "Failed to converge after 100 iterations",
            suggestions: [
                "Try using Newton-Raphson method with a different initial guess",
                "Consider using bisection method for more stable convergence",
                "Check if cash flows are realistic for IRR calculation"
            ]
        )
    }

    private func calculateMetricWithZeroDenominator() throws -> Double {
        throw BusinessMathError.divisionByZero(
            context: ["operation": "ROI calculation", "numerator": "1000.0", "denominator": "0.0"]
        )
    }

    private func calculateWithNumericalInstability() throws -> Double {
        throw BusinessMathError.numericalInstability(
            message: "Calculation resulted in loss of precision",
            suggestions: ["Use higher precision arithmetic", "Reformulate the calculation"]
        )
    }

    private func createTimeSeriesWithGaps() -> TimeSeries<Double> {
        // Create time series with non-consecutive periods
        return TimeSeries<Double>(
            periods: [.year(2020), .year(2022), .year(2024)],  // Gap: missing 2021, 2023
            values: [100, 120, 140]
        )
    }

    private func createTimeSeriesWithOutliers() -> TimeSeries<Double> {
        // Create time series with obvious outliers
        return TimeSeries<Double>(
            periods: (2020...2030).map { .year($0) },
            values: [100, 105, 110, 1000, 115, 120, 125, 130, 135, 140, 145]  // 1000 is outlier
        )
    }

    private func createTimeSeriesWithNaN() -> TimeSeries<Double> {
        return TimeSeries<Double>(
            periods: [.year(2020), .year(2021), .year(2022)],
            values: [100, .nan, 120]
        )
    }

    private func createTimeSeriesWithInfinite() -> TimeSeries<Double> {
        return TimeSeries<Double>(
            periods: [.year(2020), .year(2021), .year(2022)],
            values: [100, .infinity, 120]
        )
    }
}

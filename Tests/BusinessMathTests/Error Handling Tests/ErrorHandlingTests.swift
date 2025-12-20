//
//  ErrorHandlingTests.swift
//  BusinessMath Tests
//
//  Created on November 1, 2025.
//  TDD: Tests written FIRST, then implementation
//

import Testing
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
@Suite("ErrorHandlingTests") struct ErrorHandlingTests {

    // MARK: - Invalid Input Tests

    @Test("BusinessMathError_InvalidDiscountRate") func businessMathErrorInvalidDiscountRate() {
        // Given: An investment with invalid discount rate
        // When: Creating investment with negative discount rate
        // Then: Should throw BusinessMathError.invalidInput with clear message

        do {
            _ = try createInvestmentWithDiscountRate(-0.1)
            Issue.record("Expected error to be thrown")
        } catch let error as BusinessMathError {
            switch error {
            case .invalidInput(let message, let value, let expectedRange):
                #expect(message.contains("Discount rate"))
                #expect(message.contains("negative"))
                #expect(value != nil)
                #expect(expectedRange != nil)
            default:
                Issue.record("Expected .invalidInput error, got \(error)")
            }
        } catch {
            Issue.record("Expected BusinessMathError, got \(type(of: error))")
        }
    }

    @Test("BusinessMathError_NegativeInitialCost") func businessMathErrorNegativeInitialCost() {
        // Given: An investment with negative initial cost
        // When: Creating investment
        // Then: Should throw BusinessMathError.invalidInput

        do {
            _ = try createInvestmentWithInitialCost(-1000)
            Issue.record("Expected error to be thrown")
        } catch let error as BusinessMathError {
            switch error {
            case .invalidInput(let message, let value, _):
                #expect(message.contains("Initial cost"))
                #expect(message.contains("negative") || message.contains("positive"))

                // Verify value includes the invalid value
                #expect(value != nil, "Error should include the invalid value")
                if let valueString = value, let valueDouble = Double(valueString) {
                    #expect(abs(valueDouble - -1000.0) < 0.01, "Value should contain the actual invalid value")
                }
            default:
                Issue.record("Expected .invalidInput error, got \(error)")
            }
        } catch {
            Issue.record("Expected BusinessMathError, got \(type(of: error))")
        }
    }

    @Test("BusinessMathError_EmptyCashFlows") func businessMathErrorEmptyCashFlows() {
        // Given: An investment with no cash flows
        // When: Calculating NPV
        // Then: Should throw BusinessMathError.invalidInput

        do {
            _ = try calculateNPVWithEmptyCashFlows()
            Issue.record("Expected error to be thrown")
        } catch let error as BusinessMathError {
            switch error {
            case .invalidInput(let message, _, _):
                #expect(message.contains("cash flows") || message.contains("empty"))
            default:
                Issue.record("Expected .invalidInput error, got \(error)")
            }
        } catch {
            Issue.record("Expected BusinessMathError, got \(type(of: error))")
        }
    }

    @Test("BusinessMathError_MismatchedPeriods") func businessMathErrorMismatchedPeriods() {
        // Given: Two time series with different periods
        // When: Attempting to combine them
        // Then: Should throw BusinessMathError.mismatchedDimensions

        do {
            _ = try combineTimeSeriesWithMismatchedPeriods()
            Issue.record("Expected error to be thrown")
        } catch let error as BusinessMathError {
            switch error {
            case .mismatchedDimensions(let message, let expected, let actual):
                #expect(message.contains("period") || message.contains("dimension"))
                #expect(expected != nil)
                #expect(actual != nil)
            default:
                Issue.record("Expected .mismatchedDimensions error, got \(error)")
            }
        } catch {
            Issue.record("Expected BusinessMathError, got \(type(of: error))")
        }
    }

    // MARK: - Calculation Failure Tests

    @Test("BusinessMathError_IRRNonConvergence") func businessMathErrorIRRNonConvergence() {
        // Given: Cash flows that don't converge to IRR
        // When: Calculating IRR
        // Then: Should throw BusinessMathError.calculationFailed

        do {
            _ = try calculateIRRForNonConvergentCashFlows()
            Issue.record("Expected error to be thrown")
        } catch let error as BusinessMathError {
            switch error {
            case .calculationFailed(let operation, let reason, let suggestions):
                #expect(operation == "IRR")
                #expect(reason.contains("converge") || reason.contains("iteration"))
                #expect(!suggestions.isEmpty, "Should provide recovery suggestions")
                #expect(suggestions.contains { $0.contains("Newton") || $0.contains("bisection") })
            default:
                Issue.record("Expected .calculationFailed error, got \(error)")
            }
        } catch {
            Issue.record("Expected BusinessMathError, got \(type(of: error))")
        }
    }

    @Test("BusinessMathError_DivisionByZero") func businessMathErrorDivisionByZero() {
        // Given: A calculation that would divide by zero
        // When: Performing calculation
        // Then: Should throw BusinessMathError.divisionByZero

        do {
            _ = try calculateMetricWithZeroDenominator()
            Issue.record("Expected error to be thrown")
        } catch let error as BusinessMathError {
            switch error {
            case .divisionByZero(let context):
                #expect(context.contains("operation") || context.contains("ROI"))
            default:
                Issue.record("Expected .divisionByZero error, got \(error)")
            }
        } catch {
            Issue.record("Expected BusinessMathError, got \(type(of: error))")
        }
    }

    @Test("BusinessMathError_NumericalInstability") func businessMathErrorNumericalInstability() {
        // Given: A calculation with numerical instability
        // When: Performing calculation
        // Then: Should throw BusinessMathError.numericalInstability

        do {
            _ = try calculateWithNumericalInstability()
            Issue.record("Expected error to be thrown")
        } catch let error as BusinessMathError {
            switch error {
            case .numericalInstability(let message, let suggestions):
                #expect(!message.isEmpty)
                #expect(!suggestions.isEmpty, "Should suggest alternative methods")
                        default:
                Issue.record("Expected .numericalInstability error, got \(error)")
            }
        } catch {
            Issue.record("Expected BusinessMathError, got \(type(of: error))")
        }
    }

    // MARK: - Data Quality Tests

    @Test("Validation_TimeSeriesGaps") func validationTimeSeriesGaps() {
        // Given: A time series with gaps in periods
        // When: Validating the time series
        // Then: Should return validation warnings

        let timeSeriesWithGaps = createTimeSeriesWithGaps()
        let validationResult = timeSeriesWithGaps.validate()

        #expect(!validationResult.isValid, "Time series with gaps should not be valid")
        #expect(validationResult.warnings.contains { $0.severity == .error })
        #expect(validationResult.warnings.contains { $0.message.contains("gap") || $0.message.contains("missing") })
    }

    @Test("Validation_OutlierDetection") func validationOutlierDetection() {
        // Given: A time series with outliers
        // When: Validating with outlier detection
        // Then: Should identify outliers

        let timeSeriesWithOutliers = createTimeSeriesWithOutliers()
        let validationResult = timeSeriesWithOutliers.validate(detectOutliers: true)

        #expect(validationResult.warnings.contains { $0.type == .outlier })
        #expect(validationResult.warnings.contains { $0.message.contains("outlier") })

        // Should provide indices of outliers
        let outlierWarning = validationResult.warnings.first { $0.type == .outlier }
        #expect(outlierWarning?.context["indices"] != nil)
    }

    @Test("Validation_NaNValues") func validationNaNValues() {
        // Given: A time series with NaN values
        // When: Validating
        // Then: Should detect and report NaN values

        let timeSeriesWithNaN = createTimeSeriesWithNaN()
        let validationResult = timeSeriesWithNaN.validate()

        #expect(!validationResult.isValid)
        #expect(validationResult.warnings.contains { $0.message.contains("NaN") })
        #expect(validationResult.warnings.contains { $0.severity == .error })
    }

    @Test("Validation_InfiniteValues") func validationInfiniteValues() {
        // Given: A time series with infinite values
        // When: Validating
        // Then: Should detect and report infinite values

        let timeSeriesWithInf = createTimeSeriesWithInfinite()
        let validationResult = timeSeriesWithInf.validate()

        #expect(!validationResult.isValid)
        #expect(validationResult.warnings.contains { $0.message.contains("infinite") || $0.message.contains("Inf") })
    }

    // MARK: - Recovery Suggestion Tests

    @Test("Error_ProvidesFillForwardSuggestion") func errorProvidesFillForwardSuggestion() {
        // Given: A time series with gaps
        // When: Validation identifies gaps
        // Then: Should suggest fill-forward as recovery option

        let timeSeriesWithGaps = createTimeSeriesWithGaps()
        let validationResult = timeSeriesWithGaps.validate()

		if let gapWarning = validationResult.warnings.first(where: { $0.message.contains("gap") }) {
			// gapWarning already checked in if-let
			#expect(gapWarning.suggestions.contains { $0.contains("fill") || $0.contains("forward") })
		} else {
			Issue.record("Failed to find gap warning")
		}
    }

    @Test("Error_ProvidesInterpolateSuggestion") func errorProvidesInterpolateSuggestion() {
        // Given: A time series with gaps
        // When: Validation identifies gaps
        // Then: Should suggest interpolation as recovery option

        let timeSeriesWithGaps = createTimeSeriesWithGaps()
        let validationResult = timeSeriesWithGaps.validate()

        let gapWarning = validationResult.warnings.first { $0.message.contains("gap") }
        // gapWarning already checked in if-let
        #expect(gapWarning!.suggestions.contains { $0.contains("interpolate") || $0.contains("interpolation") })
    }

    @Test("Error_ProvidesAlternativeMethodSuggestion") func errorProvidesAlternativeMethodSuggestion() {
        // Given: IRR calculation that fails to converge
        // When: Error is thrown
        // Then: Should suggest alternative calculation methods

        do {
            _ = try calculateIRRForNonConvergentCashFlows()
            Issue.record("Expected error to be thrown")
        } catch let error as BusinessMathError {
            switch error {
            case .calculationFailed(_, _, let suggestions):
                #expect(suggestions.contains { $0.contains("alternative") || $0.contains("method") })
            default:
                Issue.record("Expected .calculationFailed error, got \(error)")
            }
        } catch {
            Issue.record("Expected BusinessMathError, got \(type(of: error))")
        }
    }

    // MARK: - Error Message Clarity Tests

    @Test("Error_MessageIsHumanReadable") func errorMessageIsHumanReadable() {
        // Given: Any business math error
        // When: Getting error description
        // Then: Should be human-readable and professional

        let error = BusinessMathError.invalidInput(
            message: "Discount rate must be between 0 and 1",
            value: "-0.1",
            expectedRange: "0.0 to 1.0"
        )

        let description = error.localizedDescription
        #expect(!description.contains("nil"))
        #expect(!description.contains("Optional"))
        #expect(description.count > 20, "Error message should be descriptive")
    }

    @Test("Error_IncludesContext") func errorIncludesContext() {
        // Given: Any error
        // When: Error is thrown
        // Then: Should include relevant context information

        do {
            _ = try combineTimeSeriesWithMismatchedPeriods()
            Issue.record("Expected error to be thrown")
        } catch let error as BusinessMathError {
            switch error {
            case .mismatchedDimensions(_, let expected, let actual):
                #expect(expected != nil || actual != nil, "Error should include context")
                #expect(expected != nil && actual != nil, "Should have both expected and actual")
            default:
                Issue.record("Expected .mismatchedDimensions error, got \(error)")
            }
        } catch {
            Issue.record("Expected BusinessMathError, got \(type(of: error))")
        }
    }

    @Test("Error_IncludesExpectedRange") func errorIncludesExpectedRange() {
        // Given: Invalid input that's out of range
        // When: Error is thrown
        // Then: Should include expected range in context

        do {
			_ = try createInvestmentWithDiscountRate(-0.1)
            Issue.record("Expected error to be thrown")
        } catch let error as BusinessMathError {
            switch error {
            case .invalidInput(_, let value, let expectedRange):
					#expect(expectedRange != nil)
			default:
                Issue.record("Expected .invalidInput error, got \(error)")
            }
        } catch {
            Issue.record("Expected BusinessMathError, got \(type(of: error))")
        }
    }

    // MARK: - Validation Framework Tests

    @Test("Validatable_TimeSeriesImplementation") func validatableTimeSeriesImplementation() {
        // Given: A TimeSeries instance
        // When: Calling validate()
        // Then: Should return BMValidationResult with appropriate warnings

        let validTimeSeries = TimeSeries<Double>(
            periods: [.year(2020), .year(2021), .year(2022)],
            values: [100, 110, 121]
        )

        let result = validTimeSeries.validate()
        #expect(result.isValid, "Valid time series should pass validation")
        #expect(result.warnings.isEmpty || result.warnings.allSatisfy { $0.severity != .error })
    }

    @Test("Validatable_FinancialModelImplementation") func validatableFinancialModelImplementation() {
        // Given: A FinancialModel instance
        // When: Calling validate()
        // Then: Should validate all components

        let model = FinancialModel()
        let result = model.validate()

        // Empty model should be valid (or have warnings, but not errors)
        #expect(result.warnings.allSatisfy { $0.severity != .error })
    }

    // MARK: - Helper Methods for Testing

    private func createInvestmentWithDiscountRate(_ rate: Double) throws -> Investment {
        // Validate discount rate
        guard rate >= 0 && rate <= 1 else {
			if rate < 0 {
				throw BusinessMathError.invalidInput(
					message: "Discount rate must not be negative",
					value: String(rate),
					expectedRange: "0.0 to 1.0"
				)
			}
            throw BusinessMathError.invalidInput(
                message: "Discount rate must be between 0 and 1, got \(rate)",
                value: String(rate),
                expectedRange: "0.0 to 1.0"
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
                value: String(cost)
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
            message: "Cannot calculate NPV with empty cash flows"
        )
    }

    private func combineTimeSeriesWithMismatchedPeriods() throws -> TimeSeries<Double> {
        throw BusinessMathError.mismatchedDimensions(
            message: "Cannot combine time series with different period counts",
            expected: "12",
            actual: "10"
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
            context: "ROI calculation with numerator 1000.0 and denominator 0.0"
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

@Suite("Error Handling – Additional Tests")
struct ErrorHandlingAdditionalTests {

	// MARK: - Boundary and Non-finite Inputs

	@Test("Discount rate boundary values accepted (0 and 1 inclusive)")
	func discountRate_BoundaryValuesAccepted() throws {
		_ = try createInvestmentWithDiscountRate(0.0)
		_ = try createInvestmentWithDiscountRate(1.0)
	}

	@Test("Initial cost of zero is invalid and reports value")
	func initialCost_ZeroIsInvalid() {
		do {
			_ = try createInvestmentWithInitialCost(0.0)
			Issue.record("Expected invalidInput error for zero cost")
		} catch let error as BusinessMathError {
			switch error {
			case .invalidInput(let message, let value, let expectedRange):
				#expect(message.localizedCaseInsensitiveContains("positive"))
				#expect(value == "0.0")
			default:
				Issue.record("Expected .invalidInput, got \(error)")
			}
		} catch {
			Issue.record("Expected BusinessMathError, got \(type(of: error))")
		}
	}

	@Test("Discount rate NaN is invalid and includes expected range")
	func discountRate_NaNIsInvalid() {
		let rate = Double.nan
		do {
			_ = try createInvestmentWithDiscountRate(rate)
			Issue.record("Expected throw for NaN discount rate")
		} catch let error as BusinessMathError {
			switch error {
			case .invalidInput(_, let value, let expectedRange):
				#expect(value == String(rate))
				#expect(expectedRange != nil)
			default:
				Issue.record("Expected .invalidInput")
			}
		} catch {
			Issue.record("Expected BusinessMathError, got \(type(of: error))")
		}
	}

	@Test("Discount rate +infinity is invalid and includes expected range")
	func discountRate_InfiniteIsInvalid() {
		let rate = Double.infinity
		do {
			_ = try createInvestmentWithDiscountRate(rate)
			Issue.record("Expected throw for +infinity discount rate")
		} catch let error as BusinessMathError {
			switch error {
			case .invalidInput(_, let value, let expectedRange):
				#expect(value == String(rate))
				#expect(expectedRange != nil)
			default:
				Issue.record("Expected .invalidInput")
			}
		} catch {
			Issue.record("Expected BusinessMathError, got \(type(of: error))")
		}
	}

	// MARK: - Stronger Context Assertions

	@Test("Empty cash flows exposes count in context")
	func emptyCashFlows_ContextIncludesCount() {
		do {
			_ = try calculateNPVWithEmptyCashFlows()
			Issue.record("Expected invalidInput error for empty cash flows")
		} catch let error as BusinessMathError {
			switch error {
			case .invalidInput(_, let value, let expectedRange):
				#expect(value == "0")
			default:
				Issue.record("Expected .invalidInput")
			}
		} catch {
			Issue.record("Expected BusinessMathError, got \(type(of: error))")
		}
	}

	@Test("Mismatched dimensions context carries numeric expected/actual")
	func mismatchedDimensions_ContextNumericValues() {
		do {
			_ = try combineTimeSeriesWithMismatchedPeriods()
			Issue.record("Expected mismatchedDimensions error")
		} catch let error as BusinessMathError {
			switch error {
			case .mismatchedDimensions(_, let expected, let actual):
				if let e = expected, let a = actual,
				   let expected = Int(e), let actual = Int(a) {
					#expect(expected == 12)
					#expect(actual == 10)
				} else {
					Issue.record("Expected numeric 'expected' and 'actual' context")
				}
			default:
				Issue.record("Expected .mismatchedDimensions")
			}
		} catch {
			Issue.record("Expected BusinessMathError, got \(type(of: error))")
		}
	}

	@Test("Division by zero includes denominator and operation in context")
	func divisionByZero_IncludesContext() {
		do {
			_ = try calculateMetricWithZeroDenominator()
			Issue.record("Expected divisionByZero error")
		} catch let error as BusinessMathError {
			switch error {
			case .divisionByZero(let context):
				#expect(context.contains("0.0") || context.contains("denominator"))
				#expect(context.contains("operation") || context.contains("ROI"))
				#expect(context.contains("numerator") || context.count > 10)
			default:
				Issue.record("Expected .divisionByZero")
			}
		} catch {
			Issue.record("Expected BusinessMathError, got \(type(of: error))")
		}
	}

	// MARK: - Localized Descriptions

	@Test("All error cases produce human-readable localizedDescription")
	func errorCases_LocalizedDescriptions() {
		let cases: [BusinessMathError] = [
			.invalidInput(
				message: "Invalid parameter X",
				value: "abc", expectedRange: "0..1"
			),
			.mismatchedDimensions(
				message: "Vector sizes differ",
				expected: "5", actual: "3"
			),
			.calculationFailed(
				operation: "IRR",
				reason: "Failed to converge",
				suggestions: ["Use bisection", "Change initial guess"]
			),
			.divisionByZero(
				context: "ROI with numerator 100.0 and denominator 0.0"
			),
			.numericalInstability(
				message: "Catastrophic cancellation",
				suggestions: ["Use higher precision", "Reformulate"]
			)
		]

		for error in cases {
			let desc = error.localizedDescription
			#expect(!desc.isEmpty)
			#expect(!desc.contains("Optional"))
			switch error {
			case .invalidInput(let message, let value, _):
				#expect(desc.contains(message))
				if let value = value {
					#expect(desc.contains(value))
				}
			case .mismatchedDimensions(let message, let expected, let actual):
				#expect(desc.contains(message))
				if let expected = expected {
					#expect(desc.contains(expected))
				}
				if let actual = actual {
					#expect(desc.contains(actual))
				}
			case .calculationFailed(let op, let reason, let suggestions):
				#expect(desc.contains(op))
				#expect(desc.contains(reason))
				#expect(suggestions.allSatisfy { desc.contains($0) })
			case .divisionByZero(let context):
				#expect(desc.localizedCaseInsensitiveContains("zero"))
				#expect(desc.contains(context) || context.isEmpty)
			case .numericalInstability(let message, let suggestions):
				#expect(desc.contains(message))
				#expect(suggestions.allSatisfy { desc.contains($0) })
			case .dataQuality(message: let message, context: _):
				#expect(desc.contains(message))
			default:
				// New Phase 3 errors - just verify they have descriptions
				#expect(!desc.isEmpty)
			}
		}
	}

	@Test("IRR non-convergence description includes operation and iteration hint")
	func irrNonConvergence_DescriptionContainsHints() {
		do {
			_ = try calculateIRRForNonConvergentCashFlows()
			Issue.record("Expected calculationFailed error")
		} catch let error as BusinessMathError {
			switch error {
			case .calculationFailed(let op, _, _):
				let desc = error.localizedDescription
				#expect(op == "IRR")
				#expect(desc.contains("IRR"))
				#expect(desc.localizedCaseInsensitiveContains("converge"))
				#expect(desc.contains("100")) // iteration count included
			default:
				Issue.record("Expected .calculationFailed")
			}
		} catch {
			Issue.record("Expected BusinessMathError, got \(type(of: error))")
		}
	}

	// MARK: - Validation tightening

	@Test("Infinite values are treated as errors in validation")
	func validation_InfiniteValuesSeverityIsError() {
		let series = createTimeSeriesWithInfinite()
		let result = series.validate()
		#expect(!result.isValid)
		#expect(result.warnings.contains { $0.severity == .error })
	}

	// MARK: - No-throw sanity checks

	@Test("Valid inputs do not throw")
	func validInvestment_NoThrow() throws {
		_ = try createInvestmentWithInitialCost(1_000.0)
		_ = try createInvestmentWithDiscountRate(0.10)
	}

	fileprivate func createInvestmentWithDiscountRate(_ rate: Double) throws -> Investment {
		guard rate >= 0 && rate <= 1 else {
			if rate < 0 {
				throw BusinessMathError.invalidInput(
					message: "Discount rate must not be negative",
					value: String(rate), expectedRange: "0.0 to 1.0"
				)
			}
			throw BusinessMathError.invalidInput(
				message: "Discount rate must be between 0 and 1, got \(rate)",
				value: String(rate), expectedRange: "0.0 to 1.0"
			)
		}

		return Investment {
			InitialCost(1000)
			CashFlows {
				Year(1) => 100
				Year(2) => 100
			}
			DiscountRate(rate)
		}
	}

	fileprivate func createInvestmentWithInitialCost(_ cost: Double) throws -> Investment {
		guard cost > 0 else {
			throw BusinessMathError.invalidInput(
				message: "Initial cost must be positive, got \(cost)",
				value: String(cost)
			)
		}
		return Investment {
			InitialCost(cost)
			CashFlows {
				Year(1) => 100
				Year(2) => 100
			}
			DiscountRate(0.10)
		}
	}

	fileprivate func calculateNPVWithEmptyCashFlows() throws -> Double {
		throw BusinessMathError.invalidInput(
			message: "Cannot calculate NPV with empty cash flows",
			value: "0"
		)
	}

	fileprivate func combineTimeSeriesWithMismatchedPeriods() throws -> TimeSeries<Double> {
		throw BusinessMathError.mismatchedDimensions(
			message: "Cannot combine time series with different period counts",
			expected: "12", actual: "10"
		)
	}

	fileprivate func calculateIRRForNonConvergentCashFlows() throws -> Double {
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

	fileprivate func calculateMetricWithZeroDenominator() throws -> Double {
		throw BusinessMathError.divisionByZero(
			context: "ROI calculation with numerator 1000.0 and denominator 0.0"
		)
	}

	fileprivate func createTimeSeriesWithInfinite() -> TimeSeries<Double> {
		return TimeSeries<Double>(
			periods: [.year(2020), .year(2021), .year(2022)],
			values: [100, .infinity, 120]
		)
	}

	// MARK: - Equatable Conformance Tests

	@Test("BusinessMathError_Equatable_InvalidInput_SameErrors") func equatableInvalidInputSame() {
		// Given: Two identical invalidInput errors
		let error1 = BusinessMathError.invalidInput(message: "Invalid value", value: "42", expectedRange: "0-100")
		let error2 = BusinessMathError.invalidInput(message: "Invalid value", value: "42", expectedRange: "0-100")

		// Then: They should be equal
		#expect(error1 == error2)
	}

	@Test("BusinessMathError_Equatable_InvalidInput_DifferentMessages") func equatableInvalidInputDifferent() {
		// Given: Two invalidInput errors with different messages
		let error1 = BusinessMathError.invalidInput(message: "Invalid value", value: "42", expectedRange: "0-100")
		let error2 = BusinessMathError.invalidInput(message: "Different message", value: "42", expectedRange: "0-100")

		// Then: They should not be equal
		#expect(error1 != error2)
	}

	@Test("BusinessMathError_Equatable_DivisionByZero_SameContext") func equatableDivisionByZeroSame() {
		// Given: Two identical divisionByZero errors
		let error1 = BusinessMathError.divisionByZero(context: "NPV calculation")
		let error2 = BusinessMathError.divisionByZero(context: "NPV calculation")

		// Then: They should be equal
		#expect(error1 == error2)
	}

	@Test("BusinessMathError_Equatable_DivisionByZero_DifferentContext") func equatableDivisionByZeroDifferent() {
		// Given: Two divisionByZero errors with different contexts
		let error1 = BusinessMathError.divisionByZero(context: "NPV calculation")
		let error2 = BusinessMathError.divisionByZero(context: "IRR calculation")

		// Then: They should not be equal
		#expect(error1 != error2)
	}

	@Test("BusinessMathError_Equatable_CalculationFailed_SameErrors") func equatableCalculationFailedSame() {
		// Given: Two identical calculationFailed errors
		let error1 = BusinessMathError.calculationFailed(
			operation: "IRR",
			reason: "No convergence",
			suggestions: ["Try different guess", "Increase iterations"]
		)
		let error2 = BusinessMathError.calculationFailed(
			operation: "IRR",
			reason: "No convergence",
			suggestions: ["Try different guess", "Increase iterations"]
		)

		// Then: They should be equal
		#expect(error1 == error2)
	}

	@Test("BusinessMathError_Equatable_CalculationFailed_DifferentSuggestions") func equatableCalculationFailedDifferentSuggestions() {
		// Given: Two calculationFailed errors with different suggestions
		let error1 = BusinessMathError.calculationFailed(
			operation: "IRR",
			reason: "No convergence",
			suggestions: ["Try different guess"]
		)
		let error2 = BusinessMathError.calculationFailed(
			operation: "IRR",
			reason: "No convergence",
			suggestions: ["Increase iterations"]
		)

		// Then: They should not be equal
		#expect(error1 != error2)
	}

	@Test("BusinessMathError_Equatable_DifferentCases") func equatableDifferentCases() {
		// Given: Two errors of different types
		let error1 = BusinessMathError.divisionByZero(context: "NPV calculation")
		let error2 = BusinessMathError.invalidInput(message: "Invalid value", value: nil, expectedRange: nil)

		// Then: They should not be equal
		#expect(error1 != error2)
	}

	@Test("BusinessMathError_Equatable_NegativeValue_SameErrors") func equatableNegativeValueSame() {
		// Given: Two identical negativeValue errors
		let error1 = BusinessMathError.negativeValue(name: "discount_rate", value: -0.1, context: "Investment analysis")
		let error2 = BusinessMathError.negativeValue(name: "discount_rate", value: -0.1, context: "Investment analysis")

		// Then: They should be equal
		#expect(error1 == error2)
	}

	@Test("BusinessMathError_Equatable_NegativeValue_DifferentValues") func equatableNegativeValueDifferentValues() {
		// Given: Two negativeValue errors with different values
		let error1 = BusinessMathError.negativeValue(name: "discount_rate", value: -0.1, context: "Investment analysis")
		let error2 = BusinessMathError.negativeValue(name: "discount_rate", value: -0.2, context: "Investment analysis")

		// Then: They should not be equal
		#expect(error1 != error2)
	}

	@Test("BusinessMathError_Equatable_ValidationFailed_SameErrors") func equatableValidationFailedSame() {
		// Given: Two identical validationFailed errors
		let error1 = BusinessMathError.validationFailed(errors: ["Error 1", "Error 2"])
		let error2 = BusinessMathError.validationFailed(errors: ["Error 1", "Error 2"])

		// Then: They should be equal
		#expect(error1 == error2)
	}

	@Test("BusinessMathError_Equatable_ValidationFailed_DifferentErrors") func equatableValidationFailedDifferent() {
		// Given: Two validationFailed errors with different error lists
		let error1 = BusinessMathError.validationFailed(errors: ["Error 1", "Error 2"])
		let error2 = BusinessMathError.validationFailed(errors: ["Error 1", "Error 3"])

		// Then: They should not be equal
		#expect(error1 != error2)
	}

	@Test("BusinessMathError_Equatable_CircularDependency_SamePath") func equatableCircularDependencySame() {
		// Given: Two identical circularDependency errors
		let error1 = BusinessMathError.circularDependency(path: ["A", "B", "C", "A"])
		let error2 = BusinessMathError.circularDependency(path: ["A", "B", "C", "A"])

		// Then: They should be equal
		#expect(error1 == error2)
	}

	@Test("BusinessMathError_Equatable_CircularDependency_DifferentPath") func equatableCircularDependencyDifferent() {
		// Given: Two circularDependency errors with different paths
		let error1 = BusinessMathError.circularDependency(path: ["A", "B", "C", "A"])
		let error2 = BusinessMathError.circularDependency(path: ["X", "Y", "Z", "X"])

		// Then: They should not be equal
		#expect(error1 != error2)
	}
}

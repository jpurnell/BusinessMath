//
//  ModelValidator.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - FinancialValidationRule

/// Protocol for validation rules that operate on financial projections.
public protocol FinancialValidationRule {
	/// Validates a financial projection.
	///
	/// - Parameter projection: The financial projection to validate.
	/// - Returns: The validation result.
	func validate(_ projection: FinancialProjection) -> ValidationResult
}

// MARK: - ValidationReport

/// A comprehensive report of validation results.
public struct ValidationReport: Sendable {
	/// Whether the validation passed (no errors).
	public let isValid: Bool

	/// All validation errors.
	public let errors: [ValidationError]

	/// All validation warnings.
	public let warnings: [ValidationError]

	/// A summary of the validation with emoji indicators.
	public let summary: String

	/// The timestamp when validation occurred.
	public let timestamp: Date

	/// Generates a detailed report with all errors and warnings.
	public var detailedReport: String {
		var report = "Validation Report\n"
		report += "Generated: \(timestamp)\n\n"
		report += summary + "\n\n"

		if !errors.isEmpty {
			report += "Errors (\(errors.count)):\n"
			for (index, error) in errors.enumerated() {
				report += "\(index + 1). \(error.description)\n"
			}
			report += "\n"
		}

		if !warnings.isEmpty {
			report += "Warnings (\(warnings.count)):\n"
			for (index, warning) in warnings.enumerated() {
				report += "\(index + 1). \(warning.description)\n"
			}
			report += "\n"
		}

		return report
	}
}

// MARK: - ModelValidator

/// Validates financial projections using a comprehensive set of rules.
///
/// `ModelValidator` runs standard financial validation rules plus any custom
/// rules, collecting errors and warnings into a detailed report.
///
/// ## Basic Usage
///
/// ```swift
/// let projection = try FinancialProjection.documentationFixture
/// let validator = ModelValidator<Double>()
/// let report = validator.validate(projection: financialProjection)
///
/// if report.isValid {
///     print("✅ Validation passed")
/// } else {
///     print(report.detailedReport)
/// }
/// ```
///
/// ## Custom Rules
///
/// ```swift
/// let projection = try FinancialProjection.documentationFixture
/// struct MinimumRevenueRule: FinancialValidationRule {
///     let minimumRevenue: Double
///
///     func validate(_ projection: FinancialProjection) -> ValidationResult {
///         // Custom validation logic
///     }
/// }
///
/// let customRule = MinimumRevenueRule(minimumRevenue: 50_000)
/// let validator = ModelValidator(financialRules: [customRule])
/// ```
public struct ModelValidator<T> where T: Real & Sendable & Codable & Comparable & FloatingPoint {

	// MARK: - Properties

	/// Custom financial validation rules.
	private let financialRules: [any FinancialValidationRule]

	/// The clock that stamps the ``ValidationReport`` this validator returns.
	///
	/// A report's `timestamp` made the returned value depend on the moment validation
	/// ran, so two runs over identical input were never equal. Supplying a
	/// ``FixedWallClock`` makes them so.
	public let clock: any WallClock

	// MARK: - Initialization

	/// Creates a model validator.
	///
	/// - Parameters:
	///   - financialRules: Optional custom financial validation rules.
	///   - clock: Stamps the reports this validator returns. Defaults to the system clock.
	public init(
		financialRules: [any FinancialValidationRule] = [],
		clock: any WallClock = SystemWallClock()
	) {
		self.financialRules = financialRules
		self.clock = clock
	}

	// MARK: - Validation

	/// Validates a financial projection.
	///
	/// Runs standard and custom validation rules, collecting all errors
	/// and warnings into a comprehensive report.
	///
	/// - Parameter projection: The financial projection to validate.
	/// - Returns: A validation report with results and summary.
	public func validate(projection: FinancialProjection) -> ValidationReport {
		var allErrors: [ValidationError] = []
		var allWarnings: [ValidationError] = []

		// Standard validation rules

		// Get entity from income statement
		let entity = projection.incomeStatement.entity

		// 1. Balance sheet must balance
		let balanceSheetRule = FinancialValidation.BalanceSheetBalances<Double>()
		let balanceSheetContext = ValidationContext(fieldName: "Balance Sheet", entity: entity)
		let balanceSheetResult = balanceSheetRule.validate(projection.balanceSheet, context: balanceSheetContext)

		switch balanceSheetResult {
		case .valid:
			break
		case .invalid(let errors):
			allErrors.append(contentsOf: errors)
		case .validWithWarnings(let warnings):
			allWarnings.append(contentsOf: warnings)
		}

		// 2. Revenue must be positive
		let revenueRule = FinancialValidation.PositiveRevenue<Double>()
		let revenueContext = ValidationContext(fieldName: "Income Statement", entity: entity)
		let revenueResult = revenueRule.validate(projection.incomeStatement, context: revenueContext)

		switch revenueResult {
		case .valid:
			break
		case .invalid(let errors):
			allErrors.append(contentsOf: errors)
		case .validWithWarnings(let warnings):
			allWarnings.append(contentsOf: warnings)
		}

		// 3. Gross margin should be reasonable
		let marginRule = FinancialValidation.ReasonableGrossMargin<Double>()
		let marginContext = ValidationContext(fieldName: "Income Statement", entity: entity)
		let marginResult = marginRule.validate(projection.incomeStatement, context: marginContext)

		switch marginResult {
		case .valid:
			break
		case .invalid(let errors):
			allErrors.append(contentsOf: errors)
		case .validWithWarnings(let warnings):
			allWarnings.append(contentsOf: warnings)
		}

		// Run custom financial rules
		for rule in financialRules {
			let result = rule.validate(projection)

			switch result {
			case .valid:
				break
			case .invalid(let errors):
				allErrors.append(contentsOf: errors)
			case .validWithWarnings(let warnings):
				allWarnings.append(contentsOf: warnings)
			}
		}

		// Generate summary
		let isValid = allErrors.isEmpty
		let emoji: String
		if !isValid {
			emoji = "❌"
		} else if !allWarnings.isEmpty {
			emoji = "⚠️"
		} else {
			emoji = "✅"
		}
		let scenarioName = projection.scenario.name
		let summary = "\(emoji) [\(scenarioName)] Validation \(isValid ? "PASSED" : "FAILED") - \(allErrors.count) errors, \(allWarnings.count) warnings"

		return ValidationReport(
			isValid: isValid,
			errors: allErrors,
			warnings: allWarnings,
			summary: summary,
			timestamp: clock.now
		)
	}
}

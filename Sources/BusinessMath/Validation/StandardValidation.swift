//
//  StandardValidation.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - StandardValidation

/// Standard validation rules for common scenarios.
///
/// `StandardValidation` provides a collection of reusable validation rules
/// for common validation scenarios in financial data.
///
/// ## Basic Usage
///
/// ```swift
/// let rule = StandardValidation.NonNegative<Double>()
/// let context = ValidationContext(fieldName: "Revenue")
/// let result = rule.validate(100.0, context: context)
///
/// if result.isValid {
///     print("Valid!")
/// }
/// ```
public enum StandardValidation {

	// MARK: - NonNegative

	/// Validates that a number is non-negative (>= 0).
	public struct NonNegative<T: Real & Comparable & Sendable>: ValidationRule {
		/// The type of value being validated.
		public typealias Value = T

		/// Creates a non-negative validation rule.
		public init() {}

		/// Validates that the value is non-negative (>= 0).
		/// - Parameters:
		///   - value: The value to validate
		///   - context: Validation context with field information
		/// - Returns: Valid if value >= 0, invalid otherwise
		public func validate(_ value: T?, context: ValidationContext) -> ValidationResult {
			guard let value = value else {
				return .invalid([ValidationError(
					field: context.fieldName,
					value: "nil",
					rule: "NonNegative",
					message: "\(context.fieldName) must not be nil"
				)])
			}

			if value >= .zero {
				return .valid
			}

			return .invalid([ValidationError(
				field: context.fieldName,
				value: value,
				rule: "NonNegative",
				message: "\(context.fieldName) must be non-negative (>= 0)",
				suggestion: "Check if the sign is correct or if this should be an expense"
			)])
		}
	}

	// MARK: - Positive

	/// Validates that a number is positive (> 0).
	public struct Positive<T: Real & Comparable & Sendable>: ValidationRule {
		/// The type of value being validated.
		public typealias Value = T

		/// Creates a positive validation rule.
		public init() {}

		/// Validates that the value is positive (> 0).
		/// - Parameters:
		///   - value: The value to validate
		///   - context: Validation context with field information
		/// - Returns: Valid if value > 0, invalid otherwise
		public func validate(_ value: T?, context: ValidationContext) -> ValidationResult {
			guard let value = value else {
				return .invalid([ValidationError(
					field: context.fieldName,
					value: "nil",
					rule: "Positive",
					message: "\(context.fieldName) must not be nil"
				)])
			}

			if value > .zero {
				return .valid
			}

			return .invalid([ValidationError(
				field: context.fieldName,
				value: value,
				rule: "Positive",
				message: "\(context.fieldName) must be positive (> 0)",
				suggestion: "Value must be greater than zero"
			)])
		}
	}

	// MARK: - Range

	/// Validates that a number falls within a specified range.
	public struct Range<T: Real & Comparable & Sendable>: ValidationRule {
		/// The type of value being validated.
		public typealias Value = T

		private let min: T
		private let max: T

		/// Creates a range validation rule.
		///
		/// - Parameters:
		///   - min: The minimum allowed value (inclusive).
		///   - max: The maximum allowed value (inclusive).
		public init(min: T, max: T) {
			self.min = min
			self.max = max
		}

		/// Validates that the value falls within the specified range.
		/// - Parameters:
		///   - value: The value to validate
		///   - context: Validation context with field information
		/// - Returns: Valid if min <= value <= max, invalid otherwise
		public func validate(_ value: T?, context: ValidationContext) -> ValidationResult {
			guard let value = value else {
				return .invalid([ValidationError(
					field: context.fieldName,
					value: "nil",
					rule: "Range",
					message: "\(context.fieldName) must not be nil"
				)])
			}

			if value >= min && value <= max {
				return .valid
			}

			return .invalid([ValidationError(
				field: context.fieldName,
				value: value,
				rule: "Range",
				message: "\(context.fieldName) must be between \(min) and \(max)",
				suggestion: "Adjust value to fall within the valid range"
			)])
		}
	}

	// MARK: - Required

	/// Validates that a value is not nil.
	public struct Required<T>: ValidationRule {
		public typealias Value = T
		
		/// Initializes the Rule
		public init() {}
		
		/// Confirms that the value is not nil
		public func validate(_ value: T?, context: ValidationContext) -> ValidationResult {
			guard value != nil else {
				return .invalid([ValidationError(
					field: context.fieldName,
					value: "nil",
					rule: "Required",
					message: "\(context.fieldName) is required",
					suggestion: "Provide a value for this field"
				)])
			}

			return .valid
		}
	}
}

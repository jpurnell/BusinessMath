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
		public typealias Value = T

		public init() {}

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
		public typealias Value = T

		public init() {}

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

		public init() {}

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

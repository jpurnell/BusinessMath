//
//  ValidationTypes.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation

// MARK: - ValidationContext

/// Context information for validation operations.
///
/// Provides metadata about the field being validated, including optional
/// entity, period, and custom metadata.
public struct ValidationContext {
	/// The name of the field being validated.
	public let fieldName: String

	/// The entity associated with this validation (optional).
	public let entity: Entity?

	/// The period associated with this validation (optional).
	public let period: Period?

	/// Additional metadata for validation context.
	public let metadata: [String: Any]

	/// Creates a validation context.
	///
	/// - Parameters:
	///   - fieldName: The name of the field being validated.
	///   - entity: Optional entity association.
	///   - period: Optional period association.
	///   - metadata: Optional additional metadata.
	public init(
		fieldName: String,
		entity: Entity? = nil,
		period: Period? = nil,
		metadata: [String: Any] = [:]
	) {
		self.fieldName = fieldName
		self.entity = entity
		self.period = period
		self.metadata = metadata
	}
}

// MARK: - ValidationError

/// An error encountered during validation.
public struct ValidationError: Error, CustomStringConvertible {
	/// The field that failed validation.
	public let field: String

	/// The value that failed validation.
	public let value: Any

	/// The name of the validation rule that failed.
	public let rule: String

	/// A human-readable error message.
	public let message: String

	/// An optional suggestion for fixing the error.
	public let suggestion: String?

	/// Creates a validation error.
	///
	/// - Parameters:
	///   - field: The field that failed validation.
	///   - value: The value that failed.
	///   - rule: The name of the rule that failed.
	///   - message: A descriptive error message.
	///   - suggestion: Optional suggestion for fixing the error.
	public init(
		field: String,
		value: Any,
		rule: String,
		message: String,
		suggestion: String? = nil
	) {
		self.field = field
		self.value = value
		self.rule = rule
		self.message = message
		self.suggestion = suggestion
	}

	public var description: String {
		var desc = "Validation Error (\(rule)) in '\(field)': \(message)\n"
		desc += "  Value: \(value)"
		if let suggestion = suggestion {
			desc += "\n  Suggestion: \(suggestion)"
		}
		return desc
	}
}

// MARK: - ValidationResult

/// The result of a validation operation.
public enum ValidationResult {
	/// Validation passed.
	case valid

	/// Validation failed with errors.
	case invalid([ValidationError])

	/// Validation passed but with warnings.
	case validWithWarnings([ValidationError])

	/// Whether the validation passed.
	public var isValid: Bool {
		switch self {
		case .valid, .validWithWarnings:
			return true
		case .invalid:
			return false
		}
	}

	/// Errors from validation (empty if valid).
	public var errors: [ValidationError] {
		switch self {
		case .valid, .validWithWarnings:
			return []
		case .invalid(let errors):
			return errors
		}
	}

	/// Warnings from validation (empty if no warnings).
	public var warnings: [ValidationError] {
		switch self {
		case .valid, .invalid:
			return []
		case .validWithWarnings(let warnings):
			return warnings
		}
	}
}

// MARK: - ValidationRule

/// A rule that validates a value.
public protocol ValidationRule {
	/// The type of value this rule validates.
	associatedtype Value

	/// Validates a value.
	///
	/// - Parameters:
	///   - value: The value to validate.
	///   - context: Context information for the validation.
	///
	/// - Returns: The validation result.
	func validate(_ value: Value?, context: ValidationContext) -> ValidationResult
}

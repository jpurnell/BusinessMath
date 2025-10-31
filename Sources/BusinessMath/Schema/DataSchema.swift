//
//  DataSchema.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation

// MARK: - FieldType

/// The type of a field in a data schema.
public indirect enum FieldType: Equatable, Sendable {
	/// String type
	case string

	/// Double type
	case double

	/// Integer type
	case int

	/// Boolean type
	case bool

	/// Date type
	case date

	/// Array type with element type
	case array(FieldType)

	/// Object (dictionary) type
	case object
}

// MARK: - FieldDefinition

/// Defines a field in a data schema.
///
/// `FieldDefinition` specifies the name, type, and optional description
/// of a field, and provides type validation.
public struct FieldDefinition: Sendable {
	/// The name of the field.
	public let name: String

	/// The type of the field.
	public let type: FieldType

	/// Optional description of the field.
	public let description: String?

	/// Creates a field definition.
	///
	/// - Parameters:
	///   - name: The name of the field.
	///   - type: The type of the field.
	///   - description: Optional description of the field.
	public init(name: String, type: FieldType, description: String? = nil) {
		self.name = name
		self.type = type
		self.description = description
	}

	/// Validates that a value matches the field's type.
	///
	/// - Parameter value: The value to validate.
	/// - Returns: True if the value matches the field type, false otherwise.
	public func validateType(_ value: Any) -> Bool {
		switch type {
		case .string:
			return value is String

		case .double:
			// Accept both Double and Int for double type
			return value is Double || value is Int

		case .int:
			return value is Int

		case .bool:
			return value is Bool

		case .date:
			// Accept Date objects or ISO 8601 date strings
			if value is Date {
				return true
			}
			if let string = value as? String {
				// Simple check for date-like string (YYYY-MM-DD)
				return string.range(of: #"^\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil
			}
			return false

		case .array(let elementType):
			guard let array = value as? [Any] else {
				return false
			}

			// Validate all elements match the element type
			let elementDef = FieldDefinition(name: "element", type: elementType)
			return array.allSatisfy { elementDef.validateType($0) }

		case .object:
			// Accept dictionaries (not arrays)
			if let dict = value as? [String: Any] {
				return true
			}
			if let dict = value as? [AnyHashable: Any] {
				// Also accept AnyHashable keys
				return true
			}
			return false
		}
	}
}

// MARK: - DataSchema

/// A schema defining the structure and types of data fields.
///
/// `DataSchema` provides validation of data dictionaries against a defined schema,
/// ensuring all required fields are present and all fields have correct types.
///
/// ## Basic Usage
///
/// ```swift
/// let schema = DataSchema(
///     version: 1,
///     requiredFields: [
///         FieldDefinition(name: "name", type: .string, description: "Company name"),
///         FieldDefinition(name: "revenue", type: .double, description: "Annual revenue")
///     ],
///     optionalFields: [
///         FieldDefinition(name: "notes", type: .string, description: "Additional notes")
///     ]
/// )
///
/// let data: [String: Any] = [
///     "name": "Acme Corp",
///     "revenue": 100_000.0
/// ]
///
/// let result = schema.validate(data)
/// if result.isValid {
///     print("Data is valid!")
/// } else {
///     for error in result.errors {
///         print(error.description)
///     }
/// }
/// ```
///
/// ## Type Validation
///
/// The schema validates various types:
/// - `.string`: String values
/// - `.double`: Double or Int values
/// - `.int`: Integer values
/// - `.bool`: Boolean values
/// - `.date`: Date objects or ISO 8601 date strings
/// - `.array(elementType)`: Arrays with elements of the specified type
/// - `.object`: Dictionary objects
///
/// ## Example with Arrays
///
/// ```swift
/// let schema = DataSchema(
///     version: 1,
///     requiredFields: [
///         FieldDefinition(name: "values", type: .array(.double)),
///         FieldDefinition(name: "metadata", type: .object)
///     ]
/// )
///
/// let data: [String: Any] = [
///     "values": [1.0, 2.0, 3.0],
///     "metadata": ["source": "manual", "verified": true]
/// ]
/// ```
public struct DataSchema: Sendable {
	/// The version of the schema.
	public let version: Int

	/// Fields that must be present in the data.
	public let requiredFields: [FieldDefinition]

	/// Fields that may be present in the data.
	public let optionalFields: [FieldDefinition]

	/// Creates a data schema.
	///
	/// - Parameters:
	///   - version: The version of the schema.
	///   - requiredFields: Fields that must be present.
	///   - optionalFields: Fields that may be present. Defaults to empty.
	public init(
		version: Int,
		requiredFields: [FieldDefinition],
		optionalFields: [FieldDefinition] = []
	) {
		self.version = version
		self.requiredFields = requiredFields
		self.optionalFields = optionalFields
	}

	/// Validates data against the schema.
	///
	/// Checks that:
	/// - All required fields are present
	/// - All required fields have the correct type
	/// - All optional fields (if present) have the correct type
	///
	/// - Parameter data: The data dictionary to validate.
	/// - Returns: A validation result with any errors found.
	public func validate(_ data: [String: Any]) -> ValidationResult {
		var errors: [ValidationError] = []

		// Check required fields
		for field in requiredFields {
			guard let value = data[field.name] else {
				// Missing required field
				errors.append(ValidationError(
					field: field.name,
					value: "nil",
					rule: "Required",
					message: "Required field '\(field.name)' is missing"
				))
				continue
			}

			// Check type
			if !field.validateType(value) {
				errors.append(ValidationError(
					field: field.name,
					value: value,
					rule: "Type",
					message: "Field '\(field.name)' has incorrect type (expected \(field.type))"
				))
			}
		}

		// Check optional fields (only if present)
		for field in optionalFields {
			if let value = data[field.name] {
				// Optional field is present, validate its type
				if !field.validateType(value) {
					errors.append(ValidationError(
						field: field.name,
						value: value,
						rule: "Type",
						message: "Field '\(field.name)' has incorrect type (expected \(field.type))"
					))
				}
			}
		}

		return errors.isEmpty ? .valid : .invalid(errors)
	}
}

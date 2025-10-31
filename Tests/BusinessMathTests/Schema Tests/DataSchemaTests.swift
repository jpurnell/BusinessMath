import Testing
import Foundation
@testable import BusinessMath

@Suite("Data Schema Tests")
struct DataSchemaTests {

	@Test("Create schema with required fields")
	func createSchema() throws {
		let schema = DataSchema(
			version: 1,
			requiredFields: [
				FieldDefinition(name: "name", type: .string, description: "Entity name"),
				FieldDefinition(name: "revenue", type: .double, description: "Revenue amount")
			],
			optionalFields: [
				FieldDefinition(name: "notes", type: .string, description: "Optional notes")
			]
		)

		#expect(schema.version == 1)
		#expect(schema.requiredFields.count == 2)
		#expect(schema.optionalFields.count == 1)
	}

	@Test("Validate data against schema - all fields present")
	func validateValidData() throws {
		let schema = DataSchema(
			version: 1,
			requiredFields: [
				FieldDefinition(name: "name", type: .string),
				FieldDefinition(name: "revenue", type: .double)
			]
		)

		let data: [String: Any] = [
			"name": "Acme Corp",
			"revenue": 100_000.0
		]

		let result = schema.validate(data)

		#expect(result.isValid)
		#expect(result.errors.isEmpty)
	}

	@Test("Validate data - missing required field")
	func validateMissingField() throws {
		let schema = DataSchema(
			version: 1,
			requiredFields: [
				FieldDefinition(name: "name", type: .string),
				FieldDefinition(name: "revenue", type: .double)
			]
		)

		let data: [String: Any] = [
			"name": "Acme Corp"
			// Missing "revenue"
		]

		let result = schema.validate(data)

		#expect(!result.isValid)
		#expect(result.errors.count == 1)
		#expect(result.errors[0].field == "revenue")
		#expect(result.errors[0].rule == "Required")
	}

	@Test("Validate data - incorrect type")
	func validateIncorrectType() throws {
		let schema = DataSchema(
			version: 1,
			requiredFields: [
				FieldDefinition(name: "revenue", type: .double)
			]
		)

		let data: [String: Any] = [
			"revenue": "not a number"  // Should be Double
		]

		let result = schema.validate(data)

		#expect(!result.isValid)
		#expect(result.errors[0].rule == "Type")
	}

	// MARK: - Field Type Validation

	@Test("Validate string type")
	func validateStringType() throws {
		let field = FieldDefinition(name: "name", type: .string)

		#expect(field.validateType("Acme Corp"))
		#expect(!field.validateType(123))
		#expect(!field.validateType(123.45))
	}

	@Test("Validate double type")
	func validateDoubleType() throws {
		let field = FieldDefinition(name: "revenue", type: .double)

		#expect(field.validateType(123.45))
		#expect(field.validateType(123))  // Int can be Double
		#expect(!field.validateType("123"))
	}

	@Test("Validate int type")
	func validateIntType() throws {
		let field = FieldDefinition(name: "count", type: .int)

		#expect(field.validateType(123))
		#expect(!field.validateType(123.45))
		#expect(!field.validateType("123"))
	}

	@Test("Validate bool type")
	func validateBoolType() throws {
		let field = FieldDefinition(name: "active", type: .bool)

		#expect(field.validateType(true))
		#expect(field.validateType(false))
		#expect(!field.validateType(1))
		#expect(!field.validateType("true"))
	}

	@Test("Validate date type")
	func validateDateType() throws {
		let field = FieldDefinition(name: "date", type: .date)

		#expect(field.validateType(Date()))
		#expect(field.validateType("2024-01-01"))  // String dates accepted
		#expect(!field.validateType(123))
	}

	@Test("Validate array type")
	func validateArrayType() throws {
		let field = FieldDefinition(name: "values", type: .array(.double))

		#expect(field.validateType([1.0, 2.0, 3.0]))
		#expect(field.validateType([1, 2, 3]))  // Int acceptable for double array
		#expect(!field.validateType([1.0, "2", 3.0]))  // Mixed types
		#expect(!field.validateType("not an array"))
	}

	@Test("Validate object type")
	func validateObjectType() throws {
		let field = FieldDefinition(name: "metadata", type: .object)

		#expect(field.validateType(["key": "value"]))
		#expect(field.validateType(["nested": ["key": "value"]]))
		#expect(!field.validateType("not an object"))
		#expect(!field.validateType([1, 2, 3]))
	}

	// MARK: - Optional Fields

	@Test("Optional fields not required")
	func optionalFields() throws {
		let schema = DataSchema(
			version: 1,
			requiredFields: [
				FieldDefinition(name: "name", type: .string)
			],
			optionalFields: [
				FieldDefinition(name: "notes", type: .string)
			]
		)

		// Data without optional field
		let data: [String: Any] = [
			"name": "Acme Corp"
		]

		let result = schema.validate(data)

		#expect(result.isValid)
	}

	@Test("Optional fields validated if present")
	func optionalFieldsValidated() throws {
		let schema = DataSchema(
			version: 1,
			requiredFields: [
				FieldDefinition(name: "name", type: .string)
			],
			optionalFields: [
				FieldDefinition(name: "revenue", type: .double)
			]
		)

		// Data with optional field of wrong type
		let data: [String: Any] = [
			"name": "Acme Corp",
			"revenue": "not a number"
		]

		let result = schema.validate(data)

		// Should fail because optional field has wrong type
		#expect(!result.isValid)
	}
}

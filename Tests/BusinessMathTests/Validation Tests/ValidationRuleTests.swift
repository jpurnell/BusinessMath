import Testing
import Foundation
@testable import BusinessMath

@Suite("Validation Rule Tests")
struct ValidationRuleTests {

	// MARK: - NonNegative Rule

	@Test("NonNegative rule - valid value")
	func nonNegativeValid() throws {
		let rule = StandardValidation.NonNegative<Double>()
		let context = ValidationContext(fieldName: "Revenue")

		let result = rule.validate(100.0, context: context)

		#expect(result.isValid)
		#expect(result.errors.isEmpty)
	}

	@Test("NonNegative rule - zero is valid")
	func nonNegativeZero() throws {
		let rule = StandardValidation.NonNegative<Double>()
		let context = ValidationContext(fieldName: "Revenue")

		let result = rule.validate(0.0, context: context)

		#expect(result.isValid)
	}

	@Test("NonNegative rule - negative value fails")
	func nonNegativeInvalid() throws {
		let rule = StandardValidation.NonNegative<Double>()
		let context = ValidationContext(fieldName: "Revenue")

		let result = rule.validate(-100.0, context: context)

		#expect(!result.isValid)
		#expect(result.errors.count == 1)
		#expect(result.errors[0].field == "Revenue")
		#expect(result.errors[0].rule == "NonNegative")
	}

	// MARK: - Positive Rule

	@Test("Positive rule - valid value")
	func positiveValid() throws {
		let rule = StandardValidation.Positive<Double>()
		let context = ValidationContext(fieldName: "Price")

		let result = rule.validate(10.0, context: context)

		#expect(result.isValid)
	}

	@Test("Positive rule - zero fails")
	func positiveZero() throws {
		let rule = StandardValidation.Positive<Double>()
		let context = ValidationContext(fieldName: "Price")

		let result = rule.validate(0.0, context: context)

		#expect(!result.isValid)
		#expect(result.errors[0].rule == "Positive")
	}

	@Test("Positive rule - negative fails")
	func positiveNegative() throws {
		let rule = StandardValidation.Positive<Double>()
		let context = ValidationContext(fieldName: "Price")

		let result = rule.validate(-5.0, context: context)

		#expect(!result.isValid)
	}

	// MARK: - Range Rule

	@Test("Range rule - value in range")
	func rangeValid() throws {
		let rule = StandardValidation.Range<Double>(min: 0.0, max: 100.0)
		let context = ValidationContext(fieldName: "Percentage")

		let result = rule.validate(50.0, context: context)

		#expect(result.isValid)
	}

	@Test("Range rule - value at boundaries")
	func rangeBoundaries() throws {
		let rule = StandardValidation.Range<Double>(min: 0.0, max: 100.0)
		let context = ValidationContext(fieldName: "Percentage")

		let resultMin = rule.validate(0.0, context: context)
		let resultMax = rule.validate(100.0, context: context)

		#expect(resultMin.isValid)
		#expect(resultMax.isValid)
	}

	@Test("Range rule - value below minimum")
	func rangeBelowMin() throws {
		let rule = StandardValidation.Range<Double>(min: 0.0, max: 100.0)
		let context = ValidationContext(fieldName: "Percentage")

		let result = rule.validate(-1.0, context: context)

		#expect(!result.isValid)
		#expect(result.errors[0].message.contains("between"))
	}

	@Test("Range rule - value above maximum")
	func rangeAboveMax() throws {
		let rule = StandardValidation.Range<Double>(min: 0.0, max: 100.0)
		let context = ValidationContext(fieldName: "Percentage")

		let result = rule.validate(101.0, context: context)

		#expect(!result.isValid)
	}

	// MARK: - Required Rule

	@Test("Required rule - value present")
	func requiredValid() throws {
		let rule = StandardValidation.Required<String>()
		let context = ValidationContext(fieldName: "Name")

		let result = rule.validate("John Doe", context: context)

		#expect(result.isValid)
	}

	@Test("Required rule - nil value fails")
	func requiredNil() throws {
		let rule = StandardValidation.Required<String>()
		let context = ValidationContext(fieldName: "Name")

		let result = rule.validate(nil, context: context)

		#expect(!result.isValid)
		#expect(result.errors[0].rule == "Required")
		#expect(result.errors[0].message.contains("required"))
	}

	// MARK: - Validation Context

	@Test("Validation context with metadata")
	func contextWithMetadata() throws {
		let context = ValidationContext(
			fieldName: "Revenue",
			entity: Entity(id: "TEST", primaryType: .ticker, name: "Test Co"),
			period: Period.quarter(year: 2024, quarter: 1),
			metadata: ["source": "manual_entry"]
		)

		#expect(context.fieldName == "Revenue")
		#expect(context.entity?.name == "Test Co")
		#expect(context.period != nil)
		#expect(context.metadata["source"] as? String == "manual_entry")
	}

	// MARK: - Validation Result

	@Test("Validation result - valid")
	func validationResultValid() throws {
		let result = ValidationResult.valid

		#expect(result.isValid)
		#expect(result.errors.isEmpty)
		#expect(result.warnings.isEmpty)
	}

	@Test("Validation result - invalid with errors")
	func validationResultInvalid() throws {
		let error = ValidationError(
			field: "Revenue",
			value: -100,
			rule: "NonNegative",
			message: "Value must be non-negative",
			suggestion: "Check if expense was entered as revenue"
		)

		let result = ValidationResult.invalid([error])

		#expect(!result.isValid)
		#expect(result.errors.count == 1)
		#expect(result.errors[0].field == "Revenue")
	}

	// MARK: - Validation Error

	@Test("Validation error description")
	func validationErrorDescription() throws {
		let error = ValidationError(
			field: "Revenue",
			value: -1000,
			rule: "NonNegative",
			message: "Revenue must be non-negative",
			suggestion: "Verify the sign of the value"
		)

		let description = error.description

		#expect(description.contains("Revenue"))
		#expect(description.contains("Revenue must be non-negative"))
		#expect(description.contains("-1000"))
		#expect(description.contains("Verify the sign"))
	}
}

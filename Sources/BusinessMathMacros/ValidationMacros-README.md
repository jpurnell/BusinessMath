# Validation Macros

## Overview

The BusinessMath validation macro system provides compile-time code generation for property validation. Use property-level validation attributes to mark constraints, and the `@Validated` macro generates all validation logic automatically.

## Status: ✅ Fully Implemented (v2.0)

All validation macros are production-ready and generate actual validation logic.

## Available Validation Attributes

### `@Positive`
Ensures a numeric property is greater than zero.

```swift
@Validated
struct Investment {
    @Positive var amount: Double
}

let inv = Investment(amount: -100)
inv.isValid  // false
inv.validationError  // "Validation failed for 'amount': must be positive (> 0) (value: -100.0)"
```

### `@NonNegative`
Ensures a numeric property is greater than or equal to zero.

```swift
@Validated
struct Account {
    @NonNegative var balance: Double
}

let acct = Account(balance: -50)
acct.isValid  // false
```

### `@Range(min...max)`
Ensures a numeric property falls within a closed range.

```swift
@Validated
struct Portfolio {
    @Range(0...1) var stockAllocation: Double  // 0% to 100%
    @Range(18...65) var age: Int
}

let portfolio = Portfolio(stockAllocation: 1.5, age: 25)
portfolio.isValid  // false (allocation > 1.0)
```

### `@Min(value)`
Ensures a numeric property is at least a minimum value.

```swift
@Validated
struct Loan {
    @Min(1000) var amount: Double
    @Min(1) var termYears: Int
}

let loan = Loan(amount: 500, termYears: 5)
loan.isValid  // false (amount < 1000)
```

### `@Max(value)`
Ensures a numeric property does not exceed a maximum value.

```swift
@Validated
struct Bond {
    @Max(1.0) var couponRate: Double
    @Max(30) var maturityYears: Int
}

let bond = Bond(couponRate: 0.05, maturityYears: 40)
bond.isValid  // false (maturityYears > 30)
```

### `@NonEmpty`
Ensures a collection or string is not empty.

```swift
@Validated
struct Portfolio {
    @NonEmpty var holdings: [Stock]
    @NonEmpty var name: String
}

let portfolio = Portfolio(holdings: [], name: "")
portfolio.isValid  // false (both empty)
```

## Generated Members

The `@Validated` macro generates three members on your struct:

### 1. `validate() throws`
Validates all properties and throws `ValidationError` on first failure.

```swift
do {
    try loan.validate()
    print("Validation passed!")
} catch let error as ValidationError {
    print("Failed: \(error)")
    // Prints property name, violation message, and value
}
```

### 2. `isValid: Bool`
Returns `true` if all validation rules pass, `false` otherwise.

```swift
if loan.isValid {
    processLoan(loan)
} else {
    showError("Invalid loan parameters")
}
```

### 3. `validationError: ValidationError?`
Returns the first validation error, or `nil` if all rules pass.

```swift
if let error = loan.validationError {
    print("Validation error: \(error.property)")
    print("Problem: \(error.violation)")
    print("Value: \(error.value ?? "nil")")
}
```

## ValidationError Type

The generated validation error provides structured information:

```swift
public struct ValidationError: Error, CustomStringConvertible {
    public let property: String       // Property name that failed
    public let violation: String      // Description of the violation
    public let value: Any?           // The invalid value (if applicable)

    public var description: String   // Formatted error message
}
```

## Complete Example

```swift
import BusinessMath

@Validated
struct LoanApplication {
    // Validation attributes
    @Positive var principal: Double
    @Range(0...1) var interestRate: Double
    @Min(1) var years: Int
    @Max(1_000_000) var maxAmount: Double
    @NonEmpty var borrowerName: String
    @NonEmpty var documents: [String]
}

// Valid application
let validLoan = LoanApplication(
    principal: 100_000,
    interestRate: 0.05,
    years: 30,
    maxAmount: 500_000,
    borrowerName: "John Doe",
    documents: ["income.pdf", "credit.pdf"]
)

print(validLoan.isValid)  // true

// Invalid application - negative principal
let invalidLoan = LoanApplication(
    principal: -50_000,  // ❌ Must be positive
    interestRate: 0.05,
    years: 30,
    maxAmount: 500_000,
    borrowerName: "Jane Smith",
    documents: ["income.pdf"]
)

print(invalidLoan.isValid)  // false

if let error = invalidLoan.validationError {
    print(error)
    // "Validation failed for 'principal': must be positive (> 0) (value: -50000.0)"
}

// Multiple violations - returns first one
let badLoan = LoanApplication(
    principal: -100,      // ❌ Not positive
    interestRate: 1.5,   // ❌ Out of range
    years: 0,            // ❌ Below minimum
    maxAmount: 2_000_000, // ❌ Above maximum
    borrowerName: "",    // ❌ Empty
    documents: []        // ❌ Empty
)

// validate() throws on first error
do {
    try badLoan.validate()
} catch let error as ValidationError {
    print("First error: \(error.property)")
    // "First error: principal"
}
```

## Multiple Validations on One Property

You can combine multiple validation attributes:

```swift
@Validated
struct Investment {
    @Positive
    @Max(1_000_000)
    var amount: Double
}

// Validates:
// 1. amount > 0 (Positive)
// 2. amount <= 1,000,000 (Max)
```

**Note**: Validations are checked in the order they appear. The first violation throws.

## Use Cases

### Financial Calculations
```swift
@Validated
struct NPVCalculation {
    @NonNegative var discountRate: Double
    @NonEmpty var cashFlows: [Double]
    @Min(1) var periods: Int
}
```

### Portfolio Management
```swift
@Validated
struct Portfolio {
    @Range(0...1) var stockAllocation: Double
    @Range(0...1) var bondAllocation: Double
    @Positive var totalValue: Double
    @NonEmpty var holdings: [Position]
}
```

### Loan Processing
```swift
@Validated
struct MortgageLoan {
    @Min(50_000) var principal: Double
    @Range(0.01...0.15) var interestRate: Double
    @Range(1...30) var termYears: Int
    @Range(0...1) var downPaymentPct: Double
}
```

## Integration with BusinessMath

Validation macros work seamlessly with other BusinessMath features:

```swift
@Validated
struct OptimizationProblem {
    // Combine with optimization macros
    @Variable(bounds: 0...1)
    @Range(0...1)  // Validation reinforces bounds
    var allocation: Double

    @Constraint
    func totalIsOne() -> Bool {
        return abs(allocation - 1.0) < 0.001
    }
}
```

## Playground Compatibility

Like all Swift macros, validation macros have limited support in Xcode Playgrounds due to compiler plugin loading issues. For best results:

✅ **Use in**: Regular Swift files, test targets, SPM executables
❌ **Limited in**: Xcode Playgrounds (.playground files)

**Workaround**: Move validation logic to test targets or Swift files in your SPM package.

## Testing Validation

```swift
import XCTest
import BusinessMath

final class ValidationTests: XCTestCase {
    func testPositiveValidation() {
        @Validated
        struct TestModel {
            @Positive var value: Double
        }

        let valid = TestModel(value: 100)
        XCTAssertTrue(valid.isValid)

        let invalid = TestModel(value: -100)
        XCTAssertFalse(invalid.isValid)
        XCTAssertNotNil(invalid.validationError)
    }
}
```

## Performance

Validation macros have **zero runtime overhead** beyond the generated validation code itself:

- Macro expansion happens at compile time
- Generated code is inlined and optimized by Swift compiler
- No reflection or dynamic dispatch
- Simple comparison operations (≤, ≥, contains, isEmpty)

## Error Messages

Validation errors are designed to be clear and actionable:

```
Validation failed for 'interestRate': must be within range 0.0...1.0 (value: 1.5)
Validation failed for 'principal': must be positive (> 0) (value: -50000.0)
Validation failed for 'years': must be at least 1 (value: 0)
Validation failed for 'couponRate': must be at most 1.0 (value: 1.5)
Validation failed for 'name': must not be empty
```

## Future Enhancements

Potential additions (not yet implemented):

- Custom validation functions: `@Custom(validate: myValidator)`
- Cross-property validation: `@Requires(other: "propertyName")`
- Conditional validation: `@ValidWhen(condition: ...)`
- Email/URL format validation
- Pattern matching with regex

## Related Documentation

- **Optimization Macros**: See `/Sources/BusinessMathMacros/README.md`
- **Macro Implementation**: See `/Sources/BusinessMathMacrosImpl/ValidationMacros.swift`
- **Macro Tests**: See `/Tests/BusinessMathMacrosTests/ValidationMacroTests.swift`

---

**Version**: 2.0.0
**Status**: Production Ready
**Last Updated**: 2026-01-08
**Author**: Enhanced with full validation logic generation

//
//  BusinessMathMacros.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-29.
//

/// Generates Model Context Protocol (MCP) tool definitions from functions.
///
/// This macro automatically creates the boilerplate needed to expose a function
/// as an MCP tool, including JSON schema generation, argument validation,
/// and result formatting.
///
/// ## Usage Example
///
/// ```swift
/// @MCPTool(description: "Calculate net present value")
/// func npv(rate: Double, cashFlows: [Double]) -> Double {
///     // Implementation
/// }
/// ```
///
/// The macro generates:
/// - Tool definition with name "npv"
/// - JSON schema for parameters
/// - Argument extraction and validation
/// - Result formatting
/// - Error handling
///
/// ## Parameters
/// - description: Human-readable description of what the tool does
///
/// ## Requirements
/// - Must be applied to a function declaration
/// - Function must have a return value
/// - Parameters must be JSON-serializable types
///
/// ## Supported Parameter Types
/// - Numbers: `Int`, `Double`, `Float`
/// - Strings: `String`
/// - Booleans: `Bool`
/// - Arrays: `[Int]`, `[Double]`, `[String]`
///
/// ## Optional Parameters
/// Functions with default parameter values are automatically handled:
///
/// ```swift
/// @MCPTool(description: "Calculate IRR")
/// func irr(cashFlows: [Double], guess: Double = 0.1) throws -> Double {
///     // Implementation
/// }
/// ```
///
/// ## Error Handling
/// Throwing functions are automatically wrapped with try-catch:
///
/// ```swift
/// @MCPTool(description: "May fail")
/// func riskyOperation(x: Double) throws -> Double {
///     // Errors automatically formatted in tool result
/// }
/// ```
@attached(peer, names: arbitrary)
public macro MCPTool(description: String) = #externalMacro(
    module: "BusinessMathMacrosImpl",
    type: "MCPToolMacro"
)

// MARK: - Validation Macros

/// Adds validation logic to struct properties based on property-level validation attributes.
///
/// Scans all properties for validation attributes (@Positive, @Range, @Min, @Max, @NonEmpty)
/// and generates a `validate()` method that checks all rules.
///
/// ## Generated Members
/// - `func validate() throws` - Validates all properties, throws ValidationError on failure
/// - `var isValid: Bool` - Returns true if all validation rules pass
/// - `var validationError: ValidationError?` - Returns the first validation error, or nil if valid
///
/// ## Usage Example
///
/// ```swift
/// @Validated
/// struct LoanCalculation {
///     @Positive var principal: Double
///     @Range(0...1) var interestRate: Double
///     @Min(1) var years: Int
///     @NonEmpty var description: String
/// }
///
/// let loan = LoanCalculation(principal: -1000, interestRate: 0.05, years: 5, description: "")
/// loan.isValid  // false
/// loan.validationError  // ValidationError: principal must be positive
///
/// try loan.validate()  // throws ValidationError
/// ```
///
/// ## Supported Validation Attributes
/// - `@Positive` - Value must be > 0
/// - `@NonNegative` - Value must be >= 0
/// - `@Range(min...max)` - Value must be within closed range
/// - `@Min(value)` - Value must be >= minimum
/// - `@Max(value)` - Value must be <= maximum
/// - `@NonEmpty` - Collection/String must not be empty
@attached(member, names: arbitrary)
public macro Validated() = #externalMacro(
    module: "BusinessMathMacrosImpl",
    type: "ValidatedMacro"
)

/// Marks a property as requiring positive values (> 0).
///
/// ## Usage Example
///
/// ```swift
/// @Validated
/// struct Investment {
///     @Positive var amount: Double
/// }
/// ```
@attached(peer)
public macro Positive() = #externalMacro(
    module: "BusinessMathMacrosImpl",
    type: "PositiveMacro"
)

/// Marks a property as requiring non-negative values (>= 0).
///
/// ## Usage Example
///
/// ```swift
/// @Validated
/// struct Account {
///     @NonNegative var balance: Double
/// }
/// ```
@attached(peer)
public macro NonNegative() = #externalMacro(
    module: "BusinessMathMacrosImpl",
    type: "NonNegativeMacro"
)

/// Marks a property as requiring values within a specified range.
///
/// ## Usage Example
///
/// ```swift
/// @Validated
/// struct Portfolio {
///     @Range(0...1) var stockAllocation: Double
///     @Range(0...100) var ageYears: Int
/// }
/// ```
@attached(peer)
public macro Range(_ range: ClosedRange<Double>) = #externalMacro(
    module: "BusinessMathMacrosImpl",
    type: "RangeMacro"
)

/// Marks a property as requiring a minimum value.
///
/// ## Usage Example
///
/// ```swift
/// @Validated
/// struct Loan {
///     @Min(1000) var amount: Double
///     @Min(1) var termYears: Int
/// }
/// ```
@attached(peer)
public macro Min(_ minimum: Double) = #externalMacro(
    module: "BusinessMathMacrosImpl",
    type: "MinMacro"
)

/// Marks a property as requiring a maximum value.
///
/// ## Usage Example
///
/// ```swift
/// @Validated
/// struct Bond {
///     @Max(1.0) var couponRate: Double
///     @Max(30) var maturityYears: Int
/// }
/// ```
@attached(peer)
public macro Max(_ maximum: Double) = #externalMacro(
    module: "BusinessMathMacrosImpl",
    type: "MaxMacro"
)

/// Marks a collection or string property as requiring non-empty values.
///
/// ## Usage Example
///
/// ```swift
/// @Validated
/// struct Portfolio {
///     @NonEmpty var holdings: [Stock]
///     @NonEmpty var name: String
/// }
/// ```
@attached(peer)
public macro NonEmpty() = #externalMacro(
    module: "BusinessMathMacrosImpl",
    type: "NonEmptyMacro"
)

// MARK: - Optimization Macros

/// Marks a property as an optimization variable with bounds.
///
/// ## Usage Example
///
/// ```swift
/// @OptimizationProblem
/// struct Portfolio {
///     @Variable(bounds: 0...1)
///     var stockAllocation: Double
/// }
/// ```
@attached(peer, names: arbitrary)
public macro Variable(bounds: ClosedRange<Double>) = #externalMacro(
    module: "BusinessMathMacrosImpl",
    type: "VariableMacro"
)

/// Defines a constraint for optimization problems.
///
/// ## Usage Example
///
/// ```swift
/// @OptimizationProblem
/// struct Portfolio {
///     @Constraint
///     func sumToOne() {
///         stocks + bonds == 1.0
///     }
/// }
/// ```
@attached(peer, names: arbitrary)
public macro Constraint() = #externalMacro(
    module: "BusinessMathMacrosImpl",
    type: "ConstraintMacro"
)

/// Defines the objective function for optimization.
///
/// ## Usage Example
///
/// ```swift
/// @OptimizationProblem
/// struct Portfolio {
///     @Objective
///     func sharpeRatio() -> Double {
///         return expectedReturn / volatility
///     }
/// }
/// ```
@attached(peer, names: arbitrary)
public macro Objective() = #externalMacro(
    module: "BusinessMathMacrosImpl",
    type: "ObjectiveMacro"
)

/// Generates builder initialization methods for structs.
///
/// ## Usage Example
///
/// ```swift
/// @BuilderInitializable
/// struct Portfolio {
///     var stocks: Double
///     var bonds: Double
/// }
/// ```
@attached(member, names: arbitrary)
public macro BuilderInitializable() = #externalMacro(
    module: "BusinessMathMacrosImpl",
    type: "BuilderInitializableMacro"
)

/// Generates async wrapper for synchronous functions.
///
/// ## Usage Example
///
/// ```swift
/// @AsyncWrapper
/// func calculate(x: Double) -> Double {
///     return x * 2
/// }
/// // Generates: func calculateAsync(x: Double) async -> Double
/// ```
@attached(peer, names: arbitrary)
public macro AsyncWrapper() = #externalMacro(
    module: "BusinessMathMacrosImpl",
    type: "AsyncWrapperMacro"
)

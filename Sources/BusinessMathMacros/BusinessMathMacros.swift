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

/// Adds compile-time validation to struct properties.
///
/// ## Usage Example
///
/// ```swift
/// @Validated
/// struct LoanCalculation {
///     @Positive var principal: Double
///     @Range(0...1) var interestRate: Double
///     @Positive var years: Int
/// }
/// ```
@attached(member, names: arbitrary)
public macro Validated() = #externalMacro(
    module: "BusinessMathMacrosImpl",
    type: "ValidatedMacro"
)

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

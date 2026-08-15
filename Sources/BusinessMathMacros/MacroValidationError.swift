//
//  MacroValidationError.swift
//  BusinessMath
//

/// The error thrown by the `validate()` method that ``Validated()`` generates.
///
/// This type lives in `BusinessMathMacros` — the module that declares the macros — because
/// that is the module a caller imports in order to write `@Validated`. It previously lived in
/// `BusinessMathMacrosImpl`, which is a `.macro` target: a compiler plugin that runs during
/// compilation and vends no types to compiled code. The generated `throw` could therefore
/// never resolve, and `@Validated` could not be used by anyone, in any module, at all.
///
/// It is named for its origin rather than called `ValidationError` because `BusinessMath`
/// already has a `ValidationError` — a different shape, for financial-model validation —
/// and a caller importing both modules would otherwise have to disambiguate every mention.
///
/// ## Example
///
/// ```swift
/// @Validated
/// struct LoanApplication {
///     @Positive var principal: Double
/// }
///
/// let application = LoanApplication(principal: -1_000)
/// do {
///     try application.validate()
/// } catch let error as MacroValidationError {
///     print(error.property)   // "principal"
///     print(error.violation)  // "must be positive"
/// }
/// ```
public struct MacroValidationError: Error, CustomStringConvertible {
    /// The name of the property that failed validation.
    public let property: String

    /// A description of the validation rule that was violated.
    public let violation: String

    /// The value that caused the validation failure, if available.
    public let value: (any Sendable)?

    /// Creates a validation error.
    ///
    /// - Parameters:
    ///   - property: The name of the property that failed validation.
    ///   - violation: A description of the rule that was violated.
    ///   - value: The offending value, when the generated code can supply one.
    public init(property: String, violation: String, value: (any Sendable)? = nil) {
        self.property = property
        self.violation = violation
        self.value = value
    }

    /// A human-readable description of the validation error.
    public var description: String {
        if let value = value {
            return "Validation failed for '\(property)': \(violation) (value: \(value))"
        } else {
            return "Validation failed for '\(property)': \(violation)"
        }
    }
}

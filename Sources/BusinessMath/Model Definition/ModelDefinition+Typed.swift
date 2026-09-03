import Foundation

/// Binding the typed layer to the model that evaluates it.
///
/// Every method here delegates to the string API immediately below it. Nothing in
/// this file evaluates anything, stores anything, or decides anything: the typed
/// layer is a **spelling**, and a model written with ``LineItem`` and ``Expr`` is
/// the same model as one written with strings — same definitions, same numbers.
///
/// That is the whole design. Two implementations of one semantics would drift
/// apart at whatever rate they were maintained, and the drift would show up as
/// numbers that disagree depending on how the model happened to be written.
extension ModelDefinition {

    /// Returns a copy with one more derivation, written in typed form.
    ///
    /// The unit of the expression must match the unit of the item, which is the
    /// check this overload exists for: `defining(ebitda, as: revenue.expr)` is
    /// fine, and `defining(ebitda, as: margin.expr)` does not compile.
    ///
    /// - Parameters:
    ///   - item: The line item being defined.
    ///   - expr: The expression producing it, of the same unit.
    /// - Returns: A definition set including it.
    public func defining<U: ModelUnit>(
        _ item: LineItem<U>, as expr: Expr<U>
    ) -> ModelDefinition<T> {
        var copy = self
        copy.define(item, as: expr)
        return copy
    }

    /// Adds or replaces a derivation, written in typed form.
    ///
    /// - Parameters:
    ///   - item: The line item being defined.
    ///   - expr: The expression producing it, of the same unit.
    public mutating func define<U: ModelUnit>(_ item: LineItem<U>, as expr: Expr<U>) {
        define(item.name, as: expr.formula)
        // Both sides. The item being defined is as much a declaration as the ones
        // its formula reads, and a conflict between the two is exactly the kind
        // this catches: defining a `Money` account from a `Ratio` of the same name.
        declare(UnitDeclaration(item))
        for declaration in expr.declarations { declare(declaration) }
    }

    /// The formula defining a line item, if it is derived rather than supplied.
    ///
    /// - Parameter item: The item.
    /// - Returns: The formula, or `nil` if the item is supplied or unknown.
    public func formula<U: ModelUnit>(for item: LineItem<U>) -> String? {
        formula(for: item.name)
    }

    /// Reads a line item's series out of an evaluation.
    ///
    /// A convenience over subscripting the result dictionary by name, and the
    /// point at which a typed model stops being typed: the values that come back
    /// are plain numbers, because a unit is a claim about what a number *means*
    /// and not a property of the number.
    ///
    /// - Parameters:
    ///   - item: The item to read.
    ///   - results: An evaluation's output.
    /// - Returns: The series, or `nil` when the model produced no such account.
    public func series<U: ModelUnit>(
        for item: LineItem<U>, in results: [String: TimeSeries<T>]
    ) -> TimeSeries<T>? {
        results[item.name]
    }
}

import Foundation

/// An expression over line items, carrying the unit of what it computes.
///
/// ## What this is, and is not
///
/// An `Expr` renders a string in the ``FormulaEvaluator`` grammar. It is a
/// **spelling** of the string API, not a second engine: what a model evaluates to
/// does not depend on which way it was written, and every typed binding delegates
/// downward. Nothing here computes anything.
///
/// ## The algebra
///
/// The unit is the point. Legal combinations have an overload; illegal ones simply
/// have none, so they fail to compile:
///
/// | Combination | Result | Why |
/// |---|---|---|
/// | `Money + Money` | `Money` | Amounts add |
/// | `Money * Ratio` | `Money` | Scaling by a dimensionless quantity |
/// | `Money * Rate` | `Money` | Applying a per-period rate |
/// | `Money / Money` | `Ratio` | A margin |
/// | `Money / Count` | `Money` | An amount per unit |
/// | `Money / Ratio` | `Money` | Grossing up |
/// | `Money + Ratio` | — | Adding a margin to a balance means nothing |
/// | `Money * Money` | — | Money squared is not a quantity |
///
/// The negative cases are verified by `Tests/CompileFailures/`, because a test
/// that compiles cannot observe an expression that does not.
///
/// ## Literals are explicit
///
/// `Expr` is deliberately **not** `ExpressibleByFloatLiteral`. A bare `0.4` would
/// infer its unit from context, which reintroduces exactly the ambiguity the units
/// exist to prevent, and produces the overload-resolution diagnostics Swift
/// reports worst. `revenue * ratio(0.4)` is three characters longer and cannot be
/// misread — and, measured, it is also what keeps type-checking fast: the solver
/// never infers a literal's type across an overload set.
public struct Expr<U: ModelUnit>: Sendable, Equatable {

    /// The rendered formula, in ``FormulaEvaluator`` grammar.
    public let formula: String

    /// Every line item this expression reads, with the unit it was read at.
    ///
    /// Rendering to a string is lossy: `[Interest Rate]` says nothing about
    /// whether that account is money or a rate, or what period a rate is per. The
    /// checks in ``ModelDefinition/validateUnits()`` need exactly that, so an
    /// expression carries it alongside the string rather than discarding it at the
    /// first operator.
    public let declarations: [UnitDeclaration]

    /// Creates an expression from an already-rendered formula.
    ///
    /// Internal: the public way to make one is from a ``LineItem`` or a literal
    /// constructor, so that every `Expr` carries a unit something vouched for.
    init(_ formula: String, _ declarations: [UnitDeclaration] = []) {
        self.formula = formula
        self.declarations = declarations
    }

    /// An expression reading one line item.
    ///
    /// - Parameter item: The item to read.
    /// - Returns: The expression.
    public static func item(_ item: LineItem<U>) -> Expr<U> {
        // Bracketed always. The grammar reads `&`, `/` and spaces as operators and
        // separators, so `Sales & Marketing` unbracketed arrives as three tokens
        // and `A/P` becomes a division.
        Expr("[\(item.name)]", [UnitDeclaration(item)])
    }

    /// An expression holding a constant of this unit.
    ///
    /// - Parameter value: The value.
    /// - Returns: The expression.
    public static func constant(_ value: Double) -> Expr<U> {
        Expr("\(value)")
    }
}

extension LineItem {

    /// This item as an expression.
    public var expr: Expr<U> { .item(self) }
}

// MARK: - Literals

/// A currency amount.
///
/// - Parameter value: The amount.
/// - Returns: The expression.
public func money(_ value: Double) -> Expr<Money> { .constant(value) }

/// A dimensionless proportion: a margin, a multiple.
///
/// - Parameter value: The proportion.
/// - Returns: The expression.
public func ratio(_ value: Double) -> Expr<Ratio> { .constant(value) }

/// A per-period rate.
///
/// - Parameters:
///   - value: The rate.
///   - basis: The period the rate is expressed per. Required at the call site
///     because a rate without one cannot be validated, and the commonest modelling
///     error this layer exists to catch is an annual rate applied monthly.
/// - Returns: The expression.
public func rate(_ value: Double, per basis: PeriodType) -> Expr<Rate> { .constant(value) }

/// A count of periods, units, or shares.
///
/// - Parameter value: The count.
/// - Returns: The expression.
public func count(_ value: Double) -> Expr<Count> { .constant(value) }

/// One plus a rate: the growth factor `(1 + g)`.
///
/// `revenue * (ratio(1) + growth)` does not compile, and correctly so — a
/// dimensionless one and a per-period rate are not the same dimension. But
/// `Revenue × (1 + g)` is the commonest line in financial modelling, so the factor
/// gets a name instead of an overload that would also admit `margin + growth`.
///
/// Naming it is a gain rather than a tax: a growth factor is a distinct quantity
/// from the rate it is built from, which `1 + g` never said.
///
/// - Parameter rate: The rate to build a factor from.
/// - Returns: `1 + rate`, as a dimensionless ratio.
public func factor(_ rate: Expr<Rate>) -> Expr<Ratio> {
    Expr("(1.0 + \(rate.formula))", rate.declarations)
}

// MARK: - Same-unit arithmetic

/// Adds two quantities of the same unit.
///
/// - Parameters:
///   - lhs: The left operand.
///   - rhs: The right operand.
/// - Returns: Their sum.
public func + <U: ModelUnit>(lhs: Expr<U>, rhs: Expr<U>) -> Expr<U> {
    Expr("(\(lhs.formula) + \(rhs.formula))", lhs.declarations + rhs.declarations)
}

/// Subtracts two quantities of the same unit.
///
/// - Parameters:
///   - lhs: The left operand.
///   - rhs: The right operand.
/// - Returns: Their difference.
public func - <U: ModelUnit>(lhs: Expr<U>, rhs: Expr<U>) -> Expr<U> {
    Expr("(\(lhs.formula) - \(rhs.formula))", lhs.declarations + rhs.declarations)
}

/// Negates a quantity.
///
/// - Parameter operand: The quantity.
/// - Returns: Its negation.
public prefix func - <U: ModelUnit>(operand: Expr<U>) -> Expr<U> {
    Expr("(0.0 - \(operand.formula))", operand.declarations)
}

// MARK: - Scaling

/// Scales money by a dimensionless proportion.
///
/// - Parameters:
///   - lhs: The amount.
///   - rhs: The proportion.
/// - Returns: The scaled amount.
public func * (lhs: Expr<Money>, rhs: Expr<Ratio>) -> Expr<Money> {
    Expr("(\(lhs.formula) * \(rhs.formula))", lhs.declarations + rhs.declarations)
}

/// Scales money by a dimensionless proportion.
///
/// - Parameters:
///   - lhs: The proportion.
///   - rhs: The amount.
/// - Returns: The scaled amount.
public func * (lhs: Expr<Ratio>, rhs: Expr<Money>) -> Expr<Money> {
    Expr("(\(lhs.formula) * \(rhs.formula))", lhs.declarations + rhs.declarations)
}

/// Applies a per-period rate to an amount.
///
/// - Parameters:
///   - lhs: The amount.
///   - rhs: The rate.
/// - Returns: The resulting amount.
public func * (lhs: Expr<Money>, rhs: Expr<Rate>) -> Expr<Money> {
    Expr("(\(lhs.formula) * \(rhs.formula))", lhs.declarations + rhs.declarations)
}

/// Applies a per-period rate to an amount.
///
/// - Parameters:
///   - lhs: The rate.
///   - rhs: The amount.
/// - Returns: The resulting amount.
public func * (lhs: Expr<Rate>, rhs: Expr<Money>) -> Expr<Money> {
    Expr("(\(lhs.formula) * \(rhs.formula))", lhs.declarations + rhs.declarations)
}

/// Composes two dimensionless proportions.
///
/// - Parameters:
///   - lhs: The left operand.
///   - rhs: The right operand.
/// - Returns: Their product.
public func * (lhs: Expr<Ratio>, rhs: Expr<Ratio>) -> Expr<Ratio> {
    Expr("(\(lhs.formula) * \(rhs.formula))", lhs.declarations + rhs.declarations)
}

// MARK: - Division

/// Divides one amount by another, giving a proportion — a margin.
///
/// - Parameters:
///   - lhs: The numerator.
///   - rhs: The denominator.
/// - Returns: The proportion.
public func / (lhs: Expr<Money>, rhs: Expr<Money>) -> Expr<Ratio> {
    Expr("(\(lhs.formula) / \(rhs.formula))", lhs.declarations + rhs.declarations)
}

/// Divides an amount by a count, giving an amount per unit.
///
/// - Parameters:
///   - lhs: The amount.
///   - rhs: The count.
/// - Returns: The amount per unit.
public func / (lhs: Expr<Money>, rhs: Expr<Count>) -> Expr<Money> {
    Expr("(\(lhs.formula) / \(rhs.formula))", lhs.declarations + rhs.declarations)
}

/// Grosses an amount up by a proportion.
///
/// - Parameters:
///   - lhs: The amount.
///   - rhs: The proportion.
/// - Returns: The grossed-up amount.
public func / (lhs: Expr<Money>, rhs: Expr<Ratio>) -> Expr<Money> {
    Expr("(\(lhs.formula) / \(rhs.formula))", lhs.declarations + rhs.declarations)
}

/// Divides one proportion by another.
///
/// - Parameters:
///   - lhs: The numerator.
///   - rhs: The denominator.
/// - Returns: The proportion.
public func / (lhs: Expr<Ratio>, rhs: Expr<Ratio>) -> Expr<Ratio> {
    Expr("(\(lhs.formula) / \(rhs.formula))", lhs.declarations + rhs.declarations)
}

// MARK: - Functions

/// The smaller of two quantities of the same unit.
///
/// - Parameters:
///   - lhs: The left operand.
///   - rhs: The right operand.
/// - Returns: The smaller.
public func min<U: ModelUnit>(_ lhs: Expr<U>, _ rhs: Expr<U>) -> Expr<U> {
    Expr("MIN(\(lhs.formula), \(rhs.formula))", lhs.declarations + rhs.declarations)
}

/// The larger of two quantities of the same unit.
///
/// - Parameters:
///   - lhs: The left operand.
///   - rhs: The right operand.
/// - Returns: The larger.
public func max<U: ModelUnit>(_ lhs: Expr<U>, _ rhs: Expr<U>) -> Expr<U> {
    Expr("MAX(\(lhs.formula), \(rhs.formula))", lhs.declarations + rhs.declarations)
}

/// The magnitude of a quantity, keeping its unit.
///
/// - Parameter operand: The quantity.
/// - Returns: Its magnitude.
public func abs<U: ModelUnit>(_ operand: Expr<U>) -> Expr<U> {
    Expr("ABS(\(operand.formula))", operand.declarations)
}

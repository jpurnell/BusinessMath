import Foundation

/// A dimensional marker for a line item or expression.
///
/// A unit is a **phantom** type: it exists to be checked and is never
/// instantiated, carries no storage, and costs nothing at runtime. Its whole
/// purpose is to make `revenue * margin` compile and `revenue + margin` not.
///
/// ## Why not simply `Unit`
///
/// `Foundation.Unit` exists — the base class of the `Measurement` API — and
/// essentially every consumer imports Foundation. Inside this module a local
/// declaration would shadow it and everything would look fine; from outside,
/// `Unit` becomes ambiguous at every use site. That is the worst shape a naming
/// problem can take, because the module that owns the name never sees it.
public protocol ModelUnit: Sendable {

    /// The unit's name, for diagnostics and generated source.
    static var symbol: String { get }
}

/// A currency amount: revenue, cost, a balance, a cash flow.
public enum Money: ModelUnit {

    /// The unit's name.
    public static var symbol: String { "money" }
}

/// A per-period rate: growth, interest, decay.
///
/// Carries a period basis on the ``LineItem`` rather than in the type — see
/// ``LineItem/basis``.
public enum Rate: ModelUnit {

    /// The unit's name.
    public static var symbol: String { "rate" }
}

/// A dimensionless ratio: a margin, a multiple, a percentage.
public enum Ratio: ModelUnit {

    /// The unit's name.
    public static var symbol: String { "ratio" }
}

/// A count of periods, units, or shares.
///
/// Named `Count` rather than `Duration`, which the proposal originally proposed
/// and the standard library already owns. `BusinessMath` uses `Duration`
/// unqualified in eight files and *extends* it in one, so declaring another would
/// shadow it module-wide — a landmine for every file written afterwards rather
/// than a set of call sites to fix. `Count` is also the more accurate word for
/// something that counts shares as readily as periods.
public enum Count: ModelUnit {

    /// The unit's name.
    public static var symbol: String { "count" }
}

/// A typed handle to a named line item in a model.
///
/// ## Why a handle rather than a string
///
/// ``ModelDefinition`` names its accounts with strings, which is what makes a
/// model serializable and what lets a spreadsheet importer target it. The cost is
/// that a misspelling is a runtime failure and a rename is a search-and-replace
/// over string literals. A `LineItem` is the same name held in a Swift value, so
/// the compiler holds it too: `revenu` does not compile, and rename works.
///
/// The typed layer is a **spelling**, not a second engine. Every typed binding
/// delegates to the string API beneath it, so what a model evaluates to does not
/// depend on which way it was written.
///
/// ## Why the unit is a phantom
///
/// `U` appears in no stored property. `LineItem<Money>("Revenue")` and
/// `LineItem<Ratio>("Revenue")` name the same account in the same model and are
/// different Swift types, which is the entire mechanism: the check happens before
/// a model is built, and nothing about it survives into evaluation.
///
/// ## Why this is not called `Account`
///
/// ``Account`` is taken, by a type on the financial-statement surface that is
/// generic over the *numeric* type rather than a unit. Both are public, both live
/// in this module, and `Account<Double>` and `Account<Money>` cannot coexist.
/// `LineItem` is what the domain calls a named quantity in a model, and unlike
/// `Line` it cannot be misread as a row index.
public struct LineItem<U: ModelUnit>: Sendable, Hashable {

    /// The name the model knows this item by.
    public let name: String

    /// For a ``Rate``, the period the rate is expressed per.
    ///
    /// A value rather than a second type parameter. A rate's period is data a
    /// model validates, not a dimension worth doubling every expression's type
    /// signature to track — and `validateUnits()` reports a mismatch with a better
    /// message than a compiler could. `nil` for every other unit.
    public let basis: PeriodType?

    /// Creates a handle to a named line item.
    ///
    /// - Parameters:
    ///   - name: The name the model knows it by.
    ///   - basis: For a rate, the period it is expressed per.
    public init(_ name: String, basis: PeriodType? = nil) {
        self.name = name
        self.basis = basis
    }
}

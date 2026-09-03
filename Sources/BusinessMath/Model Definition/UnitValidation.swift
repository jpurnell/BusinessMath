import Foundation

/// What a model was told about one line item.
///
/// A rendered formula is lossy: `[Interest Rate]` says nothing about whether that
/// account holds money or a rate, or what period a rate is expressed per. The
/// typed layer knows both at the moment it renders, and this is where that
/// knowledge is kept so the checks in ``ModelDefinition/validateUnits()`` have
/// something to check.
public struct UnitDeclaration: Sendable, Equatable, Hashable {

    /// The account name.
    public let name: String

    /// The unit's symbol, from ``ModelUnit/symbol``.
    ///
    /// A symbol rather than the type, because declarations of different units must
    /// sit in one collection to be compared with each other.
    public let symbol: String

    /// For a rate, the period it is expressed per.
    public let basis: PeriodType?

    /// Records what a line item declared.
    ///
    /// - Parameter item: The item.
    public init<U: ModelUnit>(_ item: LineItem<U>) {
        self.name = item.name
        self.symbol = U.symbol
        self.basis = item.basis
    }

    /// Records a declaration directly.
    ///
    /// - Parameters:
    ///   - name: The account name.
    ///   - symbol: The unit's symbol.
    ///   - basis: For a rate, the period it is expressed per.
    public init(name: String, symbol: String, basis: PeriodType? = nil) {
        self.name = name
        self.symbol = symbol
        self.basis = basis
    }
}

/// What unit validation can find that the compiler cannot.
///
/// The algebra in ``Expr`` rejects combinations wrong for *any* model: `money +
/// ratio` means nothing regardless of what is being modelled, and no model needs
/// to exist to say so. These are the errors that depend on the model — they are
/// well-typed expressions that are nonetheless wrong, and each evaluates cleanly
/// to a number nobody should trust.
public enum TypedModelError: Error, Sendable, Equatable {

    /// A rate never said what period it is expressed per.
    ///
    /// Without a basis the rate cannot be checked against the timeline at all, so
    /// the commonest error in this family becomes undetectable.
    case missingRateBasis(account: String)

    /// A rate declared per one period was applied over another.
    ///
    /// An annual rate on a monthly timeline is off by twelve, evaluates without
    /// complaint, and looks entirely plausible in a report. If the conversion is
    /// deliberate, declare the rate at the timeline's basis — saying so is the
    /// point, since a converted rate and an unconverted one are indistinguishable
    /// once both are just numbers.
    case rateBasisMismatch(account: String, declared: PeriodType, applied: PeriodType)

    /// Two line items share a name but were measured differently.
    ///
    /// One account cannot be both a balance and a percentage. Left alone, whichever
    /// declaration a reference resolves to decides the answer, which is a model
    /// that runs and is wrong.
    case conflictingUnits(name: String, String, String)
}

extension ModelDefinition {

    /// Checks the units this model was told about.
    ///
    /// ## What this can and cannot see
    ///
    /// Only what the typed API declared. A model written entirely with strings
    /// declares nothing, so this succeeds without checking anything — and a caller
    /// should not read that as evidence the model is sound. ``unitDeclarations``
    /// says plainly how much was known.
    ///
    /// ## The order of the checks
    ///
    /// Conflicts first. A name meaning two things makes every later question about
    /// it ambiguous, so reporting a basis mismatch on an account that is not one
    /// account would be reporting the second symptom of the first problem.
    ///
    /// - Throws: ``TypedModelError`` on the first problem found.
    public func validateUnits() throws {
        var byName: [String: UnitDeclaration] = [:]
        for declaration in unitDeclarations {
            guard let seen = byName[declaration.name] else {
                byName[declaration.name] = declaration
                continue
            }
            guard seen.symbol != declaration.symbol else { continue }
            // Sorted so the message does not depend on which was declared first.
            let symbols = [seen.symbol, declaration.symbol].sorted()
            throw TypedModelError.conflictingUnits(
                name: declaration.name, symbols[0], symbols[1])
        }

        let rates = unitDeclarations.filter { $0.symbol == Rate.symbol }
        for declaration in rates.sorted(by: { $0.name < $1.name }) where declaration.basis == nil {
            throw TypedModelError.missingRateBasis(account: declaration.name)
        }

        // A model with no data has no timeline, so a declared basis has nothing to
        // disagree with. Refusing here would reject a model being assembled before
        // its figures arrive, which is a supported way to build one.
        guard let timeline = timelineGranularity else { return }
        for declaration in rates.sorted(by: { $0.name < $1.name }) {
            guard let basis = declaration.basis, basis != timeline else { continue }
            throw TypedModelError.rateBasisMismatch(
                account: declaration.name, declared: basis, applied: timeline)
        }
    }

    /// The period type this model's data is stated in, if it has any.
    ///
    /// Read from the inputs rather than declared, because the timeline is a fact
    /// about the figures a model was given. A model whose inputs disagree has no
    /// single granularity, and returning `nil` there means the basis check is
    /// skipped rather than run against an arbitrary one of them.
    private var timelineGranularity: PeriodType? {
        var found: PeriodType?
        for series in inputs.values {
            for period in series.periods {
                guard let existing = found else {
                    found = period.type
                    continue
                }
                guard existing == period.type else { return nil }
            }
        }
        return found
    }
}

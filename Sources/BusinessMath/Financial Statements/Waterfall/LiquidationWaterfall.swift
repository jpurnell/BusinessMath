import Foundation

// MARK: - Result

/// How a waterfall allocated a set of proceeds.
public struct WaterfallResult: Sendable, Equatable {

    /// What each recipient received.
    public let distributions: [String: Double]

    /// What was left after every tier was satisfied.
    public let remaining: Double

    /// Creates a waterfall result.
    ///
    /// - Parameters:
    ///   - distributions: What each recipient received.
    ///   - remaining: What was left over.
    public init(distributions: [String: Double], remaining: Double) {
        self.distributions = distributions
        self.remaining = remaining
    }
}

// MARK: - Waterfall

/// A priority-ordered set of tiers through which liquidation proceeds flow.
///
/// ```swift
/// let waterfall = try LiquidationWaterfall {
///     try Tier("Senior Debt", priority: 1) {
///         try CapitalReturn(500_000)
///     }
///     try Tier("Common Equity", priority: 2) {
///         Residual()
///     }
/// }
/// let result = waterfall.distribute(700_000)
/// ```
public struct LiquidationWaterfall: Sendable, Equatable {

    /// The tiers, held in priority order regardless of the order given.
    public let tiers: [Tier]

    /// Creates a waterfall from explicit tiers.
    ///
    /// - Parameter tiers: The tiers, in any order. They are sorted by priority.
    public init(tiers: [Tier] = []) {
        // Sorted by priority, with ties broken on name.
        //
        // The tie-break is not decoration: `sorted(by:)` is documented as **not guaranteed
        // stable**, so two tiers sharing a priority were ordered by an implementation detail —
        // and in a waterfall that order decides **who gets paid when the money runs out**.
        // Distributing 500,000 across two 300,000 tiers pays the first in full and the second
        // 200,000; which one is "first" must not depend on the sort algorithm.
        self.tiers = tiers.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.name < rhs.name
        }
    }

    /// Creates a waterfall from a declarative list of tiers.
    ///
    /// - Parameter content: The tiers.
    /// - Throws: Whatever `content` throws.
    public init(@LiquidationWaterfallBuilder content: () throws -> LiquidationWaterfall) rethrows {
        self = try content()
    }

    /// Distributes proceeds through the tiers in priority order.
    ///
    /// Every tier appears in the result even when it receives nothing, so a caller
    /// can tell "this tier got zero" from "this tier is not in the waterfall".
    ///
    /// - Parameter proceeds: The total to distribute.
    /// - Returns: What each recipient received, and what was left over.
    public func distribute(_ proceeds: Double) -> WaterfallResult {
        guard proceeds > 0 else {
            var empty: [String: Double] = [:]
            for tier in tiers { empty[tier.name] = 0 }
            return WaterfallResult(distributions: empty, remaining: 0)
        }

        var remaining = proceeds
        var allDistributions: [String: Double] = [:]

        let totalCapital = tiers.reduce(0.0) { $0 + $1.capitalReturn }
        var context = WaterfallContext(
            totalCapitalInvested: totalCapital,
            totalProceeds: proceeds,
            currentDistributions: [:]
        )

        for tier in tiers {
            guard remaining > 0 else {
                // Exhausted, but still record the tier so its absence from the
                // result never has to be interpreted.
                if let proRata = tier.proRata {
                    for participant in proRata.participants {
                        allDistributions[participant.name] =
                            allDistributions[participant.name] ?? 0
                    }
                } else {
                    allDistributions[tier.name] = allDistributions[tier.name] ?? 0
                }
                continue
            }

            let (distributions, overflow) = tier.distribute(remaining, context: context)

            for (name, amount) in distributions {
                allDistributions[name] = (allDistributions[name] ?? 0) + amount
                context.currentDistributions[name] =
                    (context.currentDistributions[name] ?? 0) + amount
            }

            remaining = overflow
        }

        return WaterfallResult(distributions: allDistributions, remaining: remaining)
    }
}

// MARK: - Waterfall Builder

/// Collects ``Tier`` values into a ``LiquidationWaterfall``.
@resultBuilder
public struct LiquidationWaterfallBuilder {
    // The partial result threaded through this builder is `[Tier]`, not `Tier`.
    //
    // It used to be neither consistently: `buildBlock` consumed `Tier` while `buildOptional`
    // produced `Tier?` and `buildArray` produced `LiquidationWaterfall`. A result builder
    // needs one partial-result type through every `build*`, so those three could not be
    // reached from any valid program — an `if`, an `if`/`else` or a `for` inside a waterfall
    // each failed to compile:
    //
    //     if flag { Tier(…) }        error: conflicting arguments to generic parameter 'Wrapped'
    //     if flag { … } else { … }   error: cannot convert 'LiquidationWaterfall' to 'Tier'
    //     for i in 1...2 { … }       error: cannot convert '[LiquidationWaterfall]' to '[Tier]'
    //
    // That is why all five carried zero test coverage: it was a symptom, not an oversight.
    // Straight-line waterfalls were unaffected and still build exactly as before.

    /// Wraps a single tier as a partial result.
    public static func buildExpression(_ expression: Tier) -> [Tier] {
        [expression]
    }

    /// Concatenates the statements of a block.
    public static func buildBlock(_ components: [Tier]...) -> [Tier] {
        components.flatMap { $0 }
    }

    /// Supports a tier behind an `if` with no `else`.
    public static func buildOptional(_ component: [Tier]?) -> [Tier] {
        component ?? []
    }

    /// Supports the first branch of an `if`-`else`.
    public static func buildEither(first component: [Tier]) -> [Tier] {
        component
    }

    /// Supports the second branch of an `if`-`else`.
    public static func buildEither(second component: [Tier]) -> [Tier] {
        component
    }

    /// Supports a `for` loop over tiers.
    public static func buildArray(_ components: [[Tier]]) -> [Tier] {
        components.flatMap { $0 }
    }

    /// Turns the accumulated tiers into the waterfall, which sorts them by priority.
    public static func buildFinalResult(_ component: [Tier]) -> LiquidationWaterfall {
        LiquidationWaterfall(tiers: component)
    }
}

// MARK: - Property Wrapper

/// Declares a waterfall as a stored property.
///
/// ```swift
/// let senior = try LiquidationWaterfall {
///     try Tier("Senior Debt", priority: 1) { try CapitalReturn(500_000) }
/// }
///
/// struct Fund {
///     @WaterfallDistribution var waterfall: LiquidationWaterfall
/// }
///
/// let fund = Fund(waterfall: senior)
/// ```
///
/// Build the waterfall first and wrap it, rather than building it inside the
/// attribute. Validation throws, and an attribute has nowhere to write `try` —
/// so ``init(builder:)`` is reachable as a direct call but not in attribute
/// position. That is the cost of validating rather than trapping, and it is
/// worth paying: the amounts reaching a waterfall are frequently not the
/// programmer's.
@propertyWrapper
public struct WaterfallDistribution: Sendable {

    /// The wrapped waterfall.
    public var wrappedValue: LiquidationWaterfall

    /// Wraps an existing waterfall.
    ///
    /// - Parameter wrappedValue: The waterfall to wrap.
    public init(wrappedValue: LiquidationWaterfall) {
        self.wrappedValue = wrappedValue
    }

    /// Builds and wraps a waterfall.
    ///
    /// - Parameter builder: The tiers.
    /// - Throws: Whatever `builder` throws.
    public init(
        @LiquidationWaterfallBuilder builder: () throws -> LiquidationWaterfall
    ) rethrows {
        self.wrappedValue = try builder()
    }
}

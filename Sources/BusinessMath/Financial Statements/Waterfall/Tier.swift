import Foundation

// MARK: - Tier

/// One tier of a liquidation waterfall, with its priority and distribution rules.
///
/// Tiers are satisfied in priority order: each takes what it requires from the
/// remaining proceeds and passes the rest down.
public struct Tier: Sendable, Equatable {

    /// The tier name, used as the key in distribution results.
    public let name: String

    /// The priority order. Lower numbers distribute first.
    public let priority: Int

    /// Capital to return before any profit is shared.
    public let capitalReturn: Double

    /// The preferred return hurdle, if any.
    public let preferredReturn: PreferredReturn?

    /// The catch-up provision, if any.
    public let catchUp: CatchUp?

    /// Whether this tier sweeps everything remaining.
    public let residual: Bool

    /// The pro-rata split among participants, if any.
    public let proRata: ProRata?

    /// Creates a tier from explicit terms.
    ///
    /// - Parameters:
    ///   - name: The tier name.
    ///   - priority: The priority order; lower distributes first.
    ///   - capitalReturn: Capital to return before profits.
    ///   - preferredReturn: The preferred return hurdle, if any.
    ///   - catchUp: The catch-up provision, if any.
    ///   - residual: Whether this tier sweeps what remains.
    ///   - proRata: The pro-rata split, if any.
    /// - Throws: ``WaterfallError/nonPositivePriority(tierName:priority:)``.
    public init(
        name: String,
        priority: Int,
        capitalReturn: Double = 0,
        preferredReturn: PreferredReturn? = nil,
        catchUp: CatchUp? = nil,
        residual: Bool = false,
        proRata: ProRata? = nil
    ) throws {
        guard priority > 0 else {
            throw WaterfallError.nonPositivePriority(tierName: name, priority: priority)
        }
        self.name = name
        self.priority = priority
        self.capitalReturn = capitalReturn
        self.preferredReturn = preferredReturn
        self.catchUp = catchUp
        self.residual = residual
        self.proRata = proRata
    }

    /// Creates a tier from a declarative list of components.
    ///
    /// ```swift
    /// try Tier("LP Preferred", priority: 2) {
    ///     try CapitalReturn(5_000_000)
    ///     try PreferredReturn(0.08, years: 5)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - name: The tier name.
    ///   - priority: The priority order.
    ///   - content: The tier's components.
    /// - Throws: Whatever `content` throws, or
    ///   ``WaterfallError/nonPositivePriority(tierName:priority:)``.
    public init(
        _ name: String,
        priority: Int,
        @TierBuilder content: () throws -> TierTerms
    ) throws {
        let terms = try content()
        self = try Tier(
            name: name,
            priority: priority,
            capitalReturn: terms.capitalReturn,
            preferredReturn: terms.preferredReturn,
            catchUp: terms.catchUp,
            residual: terms.residual,
            proRata: terms.proRata
        )
    }

    /// What this tier requires before passing proceeds down.
    ///
    /// A preferred return accrues on this tier's own capital when it has any, and
    /// on the waterfall's total capital when it does not — a hurdle tier with no
    /// capital of its own is expressed against the whole investment.
    ///
    /// - Parameter context: The waterfall's running state.
    /// - Returns: The amount required to satisfy this tier in full.
    public func requiredAmount(context: WaterfallContext) -> Double {
        var total = capitalReturn
        if let preferred = preferredReturn {
            let baseCapital = capitalReturn > 0 ? capitalReturn : context.totalCapitalInvested
            total += baseCapital * preferred.totalReturn
        }
        return total
    }

    /// Distributes proceeds to this tier.
    ///
    /// - Parameters:
    ///   - amount: The proceeds available to this tier.
    ///   - context: The waterfall's running state, which a catch-up reads to work
    ///     out how far behind its target it is.
    /// - Returns: What this tier takes, keyed by recipient, and what passes down.
    public func distribute(
        _ amount: Double,
        context: WaterfallContext
    ) -> (distribution: [String: Double], remaining: Double) {
        guard amount > 0 else { return ([:], 0) }

        var distributions: [String: Double] = [:]
        var remaining = amount

        if let proRata {
            for participant in proRata.participants {
                distributions[participant.name] = amount * participant.percentage
            }
            return (distributions, 0)
        }

        if residual {
            distributions[name] = amount
            return (distributions, 0)
        }

        if let catchUp {
            let totalDistributed = context.currentDistributions.values.reduce(0, +)
            let profitsDistributed = totalDistributed - context.totalCapitalInvested

            let targetShare = catchUp.targetPercentage
            let othersShare = 1.0 - targetShare

            // Nothing to catch up to before any profit exists, and a 100% target
            // has no ratio to solve for.
            guard othersShare > 0, profitsDistributed > 0 else {
                return (distributions, remaining)
            }

            // Bring this tier to `targetShare` of the profits distributed so far,
            // so that later pro-rata tiers preserve the intended split.
            let totalProfitsForRatio = profitsDistributed / othersShare
            let shouldHave = totalProfitsForRatio * targetShare
            let alreadyHas = context.currentDistributions[name] ?? 0

            let owed = max(0, shouldHave - alreadyHas)
            let paid = min(remaining, owed)

            if paid > 0 {
                distributions[name] = paid
                remaining -= paid
            }
            return (distributions, remaining)
        }

        let required = requiredAmount(context: context)
        let paid = min(remaining, required)

        distributions[name] = paid
        remaining -= paid

        return (distributions, remaining)
    }
}

// MARK: - Tier Builder

/// The terms collected from a tier's components, before a name and priority are
/// attached.
///
/// Separate from ``Tier`` on purpose. A result builder's `buildBlock` cannot be
/// throwing — the compiler generates that call and has nowhere to write `try` —
/// so the intermediate value must be one that needs no validation. Returning a
/// `Tier` here would have forced either a placeholder name and priority carried
/// through an invalid state, or validation the builder cannot perform.
public struct TierTerms: Sendable, Equatable {

    /// Capital to return before profits.
    public let capitalReturn: Double

    /// The preferred return hurdle, if any.
    public let preferredReturn: PreferredReturn?

    /// The catch-up provision, if any.
    public let catchUp: CatchUp?

    /// Whether the tier sweeps what remains.
    public let residual: Bool

    /// The pro-rata split, if any.
    public let proRata: ProRata?

    /// Creates a set of tier terms.
    ///
    /// - Parameters:
    ///   - capitalReturn: Capital to return before profits.
    ///   - preferredReturn: The preferred return hurdle, if any.
    ///   - catchUp: The catch-up provision, if any.
    ///   - residual: Whether the tier sweeps what remains.
    ///   - proRata: The pro-rata split, if any.
    public init(
        capitalReturn: Double = 0,
        preferredReturn: PreferredReturn? = nil,
        catchUp: CatchUp? = nil,
        residual: Bool = false,
        proRata: ProRata? = nil
    ) {
        self.capitalReturn = capitalReturn
        self.preferredReturn = preferredReturn
        self.catchUp = catchUp
        self.residual = residual
        self.proRata = proRata
    }
}

/// Collects ``TierComponent`` values into a ``TierTerms``.
@resultBuilder
public struct TierBuilder {

    /// Combines components into a tier's terms.
    ///
    /// Repeated capital returns accumulate; the other components take the last
    /// one given, since a tier has at most one hurdle, catch-up, or split.
    ///
    /// - Parameter components: The tier's components.
    /// - Returns: The combined terms.
    public static func buildBlock(_ components: TierComponent...) -> TierTerms {
        var capitalReturn: Double = 0
        var preferredReturn: PreferredReturn?
        var catchUp: CatchUp?
        var residual = false
        var proRata: ProRata?

        for component in components {
            switch component {
            case .capitalReturn(let value):
                capitalReturn += value.amount
            case .preferredReturn(let value):
                preferredReturn = value
            case .catchUp(let value):
                catchUp = value
            case .residual:
                residual = true
            case .proRata(let value):
                proRata = value
            }
        }

        return TierTerms(
            capitalReturn: capitalReturn,
            preferredReturn: preferredReturn,
            catchUp: catchUp,
            residual: residual,
            proRata: proRata
        )
    }

    /// Converts a component-convertible value into a component.
    ///
    /// - Parameter expression: The value to convert.
    /// - Returns: Its tier component.
    public static func buildExpression(_ expression: TierComponentConvertible) -> TierComponent {
        expression.tierComponent
    }
}

// MARK: - Waterfall Context

/// The waterfall's running state, as seen by a tier being distributed to.
public struct WaterfallContext: Sendable, Equatable {

    /// Total capital invested across every tier.
    public let totalCapitalInvested: Double

    /// Total proceeds being distributed.
    public let totalProceeds: Double

    /// What has been distributed so far, by recipient.
    public var currentDistributions: [String: Double]

    /// Creates a waterfall context.
    ///
    /// - Parameters:
    ///   - totalCapitalInvested: Total capital across all tiers.
    ///   - totalProceeds: The proceeds being distributed.
    ///   - currentDistributions: What has been distributed so far.
    public init(
        totalCapitalInvested: Double,
        totalProceeds: Double,
        currentDistributions: [String: Double] = [:]
    ) {
        self.totalCapitalInvested = totalCapitalInvested
        self.totalProceeds = totalProceeds
        self.currentDistributions = currentDistributions
    }
}

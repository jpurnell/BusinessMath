//
//  Tier.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-29.
//

import Foundation
import Numerics

// MARK: - Tier Model

/// A single tier in the liquidation waterfall with priority and distribution rules.
public struct Tier {
    /// The tier name used in distribution reporting.
    public let name: String
    /// The priority order (lower numbers distribute first).
    public let priority: Int
    /// The amount of capital to return before profits.
    public let capitalReturn: Double
    /// The preferred return (hurdle rate) requirement.
    public let preferredReturn: PreferredReturn?
    /// The catch-up provision for achieving target profit split.
    public let catchUp: CatchUp?
    /// Whether this tier captures all remaining proceeds.
    public let residual: Bool
    /// The pro-rata distribution among multiple participants.
    public let proRata: ProRata?

    internal init(
        name: String,
        priority: Int,
        capitalReturn: Double = 0,
        preferredReturn: PreferredReturn? = nil,
        catchUp: CatchUp? = nil,
        residual: Bool = false,
        proRata: ProRata? = nil
    ) {
        guard priority > 0 else {
            preconditionFailure("Tier priority must be positive: \(priority)")
        }
        self.name = name
        self.priority = priority
        self.capitalReturn = capitalReturn
        self.preferredReturn = preferredReturn
        self.catchUp = catchUp
        self.residual = residual
        self.proRata = proRata
    }

    /// Create tier using result builder
    public init(
        _ name: String,
        priority: Int,
        @TierBuilder content: () -> Tier
    ) {
        var tier = content()
        tier = Tier(
            name: name,
            priority: priority,
            capitalReturn: tier.capitalReturn,
            preferredReturn: tier.preferredReturn,
            catchUp: tier.catchUp,
            residual: tier.residual,
            proRata: tier.proRata
        )
        self = tier
    }

    /// Calculate how much this tier requires
    /// - Parameter context: Waterfall context for calculating preferred returns on capital
    public func requiredAmount(context: WaterfallContext) -> Double {
        var total = capitalReturn
        if let pref = preferredReturn {
            // Preferred return is on the capital in this tier OR total capital if this tier has no capital
            let baseCapital = capitalReturn > 0 ? capitalReturn : context.totalCapitalInvested
            total += baseCapital * pref.totalReturn
        }
        return total
    }

    /// Distribute amount to this tier
    /// Returns (amountDistributed, overflow)
    public func distribute(
        _ amount: Double,
        context: WaterfallContext
    ) -> (distribution: [String: Double], remaining: Double) {
        guard amount > 0 else {
            return ([:], 0)
        }

        var distributions: [String: Double] = [:]
        var remaining = amount

        // Handle ProRata distribution
        if let proRata = proRata {
            for participant in proRata.participants {
                let share = amount * participant.percentage
                distributions[participant.name] = share
            }
            return (distributions, 0)
        }

        // Handle Residual
        if residual {
            distributions[name] = amount
            return (distributions, 0)
        }

        // Handle CatchUp
        if let catchUp = catchUp {
            // Catch-up brings GP to target % of ACCUMULATED profits
            // so that subsequent pro-rata tiers maintain the split
            let totalCapital = context.totalCapitalInvested
            let totalDistributed = context.currentDistributions.values.reduce(0, +)
            let profitsDistributed = totalDistributed - totalCapital

            // If LP has all profits so far (profitsDistributed), and we want GP at targetPercentage:
            // totalNeeded = profitsDistributed / (1 - targetPercentage)
            // gpNeeds = totalNeeded * targetPercentage
            let targetGPShare = catchUp.targetPercentage
            let targetLPShare = 1.0 - targetGPShare

            // Avoid division by zero
            guard targetLPShare > 0, profitsDistributed > 0 else {
                return (distributions, remaining)
            }

            let totalProfitsForRatio = profitsDistributed / targetLPShare
            let gpShouldHave = totalProfitsForRatio * targetGPShare

            // How much has GP gotten so far?
            let currentGPProfit = context.currentDistributions[name] ?? 0

            let neededCatchUp = max(0, gpShouldHave - currentGPProfit)
            let actualCatchUp = min(remaining, neededCatchUp)

            if actualCatchUp > 0 {
                distributions[name] = actualCatchUp
                remaining -= actualCatchUp
            }
            return (distributions, remaining)
        }

        // Handle Capital Return + Preferred Return
        let required = requiredAmount(context: context)
        let distributed = min(remaining, required)

        distributions[name] = distributed
        remaining -= distributed

        return (distributions, remaining)
    }
}

// MARK: - Tier Result Builder

/// Result builder for constructing `Tier` instances declaratively.
@resultBuilder
public struct TierBuilder {
    /// Builds a tier from the provided components.
    ///
    /// - Parameter components: The capital return, preferred return, catch-up, residual, and pro-rata components.
    /// - Returns: A configured `Tier`.
    public static func buildBlock(_ components: TierComponent...) -> Tier {
        var capitalReturn: Double = 0
        var preferredReturn: PreferredReturn? = nil
        var catchUp: CatchUp? = nil
        var residual: Bool = false
        var proRata: ProRata? = nil

        for component in components {
            switch component {
            case .capitalReturn(let cap):
                capitalReturn += cap.amount
            case .preferredReturn(let pref):
                preferredReturn = pref
            case .catchUp(let cu):
                catchUp = cu
            case .residual(_):
                residual = true
            case .proRata(let pr):
                proRata = pr
            }
        }

        return Tier(
            name: "",  // Will be set by Tier init
            priority: 1,  // Will be set by Tier init
            capitalReturn: capitalReturn,
            preferredReturn: preferredReturn,
            catchUp: catchUp,
            residual: residual,
            proRata: proRata
        )
    }
}

extension TierBuilder {
    /// Converts a conforming expression to a tier component.
    public static func buildExpression(_ expression: TierComponentConvertible) -> TierComponent {
        expression.tierComponent
    }
}

// MARK: - Waterfall Context

/// Context for waterfall distribution calculations.
public struct WaterfallContext {
    /// Total capital invested across all tiers.
    public let totalCapitalInvested: Double
    /// Total proceeds being distributed.
    public let totalProceeds: Double
    /// Running tally of distributions by participant name.
    public var currentDistributions: [String: Double]

    /// Creates a waterfall context for distribution calculations.
    ///
    /// - Parameters:
    ///   - totalCapitalInvested: Total capital invested.
    ///   - totalProceeds: Total proceeds to distribute.
    ///   - currentDistributions: Current distribution state.
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

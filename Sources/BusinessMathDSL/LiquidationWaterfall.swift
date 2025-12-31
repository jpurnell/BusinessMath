//
//  LiquidationWaterfall.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-29.
//

import Foundation
import Numerics

/// # Liquidation Waterfall - Priority Distribution Modeling
///
/// Models how proceeds are distributed through priority tiers in investment structures.
/// Common in private equity, venture capital, and real estate investments.
///
/// ## Basic Usage
///
/// ```swift
/// let waterfall = LiquidationWaterfall {
///     Tier("Senior Debt", priority: 1) {
///         CapitalReturn(500_000)
///         PreferredReturn(0.12, years: 2)
///     }
///     Tier("Common Equity", priority: 2) {
///         Residual()
///     }
/// }
///
/// let result = waterfall.distribute(1_000_000)
/// print("Senior Debt gets: \(result.distributions["Senior Debt"] ?? 0)")
/// ```
///
/// ## Complete Example
///
/// ```swift
/// let waterfall = LiquidationWaterfall {
///     // Tier 1: LP gets capital back + preferred return
///     Tier("LP Capital + Preferred", priority: 1) {
///         CapitalReturn(5_000_000)
///         PreferredReturn(0.08, years: 5)  // 8% for 5 years
///     }
///
///     // Tier 2: GP catch-up to achieve 20% profit share
///     Tier("GP Catch-Up", priority: 2) {
///         CatchUp(to: 0.20)
///     }
///
///     // Tier 3: Remaining proceeds split 80/20
///     Tier("Residual", priority: 3) {
///         ProRata([
///             ("LP", 0.80),
///             ("GP", 0.20)
///         ])
///     }
/// }
///
/// // Exit at $10M
/// let result = waterfall.distribute(10_000_000)
/// ```

// MARK: - Waterfall Result

/// Result of waterfall distribution
public struct WaterfallResult {
    public let distributions: [String: Double]
    public let remaining: Double

    public init(distributions: [String: Double], remaining: Double) {
        self.distributions = distributions
        self.remaining = remaining
    }
}

// MARK: - Liquidation Waterfall Model

/// Liquidation waterfall model for distributing proceeds through priority tiers
public struct LiquidationWaterfall {
    public let tiers: [Tier]

    internal init(tiers: [Tier] = []) {
        // Sort tiers by priority
        self.tiers = tiers.sorted { $0.priority < $1.priority }
    }

    /// Distribute proceeds through the waterfall
    /// - Parameter proceeds: Total proceeds to distribute
    /// - Returns: Distribution result showing how proceeds were allocated
    public func distribute(_ proceeds: Double) -> WaterfallResult {
        guard proceeds > 0 else {
            // Return zero distributions for all tiers
            var emptyDistributions: [String: Double] = [:]
            for tier in tiers {
                emptyDistributions[tier.name] = 0
            }
            return WaterfallResult(distributions: emptyDistributions, remaining: 0)
        }

        var remaining = proceeds
        var allDistributions: [String: Double] = [:]

        // Calculate total capital invested for context
        let totalCapital = tiers.reduce(0.0) { $0 + $1.capitalReturn }

        // Create context for catch-up calculations
        var context = WaterfallContext(
            totalCapitalInvested: totalCapital,
            totalProceeds: proceeds,
            currentDistributions: [:]
        )

        // Process each tier in priority order
        for tier in tiers {
            guard remaining > 0 else {
                // No more to distribute, but still track tier
                if let _ = tier.proRata {
                    // ProRata participants get zero
                    for participant in tier.proRata!.participants {
                        allDistributions[participant.name] = (allDistributions[participant.name] ?? 0) + 0
                    }
                } else {
                    allDistributions[tier.name] = (allDistributions[tier.name] ?? 0) + 0
                }
                continue
            }

            let (distributions, overflow) = tier.distribute(remaining, context: context)

            // Merge distributions
            for (name, amount) in distributions {
                allDistributions[name] = (allDistributions[name] ?? 0) + amount
                context.currentDistributions[name] = (context.currentDistributions[name] ?? 0) + amount
            }

            remaining = overflow
        }

        return WaterfallResult(distributions: allDistributions, remaining: remaining)
    }

    /// Create waterfall using result builder
    public init(@LiquidationWaterfallBuilder content: () -> LiquidationWaterfall) {
        self = content()
    }
}

// MARK: - Liquidation Waterfall Result Builder

@resultBuilder
public struct LiquidationWaterfallBuilder {
    public static func buildBlock(_ components: Tier...) -> LiquidationWaterfall {
        LiquidationWaterfall(tiers: Array(components))
    }

    public static func buildOptional(_ component: Tier?) -> Tier? {
        component
    }

    public static func buildEither(first component: Tier) -> Tier {
        component
    }

    public static func buildEither(second component: Tier) -> Tier {
        component
    }

    public static func buildArray(_ components: [Tier]) -> LiquidationWaterfall {
        LiquidationWaterfall(tiers: components)
    }

    public static func buildExpression(_ expression: Tier) -> Tier {
        expression
    }
}

// MARK: - @WaterfallDistribution Property Wrapper

/// Property wrapper for declarative waterfall creation
@propertyWrapper
public struct WaterfallDistribution {
    public var wrappedValue: LiquidationWaterfall

    public init(wrappedValue: LiquidationWaterfall) {
        self.wrappedValue = wrappedValue
    }

    public init(@LiquidationWaterfallBuilder builder: () -> LiquidationWaterfall) {
        self.wrappedValue = builder()
    }
}

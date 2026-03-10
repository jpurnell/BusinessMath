//
//  TierComponents.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-29.
//

import Foundation
import Numerics

/// # Tier Components for Waterfall Distributions
///
/// Components define how proceeds are distributed within each waterfall tier:
///
/// - **CapitalReturn**: Return of original investment
/// - **PreferredReturn**: Hurdle rate return (e.g., 8% annually)
/// - **CatchUp**: Provisions to achieve target profit share
/// - **Residual**: Captures all remaining proceeds
/// - **ProRata**: Splits proceeds among multiple participants
///
/// ## Examples
///
/// ### Capital Return
/// ```swift
/// Tier("Investors", priority: 1) {
///     CapitalReturn(1_000_000)  // Return $1M before any profits
/// }
/// ```
///
/// ### Preferred Return (Hurdle)
/// ```swift
/// Tier("LP Preferred", priority: 2) {
///     CapitalReturn(5_000_000)
///     PreferredReturn(0.08, years: 5)  // 8% annually for 5 years
/// }
/// // Total required: $5M + ($5M × 0.08 × 5) = $7M
/// ```
///
/// ### GP Catch-Up
/// ```swift
/// Tier("GP Catch-Up", priority: 3) {
///     CatchUp(to: 0.20)  // GP gets to 20% of total profits
/// }
/// // Brings GP to target % based on profits distributed in earlier tiers
/// ```
///
/// ### Pro-Rata Distribution
/// ```swift
/// Tier("Residual Split", priority: 4) {
///     ProRata([
///         ("LP", 0.80),
///         ("GP", 0.20)
///     ])
/// }
/// // Splits remaining proceeds 80/20
/// ```
///
/// ### Residual (All Remaining)
/// ```swift
/// Tier("Final", priority: 5) {
///     Residual()  // Gets everything left
/// }
/// ```

// MARK: - Tier Components

/// Return of original capital investment.
public struct CapitalReturn {
    /// The capital amount to return before profits.
    public let amount: Double

    /// Creates a capital return requirement.
    ///
    /// - Parameter amount: The capital to return (must be non-negative).
    public init(_ amount: Double) {
        guard amount >= 0 else {
            fatalError("Capital return cannot be negative: \(amount)")
        }
        self.amount = amount
    }
}

/// Preferred return (hurdle rate) over a period.
public struct PreferredReturn {
    /// The annual preferred return rate (e.g., 0.08 for 8%).
    public let rate: Double
    /// The number of years for the preferred return.
    public let years: Int

    /// Creates a preferred return requirement.
    ///
    /// - Parameters:
    ///   - rate: The annual rate (must be non-negative).
    ///   - years: The number of years (must be positive).
    public init(_ rate: Double, years: Int) {
        guard rate >= 0 else {
            fatalError("Preferred return rate cannot be negative: \(rate)")
        }
        guard years > 0 else {
            fatalError("Years must be positive: \(years)")
        }
        self.rate = rate
        self.years = years
    }

    /// Calculate total preferred return amount
    public var totalReturn: Double {
        // Simple interest calculation for now
        // Could be enhanced with compounding
        rate * Double(years)
    }
}

/// Catch-up provision to achieve target profit split.
public struct CatchUp {
    /// The target percentage of profits for the catch-up recipient.
    public let targetPercentage: Double

    /// Creates a catch-up provision.
    ///
    /// - Parameter percentage: The target profit share (must be between 0 and 1).
    public init(to percentage: Double) {
        guard percentage >= 0, percentage <= 1.0 else {
            fatalError("Catch-up percentage must be between 0 and 1: \(percentage)")
        }
        self.targetPercentage = percentage
    }
}

/// Residual distribution (captures all remaining proceeds)
public struct Residual {
    public init() {}
}

/// Pro-rata distribution among multiple participants.
public struct ProRata {
    /// The participants and their percentage shares.
    public let participants: [(name: String, percentage: Double)]

    /// Creates a pro-rata distribution.
    ///
    /// - Parameter participants: Array of (name, percentage) tuples that must sum to 1.0.
    public init(_ participants: [(String, Double)]) {
        guard !participants.isEmpty else {
            fatalError("ProRata must have at least one participant")
        }

        let total = participants.reduce(0.0) { $0 + $1.1 }
        guard abs(total - 1.0) < 0.001 else {
            fatalError("ProRata percentages must sum to 1.0, got \(total)")
        }

        self.participants = participants.map { (name: $0.0, percentage: $0.1) }
    }
}

// MARK: - Tier Component Protocol

/// Represents a tier component that can be used in the builder.
public enum TierComponent {
    case capitalReturn(CapitalReturn)
    case preferredReturn(PreferredReturn)
    case catchUp(CatchUp)
    case residual(Residual)
    case proRata(ProRata)
}

extension CapitalReturn: TierComponentConvertible {
    /// Converts this capital return to a tier component.
    public var tierComponent: TierComponent { .capitalReturn(self) }
}

extension PreferredReturn: TierComponentConvertible {
    /// Converts this preferred return to a tier component.
    public var tierComponent: TierComponent { .preferredReturn(self) }
}

extension CatchUp: TierComponentConvertible {
    /// Converts this catch-up to a tier component.
    public var tierComponent: TierComponent { .catchUp(self) }
}

extension Residual: TierComponentConvertible {
    /// Converts this residual to a tier component.
    public var tierComponent: TierComponent { .residual(self) }
}

extension ProRata: TierComponentConvertible {
    /// Converts this pro-rata to a tier component.
    public var tierComponent: TierComponent { .proRata(self) }
}

/// Protocol for types that can be converted to a `TierComponent`.
public protocol TierComponentConvertible {
    /// The tier component representation of this type.
    var tierComponent: TierComponent { get }
}

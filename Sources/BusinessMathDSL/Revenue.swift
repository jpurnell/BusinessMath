//
//  Revenue.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-29.
//

import Foundation
import Numerics

/// # Revenue Components
///
/// Revenue modeling components for cash flow projections with support for:
/// - Base annual revenue amounts
/// - Year-over-year growth rates
/// - Quarterly seasonality patterns
///
/// ## Usage Examples
///
/// ### Simple Revenue with Base Amount
/// ```swift
/// let revenue = Revenue {
///     Base(1_000_000)
/// }
/// let year1 = revenue.value(forYear: 1)  // 1,000,000
/// ```
///
/// ### Revenue with Growth
/// ```swift
/// let growingRevenue = Revenue {
///     Base(1_000_000)
///     GrowthRate(0.15)  // 15% annual growth
/// }
/// let year1 = growingRevenue.value(forYear: 1)  // 1,000,000
/// let year2 = growingRevenue.value(forYear: 2)  // 1,150,000
/// let year3 = growingRevenue.value(forYear: 3)  // 1,322,500
/// ```
///
/// ### Revenue with Seasonality
/// ```swift
/// let seasonalRevenue = Revenue {
///     Base(1_200_000)  // $1.2M annual
///     Seasonality([1.5, 1.0, 0.75, 0.75])  // Q1 strong, Q3-Q4 weak
/// }
/// // Quarterly base: 300k per quarter
/// let q1 = seasonalRevenue.value(forYear: 1, quarter: 1)  // 450,000 (300k * 1.5)
/// let q2 = seasonalRevenue.value(forYear: 1, quarter: 2)  // 300,000 (300k * 1.0)
/// let q3 = seasonalRevenue.value(forYear: 1, quarter: 3)  // 225,000 (300k * 0.75)
/// ```
///
/// ### Revenue with Growth and Seasonality Combined
/// ```swift
/// let fullRevenue = Revenue {
///     Base(1_000_000)
///     GrowthRate(0.20)
///     Seasonality([1.2, 1.0, 0.8, 1.0])
/// }
/// let year1Q1 = fullRevenue.value(forYear: 1, quarter: 1)  // 300,000
/// let year2Q1 = fullRevenue.value(forYear: 2, quarter: 1)  // 360,000 (20% growth applied)
/// ```

// MARK: - Revenue Components

/// Base revenue amount for cash flow projections
public struct Base {
    public let amount: Double

    public init(_ amount: Double) {
        guard amount >= 0 else {
            fatalError("Base revenue cannot be negative: \(amount)")
        }
        self.amount = amount
    }
}

/// Annual growth rate for revenue projections
public struct GrowthRate {
    public let rate: Double

    public init(_ rate: Double) {
        guard rate > -1.0 else {
            fatalError("Growth rate cannot be less than -100%: \(rate)")
        }
        self.rate = rate
    }
}

/// Quarterly seasonality factors for revenue
public struct Seasonality {
    public let factors: [Double]

    public init(_ factors: [Double]) {
        guard factors.count == 4 else {
            fatalError("Seasonality must have exactly 4 quarterly factors")
        }

        let sum = factors.reduce(0, +)
        guard abs(sum - 4.0) < 0.001 else {
            fatalError("Seasonality factors must sum to 4.0, got \(sum)")
        }

        self.factors = factors
    }
}

// MARK: - Revenue Model

/// Revenue model with base, growth, and optional seasonality for cash flow projections
public struct Revenue {
    public let baseValue: Double
    public let growthRate: Double
    public let seasonalityFactors: [Double]

    internal init(
        baseValue: Double,
        growthRate: Double = 0.0,
        seasonalityFactors: [Double] = [1.0, 1.0, 1.0, 1.0]
    ) {
        self.baseValue = baseValue
        self.growthRate = growthRate
        self.seasonalityFactors = seasonalityFactors
    }

    /// Calculate revenue for a specific year
    /// - Parameter year: The year number (1-based)
    /// - Returns: Annual revenue for the specified year
    public func value(forYear year: Int) -> Double {
        guard year > 0 else { return 0 }

        // Apply growth: base * (1 + growth)^(year - 1)
        let growthMultiplier = pow(1.0 + growthRate, Double(year - 1))
        return baseValue * growthMultiplier
    }

    /// Calculate revenue for a specific quarter
    /// - Parameters:
    ///   - year: The year number (1-based)
    ///   - quarter: The quarter number (1-4)
    /// - Returns: Quarterly revenue
    public func value(forYear year: Int, quarter: Int) -> Double {
        guard year > 0, quarter >= 1, quarter <= 4 else { return 0 }

        let annualRevenue = value(forYear: year)
        let quarterlyBase = annualRevenue / 4.0
        let seasonalFactor = seasonalityFactors[quarter - 1]

        return quarterlyBase * seasonalFactor
    }

    /// Create revenue model using result builder
    public init(@RevenueBuilder content: () throws -> Revenue) rethrows {
        self = try content()
    }
}

// MARK: - Revenue Result Builder

@resultBuilder
public struct RevenueBuilder {
    public static func buildBlock(_ components: RevenueComponent...) -> Revenue {
        var baseValue: Double = 0
        var growthRate: Double = 0
        var seasonalityFactors: [Double] = [1.0, 1.0, 1.0, 1.0]

        for component in components {
            switch component {
            case .base(let base):
                baseValue = base.amount
            case .growthRate(let growth):
                growthRate = growth.rate
            case .seasonality(let seasonality):
                seasonalityFactors = seasonality.factors
            }
        }

        return Revenue(
            baseValue: baseValue,
            growthRate: growthRate,
            seasonalityFactors: seasonalityFactors
        )
    }
}

// MARK: - Revenue Component Protocol

public enum RevenueComponent {
    case base(Base)
    case growthRate(GrowthRate)
    case seasonality(Seasonality)
}

extension Base: RevenueComponentConvertible {
    public var revenueComponent: RevenueComponent { .base(self) }
}

extension GrowthRate: RevenueComponentConvertible {
    public var revenueComponent: RevenueComponent { .growthRate(self) }
}

extension Seasonality: RevenueComponentConvertible {
    public var revenueComponent: RevenueComponent { .seasonality(self) }
}

public protocol RevenueComponentConvertible {
    var revenueComponent: RevenueComponent { get }
}

extension RevenueBuilder {
    public static func buildExpression(_ expression: RevenueComponentConvertible) -> RevenueComponent {
        expression.revenueComponent
    }
}

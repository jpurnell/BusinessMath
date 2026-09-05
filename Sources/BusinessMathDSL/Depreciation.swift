//
//  Depreciation.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-29.
//

import Foundation
#if canImport(os)
import os

private let logger = Logger(subsystem: "com.businessmath", category: "Depreciation")
#endif
import Numerics
import BusinessMath

/// # Depreciation Components
///
/// Depreciation modeling for capital assets using straight-line depreciation.
/// Supports multiple asset schedules that are automatically combined.
///
/// ## Usage Examples
///
/// ### Single Asset Depreciation
/// ```swift
/// let depreciation = Depreciation {
///     StraightLine(asset: 1_000_000, years: 10)
/// }
/// let year1 = depreciation.value(forYear: 1)   // 100,000
/// let year5 = depreciation.value(forYear: 5)   // 100,000
/// let year10 = depreciation.value(forYear: 10) // 100,000
/// let year11 = depreciation.value(forYear: 11) // 0 (fully deprecated)
/// ```
///
/// ### Multiple Asset Schedules
/// ```swift
/// let multiAsset = Depreciation {
///     StraightLine(asset: 2_000_000, years: 10)  // Building
///     StraightLine(asset: 500_000, years: 5)     // Equipment
///     StraightLine(asset: 100_000, years: 3)     // Computers
/// }
/// // Year 1: 200k + 100k + 33.3k = 333.3k total depreciation
/// let year1 = multiAsset.value(forYear: 1)  // 333,333
///
/// // Year 6: 200k + 0 + 0 = 200k (only building remains)
/// let year6 = multiAsset.value(forYear: 6)  // 200,000
///
/// // Year 11: All assets fully deprecated
/// let year11 = multiAsset.value(forYear: 11) // 0
/// ```
///
/// ### Integration with Cash Flow Model
/// ```swift
/// let projection = CashFlowModel(
///     revenue: Revenue { Base(1_000_000) },
///     expenses: Expenses { Variable(percentage: 0.60) },
///     depreciation: Depreciation {
///         StraightLine(asset: 500_000, years: 5)
///     },
///     taxes: Taxes { CorporateRate(0.30) }
/// )
/// // Depreciation reduces EBIT (taxable income) but is added back for FCF
/// let fcf = projection.freeCashFlow(year: 1)
/// ```
///
/// ## Depreciation and Cash Flow
///
/// Depreciation is a non-cash expense that:
/// - Reduces EBIT (Earnings Before Interest and Taxes) and therefore taxes
/// - Is added back to Net Income to calculate Free Cash Flow
/// - Does not affect actual cash in the business
///
/// **Formula**: `Free Cash Flow = Net Income + Depreciation`

// MARK: - Depreciation Components

/// Straight-line depreciation schedule.
public struct StraightLine {
    /// The original asset value to depreciate.
    public let assetValue: Double
    /// The number of years over which to depreciate the asset.
    public let years: Int

    /// What the asset is still worth when its life ends, and which is therefore not
    /// depreciated.
    ///
    /// Defaults to zero, which is what this type assumed before it could be stated.
    public let salvageValue: Double

    /// Creates a straight-line depreciation schedule.
    ///
    /// - Parameters:
    ///   - asset: The original asset value (must be non-negative).
    ///   - years: The depreciation period in years (must be positive).
    ///   - salvage: What the asset is worth at the end of that period. Defaults to
    ///     zero, so existing callers are unaffected; must not exceed the asset value.
    public init(asset: Double, years: Int, salvage: Double = 0) {
        guard asset >= 0 else {
            preconditionFailure("Asset value cannot be negative: \(asset)")
        }
        guard years > 0 else {
            preconditionFailure("Depreciation years must be positive: \(years)")
        }
        guard salvage >= 0, salvage <= asset else {
            preconditionFailure("Salvage value \(salvage) must be between zero and the asset value \(asset)")
        }
        self.assetValue = asset
        self.years = years
        self.salvageValue = salvage
    }

    /// Calculate annual depreciation
    /// The charge in each year: `(asset − salvage) / years`.
    ///
    /// Delegates to ``BusinessMath/straightLineDepreciation(cost:salvage:life:)`` rather
    /// than dividing here, so this schedule and the general function cannot disagree
    /// about what straight line means. `years` is positive by the precondition in the
    /// initializer, so the shared function cannot fail.
    public var annualDepreciation: Double {
        do {
            return try straightLineDepreciation(
                cost: assetValue, salvage: salvageValue, life: Double(years))
        } catch {
            // Unreachable: `years` is positive by the initializer's precondition. The
            // branch reports rather than returns a plausible number, so that if the
            // precondition is ever relaxed the consequence is visible.
            #if canImport(os)
            logger.error("Depreciation unavailable, returning nan: \(error, privacy: .public)")
            #endif
            return Double.nan
        }
    }

    /// Calculate depreciation for a specific year
    /// - Parameter year: The year number (1-based)
    /// - Returns: Depreciation amount (0 after asset life ends)
    public func value(forYear year: Int) -> Double {
        guard year > 0, year <= years else { return 0 }
        return annualDepreciation
    }
}

// MARK: - Depreciation Model

/// Depreciation model combining multiple depreciation schedules
public struct Depreciation {
    /// The individual straight-line depreciation schedules that compose this model.
    public let schedules: [StraightLine]

    internal init(schedules: [StraightLine] = []) {
        self.schedules = schedules
    }

    /// Calculate total depreciation for a specific year
    /// - Parameter year: The year number (1-based)
    /// - Returns: Total depreciation across all schedules
    public func value(forYear year: Int) -> Double {
        guard year > 0 else { return 0 }

        return schedules.reduce(0) { total, schedule in
            total + schedule.value(forYear: year)
        }
    }

    /// Create depreciation model using result builder
    public init(@CashFlowDepreciationBuilder content: () -> Depreciation) {
        self = content()
    }
}

// MARK: - Depreciation Result Builder

/// Result builder for constructing `Depreciation` instances declaratively.
@resultBuilder
public struct CashFlowDepreciationBuilder {
    /// Builds a depreciation model from the provided schedules.
    ///
    /// - Parameter components: The depreciation schedules to combine.
    /// - Returns: A configured `Depreciation` model.
    public static func buildBlock(_ components: CashFlowDepreciationComponent...) -> Depreciation {
        var schedules: [StraightLine] = []

        for component in components {
            switch component {
            case .straightLine(let schedule):
                schedules.append(schedule)
            }
        }

        return Depreciation(schedules: schedules)
    }
}

// MARK: - Depreciation Component Protocol

/// Represents a depreciation component that can be used in the builder.
public enum CashFlowDepreciationComponent {
    case straightLine(StraightLine)
}

extension StraightLine: CashFlowDepreciationComponentConvertible {
    /// Converts this straight-line schedule to a depreciation component.
    public var cashFlowDepreciationComponent: CashFlowDepreciationComponent { .straightLine(self) }
}

/// Protocol for types that can be converted to a `CashFlowDepreciationComponent`.
public protocol CashFlowDepreciationComponentConvertible {
    /// The depreciation component representation of this type.
    var cashFlowDepreciationComponent: CashFlowDepreciationComponent { get }
}

extension CashFlowDepreciationBuilder {
    /// Converts a conforming expression to a depreciation component.
    public static func buildExpression(_ expression: CashFlowDepreciationComponentConvertible) -> CashFlowDepreciationComponent {
        expression.cashFlowDepreciationComponent
    }
}

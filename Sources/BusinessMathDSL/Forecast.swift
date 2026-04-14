//
//  Forecast.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation

// MARK: - Forecast Components

/// Revenue forecast with base amount and compound annual growth rate.
///
/// Use in DCF forecasts: `ForecastRevenue(base: 1_000_000, cagr: 0.15)`
public struct ForecastRevenue {
    /// The base revenue amount for year 1.
    public let base: Double
    /// The compound annual growth rate (e.g., 0.15 for 15% growth).
    public let cagr: Double

    /// Creates a revenue forecast with a base amount and growth rate.
    ///
    /// - Parameters:
    ///   - base: The base revenue (must be non-negative).
    ///   - cagr: The compound annual growth rate (must be > -100%).
    public init(base: Double, cagr: Double) {
        guard base >= 0 else {
            preconditionFailure("Base revenue cannot be negative: \(base)")
        }
        guard cagr > -1.0 else {
            preconditionFailure("CAGR cannot be less than -100%: \(cagr)")
        }
        self.base = base
        self.cagr = cagr
    }

    /// Calculate revenue for a specific year
    public func value(forYear year: Int) -> Double {
        guard year > 0 else { return 0 }
        return base * pow(1.0 + cagr, Double(year - 1))
    }
}

/// EBITDA as a percentage margin of revenue.
public struct EBITDA {
    /// The EBITDA margin as a decimal (e.g., 0.25 for 25%).
    public let margin: Double

    /// Creates an EBITDA configuration with the specified margin.
    ///
    /// - Parameter margin: The EBITDA margin (must be between 0 and 1).
    public init(margin: Double) {
        guard margin >= 0 && margin <= 1.0 else {
            preconditionFailure("EBITDA margin must be between 0 and 1: \(margin)")
        }
        self.margin = margin
    }
}

/// Depreciation as a percentage of revenue.
///
/// Use in DCF forecasts: `ForecastDepreciation(percentage: 0.05)`
public struct ForecastDepreciation {
    /// The depreciation percentage as a decimal (e.g., 0.05 for 5%).
    public let percentage: Double

    /// Creates a depreciation configuration as a percentage of revenue.
    ///
    /// - Parameter percentage: The depreciation percentage (must be between 0 and 1).
    public init(percentage: Double) {
        guard percentage >= 0 && percentage <= 1.0 else {
            preconditionFailure("Depreciation percentage must be between 0 and 1: \(percentage)")
        }
        self.percentage = percentage
    }
}

/// Capital expenditures as a percentage of revenue.
public struct CapEx {
    /// The CapEx percentage as a decimal (e.g., 0.08 for 8%).
    public let percentage: Double

    /// Creates a CapEx configuration as a percentage of revenue.
    ///
    /// - Parameter percentage: The CapEx percentage (must be between 0 and 1).
    public init(percentage: Double) {
        guard percentage >= 0 && percentage <= 1.0 else {
            preconditionFailure("CapEx percentage must be between 0 and 1: \(percentage)")
        }
        self.percentage = percentage
    }
}

/// Working capital requirements based on days of sales.
public struct WorkingCapital {
    /// The number of days of sales to hold as working capital.
    public let daysOfSales: Double

    /// Creates a working capital configuration based on days of sales.
    ///
    /// - Parameter daysOfSales: The number of days of sales (must be non-negative).
    public init(daysOfSales: Double) {
        guard daysOfSales >= 0 else {
            preconditionFailure("Days of sales cannot be negative: \(daysOfSales)")
        }
        self.daysOfSales = daysOfSales
    }
}

// MARK: - Forecast Model

/// Multi-year financial forecast for DCF valuation.
///
/// Combines revenue, EBITDA margin, depreciation, CapEx, and working capital assumptions.
public struct Forecast {
    /// The number of years in the forecast period.
    public let years: Int
    /// The revenue forecast with base amount and growth rate.
    public let revenue: ForecastRevenue?
    /// The EBITDA margin as a percentage of revenue.
    public let ebitda: EBITDA?
    /// The depreciation as a percentage of revenue.
    public let depreciation: ForecastDepreciation?
    /// The capital expenditure as a percentage of revenue.
    public let capex: CapEx?
    /// The working capital requirement in days of sales.
    public let workingCapital: WorkingCapital?

    internal init(
        years: Int,
        revenue: ForecastRevenue? = nil,
        ebitda: EBITDA? = nil,
        depreciation: ForecastDepreciation? = nil,
        capex: CapEx? = nil,
        workingCapital: WorkingCapital? = nil
    ) {
        guard years > 0 else {
            preconditionFailure("Forecast years must be positive: \(years)")
        }
        self.years = years
        self.revenue = revenue
        self.ebitda = ebitda
        self.depreciation = depreciation
        self.capex = capex
        self.workingCapital = workingCapital
    }

    /// Create forecast using result builder
    public init(_ years: Int, @ForecastBuilder content: () -> ForecastComponents) {
        guard years > 0 else {
            preconditionFailure("Forecast years must be positive: \(years)")
        }
        let components = content()
        self.years = years
        self.revenue = components.revenue
        self.ebitda = components.ebitda
        self.depreciation = components.depreciation
        self.capex = components.capex
        self.workingCapital = components.workingCapital
    }

    /// Calculate projected revenues for all years
    public var projectedRevenues: [Double] {
        guard let revenue = revenue else { return [] }
        return (1...years).map { year in
            revenue.value(forYear: year)
        }
    }

    /// Calculate projected EBITDA for all years
    public var projectedEBITDA: [Double] {
        guard let ebitda = ebitda else { return [] }
        return projectedRevenues.map { $0 * ebitda.margin }
    }

    /// Calculate projected depreciation for all years
    public var projectedDepreciation: [Double] {
        guard let depreciation = depreciation else { return [] }
        return projectedRevenues.map { $0 * depreciation.percentage }
    }

    /// Calculate projected CapEx for all years
    public var projectedCapEx: [Double] {
        guard let capex = capex else { return [] }
        return projectedRevenues.map { $0 * capex.percentage }
    }

    /// Calculate working capital changes for all years
    public var workingCapitalChanges: [Double] {
        guard let wc = workingCapital else { return [] }

        let revenues = projectedRevenues
        var changes: [Double] = []
        var previousWC: Double = 0

        for revenue in revenues {
            let currentWC = revenue * (wc.daysOfSales / 365.0)
            let change = currentWC - previousWC
            changes.append(change)
            previousWC = currentWC
        }

        return changes
    }

    /// Calculate free cash flows for all years
    /// FCF = EBITDA - CapEx - ΔWorking Capital
    /// (Depreciation is a non-cash expense, so it's implicitly in EBITDA calculation)
    public var freeCashFlows: [Double] {
        let ebitdaValues = projectedEBITDA
        let capexValues = projectedCapEx
        let wcChanges = workingCapitalChanges

        guard !ebitdaValues.isEmpty else { return [] }

        let capex = !capexValues.isEmpty ? capexValues : Array(repeating: 0, count: years)
        let wc = !wcChanges.isEmpty ? wcChanges : Array(repeating: 0, count: years)

        return zip(zip(ebitdaValues, capex), wc).map { (pair, wcChange) in
            let (ebitda, capexValue) = pair
            return ebitda - capexValue - wcChange
        }
    }

    /// Get final year EBITDA (used for terminal value calculation)
    public var finalEBITDA: Double {
        projectedEBITDA.last ?? 0
    }

    /// Get final year free cash flow (used for terminal value calculation)
    public var finalFCF: Double {
        freeCashFlows.last ?? 0
    }
}

// MARK: - Forecast Components Container

/// Container for forecast components (used by result builder).
public struct ForecastComponents {
    /// The revenue forecast configuration.
    public let revenue: ForecastRevenue?
    /// The EBITDA margin configuration.
    public let ebitda: EBITDA?
    /// The depreciation configuration.
    public let depreciation: ForecastDepreciation?
    /// The capital expenditure configuration.
    public let capex: CapEx?
    /// The working capital configuration.
    public let workingCapital: WorkingCapital?
}

// MARK: - Forecast Result Builder

/// Result builder for constructing `Forecast` instances declaratively.
///
/// Allows composing revenue, EBITDA, depreciation, CapEx, and working capital components.
@resultBuilder
public struct ForecastBuilder {
    /// Builds a forecast components container from the provided components.
    ///
    /// - Parameter components: The revenue, EBITDA, depreciation, CapEx, and working capital components.
    /// - Returns: A `ForecastComponents` container.
    public static func buildBlock(_ components: ForecastComponent...) -> ForecastComponents {
        var revenue: ForecastRevenue? = nil
        var ebitda: EBITDA? = nil
        var depreciation: ForecastDepreciation? = nil
        var capex: CapEx? = nil
        var workingCapital: WorkingCapital? = nil

        for component in components {
            switch component {
            case .revenue(let r):
                revenue = r
            case .ebitda(let e):
                ebitda = e
            case .depreciation(let d):
                depreciation = d
            case .capex(let c):
                capex = c
            case .workingCapital(let wc):
                workingCapital = wc
            }
        }

        return ForecastComponents(
            revenue: revenue,
            ebitda: ebitda,
            depreciation: depreciation,
            capex: capex,
            workingCapital: workingCapital
        )
    }

    /// Converts a `ForecastRevenue` to a forecast component.
    public static func buildExpression(_ expression: ForecastRevenue) -> ForecastComponent {
        .revenue(expression)
    }

    /// Converts an `EBITDA` to a forecast component.
    public static func buildExpression(_ expression: EBITDA) -> ForecastComponent {
        .ebitda(expression)
    }

    /// Converts a `ForecastDepreciation` to a forecast component.
    public static func buildExpression(_ expression: ForecastDepreciation) -> ForecastComponent {
        .depreciation(expression)
    }

    /// Converts a `CapEx` to a forecast component.
    public static func buildExpression(_ expression: CapEx) -> ForecastComponent {
        .capex(expression)
    }

    /// Converts a `WorkingCapital` to a forecast component.
    public static func buildExpression(_ expression: WorkingCapital) -> ForecastComponent {
        .workingCapital(expression)
    }
}

// MARK: - Forecast Component Protocol

/// Represents a component that can be used in a forecast builder.
///
/// Cases correspond to revenue, EBITDA, depreciation, CapEx, and working capital.
public enum ForecastComponent {
    case revenue(ForecastRevenue)
    case ebitda(EBITDA)
    case depreciation(ForecastDepreciation)
    case capex(CapEx)
    case workingCapital(WorkingCapital)
}

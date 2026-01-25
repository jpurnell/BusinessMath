//
//  Forecast.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation

// MARK: - Forecast Components

/// Revenue forecast with base amount and compound annual growth rate
/// Use in DCF forecasts: ForecastRevenue(base: 1_000_000, cagr: 0.15)
public struct ForecastRevenue {
    public let base: Double
    public let cagr: Double

    public init(base: Double, cagr: Double) {
        guard base >= 0 else {
            fatalError("Base revenue cannot be negative: \(base)")
        }
        guard cagr > -1.0 else {
            fatalError("CAGR cannot be less than -100%: \(cagr)")
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

/// EBITDA as a percentage margin of revenue
public struct EBITDA {
    public let margin: Double

    public init(margin: Double) {
        guard margin >= 0 && margin <= 1.0 else {
            fatalError("EBITDA margin must be between 0 and 1: \(margin)")
        }
        self.margin = margin
    }
}

/// Depreciation as a percentage of revenue
/// Use in DCF forecasts: ForecastDepreciation(percentage: 0.05)
public struct ForecastDepreciation {
    public let percentage: Double

    public init(percentage: Double) {
        guard percentage >= 0 && percentage <= 1.0 else {
            fatalError("Depreciation percentage must be between 0 and 1: \(percentage)")
        }
        self.percentage = percentage
    }
}

/// Capital expenditures as a percentage of revenue
public struct CapEx {
    public let percentage: Double

    public init(percentage: Double) {
        guard percentage >= 0 && percentage <= 1.0 else {
            fatalError("CapEx percentage must be between 0 and 1: \(percentage)")
        }
        self.percentage = percentage
    }
}

/// Working capital requirements based on days of sales
public struct WorkingCapital {
    public let daysOfSales: Double

    public init(daysOfSales: Double) {
        guard daysOfSales >= 0 else {
            fatalError("Days of sales cannot be negative: \(daysOfSales)")
        }
        self.daysOfSales = daysOfSales
    }
}

// MARK: - Forecast Model

/// Multi-year financial forecast for DCF valuation
public struct Forecast {
    public let years: Int
    public let revenue: ForecastRevenue?
    public let ebitda: EBITDA?
    public let depreciation: ForecastDepreciation?
    public let capex: CapEx?
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
            fatalError("Forecast years must be positive: \(years)")
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
            fatalError("Forecast years must be positive: \(years)")
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

/// Container for forecast components (used by result builder)
public struct ForecastComponents {
    public let revenue: ForecastRevenue?
    public let ebitda: EBITDA?
    public let depreciation: ForecastDepreciation?
    public let capex: CapEx?
    public let workingCapital: WorkingCapital?
}

// MARK: - Forecast Result Builder

@resultBuilder
public struct ForecastBuilder {
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

    public static func buildExpression(_ expression: ForecastRevenue) -> ForecastComponent {
        .revenue(expression)
    }

    public static func buildExpression(_ expression: EBITDA) -> ForecastComponent {
        .ebitda(expression)
    }

    public static func buildExpression(_ expression: ForecastDepreciation) -> ForecastComponent {
        .depreciation(expression)
    }

    public static func buildExpression(_ expression: CapEx) -> ForecastComponent {
        .capex(expression)
    }

    public static func buildExpression(_ expression: WorkingCapital) -> ForecastComponent {
        .workingCapital(expression)
    }
}

// MARK: - Forecast Component Protocol

public enum ForecastComponent {
    case revenue(ForecastRevenue)
    case ebitda(EBITDA)
    case depreciation(ForecastDepreciation)
    case capex(CapEx)
    case workingCapital(WorkingCapital)
}

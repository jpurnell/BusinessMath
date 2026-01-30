//
//  DataExport.swift
//  BusinessMath
//
//  Created on November 1, 2025.
//

import Foundation
import RealModule

// MARK: - Financial Model Exporter

/// Exporter for FinancialModel to various formats.
///
/// DataExporter provides functionality to export financial models to
/// CSV and JSON formats for external analysis and reporting.
///
/// Example:
/// ```swift
/// let model = FinancialModel {
///     Revenue {
///         Product("SaaS").price(99).customers(1000)
///     }
///     Costs {
///         Fixed("Salaries", 50_000)
///     }
/// }
///
/// let exporter = DataExporter(model: model)
/// let csv = exporter.exportToCSV()
/// let json = exporter.exportToJSON()
/// ```
public struct DataExporter: Sendable {
    /// The financial model to export
    public let model: FinancialModel

    public init(model: FinancialModel) {
        self.model = model
    }

    /// Export model to CSV format
    ///
    /// - Returns: CSV-formatted string with model components
    public func exportToCSV() -> String {
        var lines: [String] = []

        // Header row
        lines.append("Component,Type,Category,Amount,Percentage")

        // Revenue components
        for component in model.revenueComponents {
            let row = "\(escapeCsv(component.name)),Revenue,Fixed,\(component.amount),"
            lines.append(row)
        }

        // Cost components
        for component in model.costComponents {
            switch component.type {
            case .fixed(let amount):
                let row = "\(escapeCsv(component.name)),Cost,Fixed,\(amount),"
                lines.append(row)
            case .variable(let percentage):
					let percentageStr = percentage.percent()
                let row = "\(escapeCsv(component.name)),Cost,Variable,,\(percentageStr)"
                lines.append(row)
            }
        }

        if lines.count == 1 {
            lines.append("(empty model)")
        }

        return lines.joined(separator: "\n")
    }

    /// Export model to JSON format
    ///
    /// - Parameter includeMetadata: Whether to include model metadata (default: false)
    /// - Returns: JSON-formatted string with model data
    public func exportToJSON(includeMetadata: Bool = false) -> String {
        var dict: [String: Any] = [:]

        // Revenue section
        var revenueArray: [[String: Any]] = []
        for component in model.revenueComponents {
            revenueArray.append([
                "name": component.name,
                "amount": component.amount
            ])
        }
        dict["revenue"] = revenueArray

        // Costs section
        var costsArray: [[String: Any]] = []
        for component in model.costComponents {
            var costDict: [String: Any] = ["name": component.name]
            switch component.type {
            case .fixed(let amount):
                costDict["type"] = "fixed"
                costDict["amount"] = amount
            case .variable(let percentage):
                costDict["type"] = "variable"
                costDict["percentage"] = percentage
            }
            costsArray.append(costDict)
        }
        dict["costs"] = costsArray

        // Metadata (if requested)
        if includeMetadata {
            var metadataDict: [String: Any] = [:]
            if let name = model.metadata.name {
                metadataDict["name"] = name
            }
            metadataDict["version"] = model.metadata.version
            if let description = model.metadata.description {
                metadataDict["description"] = description
            }
            metadataDict["created"] = ISO8601DateFormatter().string(from: model.metadata.createdAt)
            dict["metadata"] = metadataDict
        }

        return dictToJson(dict)
    }

    private func escapeCsv(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }
}

// MARK: - Time Series Exporter

/// Exporter for TimeSeries to various formats.
public struct TimeSeriesExporter<T: Real & Sendable>: Sendable {
    /// The time series to export
    public let series: TimeSeries<T>

	public init(series: TimeSeries<T>) {
        self.series = series
    }

    /// Export time series to CSV format
    ///
    /// - Returns: CSV-formatted string with period and value columns
    public func exportToCSV() -> String {
        var lines: [String] = []

        // Header row
        lines.append("Period,Value\n")

        if series.count == 0 {
            lines.append("(empty series)")
            return lines.joined(separator: "\n")
        }

        // Data rows
        for (period, value) in zip(series.periods, series.valuesArray) {
            let row = "\(period.label),\(value)\n"
            lines.append(row)
        }

        return lines.joined(separator: "")
    }

    /// Export time series to JSON format
    ///
    /// - Returns: JSON-formatted string with period and value data
    public func exportToJSON() -> String {
        var dict: [String: Any] = [:]

        if series.count == 0 {
            dict["data"] = []
            dict["count"] = 0
            return dictToJson(dict)
        }

        var dataArray: [[String: Any]] = []
        for (period, value) in zip(series.periods, series.valuesArray) {
            // Convert to string representation for JSON compatibility
            let valueStr = "\(value)"
            let doubleValue = Double(valueStr) ?? 0.0
            dataArray.append([
                "period": period.label,
                "value": doubleValue
            ])
        }

        dict["data"] = dataArray
        dict["count"] = series.count

        return dictToJson(dict)
    }
}

// MARK: - Investment Exporter

/// Exporter for Investment analysis to various formats.
public struct InvestmentExporter: Sendable {
    /// The investment to export
    public let investment: Investment

    public init(investment: Investment) {
        self.investment = investment
    }

    /// Export investment analysis to CSV format
    ///
    /// - Returns: CSV-formatted string with investment metrics and cash flows
    public func exportToCSV() -> String {
        var lines: [String] = []

        // Header
        lines.append("Metric,Value")

        // Investment metrics
        lines.append("Initial Cost,\(investment.initialCost)")
        lines.append("Discount Rate,\(investment.discountRate)")
        lines.append("NPV,\(investment.npv)")

        if let irr = investment.irr {
            lines.append("IRR,\(irr)")
        }

        if let paybackPeriod = investment.paybackPeriod {
            lines.append("Payback Period,\(paybackPeriod)")
        }

        lines.append("")
        lines.append("Period,Cash Flow,Present Value")

        // Cash flows
        for cashFlow in investment.cashFlows {
            let pv = cashFlow.amount / pow(1 + investment.discountRate, Double(cashFlow.period))
            lines.append("\(cashFlow.period),\(cashFlow.amount),\(pv)")
        }

        return lines.joined(separator: "\n")
    }

    /// Export investment analysis to JSON format
    ///
    /// - Returns: JSON-formatted string with investment data
    public func exportToJSON() -> String {
        var dict: [String: Any] = [:]

        dict["initial_cost"] = investment.initialCost
        dict["discount_rate"] = investment.discountRate
        dict["npv"] = investment.npv

        if let irr = investment.irr {
            dict["irr"] = irr
        }

        if let paybackPeriod = investment.paybackPeriod {
            dict["payback_period"] = paybackPeriod
        }

        var cashFlowsArray: [[String: Any]] = []
        for cashFlow in investment.cashFlows {
            let pv = cashFlow.amount / pow(1 + investment.discountRate, Double(cashFlow.period))
            cashFlowsArray.append([
                "period": cashFlow.period,
                "amount": cashFlow.amount,
                "present_value": pv
            ])
        }
        dict["cash_flows"] = cashFlowsArray

        return dictToJson(dict)
    }
}

// MARK: - JSON Helper

/// Convert dictionary to formatted JSON string
private func dictToJson(_ dict: [String: Any]) -> String {
    guard let jsonData = try? JSONSerialization.data(
        withJSONObject: dict,
        options: [.prettyPrinted, .sortedKeys]
    ) else {
        return "{}"
    }

    return String(data: jsonData, encoding: .utf8) ?? "{}"
}

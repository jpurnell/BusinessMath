//
//  DataExport.swift
//  BusinessMath
//
//  Created on November 1, 2025.
//

import Foundation
import Numerics

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
/// let json = try exporter.exportToJSON()
/// ```
///
/// JSON export refuses rather than defaults: if the model contains a non-finite amount —
/// which a division by zero upstream will produce — ``DataExporter/exportToJSON(includeMetadata:)``
/// throws an error naming the offending key path instead of emitting misleading output.
public struct DataExporter: Sendable {
    /// The financial model to export
    public let model: FinancialModel

    /// Creates a data exporter for a financial model.
    ///
    /// - Parameter model: The financial model to export to CSV or JSON format.
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
    /// - Throws: ``BusinessMathError/dataQuality(message:context:)`` if any component amount or
    ///   percentage is non-finite (NaN or infinite). The error names the offending key path,
    ///   such as `revenue[2].amount`, so the model can be corrected at the source.
    public func exportToJSON(includeMetadata: Bool = false) throws -> String {
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

        return try dictToJson(dict)
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

    /// Creates a time series exporter.
    ///
    /// - Parameter series: The time series to export to CSV or JSON format.
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
    /// - Throws: ``BusinessMathError/dataQuality(message:context:)`` if any observation is
    ///   non-finite (NaN or infinite). The error names the offending key path, such as
    ///   `data[7].value`, so the series can be corrected at the source.
    public func exportToJSON() throws -> String {
        var dict: [String: Any] = [:]

        if series.count == 0 {
            dict["data"] = []
            dict["count"] = 0
            return try dictToJson(dict)
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

        return try dictToJson(dict)
    }
}

// MARK: - Investment Exporter

/// Exporter for Investment analysis to various formats.
public struct InvestmentExporter: Sendable {
    /// The investment to export
    public let investment: Investment

    /// Creates an investment exporter.
    ///
    /// - Parameter investment: The investment analysis to export to CSV or JSON format.
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
    /// - Throws: ``BusinessMathError/dataQuality(message:context:)`` if any metric or cash flow
    ///   is non-finite (NaN or infinite) — for instance a present value derived from a discount
    ///   rate of -100%. The error names the offending key path, such as `cash_flows[3].amount`.
    public func exportToJSON() throws -> String {
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

        return try dictToJson(dict)
    }
}

// MARK: - JSON Helper

/// Human-readable rendering of a non-finite value, for error messages.
private func nonFiniteDescription(_ value: Double) -> String {
    if value.isNaN {
        return "NaN"
    }
    return value > 0 ? "+Infinity" : "-Infinity"
}

/// Find the first non-finite number in a candidate JSON object graph and report its key path.
///
/// Key paths use dot notation for dictionary keys and bracket notation for array indices,
/// so a caller is told exactly which component is at fault — e.g. `revenue[2].amount`.
///
/// - Parameters:
///   - value: The value to inspect. Dictionaries and arrays are walked recursively.
///   - path: The key path accumulated so far.
///   - depth: Current recursion depth.
/// - Returns: The key path and value of the first non-finite number found, or `nil` if none.
private func firstNonFiniteValue(in value: Any, at path: String, depth: Int = 0) -> (path: String, value: Double)? {
    // recursion-safe: bounded by an explicit depth guard; export dictionaries nest two levels
    guard depth < 32 else { return nil }

    if let dictionary = value as? [String: Any] {
        for key in dictionary.keys.sorted() {
            let childPath = path.isEmpty ? key : "\(path).\(key)"
            if let found = firstNonFiniteValue(in: dictionary[key] as Any, at: childPath, depth: depth + 1) {
                return found
            }
        }
        return nil
    }

    if let array = value as? [Any] {
        for (index, element) in array.enumerated() {
            if let found = firstNonFiniteValue(in: element, at: "\(path)[\(index)]", depth: depth + 1) {
                return found
            }
        }
        return nil
    }

    if let double = value as? Double, !double.isFinite {
        return (path, double)
    }

    if let float = value as? Float, !float.isFinite {
        return (path, Double(float))
    }

    return nil
}

/// Convert dictionary to formatted JSON string.
///
/// A non-finite `Double` anywhere in `dict` cannot be written as JSON. `JSONSerialization.data`
/// signals this by raising an Objective-C `NSInvalidArgumentException`, which is not a Swift
/// error: `try?` does not catch it and the process terminates. `isValidJSONObject(_:)` performs
/// the same validation without raising, so it is used as the pre-check here and the offending
/// value is reported rather than defaulted away.
///
/// - Parameter dict: The dictionary to serialize.
/// - Returns: Pretty-printed JSON with sorted keys.
/// - Throws: ``BusinessMathError/dataQuality(message:context:)`` naming the key path and value
///   of the first entry that JSON cannot represent.
private func dictToJson(_ dict: [String: Any]) throws -> String {
    guard JSONSerialization.isValidJSONObject(dict) else {
        guard let offender = firstNonFiniteValue(in: dict, at: "") else {
            throw BusinessMathError.dataQuality(
                message: "Export contains a value that JSON cannot represent",
                context: ["format": "JSON"]
            )
        }

        let rendered = nonFiniteDescription(offender.value)
        throw BusinessMathError.dataQuality(
            message: "\(offender.path) is \(rendered); JSON has no representation for non-finite numbers",
            context: [
                "format": "JSON",
                "path": offender.path,
                "value": rendered
            ]
        )
    }

    let jsonData = try JSONSerialization.data(
        withJSONObject: dict,
        options: [.prettyPrinted, .sortedKeys]
    )

    return String(decoding: jsonData, as: UTF8.self)
}

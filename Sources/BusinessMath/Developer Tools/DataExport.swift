//
//  DataExport.swift
//  BusinessMath
//
//  Created on November 1, 2025.
//

import Foundation
import Numerics

// MARK: - CSV Non-Finite Values

/// The lowercase ASCII token a CSV data column uses for a non-finite number.
///
/// CSV columns are read by parsers, not by people, and unlike JSON — which has no numeric
/// representation for these values at all — CSV can carry them faithfully, so it emits them.
///
/// These three tokens are chosen because they round-trip. They are precisely what Swift's own
/// `Double.description` writes and what `Double(_: String)` reads back, so the value a consumer
/// recovers is the value that was exported; C's `strtod` and Python's `float()` accept them, and
/// pandas treats them as NA/infinity out of the box. They are also locale-invariant, which a
/// formatted number is not. Spreadsheets are the weak case — Excel and Numbers parse none of the
/// candidates as numeric and will land any of them in a text cell — but that is a tie between
/// every option, and a visible `nan` that makes downstream formulas fail loudly is better than
/// the alternative of an empty field, which silently reads as zero.
///
/// What no export path may do is reach for a *display* formatter. `percent()` renders infinity
/// as `∞`, which is right for a person reading a report and wrong for a data column: it is a
/// glyph no numeric parser accepts, and it made the same model emit `nan` in one column and `∞`
/// in another. Routing every numeric CSV field through this function is what makes the token
/// uniform — including for a NaN carrying a payload, whose `description` would otherwise be
/// `nan(0x…)`, and for a generic `T: Real` whose `description` is not specified at all.
///
/// - Parameter value: The value bound for a CSV data column.
/// - Returns: The ASCII token, or `nil` when `value` is finite and should be formatted normally.
internal func csvNonFiniteToken<T: FloatingPoint>(_ value: T) -> String? {
    if value.isNaN {
        return "nan"
    }
    if value.isInfinite {
        return value < 0 ? "-inf" : "inf"
    }
    return nil
}

/// Renders a `Double` for a CSV data column, substituting the ASCII token when it is non-finite.
///
/// - Parameter value: The value bound for a CSV data column.
/// - Returns: ``csvNonFiniteToken(_:)`` when `value` is non-finite, otherwise its default
///   textual representation — byte-identical to interpolating the value directly.
internal func csvNumber(_ value: Double) -> String {
    csvNonFiniteToken(value) ?? "\(value)"
}

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
///
/// Neither export refuses on a non-finite amount — which a division by zero upstream will
/// produce — and neither invents a number to replace it. ``DataExporter/exportToCSV()`` writes
/// the ASCII token `nan`, `inf` or `-inf`, which a numeric parser round-trips back to the value.
/// ``DataExporter/exportToJSON(includeMetadata:)`` writes `null`, because JSON has no literal
/// for those values but `null` is legal, standard, and self-documenting: the reader sees that a
/// number was not available, in the record where it belonged, and can act on it. What neither
/// does is substitute a plausible zero or drop the field.
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
    ///
    /// Non-finite values are written as the lowercase ASCII tokens `nan`, `inf` and `-inf` —
    /// see ``csvNonFiniteToken(_:)``. Every numeric column uses the same token for the same
    /// condition, and no column ever contains a display glyph such as `∞`.
    public func exportToCSV() -> String {
        var lines: [String] = []

        // Header row
        lines.append("Component,Type,Category,Amount,Percentage")

        // Revenue components
        for component in model.revenueComponents {
            let amountStr = csvNonFiniteToken(component.amount) ?? "\(component.amount)"
            let row = "\(escapeCsv(component.name)),Revenue,Fixed,\(amountStr),"
            lines.append(row)
        }

        // Cost components
        for component in model.costComponents {
            switch component.type {
            case .fixed(let amount):
                let amountStr = csvNonFiniteToken(amount) ?? "\(amount)"
                let row = "\(escapeCsv(component.name)),Cost,Fixed,\(amountStr),"
                lines.append(row)
            case .variable(let percentage):
                // `percent()` is a display formatter and renders infinity as the glyph `∞`;
                // a data column takes the ASCII token instead. Finite values are unaffected.
                let percentageStr = csvNonFiniteToken(percentage) ?? percentage.percent()
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
    /// A component amount or percentage that is non-finite (NaN or ±infinity) is written as
    /// JSON `null`. JSON has no literal for those values, but `null` is legal and standard, and
    /// it says in band exactly what happened: the number was not available. The component's
    /// other fields — its name, its type — are still exported, so the reader can see *which*
    /// figure is missing and go fix the model.
    ///
    /// ```json
    /// { "name" : "Bad", "amount" : null }
    /// ```
    ///
    /// - Parameter includeMetadata: Whether to include model metadata (default: false)
    /// - Returns: JSON-formatted string with model data; non-finite numbers appear as `null`.
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

    /// Creates a time series exporter.
    ///
    /// - Parameter series: The time series to export to CSV or JSON format.
	public init(series: TimeSeries<T>) {
        self.series = series
    }

    /// Export time series to CSV format
    ///
    /// - Returns: CSV-formatted string with period and value columns
    ///
    /// Non-finite values are written as the lowercase ASCII tokens `nan`, `inf` and `-inf` —
    /// see ``csvNonFiniteToken(_:)``. Every numeric column uses the same token for the same
    /// condition, and no column ever contains a display glyph such as `∞`.
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
            let valueStr = csvNonFiniteToken(value) ?? "\(value)"
            let row = "\(period.label),\(valueStr)\n"
            lines.append(row)
        }

        return lines.joined(separator: "")
    }

    /// Export time series to JSON format
    ///
    /// A non-finite observation (NaN or ±infinity) is written as JSON `null`. The observation
    /// keeps its place and its period label, so the series stays aligned with its index and a
    /// gap reads as a gap rather than as a shortened series.
    ///
    /// - Returns: JSON-formatted string with period and value data; non-finite observations
    ///   appear as `null`.
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

    /// Creates an investment exporter.
    ///
    /// - Parameter investment: The investment analysis to export to CSV or JSON format.
    public init(investment: Investment) {
        self.investment = investment
    }

    /// Export investment analysis to CSV format
    ///
    /// - Returns: CSV-formatted string with investment metrics and cash flows
    ///
    /// Non-finite values are written as the lowercase ASCII tokens `nan`, `inf` and `-inf` —
    /// see ``csvNonFiniteToken(_:)``. Every numeric column uses the same token for the same
    /// condition, and no column ever contains a display glyph such as `∞`.
    public func exportToCSV() -> String {
        var lines: [String] = []

        // Header
        lines.append("Metric,Value")

        // Investment metrics
        lines.append("Initial Cost,\(csvNumber(investment.initialCost))")
        lines.append("Discount Rate,\(csvNumber(investment.discountRate))")
        lines.append("NPV,\(csvNumber(investment.npv))")

        if let irr = investment.irr {
            lines.append("IRR,\(csvNumber(irr))")
        }

        if let paybackPeriod = investment.paybackPeriod {
            lines.append("Payback Period,\(csvNumber(paybackPeriod))")
        }

        lines.append("")
        lines.append("Period,Cash Flow,Present Value")

        // Cash flows
        for cashFlow in investment.cashFlows {
            // A discount rate of -100% divides by zero, so the present value can be non-finite
            // even when every input amount is finite.
            let pv = cashFlow.amount / pow(1 + investment.discountRate, Double(cashFlow.period))
            lines.append("\(cashFlow.period),\(csvNumber(cashFlow.amount)),\(csvNumber(pv))")
        }

        return lines.joined(separator: "\n")
    }

    /// Export investment analysis to JSON format
    ///
    /// A non-finite metric or cash flow (NaN or ±infinity) — for instance a present value
    /// derived from a discount rate of -100% — is written as JSON `null`. Every other figure in
    /// the export is unaffected, so one undefined present value does not cost the caller the
    /// NPV, the IRR and the rest of the schedule.
    ///
    /// - Returns: JSON-formatted string with investment data; non-finite figures appear as
    ///   `null`.
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

/// The maximum nesting the JSON sanitizer will descend before it stops trusting the graph.
///
/// Export dictionaries nest two or three levels. The limit exists to make the recursion
/// provably terminating, not because any real export approaches it.
private let jsonSanitizerDepthLimit = 32

/// Replace every non-finite number in a candidate JSON object graph with `NSNull()`.
///
/// JSON has no literal for NaN or ±Infinity — the grammar admits no such token — but it does
/// have `null`, and `null` where a number belongs is the standard, self-documenting way to say
/// "this number is not available". That is what makes it the right substitution and a default
/// like `0` the wrong one: `0` is a lie a consumer cannot detect, `null` is a fact it can.
///
/// Everything else is passed through untouched, so a model whose values are all finite
/// serializes byte-for-byte as it always did.
///
/// - Parameters:
///   - value: The value to sanitize. Dictionaries and arrays are walked recursively.
///   - depth: Current recursion depth.
/// - Returns: The same graph with non-finite `Double` and `Float` values replaced by `NSNull()`.
///   A subtree deeper than ``jsonSanitizerDepthLimit`` is replaced wholesale by `NSNull()`,
///   because at that point the walk cannot certify it contains nothing un-serializable.
internal func sanitizedForJSON(_ value: Any, depth: Int = 0) -> Any {
    // recursion-safe: bounded by an explicit depth guard; export dictionaries nest two levels
    guard depth < jsonSanitizerDepthLimit else { return NSNull() }

    if let dictionary = value as? [String: Any] {
        var sanitized: [String: Any] = [:]
        sanitized.reserveCapacity(dictionary.count)
        for (key, element) in dictionary {
            sanitized[key] = sanitizedForJSON(element, depth: depth + 1)
        }
        return sanitized
    }

    if let array = value as? [Any] {
        return array.map { sanitizedForJSON($0, depth: depth + 1) }
    }

    if let double = value as? Double, !double.isFinite {
        return NSNull()
    }

    if let float = value as? Float, !float.isFinite {
        return NSNull()
    }

    return value
}

/// Convert dictionary to formatted JSON string.
///
/// A non-finite `Double` anywhere in `dict` cannot be written as JSON. `JSONSerialization.data`
/// signals this by raising an Objective-C `NSInvalidArgumentException`, which is not a Swift
/// error: `try?` does not catch it and the process terminates. So the graph is sanitized first
/// — every non-finite number becomes `NSNull()`, which is legal JSON and tells the consumer
/// plainly that a number was not available. Nothing is dropped and nothing is defaulted, so a
/// single bad field does not cost the caller the export.
///
/// `isValidJSONObject(_:)` remains as a second check after sanitizing. It cannot now be tripped
/// by a non-finite number, so if it fails it means an exporter placed a value in the dictionary
/// that JSON cannot carry at all — a `Date`, a struct, a `URL`. That is a defect in this file,
/// not in the caller's data: no model change can fix it and no `null` can honestly stand in for
/// it. It therefore traps with a message naming the situation rather than returning `"{}"`,
/// which is what the original code did and which reported success while emitting nothing.
///
/// - Parameter dict: The dictionary to serialize.
/// - Returns: Pretty-printed JSON with sorted keys, non-finite numbers rendered as `null`.
private func dictToJson(_ dict: [String: Any]) -> String {
    let sanitized = sanitizedForJSON(dict)

    guard JSONSerialization.isValidJSONObject(sanitized) else {
        preconditionFailure(
            "BusinessMath JSON export built an object JSONSerialization rejects even after "
            + "non-finite numbers were replaced with null. This is a bug in DataExport.swift — "
            + "an exporter put a value of a type JSON cannot represent into the dictionary."
        )
    }

    do {
        let jsonData = try JSONSerialization.data(
            withJSONObject: sanitized,
            options: [.prettyPrinted, .sortedKeys]
        )
        return String(decoding: jsonData, as: UTF8.self)
    } catch {
        preconditionFailure(
            "BusinessMath JSON export failed to serialize an object that isValidJSONObject "
            + "accepted: \(error). This is a bug in DataExport.swift."
        )
    }
}

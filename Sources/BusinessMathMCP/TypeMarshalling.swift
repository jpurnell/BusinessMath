import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - JSON-Compatible Type Wrappers

/// JSON-compatible representation of a Period
public struct PeriodJSON: Codable, Sendable {
    public let year: Int
    public let month: Int?
    public let day: Int?
    public let type: String

    public init(from period: Period) {
        self.year = period.year
        self.month = period.month
        self.day = period.day
        self.type = period.type.rawValue
    }

    public func toPeriod() throws -> Period {
        guard let periodType = PeriodType(rawValue: type) else {
            throw MarshallingError.invalidPeriodType(type)
        }

        switch periodType {
        case .annual:
            return Period.year(year)
        case .quarterly:
            // For quarterly, calculate quarter number from month
            guard let month = month else {
                throw MarshallingError.missingField("month")
            }
            let quarter = (month - 1) / 3 + 1
            return Period.quarter(year: year, quarter: quarter)
        case .monthly:
            guard let month = month else {
                throw MarshallingError.missingField("month")
            }
            return Period.month(year: year, month: month)
        case .daily:
            // For daily periods, need to construct a Date
            guard let month = month, let day = day else {
                throw MarshallingError.missingField("month or day")
            }
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            guard let date = Calendar.current.date(from: components) else {
                throw MarshallingError.invalidData("Invalid date components")
            }
            return Period.day(date)
        }
    }
}

/// JSON-compatible representation of a TimeSeries
public struct TimeSeriesJSON: Codable, Sendable {
    public let data: [TimeSeriesPointJSON]
    public let metadata: TimeSeriesMetadataJSON?

    public struct TimeSeriesPointJSON: Codable, Sendable {
        public let period: PeriodJSON
        public let value: Double
    }

    public struct TimeSeriesMetadataJSON: Codable, Sendable {
        public let name: String
        public let description: String?
        public let unit: String?
    }

    public init(from timeSeries: TimeSeries<Double>) {
        // Combine periods and values into data points
        let periods = timeSeries.periods
        let values = timeSeries.valuesArray

        self.data = zip(periods, values).map { period, value in
            TimeSeriesPointJSON(
                period: PeriodJSON(from: period),
                value: value
            )
        }

        self.metadata = TimeSeriesMetadataJSON(
            name: timeSeries.metadata.name,
            description: timeSeries.metadata.description,
            unit: timeSeries.metadata.unit
        )
    }

    public func toTimeSeries() throws -> TimeSeries<Double> {
        var periods: [Period] = []
        var values: [Double] = []

        for point in data {
            let period = try point.period.toPeriod()
            periods.append(period)
            values.append(point.value)
        }

        let metadata: TimeSeriesMetadata
        if let md = self.metadata {
            metadata = TimeSeriesMetadata(
                name: md.name,
                description: md.description,
                unit: md.unit
            )
        } else {
            metadata = TimeSeriesMetadata(name: "Unnamed")
        }

        return TimeSeries(periods: periods, values: values, metadata: metadata)
    }
}

/// JSON-compatible representation of cash flows
public struct CashFlowJSON: Codable, Sendable {
    public let period: Int
    public let amount: Double

    public init(period: Int, amount: Double) {
        self.period = period
        self.amount = amount
    }
}

/// JSON-compatible representation of an amortization schedule
public struct AmortizationScheduleJSON: Codable, Sendable {
    public let payments: [AmortizationPaymentJSON]
    public let summary: SummaryJSON

    public struct AmortizationPaymentJSON: Codable, Sendable {
        public let period: Int
        public let payment: Double
        public let principal: Double
        public let interest: Double
        public let balance: Double
    }

    public struct SummaryJSON: Codable, Sendable {
        public let totalPayments: Double
        public let totalPrincipal: Double
        public let totalInterest: Double
    }
}

/// JSON-compatible representation of financial ratios
public struct FinancialRatiosJSON: Codable, Sendable {
    public let profitability: ProfitabilityRatiosJSON?
    public let efficiency: EfficiencyRatiosJSON?
    public let liquidity: LiquidityRatiosJSON?
    public let solvency: SolvencyRatiosJSON?

    public struct ProfitabilityRatiosJSON: Codable, Sendable {
        public let returnOnAssets: Double?
        public let returnOnEquity: Double?
        public let grossMargin: Double?
        public let operatingMargin: Double?
        public let netMargin: Double?
    }

    public struct EfficiencyRatiosJSON: Codable, Sendable {
        public let assetTurnover: Double?
        public let inventoryTurnover: Double?
        public let receivablesTurnover: Double?
        public let daysInInventory: Double?
        public let daysInReceivables: Double?
    }

    public struct LiquidityRatiosJSON: Codable, Sendable {
        public let currentRatio: Double?
        public let quickRatio: Double?
        public let cashRatio: Double?
    }

    public struct SolvencyRatiosJSON: Codable, Sendable {
        public let debtToEquity: Double?
        public let debtToAssets: Double?
        public let interestCoverage: Double?
        public let debtServiceCoverage: Double?
    }
}

/// JSON-compatible representation of simulation results
public struct SimulationResultsJSON: Codable, Sendable {
    public let statistics: StatisticsJSON
    public let percentiles: PercentilesJSON
    public let trials: Int

    public struct StatisticsJSON: Codable, Sendable {
        public let mean: Double
        public let standardDeviation: Double
        public let minimum: Double
        public let maximum: Double
        public let confidenceInterval95Lower: Double
        public let confidenceInterval95Upper: Double
    }

    public struct PercentilesJSON: Codable, Sendable {
        public let p10: Double
        public let p25: Double
        public let p50: Double
        public let p75: Double
        public let p90: Double
        public let p95: Double
        public let p99: Double
    }
}

/// JSON-compatible representation of trend analysis results
public struct TrendAnalysisJSON: Codable, Sendable {
    public let trendType: String
    public let parameters: [String: Double]
    public let forecast: [ForecastPointJSON]
    public let rSquared: Double?

    public struct ForecastPointJSON: Codable, Sendable {
        public let period: PeriodJSON
        public let value: Double
    }
}

// MARK: - Marshalling Errors

public enum MarshallingError: Error, LocalizedError, Sendable {
    case invalidPeriodType(String)
    case missingField(String)
    case invalidData(String)
    case conversionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPeriodType(let type):
            return "Invalid period type: \(type)"
        case .missingField(let field):
            return "Missing required field: \(field)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .conversionFailed(let message):
            return "Conversion failed: \(message)"
        }
    }
}

// MARK: - Helper Extensions

extension Array where Element == (Period, Double) {
    /// Convert to JSON-compatible format
    public func toJSON() -> [[String: Any]] {
        return self.map { period, value in
            [
                "period": PeriodJSON(from: period),
                "value": value
            ]
        }
    }
}

extension Dictionary where Key == String, Value == MCP.Value {
    /// Parse a Period from arguments
    public func getPeriod(_ key: String) throws -> Period {
        guard let value = self[key] else {
            throw ValueExtractionError.missingRequiredArgument(key)
        }

        // Try to decode as PeriodJSON
        guard let dict = value.objectValue else {
            throw ValueExtractionError.invalidArguments("\(key) must be an object")
        }

        // Manual parsing of period dictionary
        guard let yearValue = dict["year"],
              let year = yearValue.intValue,
              let typeValue = dict["type"],
              let typeString = typeValue.stringValue,
              let periodType = PeriodType(rawValue: typeString) else {
            throw ValueExtractionError.invalidArguments("\(key) must have valid year and type")
        }

        switch periodType {
        case .annual:
            return Period.year(year)
        case .quarterly:
            guard let monthValue = dict["month"],
                  let month = monthValue.intValue else {
                throw ValueExtractionError.invalidArguments("\(key) quarter must have month")
            }
            let quarter = (month - 1) / 3 + 1
            return Period.quarter(year: year, quarter: quarter)
        case .monthly:
            guard let monthValue = dict["month"],
                  let month = monthValue.intValue else {
                throw ValueExtractionError.invalidArguments("\(key) month must have month")
            }
            return Period.month(year: year, month: month)
        case .daily:
            guard let monthValue = dict["month"],
                  let month = monthValue.intValue,
                  let dayValue = dict["day"],
                  let day = dayValue.intValue else {
                throw ValueExtractionError.invalidArguments("\(key) day must have month and day")
            }
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            guard let date = Calendar.current.date(from: components) else {
                throw ValueExtractionError.invalidArguments("\(key) has invalid date components")
            }
            return Period.day(date)
        }
    }

    /// Parse a TimeSeries from arguments
    public func getTimeSeries(_ key: String) throws -> TimeSeries<Double> {
        guard let value = self[key] else {
            throw ValueExtractionError.missingRequiredArgument(key)
        }

        // Convert Value to JSON data and decode
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(value)
        let decoder = JSONDecoder()
        let timeSeriesJSON = try decoder.decode(TimeSeriesJSON.self, from: jsonData)
        return try timeSeriesJSON.toTimeSeries()
    }
}

// MARK: - Formatting Helpers

extension Double {
    /// Format as currency
    public func formatCurrency(decimals: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = decimals
        formatter.minimumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: self)) ?? "$\(self)"
    }

    /// Format as percentage
    public func formatPercentage(decimals: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = decimals
        formatter.minimumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: self)) ?? "\(self * 100)%"
    }

    /// Format as decimal
    public func formatDecimal(decimals: Int = 2) -> String {
        return String(format: "%.\(decimals)f", self)
    }
}

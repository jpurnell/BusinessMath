//
//  CalculationCache.swift
//  BusinessMath
//
//  Created on November 1, 2025.
//

import Foundation

// MARK: - Calculation Cache

/// Cache for frequently-accessed financial calculations.
///
/// Provides thread-safe caching of calculation results to avoid
/// redundant expensive operations when inputs haven't changed.
///
/// Example:
/// ```swift
/// let cache = CalculationCache()
/// let profit = cache.getOrCalculate(key: "model_profit_\(modelId)") {
///     model.calculateProfit()
/// }
/// ```
public final class CalculationCache: @unchecked Sendable {
    private var cache: [String: CachedValue] = [:]
    private let lock = NSLock()
    private let maxSize: Int
    private let ttl: TimeInterval

    private struct CachedValue {
        let value: Any
        let timestamp: Date
    }

    /// Initialize a calculation cache
    ///
    /// - Parameters:
    ///   - maxSize: Maximum number of cached items (default: 1000)
    ///   - ttl: Time-to-live in seconds (default: 300 = 5 minutes)
    public init(maxSize: Int = 1000, ttl: TimeInterval = 300) {
        self.maxSize = maxSize
        self.ttl = ttl
    }

    /// Get cached value or calculate and cache it
    ///
    /// - Parameters:
    ///   - key: Cache key
    ///   - calculation: Closure that performs the calculation
    /// - Returns: Cached or newly calculated value
    public func getOrCalculate<T>(key: String, calculation: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }

        // Check cache
        if let cached = cache[key] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < ttl, let value = cached.value as? T {
                return value
            }
        }

        // Calculate and cache
        let value = calculation()
        cache[key] = CachedValue(value: value, timestamp: Date())

        // Evict old entries if needed
        if cache.count > maxSize {
            evictOldest()
        }

        return value
    }

    /// Clear all cached values
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }

    /// Remove specific cached value
    public func remove(key: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: key)
    }

    /// Get current cache size
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }

    private func evictOldest() {
        // Remove the oldest 20% of entries
        let entriesToRemove = maxSize / 5
        let sortedKeys = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            .prefix(entriesToRemove)
            .map { $0.key }

        for key in sortedKeys {
            cache.removeValue(forKey: key)
        }
    }
}

// MARK: - Model Hash Extension

extension FinancialModel {
    /// Generate a hash key for caching based on model contents
    public func cacheKey() -> String {
        var hasher = Hasher()

        // Hash revenue components
        for component in revenueComponents {
            hasher.combine(component.name)
            hasher.combine(component.amount)
        }

        // Hash cost components
        for component in costComponents {
            hasher.combine(component.name)
            switch component.type {
            case .fixed(let amount):
                hasher.combine("fixed")
                hasher.combine(amount)
            case .variable(let percentage):
                hasher.combine("variable")
                hasher.combine(percentage)
            }
        }

        return "model_\(hasher.finalize())"
    }
}

// MARK: - Cached Financial Model Extension

extension FinancialModel {
    /// Shared cache for all financial models
    private static let sharedCache = CalculationCache()

    /// Calculate revenue with caching
    public func calculateRevenueCached() -> Double {
        let key = "\(cacheKey())_revenue"
        return Self.sharedCache.getOrCalculate(key: key) {
            calculateRevenue()
        }
    }

    /// Calculate costs with caching
    public func calculateCostsCached(revenue: Double? = nil) -> Double {
        let revenueKey = revenue.map { String($0) } ?? "nil"
        let key = "\(cacheKey())_costs_\(revenueKey)"
        return Self.sharedCache.getOrCalculate(key: key) {
            calculateCosts(revenue: revenue)
        }
    }

    /// Calculate profit with caching
    public func calculateProfitCached() -> Double {
        let key = "\(cacheKey())_profit"
        return Self.sharedCache.getOrCalculate(key: key) {
            calculateProfit()
        }
    }

    /// Clear calculation cache for all models
    public static func clearCalculationCache() {
        sharedCache.clear()
    }
}

// MARK: - String Builder Optimization

/// Efficient string builder for export operations
final class StringBuilder {
    private var parts: [String] = []
    private var estimatedLength: Int = 0

    func append(_ string: String) {
        parts.append(string)
        estimatedLength += string.count
    }

    func append(_ strings: [String]) {
        parts.append(contentsOf: strings)
        estimatedLength += strings.reduce(0) { $0 + $1.count }
    }

    func build() -> String {
        parts.joined()
    }

    func clear() {
        parts.removeAll(keepingCapacity: true)
        estimatedLength = 0
    }

    var count: Int {
        estimatedLength
    }
}

// MARK: - Optimized Export Functions

extension DataExporter {
    /// Export model to CSV using optimized string building
    public func exportToCSVOptimized() -> String {
        let builder = StringBuilder()

        // Header row
        builder.append("Component,Type,Category,Amount,Percentage\n")

        // Revenue components
        for component in model.revenueComponents {
            builder.append("\(escapeCsv(component.name)),Revenue,Fixed,\(component.amount),\n")
        }

        // Cost components
        for component in model.costComponents {
            switch component.type {
            case .fixed(let amount):
                builder.append("\(escapeCsv(component.name)),Cost,Fixed,\(amount),\n")
            case .variable(let percentage):
                let percentageStr = String(format: "%.2f%%", percentage * 100)
                builder.append("\(escapeCsv(component.name)),Cost,Variable,,\(percentageStr)\n")
            }
        }

        if model.revenueComponents.isEmpty && model.costComponents.isEmpty {
            builder.append("(empty model)\n")
        }

        return builder.build()
    }

    private func escapeCsv(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }
}

extension TimeSeriesExporter {
    /// Export time series to CSV using optimized string building
    public func exportToCSVOptimized() -> String {
        let builder = StringBuilder()

        // Header row
        builder.append("Period,Value\n")

        if series.count == 0 {
            builder.append("(empty series)\n")
            return builder.build()
        }

        // Data rows - pre-allocate array for efficiency
        let rows = zip(series.periods, series.valuesArray).map { period, value in
            "\(period.label),\(value)\n"
        }
        builder.append(rows)

        return builder.build()
    }
}

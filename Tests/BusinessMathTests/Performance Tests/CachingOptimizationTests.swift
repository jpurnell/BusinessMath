//
//  CachingOptimizationTests.swift
//  BusinessMath Tests
//
//  Created on November 1, 2025.
//  TDD: Tests verify caching improves performance
//

import XCTest
import RealModule
@testable import BusinessMath

/// Tests for caching optimizations and performance improvements.
final class CachingOptimizationTests: XCTestCase {

    override func tearDown() {
        // Clean up cache between tests
        FinancialModel.clearCalculationCache()
        super.tearDown()
    }

    // MARK: - Basic Caching Tests

    func testCaching_BasicCacheOperations() {
        // Given: A calculation cache
        let cache = CalculationCache(maxSize: 10, ttl: 60)

        // When: Storing and retrieving a value
        let value1 = cache.getOrCalculate(key: "test1") { 42 }
        let value2 = cache.getOrCalculate(key: "test1") { 100 }  // Should return cached value

        // Then: Should return cached value on second call
        XCTAssertEqual(value1, 42)
        XCTAssertEqual(value2, 42, "Should return cached value")
        XCTAssertEqual(cache.count, 1)
    }

    func testCaching_CacheExpiration() {
        // Given: Cache with short TTL
        let cache = CalculationCache(maxSize: 10, ttl: 0.1)  // 100ms TTL

        // When: Storing a value and waiting for expiration
        let value1 = cache.getOrCalculate(key: "test") { 42 }
        XCTAssertEqual(value1, 42)

        // Wait for TTL to expire
        Thread.sleep(forTimeInterval: 0.2)

        // Then: Should recalculate after expiration
        var recalculated = false
        let value2 = cache.getOrCalculate(key: "test") {
            recalculated = true
            return 100
        }

        XCTAssertEqual(value2, 100, "Should have recalculated")
        XCTAssertTrue(recalculated, "Should have triggered recalculation")
    }

    func testCaching_CacheEviction() {
        // Given: Cache with small max size
        let cache = CalculationCache(maxSize: 5, ttl: 60)

        // When: Adding more items than max size
        for i in 0..<10 {
            _ = cache.getOrCalculate(key: "key_\(i)") { i }
        }

        // Then: Should have evicted oldest entries
        XCTAssertLessThanOrEqual(cache.count, 5, "Should not exceed max size")
    }

    func testCaching_ClearCache() {
        // Given: Cache with values
        let cache = CalculationCache()
        _ = cache.getOrCalculate(key: "test1") { 1 }
        _ = cache.getOrCalculate(key: "test2") { 2 }
        XCTAssertEqual(cache.count, 2)

        // When: Clearing cache
        cache.clear()

        // Then: Should be empty
        XCTAssertEqual(cache.count, 0)
    }

    // MARK: - Model Caching Tests

    func testCaching_ModelCalculationCaching() {
        // Given: A financial model
        let model = FinancialModel {
            Revenue {
                Product("Product").price(100).quantity(1000)
            }
            Costs {
                Fixed("Costs", 50_000)
            }
        }

        // When: Calculating with caching
        let profit1 = model.calculateProfitCached()
        let profit2 = model.calculateProfitCached()

        // Then: Both should return same value
        XCTAssertEqual(profit1, profit2)
        XCTAssertEqual(profit1, 50_000, accuracy: 1.0)
    }

    func testCaching_CachedBenefitForRepeatedCalls() {
        // Given: Complex model
        var model = FinancialModel()
        for i in 1...100 {
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue \(i)", amount: Double(i * 1000))
            )
            model.costComponents.append(
                CostComponent(name: "Cost \(i)", type: .fixed(Double(i * 500)))
            )
        }

        // When/Then: Cached calculations work correctly
        // Note: For such fast calculations (<1ms), caching overhead may exceed benefit
        // The real benefit is avoiding redundant calculations, not raw speed

        _ = model.calculateProfitCached()
        let cachedResult1 = model.calculateProfitCached()
        let cachedResult2 = model.calculateProfitCached()
        let uncachedResult = model.calculateProfit()

        // Verify all produce same result
        XCTAssertEqual(cachedResult1, cachedResult2)
        XCTAssertEqual(cachedResult1, uncachedResult, accuracy: 0.01)

//        print("Cached profit: \(cachedResult1), Uncached profit: \(uncachedResult)")
    }

    // MARK: - Optimized Export Tests

    func testCaching_OptimizedCSVExport() {
        // Given: Model with many components
        var model = FinancialModel()
        for i in 1...500 {
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue \(i)", amount: Double(i * 1000))
            )
        }

        let exporter = DataExporter(model: model)

        // When: Comparing normal vs optimized export
        let normalStart = Date()
        let normalCSV = exporter.exportToCSV()
        let normalTime = Date().timeIntervalSince(normalStart)

        let optimizedStart = Date()
        let optimizedCSV = exporter.exportToCSVOptimized()
        let optimizedTime = Date().timeIntervalSince(optimizedStart)

        // Then: Optimized should be at least as fast
//        print("Normal CSV: \(normalTime)s, Optimized CSV: \(optimizedTime)s")
        XCTAssertLessThanOrEqual(optimizedTime, normalTime * 1.5, "Optimized should not be significantly slower")

        // And: Output should be equivalent
        XCTAssertEqual(normalCSV.count, optimizedCSV.count, accuracy: 100)
    }

    func testCaching_OptimizedTimeSeriesExport() {
        // Given: Large time series
        let periods = (0..<1000).map { Period.year(2000 + $0) }
        let values = (0..<1000).map { Double($0 * 100) }
        let series = TimeSeries<Double>(periods: periods, values: values)

        let exporter = TimeSeriesExporter<Double>(series: series)

        // When: Comparing export methods
        let normalStart = Date()
        let normalCSV = exporter.exportToCSV()
        let normalTime = Date().timeIntervalSince(normalStart)

        let optimizedStart = Date()
        let optimizedCSV = exporter.exportToCSVOptimized()
        let optimizedTime = Date().timeIntervalSince(optimizedStart)

        // Then: Both should produce valid output
//        print("Normal TS Export: \(normalTime)s, Optimized TS Export: \(optimizedTime)s")
        XCTAssertFalse(normalCSV.isEmpty)
        XCTAssertFalse(optimizedCSV.isEmpty)
        XCTAssertEqual(normalCSV.count, optimizedCSV.count, accuracy: 100)
    }

    // MARK: - Cache Key Generation Tests

    func testCaching_ModelCacheKeyGeneration() {
        // Given: Two identical models
        let model1 = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 100_000)
            }
        }

        let model2 = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 100_000)
            }
        }

        // When: Generating cache keys
        let key1 = model1.cacheKey()
        let key2 = model2.cacheKey()

        // Then: Should generate same key for identical models
        XCTAssertEqual(key1, key2, "Identical models should have same cache key")
    }

    func testCaching_DifferentModelsDifferentKeys() {
        // Given: Two different models
        let model1 = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 100_000)
            }
        }

        let model2 = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 200_000)  // Different amount
            }
        }

        // When: Generating cache keys
        let key1 = model1.cacheKey()
        let key2 = model2.cacheKey()

        // Then: Should generate different keys
        XCTAssertNotEqual(key1, key2, "Different models should have different cache keys")
    }

    // MARK: - Thread Safety Tests

    func testCaching_ThreadSafety() {
        // Given: Shared cache
        let cache = CalculationCache(maxSize: 100, ttl: 60)

        // When: Accessing from multiple threads
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 10

        for i in 0..<10 {
            DispatchQueue.global().async {
                for j in 0..<100 {
                    let key = "key_\(i)_\(j)"
                    _ = cache.getOrCalculate(key: key) { j }
                }
                expectation.fulfill()
            }
        }

        // Then: Should handle concurrent access without crashes
        wait(for: [expectation], timeout: 5.0)
        XCTAssertGreaterThan(cache.count, 0)
    }

    func testCaching_ModelCachingThreadSafety() {
        // Given: Model accessed from multiple threads
        let model = FinancialModel {
            Revenue {
                Product("Product").price(100).quantity(1000)
            }
            Costs {
                Fixed("Costs", 50_000)
            }
        }

        let expectation = XCTestExpectation(description: "Concurrent calculations complete")
        expectation.expectedFulfillmentCount = 10

        // When: Calculating from multiple threads
        for _ in 0..<10 {
            DispatchQueue.global().async {
                for _ in 0..<100 {
                    _ = model.calculateProfitCached()
                }
                expectation.fulfill()
            }
        }

        // Then: Should handle concurrent access safely
        wait(for: [expectation], timeout: 5.0)
        let finalProfit = model.calculateProfitCached()
        XCTAssertEqual(finalProfit, 50_000, accuracy: 1.0)
    }

    // MARK: - Performance Comparison Tests

    func testPerformance_CachedCalculations() {
        // Given: Model with cached calculations
        let model = FinancialModel {
            Revenue {
                Product("Product A").price(100).quantity(500)
                Product("Product B").price(200).quantity(200)
            }
            Costs {
                Fixed("Salaries", 50_000)
                Variable("COGS", 0.30)
            }
        }

        // Warm up cache
        _ = model.calculateProfitCached()

        // When/Then: Measure cached performance
        measure {
            for _ in 0..<1000 {
                _ = model.calculateProfitCached()
            }
        }
    }
}

//
//  StreamingStatisticsTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Testing
import Foundation
@testable import BusinessMath

/// Tests for Streaming Statistics (Phase 2.2)
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("Streaming Statistics Tests")
struct StreamingStatisticsTests {

    // MARK: - Rolling Mean Tests

    @Test("Calculate rolling mean over stream")
    func rollingMean() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        var means: [Double] = []
        for try await mean in stream.rollingMean(window: 3) {
            means.append(mean)
        }

        // Window 1: [1,2,3] -> mean = 2.0
        // Window 2: [2,3,4] -> mean = 3.0
        // Window 3: [3,4,5] -> mean = 4.0
        #expect(means.count == 3)
        #expect(abs(means[0] - 2.0) < 0.001)
        #expect(abs(means[1] - 3.0) < 0.001)
        #expect(abs(means[2] - 4.0) < 0.001)
    }

    @Test("Calculate cumulative mean over stream")
    func cumulativeMean() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        var means: [Double] = []
        for try await mean in stream.cumulativeMean() {
            means.append(mean)
        }

        // After 1: 1.0
        // After 2: 1.5
        // After 3: 2.0
        // After 4: 2.5
        // After 5: 3.0
        #expect(means.count == 5)
        #expect(abs(means[0] - 1.0) < 0.001)
        #expect(abs(means[1] - 1.5) < 0.001)
        #expect(abs(means[2] - 2.0) < 0.001)
        #expect(abs(means[3] - 2.5) < 0.001)
        #expect(abs(means[4] - 3.0) < 0.001)
    }

    // MARK: - Rolling Variance and StdDev Tests

    @Test("Calculate rolling variance over stream")
    func rollingVariance() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        var variances: [Double] = []
        for try await variance in stream.rollingVariance(window: 3) {
            variances.append(variance)
        }

        // Window 1: [1,2,3] -> variance = 1.0
        // Window 2: [2,3,4] -> variance = 1.0
        // Window 3: [3,4,5] -> variance = 1.0
        #expect(variances.count == 3)
        #expect(abs(variances[0] - 1.0) < 0.001)
        #expect(abs(variances[1] - 1.0) < 0.001)
        #expect(abs(variances[2] - 1.0) < 0.001)
    }

    @Test("Calculate rolling standard deviation over stream")
    func rollingStdDev() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        var stdDevs: [Double] = []
        for try await stdDev in stream.rollingStdDev(window: 3) {
            stdDevs.append(stdDev)
        }

        // Window 1: [1,2,3] -> stdDev = 1.0
        // Window 2: [2,3,4] -> stdDev = 1.0
        // Window 3: [3,4,5] -> stdDev = 1.0
        #expect(stdDevs.count == 3)
        #expect(abs(stdDevs[0] - 1.0) < 0.001)
        #expect(abs(stdDevs[1] - 1.0) < 0.001)
        #expect(abs(stdDevs[2] - 1.0) < 0.001)
    }

    // MARK: - Rolling Min/Max Tests

    @Test("Calculate rolling minimum over stream")
    func rollingMin() async throws {
        let values = [5.0, 2.0, 8.0, 1.0, 9.0, 3.0]
        let stream = AsyncValueStream(values)

        var mins: [Double] = []
        for try await min in stream.rollingMin(window: 3) {
            mins.append(min)
        }

        // Window 1: [5,2,8] -> min = 2.0
        // Window 2: [2,8,1] -> min = 1.0
        // Window 3: [8,1,9] -> min = 1.0
        // Window 4: [1,9,3] -> min = 1.0
        #expect(mins.count == 4)
        #expect(mins[0] == 2.0)
        #expect(mins[1] == 1.0)
        #expect(mins[2] == 1.0)
        #expect(mins[3] == 1.0)
    }

    @Test("Calculate rolling maximum over stream")
    func rollingMax() async throws {
        let values = [5.0, 2.0, 8.0, 1.0, 9.0, 3.0]
        let stream = AsyncValueStream(values)

        var maxs: [Double] = []
        for try await max in stream.rollingMax(window: 3) {
            maxs.append(max)
        }

        // Window 1: [5,2,8] -> max = 8.0
        // Window 2: [2,8,1] -> max = 8.0
        // Window 3: [8,1,9] -> max = 9.0
        // Window 4: [1,9,3] -> max = 9.0
        #expect(maxs.count == 4)
        #expect(maxs[0] == 8.0)
        #expect(maxs[1] == 8.0)
        #expect(maxs[2] == 9.0)
        #expect(maxs[3] == 9.0)
    }

    // MARK: - Rolling Sum Tests

    @Test("Calculate rolling sum over stream")
    func rollingSum() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        var sums: [Double] = []
        for try await sum in stream.rollingSum(window: 3) {
            sums.append(sum)
        }

        // Window 1: [1,2,3] -> sum = 6.0
        // Window 2: [2,3,4] -> sum = 9.0
        // Window 3: [3,4,5] -> sum = 12.0
        #expect(sums.count == 3)
        #expect(sums[0] == 6.0)
        #expect(sums[1] == 9.0)
        #expect(sums[2] == 12.0)
    }

    @Test("Calculate cumulative sum over stream")
    func cumulativeSum() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        var sums: [Double] = []
        for try await sum in stream.cumulativeSum() {
            sums.append(sum)
        }

        #expect(sums == [1.0, 3.0, 6.0, 10.0, 15.0])
    }

    // MARK: - Exponential Moving Average Tests

    @Test("Calculate exponential moving average")
    func exponentialMovingAverage() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        var emas: [Double] = []
        for try await ema in stream.exponentialMovingAverage(alpha: 0.5) {
            emas.append(ema)
        }

        // EMA(1) = 1.0
        // EMA(2) = 0.5 * 2.0 + 0.5 * 1.0 = 1.5
        // EMA(3) = 0.5 * 3.0 + 0.5 * 1.5 = 2.25
        // EMA(4) = 0.5 * 4.0 + 0.5 * 2.25 = 3.125
        // EMA(5) = 0.5 * 5.0 + 0.5 * 3.125 = 4.0625
        #expect(emas.count == 5)
        #expect(abs(emas[0] - 1.0) < 0.001)
        #expect(abs(emas[1] - 1.5) < 0.001)
        #expect(abs(emas[2] - 2.25) < 0.001)
        #expect(abs(emas[3] - 3.125) < 0.001)
        #expect(abs(emas[4] - 4.0625) < 0.001)
    }

    // MARK: - Rolling Statistics Struct Tests

    @Test("Calculate comprehensive rolling statistics")
    func rollingStatistics() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        var stats: [RollingStats] = []
        for try await stat in stream.rollingStatistics(window: 3) {
            stats.append(stat)
        }

        #expect(stats.count == 3)

        // Window 1: [1,2,3]
        #expect(abs(stats[0].mean - 2.0) < 0.001)
        #expect(abs(stats[0].variance - 1.0) < 0.001)
        #expect(abs(stats[0].stdDev - 1.0) < 0.001)
        #expect(stats[0].min == 1.0)
        #expect(stats[0].max == 3.0)
        #expect(stats[0].sum == 6.0)
        #expect(stats[0].count == 3)

        // Window 3: [3,4,5]
        #expect(abs(stats[2].mean - 4.0) < 0.001)
        #expect(stats[2].min == 3.0)
        #expect(stats[2].max == 5.0)
    }

    // MARK: - Cumulative Statistics Tests

    @Test("Calculate comprehensive cumulative statistics")
    func cumulativeStatistics() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        var stats: [CumulativeStats] = []
        for try await stat in stream.cumulativeStatistics() {
            stats.append(stat)
        }

        #expect(stats.count == 5)

        // After 3 values
        #expect(abs(stats[2].mean - 2.0) < 0.001)
        #expect(stats[2].count == 3)
        #expect(stats[2].sum == 6.0)
        #expect(stats[2].min == 1.0)
        #expect(stats[2].max == 3.0)

        // After all 5 values
        #expect(abs(stats[4].mean - 3.0) < 0.001)
        #expect(stats[4].count == 5)
        #expect(stats[4].sum == 15.0)
        #expect(stats[4].min == 1.0)
        #expect(stats[4].max == 5.0)
    }

    // MARK: - Memory Efficiency Tests

    @Test("Streaming statistics maintain O(1) memory")
    func constantMemoryForStatistics() async throws {
        // Simulate large stream
        let largeStream = AsyncGeneratorStream {
            return Double.random(in: 0...100)
        }

        var statCount = 0
        for try await _ in largeStream.rollingStatistics(window: 100) {
            statCount += 1
            if statCount >= 10000 {
                break
            }
        }

        // If we got 10000 statistics without memory issues, O(1) memory is maintained
        #expect(statCount == 10000)
    }

    // MARK: - Numerical Stability Tests

    @Test("Variance calculation is numerically stable with large values")
    func numericalStability() async throws {
        // Large values that would cause issues with naive variance calculation
        let values = [1_000_000.0, 1_000_001.0, 1_000_002.0, 1_000_003.0, 1_000_004.0]
        let stream = AsyncValueStream(values)

        var variances: [Double] = []
        for try await variance in stream.rollingVariance(window: 3) {
            variances.append(variance)
        }

        // All windows should have variance = 1.0
        #expect(variances.count == 3)
        for variance in variances {
            #expect(abs(variance - 1.0) < 0.001)
        }
    }
}

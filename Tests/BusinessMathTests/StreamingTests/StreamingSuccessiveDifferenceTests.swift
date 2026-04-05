//
//  StreamingSuccessiveDifferenceTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-05.
//

import Testing
import Foundation
@testable import BusinessMath

/// Tests for successive difference streaming operators (Phase 2.5 — Gap 3)
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("Streaming Successive Difference Tests")
struct StreamingSuccessiveDifferenceTests {

    // MARK: - successiveDifferences() Tests

    @Test("Successive differences of known sequence")
    func successiveDifferencesKnown() async throws {
        let values = [1.0, 3.0, 6.0, 10.0]
        let stream = AsyncValueStream(values)

        var diffs: [Double] = []
        for try await diff in stream.successiveDifferences() {
            diffs.append(diff)
        }

        // [3-1, 6-3, 10-6] = [2, 3, 4]
        #expect(diffs.count == 3)
        #expect(abs(diffs[0] - 2.0) < 1e-10)
        #expect(abs(diffs[1] - 3.0) < 1e-10)
        #expect(abs(diffs[2] - 4.0) < 1e-10)
    }

    @Test("Successive differences of single element produces empty")
    func singleElement() async throws {
        let stream = AsyncValueStream([42.0])

        var count = 0
        for try await _ in stream.successiveDifferences() {
            count += 1
        }

        #expect(count == 0)
    }

    @Test("Successive differences of empty stream produces empty")
    func emptyStream() async throws {
        let stream = AsyncValueStream([Double]())

        var count = 0
        for try await _ in stream.successiveDifferences() {
            count += 1
        }

        #expect(count == 0)
    }

    @Test("Successive differences with negative deltas")
    func negativeDiffs() async throws {
        let values = [10.0, 7.0, 3.0, 1.0]
        let stream = AsyncValueStream(values)

        var diffs: [Double] = []
        for try await diff in stream.successiveDifferences() {
            diffs.append(diff)
        }

        // [7-10, 3-7, 1-3] = [-3, -4, -2]
        #expect(diffs.count == 3)
        #expect(abs(diffs[0] - (-3.0)) < 1e-10)
        #expect(abs(diffs[1] - (-4.0)) < 1e-10)
        #expect(abs(diffs[2] - (-2.0)) < 1e-10)
    }

    @Test("Successive differences of constant stream are zero")
    func constantStream() async throws {
        let values = [5.0, 5.0, 5.0, 5.0, 5.0]
        let stream = AsyncValueStream(values)

        var diffs: [Double] = []
        for try await diff in stream.successiveDifferences() {
            diffs.append(diff)
        }

        #expect(diffs.count == 4)
        for diff in diffs {
            #expect(abs(diff) < 1e-10)
        }
    }

    // MARK: - rollingSuccessiveDifferenceRMS() Tests (RMSSD)

    @Test("RMSSD with known HRV-like intervals")
    func rmssdKnownValues() async throws {
        // RR intervals in ms: [800, 810, 790, 820, 800, 830]
        // Successive diffs: [10, -20, 30, -20, 30]
        // Squared diffs: [100, 400, 900, 400, 900]
        // RMSSD over full window of 5: sqrt(mean([100, 400, 900, 400, 900])) = sqrt(540) ≈ 23.2379
        let values = [800.0, 810.0, 790.0, 820.0, 800.0, 830.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rmssd in stream.rollingSuccessiveDifferenceRMS(window: 5) {
            results.append(rmssd)
        }

        #expect(results.count == 1)
        let expected = (540.0).squareRoot()  // sqrt(540) ≈ 23.2379
        #expect(abs(results[0] - expected) < 0.001)
    }

    @Test("RMSSD with window=2 minimal case")
    func rmssdWindowTwo() async throws {
        // Values: [100, 110, 105]
        // Successive diffs: [10, -5]
        // Squared diffs: [100, 25]
        // Window 1: sqrt(mean([100, 25])) = sqrt(62.5) ≈ 7.9057
        let values = [100.0, 110.0, 105.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rmssd in stream.rollingSuccessiveDifferenceRMS(window: 2) {
            results.append(rmssd)
        }

        #expect(results.count == 1)
        let expected = (62.5).squareRoot()
        #expect(abs(results[0] - expected) < 0.001)
    }

    @Test("RMSSD on constant stream yields zero")
    func rmssdConstant() async throws {
        let values = [500.0, 500.0, 500.0, 500.0, 500.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rmssd in stream.rollingSuccessiveDifferenceRMS(window: 3) {
            results.append(rmssd)
        }

        // All diffs are 0, so RMSSD is 0
        for result in results {
            #expect(abs(result) < 1e-10)
        }
    }

    @Test("RMSSD with sliding window eviction correctness")
    func rmssdSlidingEviction() async throws {
        // Values: [100, 110, 105, 115, 108]
        // Successive diffs: [10, -5, 10, -7]
        // Squared diffs: [100, 25, 100, 49]
        // Window=3:
        //   First window [100, 25, 100]: sqrt(225/3) = sqrt(75) ≈ 8.6603
        //   Second window [25, 100, 49]: sqrt(174/3) = sqrt(58) ≈ 7.6158
        let values = [100.0, 110.0, 105.0, 115.0, 108.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rmssd in stream.rollingSuccessiveDifferenceRMS(window: 3) {
            results.append(rmssd)
        }

        #expect(results.count == 2)
        #expect(abs(results[0] - (75.0).squareRoot()) < 0.001)
        #expect(abs(results[1] - (58.0).squareRoot()) < 0.001)
    }

    // MARK: - rollingThresholdExceedanceRate() Tests (pNN50-style)

    @Test("Threshold exceedance rate basic scenario")
    func thresholdExceedanceBasic() async throws {
        // Values: [800, 860, 810, 870, 820]
        // Successive diffs (absolute): [60, 50, 60, 50]
        // Threshold 50ms: exceeds = [true, false, true, false]
        // Window=4: rate = 2/4 = 0.5
        let values = [800.0, 860.0, 810.0, 870.0, 820.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rate in stream.rollingThresholdExceedanceRate(window: 4, threshold: 50.0) {
            results.append(rate)
        }

        #expect(results.count == 1)
        #expect(abs(results[0] - 0.5) < 1e-10)
    }

    @Test("Threshold exceedance rate all exceeding yields 1.0")
    func thresholdExceedanceAll() async throws {
        // Values: [100, 200, 300, 400]
        // Absolute diffs: [100, 100, 100] — all > 50
        // Window=3: rate = 3/3 = 1.0
        let values = [100.0, 200.0, 300.0, 400.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rate in stream.rollingThresholdExceedanceRate(window: 3, threshold: 50.0) {
            results.append(rate)
        }

        #expect(results.count == 1)
        #expect(abs(results[0] - 1.0) < 1e-10)
    }

    @Test("Threshold exceedance rate none exceeding yields 0.0")
    func thresholdExceedanceNone() async throws {
        // Values: [100, 101, 102, 103]
        // Absolute diffs: [1, 1, 1] — none > 50
        // Window=3: rate = 0/3 = 0.0
        let values = [100.0, 101.0, 102.0, 103.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rate in stream.rollingThresholdExceedanceRate(window: 3, threshold: 50.0) {
            results.append(rate)
        }

        #expect(results.count == 1)
        #expect(abs(results[0]) < 1e-10)
    }

    @Test("Threshold exceedance rate with sliding window eviction")
    func thresholdExceedanceSlidingEviction() async throws {
        // Values: [100, 200, 205, 210, 310]
        // Absolute diffs: [100, 5, 5, 100]
        // Threshold=50: exceeds = [true, false, false, true]
        // Window=3:
        //   First [true, false, false]: rate = 1/3 ≈ 0.3333
        //   Second [false, false, true]: rate = 1/3 ≈ 0.3333
        let values = [100.0, 200.0, 205.0, 210.0, 310.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rate in stream.rollingThresholdExceedanceRate(window: 3, threshold: 50.0) {
            results.append(rate)
        }

        #expect(results.count == 2)
        #expect(abs(results[0] - 1.0 / 3.0) < 1e-10)
        #expect(abs(results[1] - 1.0 / 3.0) < 1e-10)
    }

    // MARK: - Edge Case Tests

    @Test("Successive differences with NaN propagates NaN")
    func successiveDifferencesNaN() async throws {
        let values = [1.0, Double.nan, 3.0]
        let stream = AsyncValueStream(values)

        var diffs: [Double] = []
        for try await diff in stream.successiveDifferences() {
            diffs.append(diff)
        }

        // NaN - 1.0 = NaN, 3.0 - NaN = NaN
        #expect(diffs.count == 2)
        #expect(diffs[0].isNaN)
        #expect(diffs[1].isNaN)
    }

    @Test("Successive differences with Infinity values")
    func successiveDifferencesInfinity() async throws {
        let values = [1.0, Double.infinity, Double.infinity]
        let stream = AsyncValueStream(values)

        var diffs: [Double] = []
        for try await diff in stream.successiveDifferences() {
            diffs.append(diff)
        }

        // inf - 1 = inf, inf - inf = NaN
        #expect(diffs.count == 2)
        #expect(diffs[0] == Double.infinity)
        #expect(diffs[1].isNaN)
    }

    @Test("RMSSD with window=1 produces per-diff RMS")
    func rmssdWindowOne() async throws {
        // Values: [10, 20, 15]
        // Successive diffs: [10, -5]
        // Window=1: each diff is its own window
        //   sqrt(100/1) = 10.0, sqrt(25/1) = 5.0
        let values = [10.0, 20.0, 15.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rmssd in stream.rollingSuccessiveDifferenceRMS(window: 1) {
            results.append(rmssd)
        }

        #expect(results.count == 2)
        #expect(abs(results[0] - 10.0) < 1e-10)
        #expect(abs(results[1] - 5.0) < 1e-10)
    }

    @Test("Threshold exceedance with threshold=0.0 counts all nonzero diffs")
    func thresholdExceedanceZeroThreshold() async throws {
        // Values: [1.0, 2.0, 3.0, 4.0]
        // Absolute diffs: [1, 1, 1] — all > 0
        // Window=3: rate = 3/3 = 1.0
        let values = [1.0, 2.0, 3.0, 4.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rate in stream.rollingThresholdExceedanceRate(window: 3, threshold: 0.0) {
            results.append(rate)
        }

        #expect(results.count == 1)
        #expect(abs(results[0] - 1.0) < 1e-10)
    }

    // MARK: - Property-Based Tests

    @Test("Successive differences output count equals input count minus 1",
          arguments: [2, 5, 10, 100])
    func successiveDifferencesCountProperty(size: Int) async throws {
        let values = (0..<size).map { Double($0) * 1.5 }
        let stream = AsyncValueStream(values)

        var count = 0
        for try await _ in stream.successiveDifferences() {
            count += 1
        }

        #expect(count == size - 1)
    }

    @Test("RMSSD is always non-negative")
    func rmssdAlwaysNonNegative() async throws {
        let values = [100.0, 80.0, 120.0, 70.0, 130.0, 60.0, 140.0, 50.0]
        let stream = AsyncValueStream(values)

        for try await rmssd in stream.rollingSuccessiveDifferenceRMS(window: 3) {
            #expect(rmssd >= 0.0)
        }
    }

    @Test("Threshold exceedance rate is always in [0, 1]")
    func thresholdExceedanceRateInUnitInterval() async throws {
        let values = [10.0, 50.0, 12.0, 48.0, 15.0, 45.0, 20.0, 40.0, 25.0, 35.0]
        let stream = AsyncValueStream(values)

        for try await rate in stream.rollingThresholdExceedanceRate(window: 4, threshold: 20.0) {
            #expect(rate >= 0.0)
            #expect(rate <= 1.0)
        }
    }

    // MARK: - Numerical Stability Tests

    @Test("Successive differences with very small values near machine epsilon")
    func successiveDifferencesVerySmall() async throws {
        let values = [1e-15, 2e-15, 3e-15, 4e-15]
        let stream = AsyncValueStream(values)

        var diffs: [Double] = []
        for try await diff in stream.successiveDifferences() {
            diffs.append(diff)
        }

        #expect(diffs.count == 3)
        for diff in diffs {
            #expect(abs(diff - 1e-15) < 1e-25)
        }
    }

    @Test("Successive differences with very large values at 1e12 scale")
    func successiveDifferencesVeryLarge() async throws {
        let values = [1e12, 2e12, 3e12, 4e12]
        let stream = AsyncValueStream(values)

        var diffs: [Double] = []
        for try await diff in stream.successiveDifferences() {
            diffs.append(diff)
        }

        #expect(diffs.count == 3)
        for diff in diffs {
            #expect(abs(diff - 1e12) < 1.0)
        }
    }

    @Test("RMSSD with values near machine epsilon tests catastrophic cancellation")
    func rmssdCatastrophicCancellation() async throws {
        // Values clustered near 1e12 with tiny differences
        // Successive diffs should be exactly 1.0 each
        let base = 1e12
        let values = [base, base + 1.0, base + 2.0, base + 3.0, base + 4.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rmssd in stream.rollingSuccessiveDifferenceRMS(window: 3) {
            results.append(rmssd)
        }

        // All diffs are 1.0, so squared diffs are 1.0, mean is 1.0, RMSSD = 1.0
        for result in results {
            #expect(abs(result - 1.0) < 1e-6)
        }
    }

    // MARK: - Stress Tests

    @Test("Successive differences over 100_000 elements completes in time",
          .timeLimit(.minutes(1)))
    func successiveDifferencesStress() async throws {
        let values = (0..<100_000).map { Double($0) }
        let stream = AsyncValueStream(values)

        var count = 0
        for try await _ in stream.successiveDifferences() {
            count += 1
        }

        #expect(count == 99_999)
    }

    @Test("RMSSD over 50_000 elements completes in time",
          .timeLimit(.minutes(1)))
    func rmssdStress() async throws {
        let values = (0..<50_000).map { Double($0) }
        let stream = AsyncValueStream(values)

        var count = 0
        for try await _ in stream.rollingSuccessiveDifferenceRMS(window: 100) {
            count += 1
        }

        #expect(count > 0)
    }
}

//
//  DDMPerformanceTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-24.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("DDM Performance Tests", .serialized)
struct DDMPerformanceTests {

    // MARK: - Single Calculation Performance

    @Test("Gordon Growth - single calculation performance")
    func gordonGrowthSingleCalculation() {
        let model = GordonGrowthModel(
            dividendPerShare: 2.5,
            growthRate: 0.04,
            requiredReturn: 0.09
        )

        // Measure time for single calculation
        let start = Date()
        let _ = model.valuePerShare()
        let elapsed = Date().timeIntervalSince(start)

        // Should be very fast (< 200 microseconds, 4× margin for system variance)
        #expect(elapsed < 0.0002, "Gordon Growth single calculation took \(elapsed * 1_000_000) microseconds, expected < 200")
    }

    @Test("Two-Stage DDM - single calculation performance")
    func twoStageSingleCalculation() {
        let model = TwoStageDDM(
            currentDividend: 1.5,
            highGrowthRate: 0.15,
            highGrowthPeriods: 10,
            stableGrowthRate: 0.04,
            requiredReturn: 0.10
        )

        let start = Date()
        let _ = model.valuePerShare()
        let elapsed = Date().timeIntervalSince(start)

        // Should be very fast (< 600 microseconds for 10 periods, 4× margin for system variance)
        #expect(elapsed < 0.0006, "Two-Stage DDM single calculation took \(elapsed * 1_000_000) microseconds, expected < 600")
    }

    @Test("H-Model - single calculation performance")
    func hModelSingleCalculation() {
        let model = HModel(
            currentDividend: 2.0,
            initialGrowthRate: 0.12,
            terminalGrowthRate: 0.04,
            halfLife: 10,
            requiredReturn: 0.10
        )

        let start = Date()
        let _ = model.valuePerShare()
        let elapsed = Date().timeIntervalSince(start)

        // Should be very fast (< 200 microseconds, 4× margin for system variance)
        #expect(elapsed < 0.0002, "H-Model single calculation took \(elapsed * 1_000_000) microseconds, expected < 200")
    }

    // MARK: - Batch Calculations Performance

    @Test("Gordon Growth - value 1000 stocks")
    func gordonGrowthBatchCalculations() {
        // Simulate valuing a portfolio of 1000 stocks
        var stocks: [GordonGrowthModel<Double>] = []
        for i in 0..<1000 {
            let dividend = 2.0 + Double(i) * 0.01
            let growth = 0.03 + Double(i % 10) * 0.001
            let required = 0.08 + Double(i % 20) * 0.001
            stocks.append(GordonGrowthModel(
                dividendPerShare: dividend,
                growthRate: growth,
                requiredReturn: required
            ))
        }

        let start = Date()
        let values = stocks.map { $0.valuePerShare() }
        let elapsed = Date().timeIntervalSince(start)

        // Should complete in < 3 milliseconds for 1000 stocks (3× margin for system variance)
        #expect(elapsed < 0.003, "1000 Gordon Growth calculations took \(elapsed * 1000) ms, expected < 3 ms")
        #expect(values.count == 1000)
        #expect(values.allSatisfy { !$0.isNaN })
    }

    @Test("Two-Stage DDM - value 100 stocks with 10-year growth")
    func twoStageBatchCalculations() {
        // Simulate valuing 100 growth stocks
        var stocks: [TwoStageDDM<Double>] = []
        for i in 0..<100 {
            let dividend = 1.0 + Double(i) * 0.05
            let highGrowth = 0.15 + Double(i % 5) * 0.01
            let required = 0.11 + Double(i % 10) * 0.005
            stocks.append(TwoStageDDM(
                currentDividend: dividend,
                highGrowthRate: highGrowth,
                highGrowthPeriods: 10,
                stableGrowthRate: 0.04,
                requiredReturn: required
            ))
        }

        let start = Date()
        let values = stocks.map { $0.valuePerShare() }
        let elapsed = Date().timeIntervalSince(start)

        // Should complete in < 6 milliseconds for 100 stocks with 10 periods each (3× margin for system variance)
        #expect(elapsed < 0.006, "100 Two-Stage DDM calculations took \(elapsed * 1000) ms, expected < 6 ms")
        #expect(values.count == 100)
        #expect(values.allSatisfy { !$0.isNaN })
    }

    @Test("H-Model - value 500 stocks")
    func hModelBatchCalculations() {
        var stocks: [HModel<Double>] = []
        for i in 0..<500 {
            let dividend = 1.5 + Double(i) * 0.02
            let initialGrowth = 0.10 + Double(i % 15) * 0.002
            let terminalGrowth = 0.03 + Double(i % 5) * 0.001
            let required = 0.09 + Double(i % 12) * 0.003
            stocks.append(HModel(
                currentDividend: dividend,
                initialGrowthRate: initialGrowth,
                terminalGrowthRate: terminalGrowth,
                halfLife: 8,
                requiredReturn: required
            ))
        }

        let start = Date()
        let values = stocks.map { $0.valuePerShare() }
        let elapsed = Date().timeIntervalSince(start)

        // Should complete in < 1.5 milliseconds for 500 stocks (3× margin for system variance)
        #expect(elapsed < 0.0015, "500 H-Model calculations took \(elapsed * 1000) ms, expected < 1.5 ms")
        #expect(values.count == 500)
        #expect(values.allSatisfy { !$0.isNaN })
    }

    // MARK: - Sensitivity Analysis Performance

    @Test("Sensitivity analysis - vary growth rate 100 times")
    func sensitivityAnalysisGrowthRate() {
        // Test 100 different growth rates from 0% to 9%
        let growthRates = (0..<100).map { Double($0) * 0.0009 }

        let start = Date()
        let values = growthRates.map { g in
            GordonGrowthModel(
                dividendPerShare: 2.5,
                growthRate: g,
                requiredReturn: 0.10
            ).valuePerShare()
        }
        let elapsed = Date().timeIntervalSince(start)

        // Should complete in < 0.3 milliseconds for 100 iterations (3× margin for system variance)
        #expect(elapsed < 0.0003, "100 sensitivity calculations took \(elapsed * 1000) ms, expected < 0.3 ms")
        #expect(values.count == 100)
    }

    @Test("Sensitivity analysis - two-variable grid 10x10")
    func sensitivityAnalysisTwoVariable() {
        // Test 10x10 grid: growth rate vs required return
        let growthRates = (0..<10).map { Double($0) * 0.005 }
        let requiredReturns = (6..<16).map { Double($0) * 0.01 }

        let start = Date()
        var valueGrid: [[Double]] = []

        for r in requiredReturns {
            var row: [Double] = []
            for g in growthRates {
                let model = GordonGrowthModel(
                    dividendPerShare: 2.5,
                    growthRate: g,
                    requiredReturn: r
                )
                row.append(model.valuePerShare())
            }
            valueGrid.append(row)
        }
        let elapsed = Date().timeIntervalSince(start)

        // Should complete in < 3 milliseconds for 100 calculations (3× margin for system variance)
        #expect(elapsed < 0.003, "10x10 sensitivity grid took \(elapsed * 1000) ms, expected < 3 ms")
        #expect(valueGrid.count == 10)
        #expect(valueGrid.allSatisfy { $0.count == 10 })
    }

    // MARK: - Long-Period Performance

    @Test("Two-Stage DDM - 30-year high growth period")
    func twoStageLongPeriod() {
        let model = TwoStageDDM(
            currentDividend: 1.0,
            highGrowthRate: 0.15,
            highGrowthPeriods: 30,  // Very long growth period
            stableGrowthRate: 0.03,
            requiredReturn: 0.10
        )

        let start = Date()
        let value = model.valuePerShare()
        let elapsed = Date().timeIntervalSince(start)

        // Should still be very fast (< 3 milliseconds for 30 periods, 3× margin for system variance)
        #expect(elapsed < 0.003, "30-period Two-Stage DDM took \(elapsed * 1_000_000) microseconds, expected < 3000")
        #expect(!value.isNaN)
    }

    @Test("Two-Stage DDM - 100-year high growth period")
    func twoStageVeryLongPeriod() {
        let model = TwoStageDDM(
            currentDividend: 0.5,
            highGrowthRate: 0.20,
            highGrowthPeriods: 100,  // Extremely long (unrealistic but tests performance)
            stableGrowthRate: 0.02,
            requiredReturn: 0.12
        )

        let start = Date()
        let value = model.valuePerShare()
        let elapsed = Date().timeIntervalSince(start)

        // Should still complete quickly (< 6 milliseconds for 100 periods, 3× margin for system variance)
        #expect(elapsed < 0.006, "100-period Two-Stage DDM took \(elapsed * 1_000_000) microseconds, expected < 6000")
        #expect(!value.isNaN)
    }

    // MARK: - Real Type Comparison

    @Test("Performance comparison - Double vs Float")
    func performanceComparisonDoubleVsFloat() {
        // Test with Double
        let startDouble = Date()
        for _ in 0..<1000 {
            let model = GordonGrowthModel<Double>(
                dividendPerShare: 2.5,
                growthRate: 0.04,
                requiredReturn: 0.09
            )
            let _ = model.valuePerShare()
        }
        let elapsedDouble = Date().timeIntervalSince(startDouble)

        // Test with Float
        let startFloat = Date()
        for _ in 0..<1000 {
            let model = GordonGrowthModel<Float>(
                dividendPerShare: 2.5,
                growthRate: 0.04,
                requiredReturn: 0.09
            )
            let _ = model.valuePerShare()
        }
        let elapsedFloat = Date().timeIntervalSince(startFloat)

        // Both should be very fast (< 6 milliseconds for 1000 iterations, 3× margin for system variance)
        #expect(elapsedDouble < 0.006, "1000 Double calculations took \(elapsedDouble * 1000) ms")
        #expect(elapsedFloat < 0.006, "1000 Float calculations took \(elapsedFloat * 1000) ms")

        // Float should be at least as fast as Double (or close)
        print("Double: \(elapsedDouble * 1000) ms, Float: \(elapsedFloat * 1000) ms")
    }

    // MARK: - Memory Efficiency

	@Test("Memory efficiency - create 10000 models")
    func memoryEfficiencyTest() {
        // Create a large number of models to test memory efficiency
        let start = Date()
        let models = (0..<10000).map { i in
            GordonGrowthModel(
                dividendPerShare: Double(1.0 + Double(i) * 0.0001),
                growthRate: 0.03,
                requiredReturn: 0.08
            )
        }
        let elapsed = Date().timeIntervalSince(start)

        // Creating 10000 lightweight structs should be instant (< 30 milliseconds, 3× margin for system variance)
        #expect(elapsed < 0.03, "Creating 10000 models took \(elapsed * 1000) ms, expected < 30 ms")
        #expect(models.count == 10000)

        // Verify they're all valid
        let startCalc = Date()
        let values = models.map { $0.valuePerShare() }
        let elapsedCalc = Date().timeIntervalSince(startCalc)

        // Calculating 10000 values should be fast (< 30 milliseconds, 3× margin for system variance)
        #expect(elapsedCalc < 0.03, "10000 calculations took \(elapsedCalc * 1000) ms, expected < 30 ms")
        #expect(values.allSatisfy { !$0.isNaN })
    }

    // MARK: - Real-World Scenario Performance

    @Test("Real-world scenario - portfolio screening")
    func portfolioScreeningPerformance() {
        // Simulate screening a universe of 500 stocks with different models
        struct Stock {
            let ticker: String
            let dividend: Double
            let growthRate: Double
            let requiredReturn: Double
            let useHighGrowth: Bool
        }

        let universe = (0..<500).map { i -> Stock in
            Stock(
                ticker: "STOCK\(i)",
                dividend: Double(1.0 + Double(i % 50) * 0.1),
                growthRate: Double(0.02 + Double(i % 30) * 0.001),
                requiredReturn: Double(0.08 + Double(i % 25) * 0.002),
                useHighGrowth: i % 5 == 0  // 20% are growth stocks
            )
        }

        let start = Date()
        let valuations = universe.map { stock -> (String, Double) in
            let value: Double
            if stock.useHighGrowth {
                // Use Two-Stage for growth stocks
                let model = TwoStageDDM(
                    currentDividend: stock.dividend,
                    highGrowthRate: 0.15,
                    highGrowthPeriods: 5,
                    stableGrowthRate: stock.growthRate,
                    requiredReturn: stock.requiredReturn
                )
                value = model.valuePerShare()
            } else {
                // Use Gordon Growth for mature stocks
                let model = GordonGrowthModel(
                    dividendPerShare: stock.dividend,
                    growthRate: stock.growthRate,
                    requiredReturn: stock.requiredReturn
                )
                value = model.valuePerShare()
            }
            return (stock.ticker, value)
        }
        let elapsed = Date().timeIntervalSince(start)

        // Should complete portfolio screening in < 6 milliseconds (3× margin for system variance)
        #expect(elapsed < 0.006, "Portfolio screening (500 stocks) took \(elapsed * 1000) ms, expected < 6 ms")
        #expect(valuations.count == 500)
        #expect(valuations.filter { !$0.1.isNaN }.count > 450)  // Most should be valid
    }

    // MARK: - Comparison with Manual Calculation

    @Test("Performance vs manual calculation")
    func performanceVsManualCalculation() {
        // Compare struct-based Gordon Growth vs manual formula calculation
        let dividend = 2.5
        let growth = 0.04
        let required = 0.09

        // Struct-based calculation
        let startStruct = Date()
        for _ in 0..<10000 {
            let model = GordonGrowthModel(
                dividendPerShare: dividend,
                growthRate: growth,
                requiredReturn: required
            )
            let _ = model.valuePerShare()
        }
        let elapsedStruct = Date().timeIntervalSince(startStruct)

        // Manual calculation
        let startManual = Date()
        for _ in 0..<10000 {
            let _ = dividend / (required - growth)
        }
        let elapsedManual = Date().timeIntervalSince(startManual)

        // Struct-based should be comparable to manual (within 4x is acceptable)
        let ratio = elapsedStruct / elapsedManual
        #expect(ratio < 4.0, "Struct overhead is \(ratio)x manual calculation")

        print("Struct: \(elapsedStruct * 1000) ms, Manual: \(elapsedManual * 1000) ms, Ratio: \(ratio)x")
    }
}

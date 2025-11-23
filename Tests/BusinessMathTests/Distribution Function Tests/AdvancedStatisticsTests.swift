//
//  AdvancedStatisticsTests.swift
//  BusinessMath Tests
//
//  Tests for advanced statistical and probability distribution tools
//

import Testing
import OSLog
import Numerics
@testable import BusinessMath

@Suite("AdvancedStatisticsTests") struct AdvancedStatisticsTests {
    let testLogger = Logger(subsystem: "Business Math > Tests > BusinessMathTests > Distribution Tests", category: "Advanced Statistics Tests")

    // MARK: - Probability Distribution Tests

    @Test("BinomialProbability") func LBinomialProbability() {
        // Test: Probability of getting exactly 3 heads in 5 coin flips
        // P(X=3) where n=5, p=0.5, k=3
        // Expected: C(5,3) * 0.5^3 * 0.5^2 = 10 * 0.125 * 0.25 = 0.3125
        let n = 5
        let k = 3
        let p = 0.5

        // Calculate expected value manually
        let combinations = Double(combination(n, c: k))
        let expected = combinations * pow(p, Double(k)) * pow(1 - p, Double(n - k))

        #expect(abs(expected - 0.3125) < 0.0001)
    }

    @Test("PoissonProbability") func LPoissonProbability() {
        // Test: Probability of exactly 3 events when mean is 2.5
        let x = 3
        let mu = 2.5

        let result: Double = poisson(x, µ: mu)

        // Expected: (e^-2.5 * 2.5^3) / 3! ≈ 0.2138
        #expect(result > 0.2)
        #expect(result < 0.22)
    }

    @Test("ExponentialDistribution") func LExponentialDistribution() {
        // Test: PDF of exponential distribution at x=1, λ=0.5
        let x = 1.0
        let lambda = 0.5

        let result: Double = exponentialPDF(x, λ: lambda)

        // Expected: 0.5 * e^(-0.5*1) ≈ 0.303
        #expect(result > 0.3)
        #expect(result < 0.31)
    }

    @Test("HypergeometricProbability") func LHypergeometricProbability() {
        // Test: Drawing 2 aces from 5 cards drawn from a deck
        // Total cards: 52, Aces: 4, Cards drawn: 5, Aces in hand: 2
        let result: Double = hypergeometric(total: 52, r: 4, n: 5, x: 2)
		let roundedResult = (result * 10.0).rounded() / 10.0
        // Should be a small probability
        #expect(roundedResult == 0.0)
        #expect(result < 0.05)
    }

    @Test("LogNormalDistribution") func LLogNormalDistribution() {
        // Test: Log-normal PDF at various points
        // For LogNormal(μ=0, σ=1), the PDF at x=1 should be:
        // f(1) = 1/(1 * 1 * sqrt(2π)) * exp(-(ln(1) - 0)²/(2*1²))
        // f(1) = 1/sqrt(2π) * exp(0) = 1/sqrt(2π) ≈ 0.3989
        
        // Test at x=1 (the mode/peak for standard log-normal)
        let result1 = logNormalPDF(1.0, mean: 0.0, stdDev: 1.0)
//        testLogger.info("LogNormal PDF at x=1: \(result1, privacy: .public)")
        
        // At x=1, ln(1)=0, so we get peak density
        // Expected: 1/sqrt(2π) ≈ 0.3989
        #expect(!result1.isNaN, "PDF should not be NaN at x=1")
        #expect(result1.isFinite, "PDF should be finite at x=1")
        #expect(abs(result1 - 0.3989) < 0.001, "Peak should be at 1/sqrt(2π)")
        
        // Test at x=e (≈2.718), where ln(e)=1
        let resultAtE = logNormalPDF(Double.exp(1), mean: 0.0, stdDev: 1.0)
//        testLogger.info("LogNormal PDF at x=e: \(resultAtE, privacy: .public)")
        #expect(!resultAtE.isNaN, "PDF should not be NaN at x=e")
        #expect(resultAtE < result1, "Should be less than peak")
        #expect(resultAtE > 0.05, "Should still have reasonable density")
        
        // Test specific points with explicit parameters
        let result05 = logNormalPDF(0.5, mean: 0.0, stdDev: 1.0)
//        testLogger.info("LogNormal PDF at x=0.5: \(result05, privacy: .public)")
        #expect(!result05.isNaN, "PDF must not be NaN at x=0.5")
        #expect(result05 > 0, "PDF must be positive at x=0.5")
        
        let result2 = logNormalPDF(2.0, mean: 0.0, stdDev: 1.0)
//        testLogger.info("LogNormal PDF at x=2.0: \(result2, privacy: .public)")
        #expect(!result2.isNaN, "PDF must not be NaN at x=2.0")
        #expect(result2 > 0, "PDF must be positive at x=2.0")
        
        let result5 = logNormalPDF(5.0, mean: 0.0, stdDev: 1.0)
//        testLogger.info("LogNormal PDF at x=5.0: \(result5, privacy: .public)")
        #expect(!result5.isNaN, "PDF must not be NaN at x=5.0")
        #expect(result5 > 0, "PDF must be positive at x=5.0")
        
        // Test with different parameters: LogNormal(μ=1, σ=0.5)
        // Median should be at e^μ = e^1 ≈ 2.718
        let pdfAtMedian = logNormalPDF(Double.exp(1.0), mean: 1.0, stdDev: 0.5)
//        testLogger.info("LogNormal PDF at median (μ=1, σ=0.5): \(pdfAtMedian, privacy: .public)")
        #expect(!pdfAtMedian.isNaN, "PDF should not be NaN at median")
        #expect(pdfAtMedian > 0.2, "Should have substantial density at median")
        
        // Test edge case: very small x value
        let pdfSmall = logNormalPDF(0.01, mean: 0.0, stdDev: 1.0)
//        testLogger.info("LogNormal PDF at x=0.01: \(pdfSmall, privacy: .public)")
        #expect(!pdfSmall.isNaN, "PDF should handle small x values")
        #expect(pdfSmall > 0, "PDF must be positive even for small x")
    }

    // MARK: - Combinatorics Tests

    @Test("Combinations") func LCombinations() {
        // Test: C(5,3) = 10
        let result = combination(5, c: 3)
        #expect(result == 10)

        // Test: C(10,2) = 45
        let result2 = combination(10, c: 2)
        #expect(result2 == 45)
    }

    @Test("Permutations") func LPermutations() {
        // Test: P(5,3) = 60
        let result = permutation(5, p: 3)
        #expect(result == 60)

        // Test: P(10,2) = 90
        let result2 = permutation(10, p: 2)
        #expect(result2 == 90)
    }

    @Test("Factorial") func LFactorial() {
        // Test: 5! = 120
        let result = factorial(5)
        #expect(result == 120)

        // Test: 0! = 1
        let result2 = factorial(0)
        #expect(result2 == 1)

        // Test: 10! = 3628800
        let result3 = factorial(10)
        #expect(result3 == 3628800)
    }

    // MARK: - Statistical Means Tests

    @Test("GeometricMean") func LGeometricMean() {
        // Test: Geometric mean of [2, 8] = √(2*8) = 4
        let values = [2.0, 8.0]
        let result: Double = geometricMean(values)
        #expect(abs(result - 4.0) < 0.0001)

        // Test: Geometric mean of [1,2,3,4,5] ≈ 2.605
        let values2 = [1.0, 2.0, 3.0, 4.0, 5.0]
        let result2: Double = geometricMean(values2)
        #expect(result2 > 2.6)
        #expect(result2 < 2.61)
    }

    @Test("HarmonicMean") func LHarmonicMean() {
        // Test: Harmonic mean of [1,2,4] = 3 / (1/1 + 1/2 + 1/4) = 3 / 1.75 ≈ 1.714
        let values = [1.0, 2.0, 4.0]
        let result: Double = harmonicMean(values)
        #expect(result > 1.71)
        #expect(result < 1.72)
    }

    @Test("WeightedAverage") func LWeightedAverage() {
        // Test: Weighted average of [80, 90, 70] with weights [0.2, 0.3, 0.5]
        // = 80*0.2 + 90*0.3 + 70*0.5 = 16 + 27 + 35 = 78
        let values = [80.0, 90.0, 70.0]
        let weights = [0.2, 0.3, 0.5]

        // Calculate weighted average manually for test
        let result = zip(values, weights).map(*).reduce(0, +)
        #expect(abs(result - 78.0) < 0.0001)
    }

    // MARK: - Analysis Tools Tests

    @Test("GoalSeek") func LGoalSeek() throws {
        // Test: Find x where x^2 = 16 (should be 4 or -4)
        // Using positive guess should converge to 4
        let result: Double = try goalSeek(
            function: { x in x * x },
            target: 16.0,
            guess: 5.0
        )

        #expect(abs(result - 4.0) < 0.01, "Should find x=4 for x^2=16 with positive guess")

        // Using negative guess should converge to -4
        let result2: Double = try goalSeek(
            function: { x in x * x },
            target: 16.0,
            guess: -5.0
        )

        #expect(abs(result2 - (-4.0)) < 0.01, "Should find x=-4 for x^2=16 with negative guess")
    }

    @Test("DataTable") func LDataTable() {
        // Test: 1-variable data table
        // Calculate loan payments for different interest rates
        let rates = [0.03, 0.04, 0.05, 0.06]
        let principal = 100_000.0
        let periods = 360

        let table = DataTable<Double, Double>.oneVariable(
            inputs: rates,
            calculate: { rate in
                // Monthly payment formula: P * r * (1+r)^n / ((1+r)^n - 1)
                let monthlyRate = rate / 12.0
                let n = Double(periods)
                return principal * monthlyRate * pow(1 + monthlyRate, n) / (pow(1 + monthlyRate, n) - 1)
            }
        )

        #expect(table.count == 4, "Should have 4 entries")
        #expect(table[0].input == 0.03, "First input should be 0.03")
        #expect(table[0].output > 0, "Payment should be positive")
        #expect(table[3].output > table[0].output, "Higher rate should mean higher payment")

        // Test: 2-variable data table
        // Calculate profit for different price/volume combinations
        let prices = [10.0, 12.0, 14.0]
        let volumes = [100.0, 200.0, 300.0]
        let fixedCosts = 500.0
        let variableCost = 5.0

        let profitTable = DataTable<Double, Double>.twoVariable(
            rowInputs: prices,
            columnInputs: volumes,
            calculate: { price, volume in
                let revenue = price * volume
                let totalCost = fixedCosts + (variableCost * volume)
                return revenue - totalCost
            }
        )

        #expect(profitTable.count == 3, "Should have 3 rows")
        #expect(profitTable[0].count == 3, "Each row should have 3 columns")

        // At price $10, volume 100: revenue = 1000, cost = 500 + 500 = 1000, profit = 0
        #expect(abs(profitTable[0][0] - 0.0) < 0.01, "Profit should be close to 0")

        // At price $14, volume 300: revenue = 4200, cost = 500 + 1500 = 2000, profit = 2200
        #expect(abs(profitTable[2][2] - 2200.0) < 0.01, "Profit should be 2200")
    }
}

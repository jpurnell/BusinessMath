import Testing
import Foundation
@testable import BusinessMath

@Suite("Formatted Domain Results Tests")
struct FormattedDomainResultsTests {

    // MARK: - SimulationStatistics Formatting

    @Test("SimulationStatistics provides formatted output")
    func testSimulationStatisticsFormatting() throws {
        // Create stats with floating-point noise
        let values = [99.99999999999999, 100.0, 100.00000000000001, 99.99999999999998]
        let stats = SimulationStatistics(values: values)

        // Formatted values should be clean
        #expect(stats.formattedMean.contains("100"))
        #expect(!stats.formattedMean.contains("99.999"))

        // Standard deviation should be near zero and formatted cleanly
        #expect(stats.formattedStdDev.contains("0"))

        // Min/max should be clean
        #expect(stats.formattedMin.contains("100"))
        #expect(stats.formattedMax.contains("100"))
    }

    @Test("SimulationStatistics custom formatter")
    func testSimulationStatisticsCustomFormatter() throws {
        let values = [123.456, 789.012, 456.789]
        var stats = SimulationStatistics(values: values)

        // Use significant figures
        stats.formatter = FloatingPointFormatter(strategy: .significantFigures(count: 3))

        let formattedMean = stats.formattedMean
        #expect(formattedMean.contains("456") || formattedMean.contains("457"))  // ~456.4
    }

    @Test("SimulationStatistics formatted description")
    func testSimulationStatisticsDescription() throws {
        let values = [2.9999999999999964, 3.0000000000000004, 3.0]
        let stats = SimulationStatistics(values: values)

        let description = stats.formattedDescription
        #expect(description.contains("Mean"))
        #expect(description.contains("3"))
        #expect(!description.contains("2.999"))
    }

    // MARK: - SimulationResults Formatting

    @Test("SimulationResults provides formatted statistics")
    func testSimulationResultsFormatting() throws {
        // Simulation with noise
        let values = (0..<100).map { _ in 99.99999999999999 + Double.random(in: -0.0000000000000001...0.0000000000000001) }
        let results = SimulationResults(values: values)

        // Should have formatted statistics
        #expect(results.formattedStatistics.contains("100"))
        #expect(!results.formattedStatistics.contains("99.999"))
    }

    @Test("SimulationResults formatted percentiles")
    func testSimulationResultsPercentiles() throws {
        let values = [99.99999999999999, 100.0, 100.00000000000001]
        let results = SimulationResults(values: values)

        let formatted = results.formattedPercentiles
        #expect(formatted.contains("100"))
        #expect(!formatted.contains("99.999"))
    }

    @Test("SimulationResults formatted probability")
    func testSimulationResultsProbability() throws {
        // 80% of values are 100, 20% are 200
        var values: [Double] = []
        for _ in 0..<80 { values.append(100.0) }
        for _ in 0..<20 { values.append(200.0) }

        let results = SimulationResults(values: values)

        // Probability above 150 should be 0.2 (20%)
        let prob = results.probabilityAbove(150.0)
        let formatted = results.formattedProbabilityAbove(150.0)

        #expect(abs(prob - 0.2) < 0.01)
        #expect(formatted.contains("20") || formatted.contains("0.2"))
    }

    // MARK: - ConstrainedOptimizationResult Formatting

    @Test("ConstrainedOptimizationResult provides formatted output")
    func testConstrainedOptimizationResultFormatting() throws {
        let result = ConstrainedOptimizationResult(
            solution: VectorN([2.9999999999999964, 3.0000000000000004]),
            objectiveValue: 1.2345678901234567e-15,
            lagrangeMultipliers: [0.4999999999999998, 0.5000000000000002],
            iterations: 25,
            converged: true,
            history: nil,
            constraintViolation: 1e-16
        )

        // Formatted solution should be clean
        #expect(result.formattedSolution.contains("3"))
        #expect(!result.formattedSolution.contains("2.999"))

        // Objective value should be zero
        #expect(result.formattedObjectiveValue == "0")

        // Lagrange multipliers should be 0.5
        #expect(result.formattedLagrangeMultipliers.contains("0.5"))
        #expect(!result.formattedLagrangeMultipliers.contains("0.4999"))

        // Constraint violation should be zero
        #expect(result.formattedConstraintViolation == "0")
    }

    @Test("ConstrainedOptimizationResult custom formatter")
    func testConstrainedOptimizationResultCustomFormatter() throws {
        var result = ConstrainedOptimizationResult(
            solution: VectorN([123.456789]),
            objectiveValue: 456.789012,
            lagrangeMultipliers: [0.123456],
            iterations: 10,
            converged: true
        )

        // Use significant figures
        result.formatter = FloatingPointFormatter(strategy: .significantFigures(count: 2))

        let formatted = result.formattedObjectiveValue
        #expect(formatted.contains("460") || formatted.contains("4.6"))  // 2 sig figs
    }

    @Test("ConstrainedOptimizationResult formatted description")
    func testConstrainedOptimizationResultDescription() throws {
        let result = ConstrainedOptimizationResult(
            solution: VectorN([2.9999999999999964]),
            objectiveValue: 1e-15,
            lagrangeMultipliers: [0.5],
            iterations: 15,
            converged: true
        )

        let description = result.formattedDescription
        #expect(description.contains("3"))
        #expect(description.contains("15"))  // iterations
        #expect(description.contains("Converged") || description.contains("converged"))
        #expect(!description.contains("2.999"))
    }

    // MARK: - Edge Cases

    @Test("Handles very large simulation results")
    func testLargeSimulationResults() throws {
        let values = (0..<10_000).map { _ in 1_000_000.0 + Double.random(in: -0.5...0.5) }
        let results = SimulationResults(values: values)

        // Should format large numbers clearly
        let formatted = results.formattedStatistics
        #expect(formatted.contains("1") && formatted.contains("000"))
    }

    @Test("Handles skewed distributions")
    func testSkewedDistribution() throws {
        // Right-skewed data
        var values = Array(repeating: 1.0, count: 80)
        values += Array(repeating: 10.0, count: 20)

        let stats = SimulationStatistics(values: values)

        // Skewness should be formatted
        let formatted = stats.formattedSkewness
        #expect(formatted.contains("1") || formatted.contains("2"))  // Positive skew
    }
}

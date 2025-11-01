import Testing
import Foundation
@testable import BusinessMath

@Suite("Risk Aggregation Tests")
struct RiskAggregationTests {

	// MARK: - Helper Functions

	func makeSampleRisks() -> [RiskMeasure<Double>] {
		return [
			RiskMeasure(
				name: "Market Risk",
				value: 1_000_000,
				distribution: .normal(mean: 0, stdDev: 200_000)
			),
			RiskMeasure(
				name: "Credit Risk",
				value: 500_000,
				distribution: .normal(mean: 0, stdDev: 150_000)
			),
			RiskMeasure(
				name: "Operational Risk",
				value: 300_000,
				distribution: .logNormal(mean: 0, stdDev: 100_000)
			)
		]
	}

	// MARK: - Simple Aggregation

	@Test("Aggregate risks with perfect correlation")
	func perfectCorrelation() throws {
		let risks = makeSampleRisks()

		let aggregator = RiskAggregator<Double>()
		let total = aggregator.aggregate(
			risks: risks,
			correlation: 1.0
		)

		// Perfect correlation: simple sum
		let expectedTotal = risks.map { $0.value }.reduce(0, +)
		#expect(abs(total.value - expectedTotal) < 1.0)
	}

	@Test("Aggregate risks with zero correlation")
	func zeroCorrelation() throws {
		let risks = makeSampleRisks()

		let aggregator = RiskAggregator<Double>()
		let total = aggregator.aggregate(
			risks: risks,
			correlation: 0.0
		)

		// Zero correlation: sqrt(sum of variances)
		let simpleSum = risks.map { $0.value }.reduce(0, +)

		// Diversification benefit
		#expect(total.value < simpleSum)
	}

	@Test("Aggregate risks with negative correlation")
	func negativeCorrelation() throws {
		let risk1 = RiskMeasure(
			name: "Risk 1",
			value: 1_000_000,
			distribution: .normal(mean: 0, stdDev: 200_000)
		)

		let risk2 = RiskMeasure(
			name: "Risk 2",
			value: 1_000_000,
			distribution: .normal(mean: 0, stdDev: 200_000)
		)

		let aggregator = RiskAggregator<Double>()

		let positiveCorr = aggregator.aggregate(
			risks: [risk1, risk2],
			correlation: 0.5
		)

		let negativeCorr = aggregator.aggregate(
			risks: [risk1, risk2],
			correlation: -0.5
		)

		// Negative correlation provides more diversification
		#expect(negativeCorr.value < positiveCorr.value)
	}

	// MARK: - Correlation Matrix

	@Test("Aggregate with correlation matrix")
	func correlationMatrix() throws {
		let risks = makeSampleRisks()

		// Custom correlation matrix
		let correlations: [[Double]] = [
			[1.0, 0.6, 0.3],  // Market risk
			[0.6, 1.0, 0.2],  // Credit risk
			[0.3, 0.2, 1.0]   // Operational risk
		]

		let aggregator = RiskAggregator<Double>()
		let total = aggregator.aggregate(
			risks: risks,
			correlationMatrix: correlations
		)

		#expect(total.value > 0)

		// Should be less than simple sum due to diversification
		let simpleSum = risks.map { $0.value }.reduce(0, +)
		#expect(total.value < simpleSum)
	}

	@Test("Correlation matrix validation")
	func invalidCorrelationMatrix() throws {
		let risks = makeSampleRisks()

		// Invalid: diagonal not 1.0
		let invalidCorrelations: [[Double]] = [
			[0.9, 0.6, 0.3],
			[0.6, 1.0, 0.2],
			[0.3, 0.2, 1.0]
		]

		let aggregator = RiskAggregator<Double>()

		do {
			_ = aggregator.aggregate(
				risks: risks,
				correlationMatrix: invalidCorrelations
			)
			Issue.record("Should have thrown validation error")
		} catch RiskAggregationError.invalidCorrelationMatrix {
			// Expected
		}
	}

	// MARK: - VaR Aggregation

	@Test("Aggregate VaR measures")
	func aggregateVaR() throws {
		let var95_1 = ValueAtRisk(
			name: "Portfolio 1",
			value: 1_000_000,
			confidenceLevel: 0.95
		)

		let var95_2 = ValueAtRisk(
			name: "Portfolio 2",
			value: 800_000,
			confidenceLevel: 0.95
		)

		let aggregator = VaRAggregator<Double>()
		let totalVaR = aggregator.aggregate(
			vars: [var95_1, var95_2],
			correlation: 0.5
		)

		// Total VaR should reflect diversification
		#expect(totalVaR.value < var95_1.value + var95_2.value)
		#expect(totalVaR.value > max(var95_1.value, var95_2.value))
	}

	@Test("VaR subadditivity")
	func varSubadditivity() throws {
		// VaR may not be subadditive (one limitation)
		let var1 = ValueAtRisk(name: "A", value: 1_000_000, confidenceLevel: 0.95)
		let var2 = ValueAtRisk(name: "B", value: 1_000_000, confidenceLevel: 0.95)

		let aggregator = VaRAggregator<Double>()

		// With high correlation, total VaR may approach sum
		let highCorr = aggregator.aggregate(vars: [var1, var2], correlation: 0.9)

		// With low correlation, total VaR should be much less
		let lowCorr = aggregator.aggregate(vars: [var1, var2], correlation: 0.1)

		#expect(lowCorr.value < highCorr.value)
	}

	// MARK: - CVaR Aggregation

	@Test("Aggregate CVaR measures")
	func aggregateCVaR() throws {
		let cvar1 = ConditionalVaR(
			name: "Portfolio 1",
			value: 1_200_000,
			confidenceLevel: 0.95
		)

		let cvar2 = ConditionalVaR(
			name: "Portfolio 2",
			value: 900_000,
			confidenceLevel: 0.95
		)

		let aggregator = CVaRAggregator<Double>()
		let totalCVaR = aggregator.aggregate(
			cvars: [cvar1, cvar2],
			correlation: 0.6
		)

		// CVaR is coherent (subadditive)
		#expect(totalCVaR.value <= cvar1.value + cvar2.value)
	}

	// MARK: - Copula-Based Aggregation

	@Test("Gaussian copula aggregation")
	func gaussianCopula() throws {
		let risks = makeSampleRisks()

		let correlations: [[Double]] = [
			[1.0, 0.5, 0.3],
			[0.5, 1.0, 0.4],
			[0.3, 0.4, 1.0]
		]

		let aggregator = CopulaAggregator<Double>(type: .gaussian)
		let total = aggregator.aggregate(
			risks: risks,
			correlationMatrix: correlations
		)

		#expect(total.value > 0)
	}

	@Test("Student-t copula aggregation")
	func studentTCopula() throws {
		let risks = makeSampleRisks()

		let correlations: [[Double]] = [
			[1.0, 0.5, 0.3],
			[0.5, 1.0, 0.4],
			[0.3, 0.4, 1.0]
		]

		// Student-t copula captures tail dependence
		let aggregator = CopulaAggregator<Double>(
			type: .studentT(degreesOfFreedom: 5)
		)

		let total = aggregator.aggregate(
			risks: risks,
			correlationMatrix: correlations
		)

		#expect(total.value > 0)
	}

	@Test("Copula comparison")
	func copulaComparison() throws {
		let risks = makeSampleRisks()

		let correlations: [[Double]] = [
			[1.0, 0.7, 0.7],
			[0.7, 1.0, 0.7],
			[0.7, 0.7, 1.0]
		]

		let gaussian = CopulaAggregator<Double>(type: .gaussian)
			.aggregate(risks: risks, correlationMatrix: correlations)

		let studentT = CopulaAggregator<Double>(type: .studentT(degreesOfFreedom: 3))
			.aggregate(risks: risks, correlationMatrix: correlations)

		// Student-t should show higher tail risk
		#expect(studentT.tailRisk > gaussian.tailRisk)
	}

	// MARK: - Monte Carlo Aggregation

	@Test("Monte Carlo risk aggregation")
	func monteCarloAggregation() throws {
		let risks = makeSampleRisks()

		let correlations: [[Double]] = [
			[1.0, 0.5, 0.3],
			[0.5, 1.0, 0.4],
			[0.3, 0.4, 1.0]
		]

		let aggregator = MonteCarloAggregator<Double>(iterations: 10_000)
		let result = aggregator.aggregate(
			risks: risks,
			correlationMatrix: correlations
		)

		#expect(result.mean > 0)
		#expect(result.stdDev > 0)

		// Should provide percentile estimates
		#expect(result.percentile(0.95) > result.mean)
		#expect(result.percentile(0.99) > result.percentile(0.95))
	}

	@Test("Monte Carlo distribution")
	func monteCarloDistribution() throws {
		let risks = makeSampleRisks()

		let aggregator = MonteCarloAggregator<Double>(iterations: 10_000)
		let result = aggregator.aggregate(
			risks: risks,
			correlation: 0.5
		)

		let distribution = result.distribution

		// Should capture full distribution
		#expect(distribution.count == 10_000)

		// Check distribution properties
		let sorted = distribution.sorted()
		let median = sorted[5000]

		#expect(median > 0)
	}

	// MARK: - Hierarchical Aggregation

	@Test("Two-level risk aggregation")
	func hierarchicalAggregation() throws {
		// Business units
		let unit1Risks = [
			RiskMeasure(name: "Market", value: 500_000, distribution: .normal(mean: 0, stdDev: 100_000)),
			RiskMeasure(name: "Credit", value: 300_000, distribution: .normal(mean: 0, stdDev: 80_000))
		]

		let unit2Risks = [
			RiskMeasure(name: "Market", value: 600_000, distribution: .normal(mean: 0, stdDev: 120_000)),
			RiskMeasure(name: "Operational", value: 200_000, distribution: .normal(mean: 0, stdDev: 50_000))
		]

		let aggregator = HierarchicalAggregator<Double>()

		// Aggregate within units
		let unit1Total = aggregator.aggregateUnit(risks: unit1Risks, correlation: 0.6)
		let unit2Total = aggregator.aggregateUnit(risks: unit2Risks, correlation: 0.5)

		// Aggregate across units
		let firmTotal = aggregator.aggregateFirm(
			units: [unit1Total, unit2Total],
			correlation: 0.4
		)

		#expect(firmTotal.value > 0)
		#expect(firmTotal.value < unit1Risks.map { $0.value }.reduce(0, +) + unit2Risks.map { $0.value }.reduce(0, +))
	}

	// MARK: - Risk Contribution

	@Test("Calculate marginal risk contributions")
	func marginalContributions() throws {
		let risks = makeSampleRisks()

		let aggregator = RiskAggregator<Double>()
		let contributions = aggregator.marginalContributions(
			risks: risks,
			correlation: 0.5
		)

		// Contributions should sum to total
		let total = aggregator.aggregate(risks: risks, correlation: 0.5)
		let sumContributions = contributions.reduce(0, +)

		#expect(abs(sumContributions - total.value) < 1.0)
	}

	@Test("Component VaR")
	func componentVaR() throws {
		let risks = makeSampleRisks()

		let aggregator = VaRAggregator<Double>()
		let componentVaRs = aggregator.componentVaR(
			risks: risks,
			correlation: 0.5,
			confidenceLevel: 0.95
		)

		#expect(componentVaRs.count == risks.count)

		// Components should sum to total VaR
		let sum = componentVaRs.reduce(0, +)
		let total = aggregator.aggregate(
			vars: risks.map { ValueAtRisk(name: $0.name, value: $0.value, confidenceLevel: 0.95) },
			correlation: 0.5
		)

		#expect(abs(sum - total.value) < 1.0)
	}

	// MARK: - Concentration Risk

	@Test("Detect concentration risk")
	func concentrationRisk() throws {
		// One large risk, several small risks
		let concentratedRisks = [
			RiskMeasure(name: "Large", value: 5_000_000, distribution: .normal(mean: 0, stdDev: 1_000_000)),
			RiskMeasure(name: "Small 1", value: 200_000, distribution: .normal(mean: 0, stdDev: 50_000)),
			RiskMeasure(name: "Small 2", value: 300_000, distribution: .normal(mean: 0, stdDev: 60_000))
		]

		let analyzer = ConcentrationAnalyzer<Double>()
		let metrics = analyzer.analyze(risks: concentratedRisks)

		// Herfindahl index should be high
		#expect(metrics.herfindahlIndex > 0.7)

		// Should identify the large risk as concentration
		#expect(metrics.concentratedRisks.contains("Large"))
	}

	// MARK: - Diversification Benefit

	@Test("Calculate diversification benefit")
	func diversificationBenefit() throws {
		let risks = makeSampleRisks()

		let aggregator = RiskAggregator<Double>()

		// Sum of individual risks
		let undiversified = risks.map { $0.value }.reduce(0, +)

		// Diversified total
		let diversified = aggregator.aggregate(risks: risks, correlation: 0.3)

		let benefit = undiversified - diversified.value

		// Should have positive diversification benefit
		#expect(benefit > 0)
		#expect(benefit < undiversified)
	}

	@Test("Diversification ratio")
	func diversificationRatio() throws {
		let risks = makeSampleRisks()

		let aggregator = RiskAggregator<Double>()
		let ratio = aggregator.diversificationRatio(
			risks: risks,
			correlation: 0.4
		)

		// Ratio should be between 0 and 1
		#expect(ratio > 0)
		#expect(ratio < 1)

		// Higher ratio = more diversification
		let highCorrRatio = aggregator.diversificationRatio(
			risks: risks,
			correlation: 0.9
		)

		#expect(ratio > highCorrRatio)
	}

	// MARK: - Tail Dependence

	@Test("Measure tail dependence")
	func tailDependence() throws {
		let risk1 = RiskMeasure(
			name: "A",
			value: 1_000_000,
			distribution: .normal(mean: 0, stdDev: 200_000)
		)

		let risk2 = RiskMeasure(
			name: "B",
			value: 1_000_000,
			distribution: .normal(mean: 0, stdDev: 200_000)
		)

		let analyzer = TailDependenceAnalyzer<Double>()

		let upperTailDep = analyzer.upperTailDependence(
			risk1: risk1,
			risk2: risk2,
			correlation: 0.7,
			threshold: 0.95
		)

		// Should capture extreme co-movement
		#expect(upperTailDep >= 0)
		#expect(upperTailDep <= 1)
	}
}

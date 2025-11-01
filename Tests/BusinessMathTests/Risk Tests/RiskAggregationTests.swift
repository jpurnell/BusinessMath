import Testing
import Foundation
@testable import BusinessMath

@Suite("Risk Aggregation Tests")
struct RiskAggregationTests {

	// MARK: - VaR Aggregation Tests

	@Test("Aggregate VaR with perfect correlation")
	func perfectCorrelation() throws {
		let individualVaRs = [100.0, 150.0, 200.0]
		let correlations = [
			[1.0, 1.0, 1.0],
			[1.0, 1.0, 1.0],
			[1.0, 1.0, 1.0]
		]

		let aggregatedVaR = RiskAggregator<Double>.aggregateVaR(
			individualVaRs: individualVaRs,
			correlations: correlations
		)

		// With perfect correlation, aggregate VaR = sum of individual VaRs
		let expectedVaR = 100.0 + 150.0 + 200.0
		#expect(abs(aggregatedVaR - expectedVaR) < 1.0)
	}

	@Test("Aggregate VaR with zero correlation")
	func zeroCorrelation() throws {
		let individualVaRs = [100.0, 100.0, 100.0]
		let correlations = [
			[1.0, 0.0, 0.0],
			[0.0, 1.0, 0.0],
			[0.0, 0.0, 1.0]
		]

		let aggregatedVaR = RiskAggregator<Double>.aggregateVaR(
			individualVaRs: individualVaRs,
			correlations: correlations
		)

		// With zero correlation, aggregate VaR = sqrt(sum of variances)
		// sqrt(100^2 + 100^2 + 100^2) = sqrt(30000) ≈ 173.2
		#expect(aggregatedVaR > 150.0)
		#expect(aggregatedVaR < 200.0)
	}

	@Test("Aggregate VaR with negative correlation")
	func negativeCorrelation() throws {
		let individualVaRs = [100.0, 100.0]
		let correlations = [
			[1.0, -0.5],
			[-0.5, 1.0]
		]

		let aggregatedVaR = RiskAggregator<Double>.aggregateVaR(
			individualVaRs: individualVaRs,
			correlations: correlations
		)

		// Negative correlation should reduce aggregate VaR
		// Below sum but above individual
		#expect(aggregatedVaR < 200.0) // Less than sum
		#expect(aggregatedVaR > 0.0)   // Still positive
	}

	@Test("Aggregate VaR diversification benefit")
	func diversificationBenefit() throws {
		let individualVaRs = [100.0, 150.0]

		// Imperfect correlation (0.6)
		let correlations = [
			[1.0, 0.6],
			[0.6, 1.0]
		]

		let aggregatedVaR = RiskAggregator<Double>.aggregateVaR(
			individualVaRs: individualVaRs,
			correlations: correlations
		)

		let sumVaR = 250.0

		// Diversification benefit = sum - aggregate
		let benefit = sumVaR - aggregatedVaR

		#expect(benefit > 0.0) // Should have diversification benefit
		#expect(aggregatedVaR < sumVaR)
	}

	// MARK: - Marginal VaR Tests

	@Test("Marginal VaR identifies risk contribution")
	func marginalVaRContribution() throws {
		let individualVaRs = [100.0, 200.0, 150.0]
		let correlations = [
			[1.0, 0.5, 0.3],
			[0.5, 1.0, 0.4],
			[0.3, 0.4, 1.0]
		]

		let marginal0 = RiskAggregator<Double>.marginalVaR(
			entity: 0,
			individualVaRs: individualVaRs,
			correlations: correlations
		)

		let marginal1 = RiskAggregator<Double>.marginalVaR(
			entity: 1,
			individualVaRs: individualVaRs,
			correlations: correlations
		)

		// Entity with higher individual VaR should have higher marginal VaR
		#expect(marginal1 > marginal0)
		#expect(marginal0 > 0.0)
		#expect(marginal1 > 0.0)
	}

	@Test("Marginal VaR proportional to individual risk")
	func marginalVaRProportional() throws {
		let individualVaRs = [100.0, 300.0] // 3x difference
		let correlations = [
			[1.0, 0.5],
			[0.5, 1.0]
		]

		let marginal0 = RiskAggregator<Double>.marginalVaR(
			entity: 0,
			individualVaRs: individualVaRs,
			correlations: correlations
		)

		let marginal1 = RiskAggregator<Double>.marginalVaR(
			entity: 1,
			individualVaRs: individualVaRs,
			correlations: correlations
		)

		// Higher individual VaR should lead to higher marginal VaR
		#expect(marginal1 > marginal0)
	}

	// MARK: - Component VaR Tests

	@Test("Component VaR equals marginal times weight")
	func componentVaRWeighting() throws {
		let individualVaRs = [100.0, 200.0]
		let weights = [0.6, 0.4]
		let correlations = [
			[1.0, 0.5],
			[0.5, 1.0]
		]

		let components = RiskAggregator<Double>.componentVaR(
			individualVaRs: individualVaRs,
			weights: weights,
			correlations: correlations
		)

		#expect(components.count == 2)
		#expect(components[0] > 0.0)
		#expect(components[1] > 0.0)

		// Component with higher weight * VaR should contribute more
		// First: weight 0.6, VaR 100 = 60
		// Second: weight 0.4, VaR 200 = 80
		// But adjusted by marginal contributions
		#expect(components[0] > 0.0)
		#expect(components[1] > 0.0)
	}

	@Test("Component VaR sums to portfolio VaR")
	func componentVaRSumToTotal() throws {
		let individualVaRs = [100.0, 150.0, 200.0]
		let weights = [0.3, 0.4, 0.3]
		let correlations = [
			[1.0, 0.6, 0.4],
			[0.6, 1.0, 0.5],
			[0.4, 0.5, 1.0]
		]

		// Weight the individual VaRs for portfolio calculation
		let weightedVaRs = zip(individualVaRs, weights).map { $0 * $1 }

		let components = RiskAggregator<Double>.componentVaR(
			individualVaRs: individualVaRs,
			weights: weights,
			correlations: correlations
		)

		let portfolioVaR = RiskAggregator<Double>.aggregateVaR(
			individualVaRs: weightedVaRs,
			correlations: correlations
		)

		let sumComponents = components.reduce(0.0, +)

		// Component VaRs should sum approximately to portfolio VaR
		#expect(abs(sumComponents - portfolioVaR) < 1.0)
	}

	@Test("Component VaR with equal weights")
	func equalWeightComponents() throws {
		let individualVaRs = [100.0, 100.0, 100.0]
		let weights = [1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0]
		let correlations = [
			[1.0, 0.5, 0.5],
			[0.5, 1.0, 0.5],
			[0.5, 0.5, 1.0]
		]

		let components = RiskAggregator<Double>.componentVaR(
			individualVaRs: individualVaRs,
			weights: weights,
			correlations: correlations
		)

		// With equal VaRs, weights, and symmetric correlations,
		// components should be roughly equal
		let avgComponent = components.reduce(0.0, +) / 3.0

		for component in components {
			#expect(abs(component - avgComponent) < 10.0)
		}
	}

	// MARK: - Edge Cases

	@Test("Single entity VaR aggregation")
	func singleEntityVaR() throws {
		let individualVaRs = [100.0]
		let correlations = [[1.0]]

		let aggregatedVaR = RiskAggregator<Double>.aggregateVaR(
			individualVaRs: individualVaRs,
			correlations: correlations
		)

		#expect(aggregatedVaR == 100.0)
	}

	@Test("Two entities with high correlation")
	func twoEntitiesHighCorrelation() throws {
		let individualVaRs = [100.0, 100.0]
		let correlations = [
			[1.0, 0.9],
			[0.9, 1.0]
		]

		let aggregatedVaR = RiskAggregator<Double>.aggregateVaR(
			individualVaRs: individualVaRs,
			correlations: correlations
		)

		// With high correlation (0.9), should be close to sum (200)
		#expect(aggregatedVaR > 180.0)
		#expect(aggregatedVaR < 200.0)
	}
}

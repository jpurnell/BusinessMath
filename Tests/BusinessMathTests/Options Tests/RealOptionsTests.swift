import Testing
import Foundation
@testable import BusinessMath

@Suite("Real Options Analysis Tests")
struct RealOptionsTests {

	// MARK: - Expansion Option Tests

	@Test("Expansion option adds value")
	func expansionAddsValue() throws {
		let baseNPV = 10_000_000.0
		let expansionCost = 5_000_000.0
		let expansionNPV = 8_000_000.0

		let projectValue = RealOptionsAnalysis<Double>.expansionOption(
			baseNPV: baseNPV,
			expansionCost: expansionCost,
			expansionNPV: expansionNPV,
			volatility: 0.30,
			timeToDecision: 2.0,
			riskFreeRate: 0.05
		)

		// Total value should be greater than base NPV
		#expect(projectValue > baseNPV)
		// Option value should be positive
		#expect(projectValue - baseNPV > 0.0)
	}

	@Test("Expansion option with high volatility")
	func expansionHighVolatility() throws {
		let baseNPV = 10_000_000.0

		let lowVolValue = RealOptionsAnalysis<Double>.expansionOption(
			baseNPV: baseNPV,
			expansionCost: 5_000_000.0,
			expansionNPV: 8_000_000.0,
			volatility: 0.10,
			timeToDecision: 2.0,
			riskFreeRate: 0.05
		)

		let highVolValue = RealOptionsAnalysis<Double>.expansionOption(
			baseNPV: baseNPV,
			expansionCost: 5_000_000.0,
			expansionNPV: 8_000_000.0,
			volatility: 0.50,
			timeToDecision: 2.0,
			riskFreeRate: 0.05
		)

		// Higher volatility = higher option value
		#expect(highVolValue > lowVolValue)
	}

	// MARK: - Abandonment Option Tests

	@Test("Abandonment option adds value")
	func abandonmentAddsValue() throws {
		let projectNPV = 5_000_000.0
		let salvageValue = 3_000_000.0

		let projectValue = RealOptionsAnalysis<Double>.abandonmentOption(
			projectNPV: projectNPV,
			salvageValue: salvageValue,
			volatility: 0.40,
			timeToDecision: 1.0,
			riskFreeRate: 0.05
		)

		// Total value should be at least project NPV
		#expect(projectValue >= projectNPV)
		// Option value should be positive (or very small negative due to numerical precision)
		#expect(projectValue - projectNPV >= -0.01)
	}

	@Test("Abandonment option more valuable with high volatility")
	func abandonmentHighVolatility() throws {
		let projectNPV = 5_000_000.0
		let salvageValue = 3_000_000.0

		let lowVolValue = RealOptionsAnalysis<Double>.abandonmentOption(
			projectNPV: projectNPV,
			salvageValue: salvageValue,
			volatility: 0.20,
			timeToDecision: 1.0,
			riskFreeRate: 0.05
		)

		let highVolValue = RealOptionsAnalysis<Double>.abandonmentOption(
			projectNPV: projectNPV,
			salvageValue: salvageValue,
			volatility: 0.60,
			timeToDecision: 1.0,
			riskFreeRate: 0.05
		)

		// Higher volatility = higher option value
		#expect(highVolValue > lowVolValue)
	}

	// MARK: - Decision Tree Tests

	@Test("Terminal node returns value")
	func decisionTreeTerminal() throws {
		let terminal = DecisionNode<Double>(type: .terminal, value: 100.0)

		let value = RealOptionsAnalysis<Double>.decisionTree(root: terminal)

		#expect(value == 100.0)
	}

	@Test("Chance node calculates expected value")
	func decisionTreeChance() throws {
		// Chance node with two outcomes
		let goodOutcome = DecisionNode<Double>(type: .terminal, value: 200.0)
		let badOutcome = DecisionNode<Double>(type: .terminal, value: 50.0)

		let chanceNode = DecisionNode<Double>(
			type: .chance,
			branches: [
				Branch(probability: 0.6, node: goodOutcome),
				Branch(probability: 0.4, node: badOutcome)
			]
		)

		let value = RealOptionsAnalysis<Double>.decisionTree(root: chanceNode)

		// Expected value = 0.6 * 200 + 0.4 * 50 = 120 + 20 = 140
		#expect(abs(value - 140.0) < 0.01)
	}

	@Test("Decision node chooses best outcome")
	func decisionTreeDecision() throws {
		// Decision node with two choices
		let choice1 = DecisionNode<Double>(type: .terminal, value: 150.0)
		let choice2 = DecisionNode<Double>(type: .terminal, value: 200.0)

		let decisionNode = DecisionNode<Double>(
			type: .decision,
			branches: [
				Branch(probability: 1.0, node: choice1),
				Branch(probability: 1.0, node: choice2)
			]
		)

		let value = RealOptionsAnalysis<Double>.decisionTree(root: decisionNode)

		// Should choose the better option (200)
		#expect(value == 200.0)
	}

	@Test("Complex decision tree")
	func complexDecisionTree() throws {
		// Build: Decision -> Chance -> Terminal
		let highSuccess = DecisionNode<Double>(type: .terminal, value: 500.0)
		let highFailure = DecisionNode<Double>(type: .terminal, value: -100.0)

		let highRiskChoice = DecisionNode<Double>(
			type: .chance,
			branches: [
				Branch(probability: 0.3, node: highSuccess),
				Branch(probability: 0.7, node: highFailure)
			]
		)

		let lowRiskChoice = DecisionNode<Double>(type: .terminal, value: 100.0)

		let root = DecisionNode<Double>(
			type: .decision,
			branches: [
				Branch(probability: 1.0, node: highRiskChoice),
				Branch(probability: 1.0, node: lowRiskChoice)
			]
		)

		let value = RealOptionsAnalysis<Double>.decisionTree(root: root)

		// High risk EV = 0.3 * 500 + 0.7 * (-100) = 150 - 70 = 80
		// Low risk = 100
		// Should choose low risk (100)
		#expect(value == 100.0)
	}

	// MARK: - Edge Cases

	@Test("Expansion option with zero time")
	func zeroTimeExpansion() throws {
		// With zero time, option value should be max(0, expansionNPV - cost)
		let projectValue = RealOptionsAnalysis<Double>.expansionOption(
			baseNPV: 10_000_000.0,
			expansionCost: 5_000_000.0,
			expansionNPV: 8_000_000.0,
			volatility: 0.30,
			timeToDecision: 0.001,  // Near zero
			riskFreeRate: 0.05
		)

		// Should be close to base + max(0, 8M - 5M) = 10M + 3M = 13M
		#expect(projectValue >= 10_000_000.0)
		#expect(projectValue <= 14_000_000.0)
	}

	@Test("Empty decision node")
	func emptyDecisionNode() throws {
		// Decision node with no branches should return node value
		let node = DecisionNode<Double>(type: .decision, value: 50.0, branches: [])

		let value = RealOptionsAnalysis<Double>.decisionTree(root: node)

		#expect(value == 50.0)
	}
}

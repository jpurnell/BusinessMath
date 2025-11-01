import Testing
import Foundation
@testable import BusinessMath

@Suite("Real Options Tests")
struct RealOptionsTests {

	// MARK: - Expansion Option

	@Test("Value expansion option")
	func expansionOption() throws {
		let option = ExpansionOption<Double>(
			baseProjectNPV: 1_000_000,
			expansionCost: 500_000,
			expansionMultiplier: 1.5,  // Can expand to 150% of base
			timeToDecision: 2.0,
			volatility: 0.30,
			riskFreeRate: 0.05
		)

		let value = option.value()

		// Expansion option should have positive value
		#expect(value > 0)

		// Should be worth less than the full expansion benefit
		let maxBenefit = 1_000_000 * 1.5 - 1_000_000 - 500_000
		#expect(value < maxBenefit)
	}

	@Test("Expansion option increases with volatility")
	func expansionVolatility() throws {
		let optionLowVol = ExpansionOption<Double>(
			baseProjectNPV: 1_000_000,
			expansionCost: 500_000,
			expansionMultiplier: 1.5,
			timeToDecision: 2.0,
			volatility: 0.20,
			riskFreeRate: 0.05
		)

		let optionHighVol = ExpansionOption<Double>(
			baseProjectNPV: 1_000_000,
			expansionCost: 500_000,
			expansionMultiplier: 1.5,
			timeToDecision: 2.0,
			volatility: 0.40,
			riskFreeRate: 0.05
		)

		// Higher volatility = higher option value
		#expect(optionHighVol.value() > optionLowVol.value())
	}

	// MARK: - Abandonment Option

	@Test("Value abandonment option")
	func abandonmentOption() throws {
		let option = AbandonmentOption<Double>(
			projectNPV: 500_000,
			salvageValue: 300_000,
			timeToDecision: 1.0,
			volatility: 0.25,
			riskFreeRate: 0.05
		)

		let value = option.value()

		// Abandonment option (put option) should have positive value
		#expect(value > 0)
	}

	@Test("Abandonment value with high salvage")
	func highSalvageValue() throws {
		let projectNPV = 500_000.0
		let salvageValue = 600_000.0  // Salvage > NPV

		let option = AbandonmentOption<Double>(
			projectNPV: projectNPV,
			salvageValue: salvageValue,
			timeToDecision: 1.0,
			volatility: 0.25,
			riskFreeRate: 0.05
		)

		let value = option.value()

		// Should be worth at least intrinsic value
		let intrinsic = salvageValue - projectNPV
		#expect(value >= intrinsic * 0.9)  // Allow for discounting
	}

	@Test("Abandonment reduces downside risk")
	func abandonmentDownsideProtection() throws {
		let projectNPV = 500_000.0
		let salvageValue = 300_000.0

		let optionValue = AbandonmentOption<Double>(
			projectNPV: projectNPV,
			salvageValue: salvageValue,
			timeToDecision: 1.0,
			volatility: 0.30,
			riskFreeRate: 0.05
		).value()

		// Project with abandonment option worth more than base NPV
		let totalValue = projectNPV + optionValue
		#expect(totalValue > projectNPV)
	}

	// MARK: - Delay Option

	@Test("Value delay option")
	func delayOption() throws {
		let option = DelayOption<Double>(
			immediateNPV: 800_000,
			maxDelayYears: 3.0,
			volatility: 0.30,
			riskFreeRate: 0.05,
			costOfDelay: 0.02  // 2% annual cost
		)

		let value = option.value()

		// Delay option should have positive value
		#expect(value > 0)
	}

	@Test("Delay option with high cost of delay")
	func highCostOfDelay() throws {
		let optionLowCost = DelayOption<Double>(
			immediateNPV: 800_000,
			maxDelayYears: 3.0,
			volatility: 0.30,
			riskFreeRate: 0.05,
			costOfDelay: 0.02
		)

		let optionHighCost = DelayOption<Double>(
			immediateNPV: 800_000,
			maxDelayYears: 3.0,
			volatility: 0.30,
			riskFreeRate: 0.05,
			costOfDelay: 0.10  // 10% annual cost
		)

		// Higher cost of delay reduces option value
		#expect(optionLowCost.value() > optionHighCost.value())
	}

	// MARK: - Staged Investment (Compound Options)

	@Test("Value staged investment")
	func stagedInvestment() throws {
		let stages = [
			InvestmentStage(cost: 100_000, time: 0.0),
			InvestmentStage(cost: 200_000, time: 1.0),
			InvestmentStage(cost: 300_000, time: 2.0)
		]

		let option = StagedInvestmentOption<Double>(
			finalProjectValue: 1_000_000,
			stages: stages,
			volatility: 0.35,
			riskFreeRate: 0.05
		)

		let value = option.value()

		// Staged investment option should have value
		#expect(value > 0)

		// Should be worth more than simple NPV
		let simpleNPV = 1_000_000 - 100_000 - 200_000 * exp(-0.05 * 1.0) - 300_000 * exp(-0.05 * 2.0)
		#expect(value > simpleNPV)
	}

	@Test("Staged investment better than lump sum")
	func stagedVsLumpSum() throws {
		let finalValue = 1_000_000.0
		let totalCost = 600_000.0

		// Staged investment
		let staged = StagedInvestmentOption<Double>(
			finalProjectValue: finalValue,
			stages: [
				InvestmentStage(cost: 200_000, time: 0.0),
				InvestmentStage(cost: 200_000, time: 1.0),
				InvestmentStage(cost: 200_000, time: 2.0)
			],
			volatility: 0.30,
			riskFreeRate: 0.05
		).value()

		// Lump sum (no flexibility)
		let lumpSum = finalValue - totalCost

		// Staged should be worth more due to flexibility
		#expect(staged > lumpSum)
	}

	// MARK: - Decision Tree Analysis

	@Test("Simple decision tree")
	func simpleDecisionTree() throws {
		// Decision: Expand or Don't Expand
		let expandOutcome = Outcome(
			probability: 0.6,
			value: 2_000_000,
			cost: 500_000
		)

		let noExpandOutcome = Outcome(
			probability: 0.4,
			value: 800_000,
			cost: 0
		)

		let decision = DecisionNode(
			name: "Expansion Decision",
			outcomes: [expandOutcome, noExpandOutcome]
		)

		let expectedValue = decision.expectedValue()

		// EV = 0.6 * (2M - 500k) + 0.4 * 800k
		let expectedEV = 0.6 * 1_500_000 + 0.4 * 800_000
		#expect(abs(expectedValue - expectedEV) < 1.0)
	}

	@Test("Multi-stage decision tree")
	func multiStageDecisionTree() throws {
		// Stage 1: Market Research (Year 0)
		// Stage 2: Product Launch Decision (Year 1)
		// Stage 3: Expansion Decision (Year 2)

		let successfulLaunch = Outcome(
			probability: 0.7,
			value: 3_000_000,
			cost: 1_000_000
		)

		let failedLaunch = Outcome(
			probability: 0.3,
			value: 200_000,
			cost: 1_000_000
		)

		let launchDecision = DecisionNode(
			name: "Launch",
			outcomes: [successfulLaunch, failedLaunch],
			discountRate: 0.08,
			timeToDecision: 1.0
		)

		let expectedValue = launchDecision.expectedValue()

		// Should account for probabilities and costs
		#expect(expectedValue > 0)
		#expect(expectedValue < 3_000_000)
	}

	@Test("Decision tree optimal path")
	func decisionTreeOptimalPath() throws {
		let highRiskHighReturn = Outcome(
			probability: 0.4,
			value: 5_000_000,
			cost: 2_000_000
		)

		let lowRiskLowReturn = Outcome(
			probability: 0.8,
			value: 2_000_000,
			cost: 500_000
		)

		let decision = DecisionNode(
			name: "Investment Strategy",
			outcomes: [highRiskHighReturn, lowRiskLowReturn]
		)

		let optimal = decision.optimalChoice()

		// Should select based on expected value
		#expect(optimal != nil)
		#expect(optimal!.name == "High Risk" || optimal!.name == "Low Risk")
	}

	// MARK: - Switch Options

	@Test("Value switching option")
	func switchingOption() throws {
		// Option to switch between two production modes
		let option = SwitchOption<Double>(
			mode1Value: 1_000_000,
			mode2Value: 800_000,
			switchingCost: 100_000,
			timeToDecision: 1.0,
			volatility: 0.25,
			riskFreeRate: 0.05
		)

		let value = option.value()

		// Switching option should have positive value
		#expect(value > 0)
	}

	// MARK: - Real Options Portfolio

	@Test("Portfolio of real options")
	func realOptionsPortfolio() throws {
		let expansion = ExpansionOption<Double>(
			baseProjectNPV: 1_000_000,
			expansionCost: 500_000,
			expansionMultiplier: 1.5,
			timeToDecision: 2.0,
			volatility: 0.30,
			riskFreeRate: 0.05
		)

		let abandonment = AbandonmentOption<Double>(
			projectNPV: 1_000_000,
			salvageValue: 600_000,
			timeToDecision: 2.0,
			volatility: 0.30,
			riskFreeRate: 0.05
		)

		let portfolio = RealOptionsPortfolio<Double>(
			baseProjectNPV: 1_000_000,
			options: [expansion, abandonment]
		)

		let totalValue = portfolio.totalValue()

		// Total should be base + option values
		#expect(totalValue > 1_000_000)
	}

	// MARK: - Sensitivity Analysis

	@Test("Sensitivity to volatility")
	func sensitivityVolatility() throws {
		let baseOption = ExpansionOption<Double>(
			baseProjectNPV: 1_000_000,
			expansionCost: 500_000,
			expansionMultiplier: 1.5,
			timeToDecision: 2.0,
			volatility: 0.30,
			riskFreeRate: 0.05
		)

		let sensitivity = baseOption.sensitivityToVolatility(range: 0.10...0.50, steps: 5)

		// Should return values for different volatility levels
		#expect(sensitivity.count == 5)

		// Values should increase with volatility
		for i in 1..<sensitivity.count {
			#expect(sensitivity[i].value >= sensitivity[i-1].value)
		}
	}

	@Test("Sensitivity to time")
	func sensitivityTime() throws {
		let baseOption = DelayOption<Double>(
			immediateNPV: 800_000,
			maxDelayYears: 3.0,
			volatility: 0.30,
			riskFreeRate: 0.05,
			costOfDelay: 0.02
		)

		let sensitivity = baseOption.sensitivityToTime(range: 1.0...5.0, steps: 5)

		// Should return values for different time horizons
		#expect(sensitivity.count == 5)

		// Longer time generally increases option value
		#expect(sensitivity.last!.value > sensitivity.first!.value)
	}
}

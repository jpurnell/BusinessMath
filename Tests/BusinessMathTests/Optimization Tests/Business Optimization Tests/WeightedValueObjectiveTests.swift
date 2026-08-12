//
//  WeightedValueObjectiveTests.swift
//  BusinessMath
//
//  `.maximizeWeightedValue(strategicWeight:)` blended an unnormalised dollar
//  figure with a 0–10 strategic score by writing
//  `(1 - w) * expectedValue + w * strategicValue`. Those two terms are not in the
//  same units, so `w` did not set the balance between them — the magnitude of the
//  currency did. At NPVs in the hundreds of thousands, `w = 0.999` still ranked
//  purely on money; expressed in millions the same call ranked purely on strategy.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Resource Allocation: Weighted Value Objective")
struct WeightedValueObjectiveTests {

	/// Two projects that cost the same and fit the budget only one at a time.
	/// One is worth ten times more in money; the other scores ten times higher
	/// on strategy. Which one wins is exactly what `strategicWeight` is for.
	private static func rivalProjects(scale: Double) -> [AllocationOption] {
		[
			AllocationOption(
				id: "cash_cow",
				name: "High financial, low strategic",
				expectedValue: 1_000_000 * scale,
				resourceRequirements: ["budget": 100_000 * scale],
				strategicValue: 1.0
			),
			AllocationOption(
				id: "platform",
				name: "Low financial, high strategic",
				expectedValue: 100_000 * scale,
				resourceRequirements: ["budget": 100_000 * scale],
				strategicValue: 10.0
			)
		]
	}

	private static func allocate(
		scale: Double,
		strategicWeight: Double
	) throws -> [String: Double] {
		let options = rivalProjects(scale: scale)
		let optimizer = ResourceAllocationOptimizer()
		let result = try optimizer.optimize(
			options: options,
			objective: .maximizeWeightedValue(strategicWeight: strategicWeight),
			constraints: [.totalBudget(100_000 * scale)]
		)
		return result.allocations
	}

	// MARK: - The weight has to mean something

	@Test("A strategic weight near 1 ranks on strategy")
	func highWeightRanksOnStrategy() throws {
		let allocations = try Self.allocate(scale: 1.0, strategicWeight: 0.9)

		#expect(
			(allocations["platform"] ?? 0) > (allocations["cash_cow"] ?? 0),
			"w = 0.9 funded the money project \(allocations)"
		)
	}

	@Test("A strategic weight near 0 ranks on money")
	func lowWeightRanksOnMoney() throws {
		let allocations = try Self.allocate(scale: 1.0, strategicWeight: 0.1)

		#expect(
			(allocations["cash_cow"] ?? 0) > (allocations["platform"] ?? 0),
			"w = 0.1 funded the strategic project \(allocations)"
		)
	}

	// MARK: - And it has to mean the same thing in any currency unit

	/// The same two projects, the same budget, the same weight — stated in dollars
	/// and then in millions. A weight that blends two normalised criteria gives the
	/// same answer; a weight that adds dollars to a score gives whichever answer the
	/// unit happens to favour.
	@Test("The same weight picks the same project in dollars and in millions")
	func weightIsInvariantToCurrencyScale() throws {
		for weight in [0.1, 0.5, 0.9] {
			let inDollars = try Self.allocate(scale: 1.0, strategicWeight: weight)
			let inMillions = try Self.allocate(scale: 1.0 / 1_000_000, strategicWeight: weight)

			let dollarsPickedPlatform = (inDollars["platform"] ?? 0) > (inDollars["cash_cow"] ?? 0)
			let millionsPickedPlatform = (inMillions["platform"] ?? 0) > (inMillions["cash_cow"] ?? 0)

			#expect(
				dollarsPickedPlatform == millionsPickedPlatform,
				"w = \(weight): dollars \(inDollars) vs millions \(inMillions)"
			)
		}
	}

	// MARK: - The reported total stays in money

	/// Normalising the ranking criteria must not change what `totalValue` means:
	/// it is still the expected value actually bought, in the caller's own units.
	@Test("Total value is still reported in the caller's currency")
	func totalValueRemainsInCurrency() throws {
		let options = Self.rivalProjects(scale: 1.0)
		let optimizer = ResourceAllocationOptimizer()
		let result = try optimizer.optimize(
			options: options,
			objective: .maximizeWeightedValue(strategicWeight: 0.9),
			constraints: [.totalBudget(100_000)]
		)

		let expected = result.selectedOptions.reduce(0.0) { sum, option in
			sum + option.expectedValue * (result.allocations[option.id] ?? 0)
		}
		#expect(abs(result.totalValue - expected) < 1e-6)
		#expect(result.totalValue > 1_000, "a dollar total, not a normalised score")
	}
}

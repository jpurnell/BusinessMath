import Foundation
import Testing
@testable import BusinessMath

@Suite("EOQModel")
struct EOQModelTests {

	// MARK: - Golden path

	@Test("EOQ golden path: Q* = √(2SD/H) ≈ 50")
	func eoqGoldenPath() throws {
		// Standard operations textbook Problem 1:
		// D = 936 units/year, S = $10/order, H = ic = 0.15 × $50 = $7.50/unit/year
		// Q* = √(2 × 10 × 936 / 7.50) = √2496 ≈ 49.96 ≈ 50
		let result = try EOQModel<Double>.calculate(
			annualDemand: 936.0,
			orderingCost: 10.0,
			holdingCostPerUnit: 7.50
		)
		// √2496, to the last bit a Double carries. The band was ±0.1 on a quantity of 50 —
		// a 0.2% window, which cannot tell a correct Q* from one computed with the 2 or the
		// division misplaced.
		#expect(abs(result.orderQuantity - 49.95998398718719) < 1e-12,
				"Q* was \(result.orderQuantity)")
	}

	@Test("EOQ second example: Q* ≈ 632")
	func eoqSecondExample() throws {
		// D = 5000 frames/year, S = $10,000/order, H = $250/unit/year
		// Q* = √(2 × 10000 × 5000 / 250) = √400000 ≈ 632.46
		let result = try EOQModel<Double>.calculate(
			annualDemand: 5000.0,
			orderingCost: 10000.0,
			holdingCostPerUnit: 250.0
		)
		#expect(abs(result.orderQuantity - 632.4555320336759) < 1e-12,
				"Q* was \(result.orderQuantity)")
	}

	// MARK: - Cost decomposition

	@Test("At Q*, ordering cost ≈ holding cost")
	func orderingEqualsHoldingAtOptimal() throws {
		let result = try EOQModel<Double>.calculate(
			annualDemand: 936.0,
			orderingCost: 10.0,
			holdingCostPerUnit: 7.50
		)
		// **This is the optimality condition itself, and it is an identity, not an
		// approximation.** Setting dTC/dQ = 0 is exactly what makes SD/Q equal HQ/2, so the
		// two costs are equal at Q* by construction. The old ±1.0 window admitted a Q* off
		// by about 1.3% — it could not distinguish the optimum from a neighbourhood of it.
		//
		// Both sides are 187.34993995195194 on this fixture.
		let ordering: Double = result.annualOrderingCost
		let holding: Double = result.annualHoldingCost
		let scale: Double = Swift.max(abs(ordering), abs(holding))
		#expect(abs(ordering - holding) <= 1e-12 * scale,
				"at Q* ordering \(ordering) must equal holding \(holding)")
		#expect(abs(ordering - 187.34993995195194) < 1e-12, "ordering was \(ordering)")
	}

	@Test("Total cost calculation matches hand computation")
	func totalCostCalculation() throws {
		// TC = SD/Q + HQ/2 = (936/50)×10 + (7.50×50)/2 = 187.2 + 187.5 = 374.7
		let tc = EOQModel<Double>.totalCost(
			orderQuantity: 50.0,
			annualDemand: 936.0,
			orderingCost: 10.0,
			holdingCostPerUnit: 7.50
		)
		#expect(abs(tc - 374.7) < 1e-12, "total cost was \(tc)")
	}

	@Test("Total cost with unit cost: TC = SD/Q + HQ/2 + cD")
	func totalCostWithUnitCost() throws {
		// TC = 187.2 + 187.5 + 50×936 = 374.7 + 46800 = 47174.7
		let tc = EOQModel<Double>.totalCost(
			orderQuantity: 50.0,
			annualDemand: 936.0,
			orderingCost: 10.0,
			holdingCostPerUnit: 7.50,
			unitCost: 50.0
		)
		#expect(abs(tc - 47174.7) < 1e-9, "total cost was \(tc)")
	}

	// MARK: - Optimality property

	@Test("Q* minimizes total cost: TC(Q*) ≤ TC(Q*±1)")
	func optimalityProperty() throws {
		let result = try EOQModel<Double>.calculate(
			annualDemand: 936.0,
			orderingCost: 10.0,
			holdingCostPerUnit: 7.50
		)

		// A ±1 bracket on a Q* near 50 is a 2% window. The cost curve is convex, so the
		// honest claim is that Q* is the minimum of a *grid* around it — same cost to
		// evaluate, and it fails for a Q* off by any amount that matters.
		func totalCost(at quantity: Double) -> Double {
			EOQModel<Double>.totalCost(
				orderQuantity: quantity,
				annualDemand: 936.0,
				orderingCost: 10.0,
				holdingCostPerUnit: 7.50
			)
		}

		let optimum: Double = result.orderQuantity
		let costAtOptimal: Double = totalCost(at: optimum)

		for offset in [1.0, 2.0, 5.0, 10.0] {
			let above: Double = totalCost(at: optimum + offset)
			let below: Double = totalCost(at: optimum - offset)
			#expect(costAtOptimal <= above,
					"TC(\(optimum)) = \(costAtOptimal) should not exceed TC(+\(offset)) = \(above)")
			#expect(costAtOptimal <= below,
					"TC(\(optimum)) = \(costAtOptimal) should not exceed TC(-\(offset)) = \(below)")
		}
	}

	// MARK: - Derived fields

	@Test("Orders per year and days between orders")
	func derivedFields() throws {
		let result = try EOQModel<Double>.calculate(
			annualDemand: 936.0,
			orderingCost: 10.0,
			holdingCostPerUnit: 7.50
		)
		// D/Q*, exactly rather than to half an order.
		#expect(abs(result.ordersPerYear - 18.734993995195193) < 1e-12,
				"orders/year was \(result.ordersPerYear)")
		// 365 / ordersPerYear. The 365 is an ordering cadence, not an accrual — see the
		// convention note at `EOQModel.calculate`.
		#expect(abs(result.daysBetweenOrders - 19.48225871295227) < 1e-12,
				"days between orders was \(result.daysBetweenOrders)")
	}

	// MARK: - Edge cases

	@Test("Rejects zero annual demand")
	func rejectsZeroDemand() throws {
		// By case, not by type: a zero-demand error and a negative-cost error are
		// different bugs and `OperationsError.self` cannot tell them apart. The case is
		// matched rather than compared because `OperationsError` is not `Equatable`, and
		// making it so to suit a test is the wrong direction of change.
		let thrown = #expect(throws: OperationsError.self) {
			_ = try EOQModel<Double>.calculate(
				annualDemand: 0.0,
				orderingCost: 10.0,
				holdingCostPerUnit: 7.50
			)
		}
		guard case .zeroDemand? = thrown else {
			Issue.record("expected .zeroDemand, got \(String(describing: thrown))")
			return
		}
	}

	@Test("Rejects negative ordering cost")
	func rejectsNegativeOrderingCost() throws {
		let thrown = #expect(throws: OperationsError.self) {
			_ = try EOQModel<Double>.calculate(
				annualDemand: 936.0,
				orderingCost: -10.0,
				holdingCostPerUnit: 7.50
			)
		}
		guard case .negativeCost? = thrown else {
			Issue.record("expected .negativeCost, got \(String(describing: thrown))")
			return
		}
	}

	@Test("Rejects zero holding cost")
	func rejectsZeroHoldingCost() throws {
		let thrown = #expect(throws: OperationsError.self) {
			_ = try EOQModel<Double>.calculate(
				annualDemand: 936.0,
				orderingCost: 10.0,
				holdingCostPerUnit: 0.0
			)
		}
		guard case .negativeCost? = thrown else {
			Issue.record("expected .negativeCost, got \(String(describing: thrown))")
			return
		}
	}

	@Test("Handles extreme inputs without overflow")
	func extremeInputs() throws {
		let result = try EOQModel<Double>.calculate(
			annualDemand: 1e12,
			orderingCost: 1e6,
			holdingCostPerUnit: 0.01
		)
		// √(2 × 1e6 × 1e12 / 0.01). The intermediate 2SD is 2e18, comfortably inside
		// Double's range, so this case was never at risk of overflow — asserting only
		// finiteness tested nothing about the thing it was named for.
		#expect(abs(result.orderQuantity - 1.4142135623730951e10) < 1e-2,
				"Q* was \(result.orderQuantity)")
	}

	@Test("The case that would actually overflow: 2SD beyond Double's range")
	func overflowSafety() throws {
		// This is the test `extremeInputs` was named for. At D = S = 1e200 the product
		// 2SD is 2e400 — **infinity in a Double** — so a naive √(2SD/H) returns infinity
		// while √(2S/H)·√D does not. The distinction is the whole of numerical stability
		// here, and nothing in this file exercised it.
		let result = try EOQModel<Double>.calculate(
			annualDemand: 1e200,
			orderingCost: 1e200,
			holdingCostPerUnit: 1.0
		)
		#expect(result.orderQuantity.isFinite,
				"Q* overflowed to \(result.orderQuantity); 2SD must not be formed directly")
		// √(2 × 1e200 × 1e200 / 1) = √2 × 1e200.
		let expected: Double = (2.0 as Double).squareRoot() * 1e200
		let relative: Double = abs(result.orderQuantity - expected) / expected
		#expect(relative < 1e-12, "Q* was \(result.orderQuantity), expected \(expected)")
	}
}

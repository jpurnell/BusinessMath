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
		#expect(abs(result.orderQuantity - 49.96) < 0.1, "Q* should be approximately 50")
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
		#expect(abs(result.orderQuantity - 632.46) < 0.1, "Q* should be approximately 632")
	}

	// MARK: - Cost decomposition

	@Test("At Q*, ordering cost ≈ holding cost")
	func orderingEqualsHoldingAtOptimal() throws {
		let result = try EOQModel<Double>.calculate(
			annualDemand: 936.0,
			orderingCost: 10.0,
			holdingCostPerUnit: 7.50
		)
		#expect(abs(result.annualOrderingCost - result.annualHoldingCost) < 1.0,
			"At EOQ, ordering cost should approximately equal holding cost")
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
		#expect(abs(tc - 374.7) < 1.0, "Total cost should be approximately $374.70")
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
		#expect(abs(tc - 47174.7) < 1.0, "Total cost with unit cost should match")
	}

	// MARK: - Optimality property

	@Test("Q* minimizes total cost: TC(Q*) ≤ TC(Q*±1)")
	func optimalityProperty() throws {
		let result = try EOQModel<Double>.calculate(
			annualDemand: 936.0,
			orderingCost: 10.0,
			holdingCostPerUnit: 7.50
		)

		let costAtOptimal = EOQModel<Double>.totalCost(
			orderQuantity: result.orderQuantity,
			annualDemand: 936.0,
			orderingCost: 10.0,
			holdingCostPerUnit: 7.50
		)
		let costAbove = EOQModel<Double>.totalCost(
			orderQuantity: result.orderQuantity + 1.0,
			annualDemand: 936.0,
			orderingCost: 10.0,
			holdingCostPerUnit: 7.50
		)
		let costBelow = EOQModel<Double>.totalCost(
			orderQuantity: result.orderQuantity - 1.0,
			annualDemand: 936.0,
			orderingCost: 10.0,
			holdingCostPerUnit: 7.50
		)

		#expect(costAtOptimal <= costAbove, "Q* should minimize total cost")
		#expect(costAtOptimal <= costBelow, "Q* should minimize total cost")
	}

	// MARK: - Derived fields

	@Test("Orders per year and days between orders")
	func derivedFields() throws {
		let result = try EOQModel<Double>.calculate(
			annualDemand: 936.0,
			orderingCost: 10.0,
			holdingCostPerUnit: 7.50
		)
		// Orders/year = D/Q* = 936/50 ≈ 18.72
		#expect(abs(result.ordersPerYear - 18.72) < 0.5)
		// Days between orders = 365/ordersPerYear ≈ 19.5
		#expect(abs(result.daysBetweenOrders - 19.5) < 1.0)
	}

	// MARK: - Edge cases

	@Test("Rejects zero annual demand")
	func rejectsZeroDemand() {
		#expect(throws: OperationsError.self) {
			_ = try EOQModel<Double>.calculate(
				annualDemand: 0.0,
				orderingCost: 10.0,
				holdingCostPerUnit: 7.50
			)
		}
	}

	@Test("Rejects negative ordering cost")
	func rejectsNegativeOrderingCost() {
		#expect(throws: OperationsError.self) {
			_ = try EOQModel<Double>.calculate(
				annualDemand: 936.0,
				orderingCost: -10.0,
				holdingCostPerUnit: 7.50
			)
		}
	}

	@Test("Rejects zero holding cost")
	func rejectsZeroHoldingCost() {
		#expect(throws: OperationsError.self) {
			_ = try EOQModel<Double>.calculate(
				annualDemand: 936.0,
				orderingCost: 10.0,
				holdingCostPerUnit: 0.0
			)
		}
	}

	@Test("Handles extreme inputs without overflow")
	func extremeInputs() throws {
		let result = try EOQModel<Double>.calculate(
			annualDemand: 1e12,
			orderingCost: 1e6,
			holdingCostPerUnit: 0.01
		)
		#expect(result.orderQuantity.isFinite, "Should handle extreme values")
		#expect(result.orderQuantity > 0, "Q* should be positive")
	}
}

import Foundation
import Testing
@testable import BusinessMath

@Suite("NewsvendorModel")
struct NewsvendorModelTests {

	// MARK: - Critical fractile

	@Test("Critical fractile: p_c = c_u / (c_u + c_o)")
	func criticalFractileGoldenPath() throws {
		// c_u = $5, c_o = $2 → p_c = 5/7 ≈ 0.7143
		let pc = try NewsvendorModel<Double>.criticalFractile(
			underageCost: 5.0,
			overageCost: 2.0
		)
		#expect(abs(pc - 5.0 / 7.0) < 0.001, "p_c = c_u/(c_u+c_o) = 5/7")
	}

	@Test("Critical fractile with equal costs → 0.5")
	func criticalFractileEqualCosts() throws {
		let pc = try NewsvendorModel<Double>.criticalFractile(
			underageCost: 10.0,
			overageCost: 10.0
		)
		#expect(abs(pc - 0.5) < 0.001, "Equal costs → p_c = 0.5")
	}

	@Test("Critical fractile always in (0, 1)")
	func criticalFractileRange() throws {
		for cu in [1.0, 5.0, 100.0, 0.01] {
			for co in [1.0, 5.0, 100.0, 0.01] {
				let pc = try NewsvendorModel<Double>.criticalFractile(
					underageCost: cu,
					overageCost: co
				)
				#expect(pc > 0 && pc < 1, "p_c must be in (0,1) for cu=\(cu), co=\(co)")
			}
		}
	}

	@Test("Critical fractile rejects negative costs")
	func criticalFractileRejectsNegative() {
		#expect(throws: OperationsError.self) {
			_ = try NewsvendorModel<Double>.criticalFractile(
				underageCost: -1.0,
				overageCost: 2.0
			)
		}
		#expect(throws: OperationsError.self) {
			_ = try NewsvendorModel<Double>.criticalFractile(
				underageCost: 5.0,
				overageCost: -1.0
			)
		}
	}

	@Test("Critical fractile rejects zero costs")
	func criticalFractileRejectsZero() {
		#expect(throws: OperationsError.self) {
			_ = try NewsvendorModel<Double>.criticalFractile(
				underageCost: 0.0,
				overageCost: 2.0
			)
		}
		#expect(throws: OperationsError.self) {
			_ = try NewsvendorModel<Double>.criticalFractile(
				underageCost: 5.0,
				overageCost: 0.0
			)
		}
	}

	// MARK: - Optimal quantity (normal distribution)

	@Test("Watermelon example: μ=40, σ=18, c_u=1, c_o=0.5, Q*≈48")
	func optimalQuantityWatermelon() throws {
		// p_c = 1/(1+0.5) = 0.667, z* = NORMSINV(0.667) ≈ 0.431
		// Q* = 40 + 0.431 × 18 ≈ 47.75 ≈ 48
		let result = try NewsvendorModel<Double>.optimalQuantity(
			meanDemand: 40.0,
			demandStdDev: 18.0,
			underageCost: 1.0,
			overageCost: 0.5
		)
		#expect(abs(result.optimalQuantity - 47.75) < 1.0, "Q* should be approximately 48")
		#expect(abs(result.criticalFractile - 0.667) < 0.01)
	}

	@Test("High-margin item: c_u >> c_o → stock more")
	func highMarginStockMore() throws {
		// c_u = 50, c_o = 1 → p_c ≈ 0.98 → stock well above mean
		let result = try NewsvendorModel<Double>.optimalQuantity(
			meanDemand: 100.0,
			demandStdDev: 25.0,
			underageCost: 50.0,
			overageCost: 1.0
		)
		#expect(result.optimalQuantity > 100.0, "High cu/co ratio → stock above mean")
		#expect(result.serviceLevel > 0.95, "Implied service level should be high")
	}

	@Test("Low-margin item: c_u << c_o → stock less")
	func lowMarginStockLess() throws {
		// c_u = 1, c_o = 50 → p_c ≈ 0.02 → stock well below mean
		let result = try NewsvendorModel<Double>.optimalQuantity(
			meanDemand: 100.0,
			demandStdDev: 25.0,
			underageCost: 1.0,
			overageCost: 50.0
		)
		#expect(result.optimalQuantity < 100.0, "Low cu/co ratio → stock below mean")
		#expect(result.serviceLevel < 0.05, "Implied service level should be low")
	}

	@Test("Optimal quantity = μ + z* × σ matches NORMINV")
	func optimalQuantityMatchesNormInv() throws {
		let result = try NewsvendorModel<Double>.optimalQuantity(
			meanDemand: 100.0,
			demandStdDev: 25.0,
			underageCost: 5.0,
			overageCost: 1.0
		)
		// p_c = 5/6 ≈ 0.8333, z* = NORMSINV(0.8333) ≈ 0.9674
		// Q* = 100 + 0.9674 × 25 ≈ 124.18
		#expect(abs(result.optimalQuantity - 124.18) < 1.0)
	}

	// MARK: - Expected profit

	@Test("Expected profit calculation")
	func expectedProfitCalculation() throws {
		let profit = NewsvendorModel<Double>.expectedProfit(
			quantity: 48.0,
			meanDemand: 40.0,
			demandStdDev: 18.0,
			sellingPrice: 1.50,
			unitCost: 0.50,
			salvageValue: 0.0
		)
		#expect(profit.isFinite, "Expected profit should be finite")
		#expect(profit > 0, "Expected profit should be positive for reasonable stocking level")
	}

	@Test("Expected profit with zero quantity is zero")
	func expectedProfitZeroQuantity() throws {
		let profit = NewsvendorModel<Double>.expectedProfit(
			quantity: 0.0,
			meanDemand: 40.0,
			demandStdDev: 18.0,
			sellingPrice: 1.50,
			unitCost: 0.50,
			salvageValue: 0.0
		)
		#expect(abs(profit) < 0.01, "Zero stock → zero profit")
	}

	// MARK: - Edge cases

	@Test("Very small std dev → Q* ≈ μ")
	func smallStdDev() throws {
		let result = try NewsvendorModel<Double>.optimalQuantity(
			meanDemand: 100.0,
			demandStdDev: 0.001,
			underageCost: 5.0,
			overageCost: 2.0
		)
		#expect(abs(result.optimalQuantity - 100.0) < 1.0,
			"Negligible variability → Q* ≈ mean demand")
	}

	@Test("Rejects negative underage cost")
	func rejectsNegativeUnderageCost() {
		#expect(throws: OperationsError.self) {
			_ = try NewsvendorModel<Double>.optimalQuantity(
				meanDemand: 100.0,
				demandStdDev: 25.0,
				underageCost: -5.0,
				overageCost: 2.0
			)
		}
	}
}

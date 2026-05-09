import Foundation
import Testing
@testable import BusinessMath

@Suite("SafetyStockModel")
struct SafetyStockModelTests {

	// MARK: - z-score conversion

	@Test("z-score for 95% service level matches NORMSINV(0.95)")
	func zScoreAt95Percent() throws {
		let z = try SafetyStockModel<Double>.zScore(for: 0.95)
		#expect(abs(z - 1.6449) < 0.001, "NORMSINV(0.95) = 1.6449")
	}

	@Test("z-score for 99% service level matches NORMSINV(0.99)")
	func zScoreAt99Percent() throws {
		let z = try SafetyStockModel<Double>.zScore(for: 0.99)
		#expect(abs(z - 2.3263) < 0.001, "NORMSINV(0.99) = 2.3263")
	}

	@Test("z-score for 50% service level is approximately zero")
	func zScoreAt50Percent() throws {
		let z = try SafetyStockModel<Double>.zScore(for: 0.50)
		#expect(abs(z) < 0.01, "NORMSINV(0.50) = 0")
	}

	@Test("z-score rejects invalid service levels")
	func zScoreRejectsInvalid() {
		#expect(throws: OperationsError.self) {
			_ = try SafetyStockModel<Double>.zScore(for: 0.0)
		}
		#expect(throws: OperationsError.self) {
			_ = try SafetyStockModel<Double>.zScore(for: 1.0)
		}
		#expect(throws: OperationsError.self) {
			_ = try SafetyStockModel<Double>.zScore(for: -0.1)
		}
		#expect(throws: OperationsError.self) {
			_ = try SafetyStockModel<Double>.zScore(for: 1.5)
		}
	}

	// MARK: - Demand-only method

	@Test("Demand-only safety stock: SS = z × σ_d × √L")
	func demandOnlyGoldenPath() throws {
		// Hand calculation: z(0.95) ≈ 1.6449, σ=5, L=7
		// SS = 1.6449 × 5 × √7 ≈ 1.6449 × 5 × 2.6458 ≈ 21.76
		let ss = try SafetyStockModel<Double>.safetyStock(
			method: .demandOnly,
			serviceLevel: 0.95,
			averageDemand: 10.0,
			demandStdDev: 5.0,
			leadTime: 7.0
		)
		#expect(abs(ss - 21.76) < 0.1, "SS should be approximately 21.76")
	}

	@Test("Demand-only safety stock increases with service level")
	func demandOnlyMonotonicInServiceLevel() throws {
		var previousSS = 0.0
		for sl in [0.50, 0.80, 0.90, 0.95, 0.99] {
			let ss = try SafetyStockModel<Double>.safetyStock(
				method: .demandOnly,
				serviceLevel: sl,
				averageDemand: 10.0,
				demandStdDev: 5.0,
				leadTime: 7.0
			)
			#expect(ss >= previousSS, "SS should increase with service level")
			previousSS = ss
		}
	}

	@Test("Demand-only with zero std dev yields zero safety stock")
	func demandOnlyZeroVariability() throws {
		let ss = try SafetyStockModel<Double>.safetyStock(
			method: .demandOnly,
			serviceLevel: 0.95,
			averageDemand: 10.0,
			demandStdDev: 0.0,
			leadTime: 7.0
		)
		#expect(abs(ss) < 1e-10, "Zero demand variability → zero safety stock")
	}

	// MARK: - Demand and lead time method

	@Test("Demand+LT safety stock: SS = z × √(L×σ_d² + d̄²×σ_L²)")
	func demandAndLeadTimeGoldenPath() throws {
		// z(0.95) ≈ 1.6449, σ_d=5, L=7, d̄=10, σ_L=2
		// SS = 1.6449 × √(7×25 + 100×4) = 1.6449 × √(175+400) = 1.6449 × √575 ≈ 1.6449 × 23.979 ≈ 39.44
		let ss = try SafetyStockModel<Double>.safetyStock(
			method: .demandAndLeadTime,
			serviceLevel: 0.95,
			averageDemand: 10.0,
			demandStdDev: 5.0,
			leadTime: 7.0,
			leadTimeStdDev: 2.0
		)
		#expect(abs(ss - 39.44) < 0.5, "SS should be approximately 39.44")
	}

	@Test("Demand+LT degenerates to demand-only when σ_L = 0")
	func demandAndLeadTimeDegenerates() throws {
		let ssDemandOnly = try SafetyStockModel<Double>.safetyStock(
			method: .demandOnly,
			serviceLevel: 0.95,
			averageDemand: 10.0,
			demandStdDev: 5.0,
			leadTime: 7.0
		)
		let ssDemandAndLT = try SafetyStockModel<Double>.safetyStock(
			method: .demandAndLeadTime,
			serviceLevel: 0.95,
			averageDemand: 10.0,
			demandStdDev: 5.0,
			leadTime: 7.0,
			leadTimeStdDev: 0.0
		)
		#expect(abs(ssDemandOnly - ssDemandAndLT) < 0.01,
			"With σ_L=0, demandAndLeadTime should equal demandOnly")
	}

	@Test("Demand+LT always ≥ demand-only when σ_L > 0")
	func demandAndLeadTimeAlwaysLarger() throws {
		let ssDemandOnly = try SafetyStockModel<Double>.safetyStock(
			method: .demandOnly,
			serviceLevel: 0.95,
			averageDemand: 10.0,
			demandStdDev: 5.0,
			leadTime: 7.0
		)
		let ssDemandAndLT = try SafetyStockModel<Double>.safetyStock(
			method: .demandAndLeadTime,
			serviceLevel: 0.95,
			averageDemand: 10.0,
			demandStdDev: 5.0,
			leadTime: 7.0,
			leadTimeStdDev: 2.0
		)
		#expect(ssDemandAndLT >= ssDemandOnly,
			"Lead time variability can only increase safety stock")
	}

	// MARK: - Forecast error method

	@Test("Forecast error method: SS = z × RMSE × √L")
	func forecastErrorGoldenPath() throws {
		// z(0.95) ≈ 1.6449, RMSE=3.0, L=7
		// SS = 1.6449 × 3.0 × √7 ≈ 1.6449 × 3.0 × 2.6458 ≈ 13.06
		let ss = try SafetyStockModel<Double>.safetyStock(
			method: .forecastError,
			serviceLevel: 0.95,
			averageDemand: 10.0,
			demandStdDev: 5.0,
			leadTime: 7.0,
			forecastRMSE: 3.0
		)
		#expect(abs(ss - 13.06) < 0.1, "SS should be approximately 13.06")
	}

	@Test("Forecast error method requires forecastRMSE parameter")
	func forecastErrorRequiresRMSE() {
		#expect(throws: OperationsError.self) {
			_ = try SafetyStockModel<Double>.safetyStock(
				method: .forecastError,
				serviceLevel: 0.95,
				averageDemand: 10.0,
				demandStdDev: 5.0,
				leadTime: 7.0
			)
		}
	}

	// MARK: - Edge cases and fault injection

	@Test("Rejects zero demand")
	func rejectsZeroDemand() {
		#expect(throws: OperationsError.self) {
			_ = try SafetyStockModel<Double>.safetyStock(
				method: .demandOnly,
				serviceLevel: 0.95,
				averageDemand: 0.0,
				demandStdDev: 0.0,
				leadTime: 7.0
			)
		}
	}

	@Test("Handles very high service level (0.999)")
	func veryHighServiceLevel() throws {
		let ss = try SafetyStockModel<Double>.safetyStock(
			method: .demandOnly,
			serviceLevel: 0.999,
			averageDemand: 10.0,
			demandStdDev: 5.0,
			leadTime: 7.0
		)
		#expect(ss > 0, "Safety stock should be positive")
		#expect(ss.isFinite, "Safety stock should be finite")
	}

	@Test("Handles service level near 0.5 (z ≈ 0)")
	func serviceLevelNear50() throws {
		let ss = try SafetyStockModel<Double>.safetyStock(
			method: .demandOnly,
			serviceLevel: 0.50001,
			averageDemand: 10.0,
			demandStdDev: 5.0,
			leadTime: 7.0
		)
		#expect(abs(ss) < 0.1, "At 50% service level, safety stock ≈ 0")
	}

	@Test("Works with large demand values")
	func largeDemandValues() throws {
		let ss = try SafetyStockModel<Double>.safetyStock(
			method: .demandOnly,
			serviceLevel: 0.95,
			averageDemand: 1e9,
			demandStdDev: 1e7,
			leadTime: 7.0
		)
		#expect(ss.isFinite, "Should handle large values without overflow")
		#expect(ss > 0, "Safety stock should be positive")
	}
}

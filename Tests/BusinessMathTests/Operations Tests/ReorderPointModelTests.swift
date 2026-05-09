import Foundation
import Testing
@testable import BusinessMath

@Suite("ReorderPointModel")
struct ReorderPointModelTests {

	// MARK: - Golden path

	@Test("Reorder point: r = d̄ × L + SS")
	func reorderPointGoldenPath() throws {
		// d̄=10, L=7, z(0.95)=1.6449, σ_d=5
		// SS = 1.6449 × 5 × √7 ≈ 21.76
		// r = 10×7 + 21.76 = 91.76
		let result = try ReorderPointModel<Double>.calculate(
			demandHistory: Array(repeating: 10.0, count: 30),
			leadTime: 7.0,
			serviceLevel: 0.95
		)
		// With constant demand, σ_d ≈ 0, so reorder point ≈ d̄ × L = 70
		#expect(abs(result.reorderPoint - 70.0) < 1.0,
			"Constant demand → reorder point ≈ d̄ × L")
		#expect(abs(result.safetyStock) < 1.0,
			"Constant demand → safety stock ≈ 0")
		#expect(abs(result.averageDailyDemand - 10.0) < 0.01)
	}

	@Test("Reorder point with variable demand")
	func reorderPointVariableDemand() throws {
		let demand = [8.0, 12.0, 9.0, 11.0, 10.0, 13.0, 7.0, 10.0, 14.0, 6.0,
					  11.0, 9.0, 12.0, 8.0, 10.0, 11.0, 9.0, 13.0, 7.0, 10.0,
					  12.0, 8.0, 11.0, 9.0, 10.0, 13.0, 7.0, 11.0, 9.0, 10.0]
		let result = try ReorderPointModel<Double>.calculate(
			demandHistory: demand,
			leadTime: 7.0,
			serviceLevel: 0.95
		)
		#expect(result.reorderPoint > result.demandDuringLeadTime,
			"Reorder point should exceed expected demand during lead time (service level > 0.5)")
		#expect(result.safetyStock > 0,
			"Variable demand should produce positive safety stock")
		#expect(result.method == .demandOnly)
	}

	@Test("Reorder point with lead time variability")
	func reorderPointWithLeadTimeVariability() throws {
		let demand = [8.0, 12.0, 9.0, 11.0, 10.0, 13.0, 7.0, 10.0, 14.0, 6.0,
					  11.0, 9.0, 12.0, 8.0, 10.0, 11.0, 9.0, 13.0, 7.0, 10.0,
					  12.0, 8.0, 11.0, 9.0, 10.0, 13.0, 7.0, 11.0, 9.0, 10.0]
		let resultDemandOnly = try ReorderPointModel<Double>.calculate(
			demandHistory: demand,
			leadTime: 7.0,
			serviceLevel: 0.95
		)
		let resultWithLT = try ReorderPointModel<Double>.calculate(
			demandHistory: demand,
			leadTime: 7.0,
			serviceLevel: 0.95,
			leadTimeStdDev: 2.0,
			method: .demandAndLeadTime
		)
		#expect(resultWithLT.reorderPoint > resultDemandOnly.reorderPoint,
			"Lead time variability should increase reorder point")
		#expect(resultWithLT.method == .demandAndLeadTime)
	}

	// MARK: - Stockout probability

	@Test("Stockout probability with ample stock is low")
	func stockoutProbabilityAmpleStock() {
		let prob = ReorderPointModel<Double>.stockoutProbability(
			currentStock: 500.0,
			averageDemand: 10.0,
			demandStdDev: 5.0,
			leadTime: 7.0
		)
		#expect(prob < 0.01, "500 units vs 70 expected demand → very low stockout risk")
	}

	@Test("Stockout probability with low stock is high")
	func stockoutProbabilityLowStock() {
		let prob = ReorderPointModel<Double>.stockoutProbability(
			currentStock: 20.0,
			averageDemand: 10.0,
			demandStdDev: 5.0,
			leadTime: 7.0
		)
		#expect(prob > 0.5, "20 units vs 70 expected demand → high stockout risk")
	}

	@Test("Stockout probability is 0.5 when stock = mean demand during lead time")
	func stockoutProbabilityAtMean() {
		let prob = ReorderPointModel<Double>.stockoutProbability(
			currentStock: 70.0,
			averageDemand: 10.0,
			demandStdDev: 5.0,
			leadTime: 7.0
		)
		#expect(abs(prob - 0.5) < 0.05, "Stock at mean → ~50% stockout probability")
	}

	@Test("Stockout probability with lead time variability")
	func stockoutProbabilityWithLeadTimeVar() {
		let probDemandOnly = ReorderPointModel<Double>.stockoutProbability(
			currentStock: 100.0,
			averageDemand: 10.0,
			demandStdDev: 5.0,
			leadTime: 7.0
		)
		let probWithLT = ReorderPointModel<Double>.stockoutProbability(
			currentStock: 100.0,
			averageDemand: 10.0,
			demandStdDev: 5.0,
			leadTime: 7.0,
			leadTimeStdDev: 2.0
		)
		#expect(probWithLT > probDemandOnly,
			"Lead time variability increases stockout risk for the same stock level")
	}

	@Test("Stockout probability with zero std dev is binary")
	func stockoutProbabilityDeterministic() {
		let probSafe = ReorderPointModel<Double>.stockoutProbability(
			currentStock: 71.0,
			averageDemand: 10.0,
			demandStdDev: 0.0,
			leadTime: 7.0
		)
		let probStockout = ReorderPointModel<Double>.stockoutProbability(
			currentStock: 69.0,
			averageDemand: 10.0,
			demandStdDev: 0.0,
			leadTime: 7.0
		)
		#expect(probSafe < 0.01, "Stock above deterministic demand → no stockout")
		#expect(probStockout > 0.99, "Stock below deterministic demand → certain stockout")
	}

	// MARK: - TimeSeries convenience

	@Test("Accepts TimeSeries input")
	func timeSeriesInput() throws {
		let periods = (0..<30).map { i in
			Period.day(Calendar.current.date(byAdding: .day, value: i, to: Date())!)
		}
		let values: [Double] = (0..<30).map { _ in 10.0 }
		let ts = TimeSeries(periods: periods, values: values)

		let result = try ReorderPointModel<Double>.calculate(
			demandTimeSeries: ts,
			leadTime: 7.0,
			serviceLevel: 0.95
		)
		#expect(abs(result.averageDailyDemand - 10.0) < 0.01)
	}

	// MARK: - Edge cases

	@Test("Rejects empty demand history")
	func rejectsEmptyHistory() {
		#expect(throws: OperationsError.self) {
			_ = try ReorderPointModel<Double>.calculate(
				demandHistory: [],
				leadTime: 7.0,
				serviceLevel: 0.95
			)
		}
	}

	@Test("Rejects invalid service level")
	func rejectsInvalidServiceLevel() {
		#expect(throws: OperationsError.self) {
			_ = try ReorderPointModel<Double>.calculate(
				demandHistory: Array(repeating: 10.0, count: 30),
				leadTime: 7.0,
				serviceLevel: 1.5
			)
		}
	}
}

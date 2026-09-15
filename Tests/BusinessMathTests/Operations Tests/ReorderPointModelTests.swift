import Foundation
import Testing
@testable import BusinessMath

@Suite("ReorderPointModel")
struct ReorderPointModelTests {

	// MARK: - Golden path

	@Test("Reorder point: r = d̄ × L + SS")
	func reorderPointGoldenPath() throws {
		// **Constant demand, so σ_d is exactly zero and the safety-stock term vanishes.**
		//
		// The comment that stood here derived `SS = 1.6449 × 5 × √7 ≈ 21.76` and
		// `r = 91.76` from a σ_d of 5 — and then the test passed
		// `Array(repeating: 10.0, count: 30)`, whose σ_d is 0, and asserted r ≈ 70. The
		// assertions were right for the fixture; the arithmetic above them belonged to a
		// series that appears nowhere in this file. A reader met "r = 91.76" directly above
		// an assertion of 70.
		//
		// The degenerate case is worth keeping on its own terms: with no demand
		// variability there is nothing to buffer against, so `r = d̄ · L` and `SS = 0`
		// **exactly**, not approximately. `reorderPointVariableDemand` below carries the
		// variable case.
		let result = try ReorderPointModel<Double>.calculate(
			demandHistory: Array(repeating: 10.0, count: 30),
			leadTime: 7.0,
			serviceLevel: 0.95
		)
		#expect(result.reorderPoint.isEqual(to: 70.0),
			"constant demand gives r = d̄ · L exactly, got \(result.reorderPoint)")
		#expect(result.safetyStock.isEqual(to: 0.0),
			"zero variability leaves no safety stock, got \(result.safetyStock)")
		#expect(result.averageDailyDemand.isEqual(to: 10.0),
			"average daily demand was \(result.averageDailyDemand)")
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
		// The ordering claims are real — a service level above 0.5 must put the reorder
		// point above expected lead-time demand — and they are kept. They are also true of
		// a safety stock that is wrong by a factor of ten, so the values are pinned too.
		#expect(result.reorderPoint > result.demandDuringLeadTime,
			"Reorder point should exceed expected demand during lead time (service level > 0.5)")
		#expect(result.safetyStock > 0,
			"Variable demand should produce positive safety stock")
		#expect(result.method == .demandOnly)

		// Measured on this series: d̄ = 10 exactly, demand during lead time 70 exactly, and
		// a safety stock of 8.8525… from its own σ_d of about 2.04.
		//
		// Note this is **not** the 91.76 the golden-path comment used to quote: that figure
		// comes from σ_d = 5, and no fixture in this file has one. The number was carried
		// from a scenario that was never written down.
		#expect(result.averageDailyDemand.isEqual(to: 10.0),
			"average daily demand was \(result.averageDailyDemand)")
		#expect(result.demandDuringLeadTime.isEqual(to: 70.0),
			"demand during lead time was \(result.demandDuringLeadTime)")
		#expect(abs(result.safetyStock - 8.852540062993311) < 1e-12,
			"safety stock was \(result.safetyStock)")
		#expect(abs(result.reorderPoint - 78.85254006299331) < 1e-12,
			"reorder point was \(result.reorderPoint)")
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
		let periods = try (0..<30).map { i in
			Period.day(try #require(gregorianUTC.date(byAdding: .day, value: i, to: Date())))
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
	func rejectsEmptyHistory() throws {
		#expect {
			_ = try ReorderPointModel<Double>.calculate(
				demandHistory: [],
				leadTime: 7.0,
				serviceLevel: 0.95
			)
		} throws: { error in
			guard case let OperationsError.insufficientData(required, got) = error else { return false }
			return required == 1 && got == 0
		}
	}

	@Test("Rejects invalid service level")
	func rejectsInvalidServiceLevel() throws {
		#expect {
			_ = try ReorderPointModel<Double>.calculate(
				demandHistory: Array(repeating: 10.0, count: 30),
				leadTime: 7.0,
				serviceLevel: 1.5
			)
		} throws: { error in
			guard case OperationsError.invalidServiceLevel = error else { return false }
			return true
		}
	}
}

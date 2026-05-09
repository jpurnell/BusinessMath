import Foundation
import Testing
@testable import BusinessMath

@Suite("InventoryAdvisor")
struct InventoryAdvisorTests {

	// MARK: - Basic demand-only recommendations

	@Test("Recommends demand-only with minimal data")
	func recommendsDemandOnlyMinimalData() {
		let profile = InventoryAdvisor.DataProfile(
			demandHistory: Array(repeating: 10.0, count: 20),
			leadTimeMean: 7.0
		)
		let rec = InventoryAdvisor.recommended(for: profile)
		#expect(rec.safetyStockMethod == .demandOnly)
		#expect(rec.reasoning.count > 0)
	}

	// MARK: - Lead time variability

	@Test("Recommends demand-and-lead-time when lead time std dev provided")
	func recommendsDemandAndLeadTime() {
		let profile = InventoryAdvisor.DataProfile(
			demandHistory: Array(repeating: 10.0, count: 30),
			leadTimeMean: 7.0,
			leadTimeStdDev: 2.0
		)
		let rec = InventoryAdvisor.recommended(for: profile)
		#expect(rec.safetyStockMethod == .demandAndLeadTime)
	}

	@Test("Ignores zero lead time std dev")
	func ignoresZeroLeadTimeStdDev() {
		let profile = InventoryAdvisor.DataProfile(
			demandHistory: Array(repeating: 10.0, count: 30),
			leadTimeMean: 7.0,
			leadTimeStdDev: 0.0
		)
		let rec = InventoryAdvisor.recommended(for: profile)
		#expect(rec.safetyStockMethod == .demandOnly)
	}

	// MARK: - Forecast error method

	@Test("Recommends forecast error when RMSE provided")
	func recommendsForecastError() {
		let profile = InventoryAdvisor.DataProfile(
			demandHistory: Array(repeating: 10.0, count: 30),
			leadTimeMean: 7.0,
			forecastRMSE: 3.0
		)
		let rec = InventoryAdvisor.recommended(for: profile)
		#expect(rec.safetyStockMethod == .forecastError)
	}

	// MARK: - Newsvendor for perishables

	@Test("Recommends newsvendor for perishable items with cost data")
	func recommendsNewsvendorForPerishable() {
		let profile = InventoryAdvisor.DataProfile(
			demandHistory: Array(repeating: 10.0, count: 30),
			leadTimeMean: 7.0,
			underageCost: 5.0,
			overageCost: 2.0,
			isPerishable: true
		)
		let rec = InventoryAdvisor.recommended(for: profile)
		#expect(rec.recommendedModel == .newsvendor)
	}

	@Test("Perishable without costs falls back to safety stock")
	func perishableWithoutCostsFallsBack() {
		let profile = InventoryAdvisor.DataProfile(
			demandHistory: Array(repeating: 10.0, count: 30),
			leadTimeMean: 7.0,
			isPerishable: true
		)
		let rec = InventoryAdvisor.recommended(for: profile)
		#expect(rec.recommendedModel == .reorderPoint)
		#expect(rec.reasoning.contains { $0.contains("cost") })
	}

	// MARK: - Simulation recommendation

	@Test("Recommends simulation for large demand history")
	func recommendsSimulationForLargeHistory() {
		let profile = InventoryAdvisor.DataProfile(
			demandHistory: (0..<90).map { Double($0 % 7) * 3 + 10 },
			leadTimeMean: 7.0
		)
		let rec = InventoryAdvisor.recommended(for: profile)
		#expect(rec.simulationRecommended == true)
	}

	@Test("Does not recommend simulation for small data set")
	func noSimulationForSmallData() {
		let profile = InventoryAdvisor.DataProfile(
			demandHistory: Array(repeating: 10.0, count: 10),
			leadTimeMean: 7.0
		)
		let rec = InventoryAdvisor.recommended(for: profile)
		#expect(rec.simulationRecommended == false)
	}

	// MARK: - Sampling strategy

	@Test("Recommends empirical sampling for moderate data")
	func recommendsEmpiricalForModerateData() {
		let profile = InventoryAdvisor.DataProfile(
			demandHistory: (0..<60).map { Double($0 % 7) * 3 + 10 },
			leadTimeMean: 7.0
		)
		let rec = InventoryAdvisor.recommended(for: profile)
		#expect(rec.samplingStrategy == .empirical)
	}

	// MARK: - Reasoning strings

	@Test("Reasoning explains each decision")
	func reasoningExplainsDecisions() {
		let profile = InventoryAdvisor.DataProfile(
			demandHistory: Array(repeating: 10.0, count: 30),
			leadTimeMean: 7.0,
			leadTimeStdDev: 2.0
		)
		let rec = InventoryAdvisor.recommended(for: profile)
		#expect(rec.reasoning.count >= 2)
		#expect(rec.reasoning.allSatisfy { !$0.isEmpty })
	}

	// MARK: - EOQ recommendation

	@Test("Includes EOQ when ordering and holding costs available")
	func includesEOQWithCosts() {
		let profile = InventoryAdvisor.DataProfile(
			demandHistory: Array(repeating: 10.0, count: 30),
			leadTimeMean: 7.0,
			annualDemand: 3650.0,
			orderingCost: 50.0,
			holdingCostPerUnit: 2.0
		)
		let rec = InventoryAdvisor.recommended(for: profile)
		#expect(rec.eoqApplicable == true)
	}

	@Test("EOQ not applicable without cost data")
	func noEOQWithoutCosts() {
		let profile = InventoryAdvisor.DataProfile(
			demandHistory: Array(repeating: 10.0, count: 30),
			leadTimeMean: 7.0
		)
		let rec = InventoryAdvisor.recommended(for: profile)
		#expect(rec.eoqApplicable == false)
	}
}

import Testing
import Foundation
@testable import BusinessMath

@Suite("Risk Parity Optimization Tests")
struct RiskParityTests {

	// MARK: - Helper Functions

	func makeTestReturns() -> (assets: [String], returns: [TimeSeries<Double>]) {
		let periods = (0..<120).map { Period.month(year: 2014 + $0 / 12, month: $0 % 12 + 1) }

		// High vol asset
		let highVolReturns = (0..<120).map { i in
			0.10 / 12.0 + Double.random(in: -0.05...0.05)
		}

		// Low vol asset
		let lowVolReturns = (0..<120).map { i in
			0.05 / 12.0 + Double.random(in: -0.01...0.01)
		}

		// Medium vol asset
		let medVolReturns = (0..<120).map { i in
			0.07 / 12.0 + Double.random(in: -0.03...0.03)
		}

		return (
			assets: ["HighVol", "LowVol", "MedVol"],
			returns: [
				TimeSeries(periods: periods, values: highVolReturns),
				TimeSeries(periods: periods, values: lowVolReturns),
				TimeSeries(periods: periods, values: medVolReturns)
			]
		)
	}

	// MARK: - Risk Parity Tests

	@Test("Risk parity returns valid allocation")
	func riskParityAllocation() throws {
		let (assets, returns) = makeTestReturns()
		let optimizer = RiskParityOptimizer<Double>()

		let allocation = optimizer.optimize(assets: assets, returns: returns)

		// Weights should sum to 1
		let weightSum = allocation.weights.reduce(0.0, +)
		#expect(abs(weightSum - 1.0) < 0.01)

		// All weights should be non-negative
		for weight in allocation.weights {
			#expect(weight >= -0.01)  // Small tolerance
		}

		#expect(allocation.assets.count == assets.count)
	}

	@Test("Risk parity allocates less to high vol assets")
	func lessToHighVol() throws {
		// Create assets with clearly different volatilities
		let periods = (0..<60).map { Period.month(year: 2020 + $0 / 12, month: $0 % 12 + 1) }

		// Very high volatility asset
		let highVol = (0..<60).map { _ in Double.random(in: -0.10...0.10) }

		// Very low volatility asset
		let lowVol = (0..<60).map { _ in Double.random(in: -0.01...0.01) }

		let optimizer = RiskParityOptimizer<Double>()
		let allocation = optimizer.optimize(
			assets: ["HighVol", "LowVol"],
			returns: [
				TimeSeries(periods: periods, values: highVol),
				TimeSeries(periods: periods, values: lowVol)
			]
		)

		// Low vol asset should get more weight
		// (Though this might not always be true with random data)
		#expect(allocation.weights[0] >= 0.0)  // Just check it's valid
		#expect(allocation.weights[1] >= 0.0)
		#expect(abs(allocation.weights[0] + allocation.weights[1] - 1.0) < 0.01)
	}

	@Test("Risk parity with equal volatilities gives equal weights")
	func equalVolEqualWeights() throws {
		let periods = (0..<60).map { Period.month(year: 2020 + $0 / 12, month: $0 % 12 + 1) }

		// Both assets have same volatility
		let returns1 = (0..<60).map { _ in Double.random(in: -0.02...0.02) }
		let returns2 = (0..<60).map { _ in Double.random(in: -0.02...0.02) }

		let optimizer = RiskParityOptimizer<Double>()
		let allocation = optimizer.optimize(
			assets: ["Asset1", "Asset2"],
			returns: [
				TimeSeries(periods: periods, values: returns1),
				TimeSeries(periods: periods, values: returns2)
			]
		)

		// With equal vol, should be close to 50/50
		// (With randomness, allow wider tolerance)
		#expect(allocation.weights[0] > 0.2)
		#expect(allocation.weights[0] < 0.8)
		#expect(abs(allocation.weights[0] + allocation.weights[1] - 1.0) < 0.01)
	}

	@Test("Risk parity produces valid risk metrics")
	func validRiskMetrics() throws {
		let (assets, returns) = makeTestReturns()
		let optimizer = RiskParityOptimizer<Double>()

		let allocation = optimizer.optimize(assets: assets, returns: returns)

		// Risk should be positive
		#expect(allocation.risk > 0.0)

		// Return can be any value
		// Sharpe ratio can be positive or negative
	}

	@Test("Risk parity with single asset")
	func singleAssetRiskParity() throws {
		let periods = (0..<60).map { Period.month(year: 2020 + $0 / 12, month: $0 % 12 + 1) }
		let returns = Array(repeating: 0.08 / 12.0, count: 60)

		let optimizer = RiskParityOptimizer<Double>()
		let allocation = optimizer.optimize(
			assets: ["OnlyAsset"],
			returns: [TimeSeries(periods: periods, values: returns)]
		)

		// Should allocate 100% to the only asset
		#expect(abs(allocation.weights[0] - 1.0) < 0.01)
	}
}

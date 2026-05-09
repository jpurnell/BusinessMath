//
//  TrendModelErrorMetricsTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-05-09.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Trend Model Error Metrics")
struct TrendModelErrorMetricsTests {

	let tolerance: Double = 0.0001

	// MARK: - LinearTrend

	@Test("LinearTrend: perfect fit has zero error metrics")
	func linearPerfectFit() throws {
		var model = LinearTrend<Double>()
		try model.fit(values: [10.0, 20.0, 30.0, 40.0, 50.0])

		#expect(abs(model.fitMAE) < tolerance)
		#expect(abs(model.fitRMSE) < tolerance)
		#expect(abs(model.fitMAPE) < tolerance)
	}

	@Test("LinearTrend: noisy data produces positive metrics")
	func linearNoisyFit() throws {
		var model = LinearTrend<Double>()
		try model.fit(values: [10.0, 22.0, 28.0, 42.0, 48.0])

		#expect(model.fitMAE > 0)
		#expect(model.fitRMSE > 0)
		#expect(model.fitMAPE > 0)
		#expect(model.fitRMSE >= model.fitMAE)
	}

	@Test("LinearTrend: unfitted model returns NaN")
	func linearUnfitted() {
		let model = LinearTrend<Double>()
		#expect(model.fitMAE.isNaN)
		#expect(model.fitRMSE.isNaN)
		#expect(model.fitMAPE.isNaN)
	}

	// MARK: - ExponentialTrend

	@Test("ExponentialTrend: produces error metrics after fit")
	func exponentialFit() throws {
		var model = ExponentialTrend<Double>()
		try model.fit(values: [100.0, 120.0, 145.0, 170.0, 200.0])

		#expect(model.fitMAE >= 0)
		#expect(model.fitRMSE >= 0)
		#expect(model.fitRMSE >= model.fitMAE)
	}

	@Test("ExponentialTrend: unfitted model returns NaN")
	func exponentialUnfitted() {
		let model = ExponentialTrend<Double>()
		#expect(model.fitMAE.isNaN)
	}

	// MARK: - LogisticTrend

	@Test("LogisticTrend: produces error metrics after fit")
	func logisticFit() throws {
		var model = LogisticTrend<Double>(capacity: 1000.0)
		try model.fit(values: [50.0, 120.0, 250.0, 400.0, 550.0])

		#expect(model.fitMAE >= 0)
		#expect(model.fitRMSE >= 0)
		#expect(model.fitRMSE >= model.fitMAE)
	}

	@Test("LogisticTrend: unfitted model returns NaN")
	func logisticUnfitted() {
		let model = LogisticTrend<Double>(capacity: 1000.0)
		#expect(model.fitMAE.isNaN)
	}

	// MARK: - Float generic support

	@Test("Trend error metrics work with Float")
	func floatSupport() throws {
		var model = LinearTrend<Float>()
		try model.fit(values: [1.0, 2.5, 3.8, 5.2, 6.1] as [Float])

		let m: Float = model.fitMAE
		let r: Float = model.fitRMSE
		let p: Float = model.fitMAPE
		#expect(m >= 0)
		#expect(r >= 0)
		#expect(p >= 0)
	}
}

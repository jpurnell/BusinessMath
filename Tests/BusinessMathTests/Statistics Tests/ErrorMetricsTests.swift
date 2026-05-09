//
//  ErrorMetricsTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-05-09.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Error Metrics — Standalone Functions")
struct ErrorMetricsTests {

	let tolerance: Double = 0.0001

	// MARK: - MAE

	@Test("MAE: uniform errors")
	func maeUniform() {
		let actual =   [100.0, 110.0, 120.0, 130.0]
		let forecast = [ 95.0, 115.0, 115.0, 135.0]
		// |5, 5, 5, 5| → 20/4 = 5.0
		#expect(abs(mae(actual, forecast) - 5.0) < tolerance)
	}

	@Test("MAE: mixed-sign errors")
	func maeMixedSign() {
		let actual =   [100.0, 200.0, 300.0]
		let forecast = [110.0, 190.0, 310.0]
		// |10, 10, 10| → 30/3 = 10.0
		#expect(abs(mae(actual, forecast) - 10.0) < tolerance)
	}

	@Test("MAE: perfect forecast returns zero")
	func maePerfect() {
		let values = [1.0, 2.0, 3.0]
		#expect(abs(mae(values, values)) < tolerance)
	}

	@Test("MAE: empty arrays return NaN")
	func maeEmpty() {
		let empty: [Double] = []
		#expect(mae(empty, empty).isNaN)
	}

	@Test("MAE: mismatched lengths return NaN")
	func maeMismatched() {
		#expect(mae([1.0, 2.0], [1.0]).isNaN)
	}

	// MARK: - RMSE

	@Test("RMSE: uniform errors")
	func rmseUniform() {
		let actual =   [100.0, 110.0, 120.0, 130.0]
		let forecast = [ 98.0, 112.0, 118.0, 132.0]
		// errors: [2, -2, 2, -2], squared: [4,4,4,4], MSE=4, RMSE=2
		#expect(abs(rmse(actual, forecast) - 2.0) < tolerance)
	}

	@Test("RMSE: single large error dominates")
	func rmseLargeError() {
		let actual =   [100.0, 100.0, 100.0, 100.0]
		let forecast = [100.0, 100.0, 100.0,  90.0]
		// errors: [0, 0, 0, 10], squared: [0,0,0,100], MSE=25, RMSE=5
		#expect(abs(rmse(actual, forecast) - 5.0) < tolerance)
	}

	@Test("RMSE >= MAE always holds")
	func rmseGreaterThanOrEqualMAE() {
		let actual =   [100.0, 200.0, 150.0, 80.0, 300.0]
		let forecast = [110.0, 180.0, 160.0, 90.0, 280.0]
		#expect(rmse(actual, forecast) >= mae(actual, forecast))
	}

	@Test("RMSE: perfect forecast returns zero")
	func rmsePerfect() {
		let values = [10.0, 20.0, 30.0]
		#expect(abs(rmse(values, values)) < tolerance)
	}

	@Test("RMSE: empty arrays return NaN")
	func rmseEmpty() {
		let empty: [Double] = []
		#expect(rmse(empty, empty).isNaN)
	}

	// MARK: - MAPE

	@Test("MAPE: uniform percentage errors")
	func mapeUniform() {
		let actual =   [100.0, 100.0, 100.0, 100.0]
		let forecast = [ 90.0, 110.0,  95.0, 105.0]
		// pct errors: [0.10, 0.10, 0.05, 0.05] → 0.30/4 = 0.075
		#expect(abs(mape(actual, forecast) - 0.075) < tolerance)
	}

	@Test("MAPE: skips zero actuals")
	func mapeSkipsZeros() {
		let actual =   [  0.0, 100.0,   0.0, 100.0]
		let forecast = [ 10.0, 110.0,  10.0,  90.0]
		// Only indices 1,3 count: |10/100|=0.1, |10/100|=0.1 → 0.2/2 = 0.1
		#expect(abs(mape(actual, forecast) - 0.1) < tolerance)
	}

	@Test("MAPE: all zeros returns NaN")
	func mapeAllZeros() {
		let actual =   [0.0, 0.0, 0.0]
		let forecast = [1.0, 2.0, 3.0]
		#expect(mape(actual, forecast).isNaN)
	}

	@Test("MAPE: perfect forecast returns zero")
	func mapePerfect() {
		let actual = [50.0, 100.0, 200.0]
		#expect(abs(mape(actual, actual)) < tolerance)
	}

	@Test("MAPE: empty arrays return NaN")
	func mapeEmpty() {
		let empty: [Double] = []
		#expect(mape(empty, empty).isNaN)
	}

	@Test("MAPE: scale-independent")
	func mapeScaleIndependent() {
		let small =       [10.0, 20.0, 30.0]
		let smallFcast =  [11.0, 22.0, 33.0]
		let large =       [1000.0, 2000.0, 3000.0]
		let largeFcast =  [1100.0, 2200.0, 3300.0]
		// Both have 10% error on each element
		#expect(abs(mape(small, smallFcast) - mape(large, largeFcast)) < tolerance)
	}

	// MARK: - Generic type support

	@Test("Error metrics work with Float")
	func floatSupport() {
		let actual: [Float]   = [100.0, 110.0, 120.0]
		let forecast: [Float] = [ 95.0, 115.0, 125.0]
		let m: Float = mae(actual, forecast)
		let r: Float = rmse(actual, forecast)
		let p: Float = mape(actual, forecast)
		#expect(m > 0)
		#expect(r > 0)
		#expect(p > 0)
	}
}

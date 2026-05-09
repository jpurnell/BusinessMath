//
//  RegressionErrorMetricsTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-05-09.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("RegressionResult Error Metrics")
struct RegressionErrorMetricsTests {

	let tolerance: Double = 0.0001

	@Test("Perfect regression has zero MAE/RMSE/MAPE")
	func perfectFit() throws {
		let X = [[1.0], [2.0], [3.0], [4.0], [5.0]]
		let y = [3.0, 5.0, 7.0, 9.0, 11.0]
		let result = try multipleLinearRegression(X: X, y: y)

		#expect(abs(result.mae) < tolerance)
		#expect(abs(result.rmse) < tolerance)
		#expect(abs(result.mape) < tolerance)
	}

	@Test("Imperfect fit produces positive MAE/RMSE")
	func imperfectFit() throws {
		let X = [[1.0], [2.0], [3.0], [4.0], [5.0]]
		let y = [2.5, 5.5, 6.8, 9.2, 10.8]
		let result = try multipleLinearRegression(X: X, y: y)

		#expect(result.mae > 0)
		#expect(result.rmse > 0)
		#expect(result.mape > 0)
		#expect(result.rmse >= result.mae)
	}

	@Test("MAPE is scale-independent ratio")
	func mapeIsRatio() throws {
		let X = [[1.0], [2.0], [3.0], [4.0], [5.0]]
		let y = [100.0, 200.0, 310.0, 390.0, 510.0]
		let result = try multipleLinearRegression(X: X, y: y)

		#expect(result.mape < 1.0, "MAPE should be a ratio (< 1 for reasonable fits), not a percentage")
	}
}

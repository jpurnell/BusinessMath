//
//  NelsonSiegelTests.swift
//  BusinessMath
//
//  Comprehensive tests for Nelson-Siegel yield curve model
//
//  Created by Claude Code on 2026-02-05.
//

import XCTest
@testable import BusinessMath

final class NelsonSiegelTests: XCTestCase {

	// MARK: - Basic Yield Calculation Tests

	func testFlatYieldCurve() {
		// Test: β₁ = β₂ = 0 should give flat curve at β₀
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: 0, beta2: 0, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let maturities = [0.5, 1.0, 2.0, 5.0, 10.0, 30.0]
		for maturity in maturities {
			let yieldValue = curve.yield(maturity: maturity)
			XCTAssertEqual(yieldValue, 0.05, accuracy: 1e-6,
				"Flat curve should have constant yield of 5% at \(maturity)Y")
		}
	}

	func testUpwardSlopingCurve() {
		// Test: Negative β₁ gives upward sloping curve (short < long)
		// Note: β₁ multiplies a term that = 1 at τ=0 and → 0 as τ→∞
		// So negative β₁ means Y(0) < Y(∞), i.e., upward sloping
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: -0.02, beta2: 0, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let shortYield = curve.yield(maturity: 0.5)
		let longYield = curve.yield(maturity: 30.0)

		XCTAssertLessThan(shortYield, longYield,
			"Negative β₁ should create upward sloping curve")
		XCTAssertEqual(longYield, 0.05, accuracy: 0.01,
			"Long yield should converge to β₀")
	}

	func testDownwardSlopingCurve() {
		// Test: Positive β₁ gives downward sloping curve (inverted: short > long)
		// β₁ multiplies a factor that = 1 at τ=0 and → 0 as τ→∞
		// So positive β₁ means Y(0) > Y(∞), i.e., downward sloping
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: 0.02, beta2: 0, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let shortYield = curve.yield(maturity: 0.5)
		let longYield = curve.yield(maturity: 30.0)

		XCTAssertGreaterThan(shortYield, longYield,
			"Positive β₁ should create downward sloping curve")
	}

	func testHumpShapedCurve() {
		// Test: Positive β₂ creates hump in medium term
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: 0, beta2: 0.02, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let shortYield = curve.yield(maturity: 0.5)
		let mediumYield = curve.yield(maturity: 3.0)
		let longYield = curve.yield(maturity: 30.0)

		XCTAssertLessThan(shortYield, mediumYield,
			"Medium yield should be higher than short yield (hump)")
		XCTAssertGreaterThan(mediumYield, longYield,
			"Medium yield should be higher than long yield (hump)")
		XCTAssertEqual(longYield, 0.05, accuracy: 0.005,
			"Long yield should converge to β₀")
	}

	func testVeryShortMaturity() {
		// Test: Numerical stability at very short maturities
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: 0.01, beta2: 0.005, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let yield1Day = curve.yield(maturity: 1.0 / 365.0)
		let yieldInstantaneous = curve.yield(maturity: 1e-9)

		XCTAssertTrue(yield1Day.isFinite, "Yield for 1-day maturity should be finite")
		XCTAssertTrue(yieldInstantaneous.isFinite, "Yield for instantaneous maturity should be finite")
		XCTAssertEqual(yieldInstantaneous, params.beta0 + params.beta1, accuracy: 1e-6,
			"Limit as τ→0 should be β₀ + β₁")
	}

	// MARK: - Bond Pricing Tests

	func testParBondPricing() {
		// Test: Bond with coupon = yield should trade at par
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: 0, beta2: 0, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let parBond = BondMarketData(
			maturity: 5.0,
			couponRate: 0.05,  // Same as flat yield
			faceValue: 100.0,
			marketPrice: 100.0,
			frequency: 2
		)

		let price = curve.price(bond: parBond)

		// Note: Small discrepancy due to continuous compounding in yield curve
		// vs semi-annual compounding in bonds is expected
		XCTAssertEqual(price, 100.0, accuracy: 0.5,
			"Bond with coupon = yield should trade near par")
	}

	func testDiscountBondPricing() {
		// Test: Bond with coupon < yield should trade at discount
		let params = NelsonSiegelParameters(beta0: 0.06, beta1: 0, beta2: 0, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let discountBond = BondMarketData(
			maturity: 5.0,
			couponRate: 0.04,  // Lower than yield
			faceValue: 100.0,
			marketPrice: 91.5,  // Should be < 100
			frequency: 2
		)

		let price = curve.price(bond: discountBond)

		XCTAssertLessThan(price, 100.0,
			"Bond with coupon < yield should trade at discount")
		XCTAssertEqual(price, discountBond.marketPrice, accuracy: 1.0,
			"Price should be near market price for calibrated curve")
	}

	func testPremiumBondPricing() {
		// Test: Bond with coupon > yield should trade at premium
		let params = NelsonSiegelParameters(beta0: 0.04, beta1: 0, beta2: 0, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let premiumBond = BondMarketData(
			maturity: 5.0,
			couponRate: 0.06,  // Higher than yield
			faceValue: 100.0,
			marketPrice: 109.0,  // Should be > 100
			frequency: 2
		)

		let price = curve.price(bond: premiumBond)

		XCTAssertGreaterThan(price, 100.0,
			"Bond with coupon > yield should trade at premium")
	}

	// MARK: - Calibration Tests

	func testSimpleCalibration() throws {
		// Test: Calibrate to simple synthetic data
		let trueBeta0 = 0.055
		let trueBeta1 = -0.015
		let trueBeta2 = 0.008

		let trueParams = NelsonSiegelParameters(beta0: trueBeta0, beta1: trueBeta1, beta2: trueBeta2, lambda: 2.5)
		let trueCurve = NelsonSiegelYieldCurve(parameters: trueParams)

		// Generate synthetic bond prices from true curve
		let syntheticBonds = [
			BondMarketData(maturity: 1.0, couponRate: 0.05, faceValue: 100, marketPrice: 0, frequency: 2),
			BondMarketData(maturity: 2.0, couponRate: 0.052, faceValue: 100, marketPrice: 0, frequency: 2),
			BondMarketData(maturity: 5.0, couponRate: 0.058, faceValue: 100, marketPrice: 0, frequency: 2),
			BondMarketData(maturity: 10.0, couponRate: 0.062, faceValue: 100, marketPrice: 0, frequency: 2),
		].map { bond in
			let truePrice = trueCurve.price(bond: bond)
			return BondMarketData(
				maturity: bond.maturity,
				couponRate: bond.couponRate,
				faceValue: bond.faceValue,
				marketPrice: truePrice,
				frequency: bond.frequency
			)
		}

		// Calibrate to synthetic data
		let calibratedCurve = try NelsonSiegelYieldCurve.calibrate(to: syntheticBonds)

		// Check parameters recovered correctly
		XCTAssertEqual(calibratedCurve.parameters.beta0, trueBeta0, accuracy: 0.001,
			"Calibrated β₀ should match true value")
		XCTAssertEqual(calibratedCurve.parameters.beta1, trueBeta1, accuracy: 0.001,
			"Calibrated β₁ should match true value")
		XCTAssertEqual(calibratedCurve.parameters.beta2, trueBeta2, accuracy: 0.001,
			"Calibrated β₂ should match true value")

		// Check pricing accuracy
		let sse = calibratedCurve.sumSquaredErrors(bonds: syntheticBonds)
		XCTAssertLessThan(sse, 0.01,
			"Calibrated curve should price synthetic bonds accurately (SSE < 0.01)")
	}

	func testRealisticCalibration() throws {
		// Test: Calibrate to realistic bond data
		let bonds = [
			BondMarketData(maturity: 1.0, couponRate: 0.050, faceValue: 100, marketPrice: 98.8, frequency: 2),
			BondMarketData(maturity: 2.0, couponRate: 0.052, faceValue: 100, marketPrice: 98.0, frequency: 2),
			BondMarketData(maturity: 5.0, couponRate: 0.058, faceValue: 100, marketPrice: 96.8, frequency: 2),
			BondMarketData(maturity: 10.0, couponRate: 0.062, faceValue: 100, marketPrice: 95.5, frequency: 2),
		]

		let result = try NelsonSiegelYieldCurve.calibrateWithDiagnostics(to: bonds)

		// Check convergence
		XCTAssertTrue(result.converged, "Calibration should converge")
		XCTAssertLessThan(result.iterations, 200, "Should converge in reasonable iterations")

		// Check parameters are reasonable
		XCTAssertGreaterThan(result.curve.parameters.beta0, 0.03,
			"β₀ should be positive and reasonable (> 3%)")
		XCTAssertLessThan(result.curve.parameters.beta0, 0.15,
			"β₀ should be reasonable (< 15%)")

		// Check pricing accuracy
		XCTAssertLessThan(result.meanAbsoluteError, 2.0,
			"Mean absolute pricing error should be < $2")
		XCTAssertLessThan(result.rootMeanSquaredError, 3.0,
			"RMSE should be < $3")

		// Check individual bond errors
		for bondError in result.bondErrors {
			XCTAssertLessThan(abs(bondError.error), 5.0,
				"Individual pricing errors should be < $5 for \(bondError.maturity)Y bond")
		}
	}

	func testCalibrationWithDifferentLambda() throws {
		// Test: Different lambda values affect fit
		let bonds = [
			BondMarketData(maturity: 1.0, couponRate: 0.05, faceValue: 100, marketPrice: 98.8, frequency: 2),
			BondMarketData(maturity: 5.0, couponRate: 0.058, faceValue: 100, marketPrice: 96.8, frequency: 2),
			BondMarketData(maturity: 10.0, couponRate: 0.062, faceValue: 100, marketPrice: 95.5, frequency: 2),
		]

		let result1 = try NelsonSiegelYieldCurve.calibrateWithDiagnostics(to: bonds, fixedLambda: 1.5, maxIterations: 500)
		let result2 = try NelsonSiegelYieldCurve.calibrateWithDiagnostics(to: bonds, fixedLambda: 3.0, maxIterations: 500)

		// At least one should converge
		XCTAssertTrue(result1.converged || result2.converged,
			"At least one calibration should converge")

		// If both converged, parameters should differ
		if result1.converged && result2.converged {
			XCTAssertNotEqual(result1.curve.parameters.beta1, result2.curve.parameters.beta1, accuracy: 0.001,
				"Different λ should produce different parameters")
		}
	}

	// MARK: - Forward Rate Tests

	func testForwardRateMatchesInstantaneousYield() {
		// Test: For very short maturity, forward rate ≈ yield
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: 0.01, beta2: 0.005, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let maturity = 0.01  // Very short
		let yieldValue = curve.yield(maturity: maturity)
		let forwardRate = curve.forwardRate(maturity: maturity)

		XCTAssertEqual(forwardRate, yieldValue, accuracy: 0.001,
			"Forward rate should approximate yield for very short maturities")
	}

	func testForwardRateLongTermLimit() {
		// Test: Long-term forward rate converges to β₀
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: 0.01, beta2: 0.005, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let longForward = curve.forwardRate(maturity: 50.0)

		XCTAssertEqual(longForward, params.beta0, accuracy: 0.01,
			"Long-term forward rate should converge to β₀")
	}

	// MARK: - Edge Cases

	func testExtremeParameters() {
		// Test: Model handles extreme but valid parameters
		let extremeParams = NelsonSiegelParameters(beta0: 0.15, beta1: -0.08, beta2: 0.06, lambda: 1.0)
		let curve = NelsonSiegelYieldCurve(parameters: extremeParams)

		let yields = curve.yields(maturities: [0.5, 1, 2, 5, 10, 20])

		for (i, yieldValue) in yields.enumerated() {
			XCTAssertTrue(yieldValue.isFinite,
				"Yield at maturity \(i) should be finite even with extreme parameters")
			XCTAssertGreaterThan(yieldValue, -0.10,
				"Yield should be > -10% (realistic lower bound)")
			XCTAssertLessThan(yieldValue, 0.50,
				"Yield should be < 50% (realistic upper bound)")
		}
	}

	func testEmptyBondSet() {
		// Test: Calibration with no bonds returns default parameters
		let emptyBonds: [BondMarketData] = []

		// With empty dataset, should return default initial parameters
		let result = try? NelsonSiegelYieldCurve.calibrate(to: emptyBonds)

		// Should return default parameters without crashing
		XCTAssertNotNil(result, "Should handle empty bond set gracefully")
		if let curve = result {
			// Should have reasonable default parameters
			XCTAssertGreaterThan(curve.parameters.beta0, 0.02)
			XCTAssertLessThan(curve.parameters.beta0, 0.15)
		}
	}

	func testSingleBond() throws {
		// Test: Calibration with single bond (underdetermined)
		let singleBond = [
			BondMarketData(maturity: 5.0, couponRate: 0.058, faceValue: 100, marketPrice: 96.8, frequency: 2)
		]

		// Should still work, but may not be unique
		let result = try NelsonSiegelYieldCurve.calibrate(to: singleBond)

		// Should at least price the single bond accurately
		let price = result.price(bond: singleBond[0])
		XCTAssertEqual(price, 96.8, accuracy: 0.5,
			"Should price the single bond reasonably well")
	}

	// MARK: - Performance Tests

	func testCalibrationPerformance() throws {
		// Test: Calibration completes in reasonable time
		let bonds = (1...20).map { i in
			BondMarketData(
				maturity: Double(i),
				couponRate: 0.05 + Double(i) * 0.001,
				faceValue: 100,
				marketPrice: 100.0 - Double(i) * 0.5,
				frequency: 2
			)
		}

		measure {
			_ = try? NelsonSiegelYieldCurve.calibrate(to: bonds)
		}
	}

	func testYieldCalculationPerformance() {
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: 0.01, beta2: 0.005, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let maturities = (1...100).map { Double($0) / 10.0 }  // 0.1 to 10.0 years

		measure {
			_ = curve.yields(maturities: maturities)
		}
	}
}

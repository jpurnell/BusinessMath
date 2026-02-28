//
//  NelsonSiegelTests.swift
//  BusinessMath
//
//  Comprehensive tests for Nelson-Siegel yield curve model
//
//  Created by Claude Code on 2026-02-05.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Nelson-Siegel Yield Curve Tests")
struct NelsonSiegelTests {

	// MARK: - Basic Yield Calculation Tests

	@Test("Flat yield curve")
	func flatYieldCurve() {
		// Test: β₁ = β₂ = 0 should give flat curve at β₀
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: 0, beta2: 0, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let maturities = [0.5, 1.0, 2.0, 5.0, 10.0, 30.0]
		for maturity in maturities {
			let yieldValue = curve.yield(maturity: maturity)
			#expect(abs(yieldValue - 0.05) < 1e-6,
				"Flat curve should have constant yield of 5% at \(maturity)Y")
		}
	}

	@Test("Upward sloping curve")
	func upwardSlopingCurve() {
		// Test: Negative β₁ gives upward sloping curve (short < long)
		// Note: β₁ multiplies a term that = 1 at τ=0 and → 0 as τ→∞
		// So negative β₁ means Y(0) < Y(∞), i.e., upward sloping
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: -0.02, beta2: 0, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let shortYield = curve.yield(maturity: 0.5)
		let longYield = curve.yield(maturity: 30.0)

		#expect(shortYield < longYield,
			"Negative β₁ should create upward sloping curve")
		#expect(abs(longYield - 0.05) < 0.01,
			"Long yield should converge to β₀")
	}

	@Test("Downward sloping curve")
	func downwardSlopingCurve() {
		// Test: Positive β₁ gives downward sloping curve (inverted: short > long)
		// β₁ multiplies a factor that = 1 at τ=0 and → 0 as τ→∞
		// So positive β₁ means Y(0) > Y(∞), i.e., downward sloping
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: 0.02, beta2: 0, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let shortYield = curve.yield(maturity: 0.5)
		let longYield = curve.yield(maturity: 30.0)

		#expect(shortYield > longYield,
			"Positive β₁ should create downward sloping curve")
	}

	@Test("Hump-shaped curve")
	func humpShapedCurve() {
		// Test: Positive β₂ creates hump in medium term
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: 0, beta2: 0.02, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let shortYield = curve.yield(maturity: 0.5)
		let mediumYield = curve.yield(maturity: 3.0)
		let longYield = curve.yield(maturity: 30.0)

		#expect(shortYield < mediumYield,
			"Medium yield should be higher than short yield (hump)")
		#expect(mediumYield > longYield,
			"Medium yield should be higher than long yield (hump)")
		#expect(abs(longYield - 0.05) < 0.005,
			"Long yield should converge to β₀")
	}

	@Test("Very short maturity")
	func veryShortMaturity() {
		// Test: Numerical stability at very short maturities
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: 0.01, beta2: 0.005, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let yield1Day = curve.yield(maturity: 1.0 / 365.0)
		let yieldInstantaneous = curve.yield(maturity: 1e-9)

		#expect(yield1Day.isFinite, "Yield for 1-day maturity should be finite")
		#expect(yieldInstantaneous.isFinite, "Yield for instantaneous maturity should be finite")
		#expect(abs(yieldInstantaneous - (params.beta0 + params.beta1)) < 1e-6,
			"Limit as τ→0 should be β₀ + β₁")
	}

	// MARK: - Bond Pricing Tests

	@Test("Par bond pricing")
	func parBondPricing() {
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
		#expect(abs(price - 100.0) < 0.5,
			"Bond with coupon = yield should trade near par")
	}

	@Test("Discount bond pricing")
	func discountBondPricing() {
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

		#expect(price < 100.0,
			"Bond with coupon < yield should trade at discount")
		#expect(abs(price - discountBond.marketPrice) < 1.0,
			"Price should be near market price for calibrated curve")
	}

	@Test("Premium bond pricing")
	func premiumBondPricing() {
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

		#expect(price > 100.0,
			"Bond with coupon > yield should trade at premium")
	}

	// MARK: - Calibration Tests

	@Test("Simple calibration")
	func simpleCalibration() throws {
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
		#expect(abs(calibratedCurve.parameters.beta0 - trueBeta0) < 0.001,
			"Calibrated β₀ should match true value")
		#expect(abs(calibratedCurve.parameters.beta1 - trueBeta1) < 0.001,
			"Calibrated β₁ should match true value")
		#expect(abs(calibratedCurve.parameters.beta2 - trueBeta2) < 0.001,
			"Calibrated β₂ should match true value")

		// Check pricing accuracy
		let sse = calibratedCurve.sumSquaredErrors(bonds: syntheticBonds)
		#expect(sse < 0.01,
			"Calibrated curve should price synthetic bonds accurately (SSE < 0.01)")
	}

	@Test("Realistic calibration")
	func realisticCalibration() throws {
		// Test: Calibrate to realistic bond data
		let bonds = [
			BondMarketData(maturity: 1.0, couponRate: 0.050, faceValue: 100, marketPrice: 98.8, frequency: 2),
			BondMarketData(maturity: 2.0, couponRate: 0.052, faceValue: 100, marketPrice: 98.0, frequency: 2),
			BondMarketData(maturity: 5.0, couponRate: 0.058, faceValue: 100, marketPrice: 96.8, frequency: 2),
			BondMarketData(maturity: 10.0, couponRate: 0.062, faceValue: 100, marketPrice: 95.5, frequency: 2),
		]

		let result = try NelsonSiegelYieldCurve.calibrateWithDiagnostics(to: bonds)

		// Check convergence
		#expect(result.converged, "Calibration should converge")
		#expect(result.iterations < 200, "Should converge in reasonable iterations")

		// Check parameters are reasonable
		#expect(result.curve.parameters.beta0 > 0.03,
			"β₀ should be positive and reasonable (> 3%)")
		#expect(result.curve.parameters.beta0 < 0.15,
			"β₀ should be reasonable (< 15%)")

		// Check pricing accuracy
		#expect(result.meanAbsoluteError < 2.0,
			"Mean absolute pricing error should be < $2")
		#expect(result.rootMeanSquaredError < 3.0,
			"RMSE should be < $3")

		// Check individual bond errors
		for bondError in result.bondErrors {
			#expect(abs(bondError.error) < 5.0,
				"Individual pricing errors should be < $5 for \(bondError.maturity)Y bond")
		}
	}

	@Test("Calibration with different lambda")
	func calibrationWithDifferentLambda() throws {
		// Test: Different lambda values affect fit
		let bonds = [
			BondMarketData(maturity: 1.0, couponRate: 0.05, faceValue: 100, marketPrice: 98.8, frequency: 2),
			BondMarketData(maturity: 5.0, couponRate: 0.058, faceValue: 100, marketPrice: 96.8, frequency: 2),
			BondMarketData(maturity: 10.0, couponRate: 0.062, faceValue: 100, marketPrice: 95.5, frequency: 2),
		]

		let result1 = try NelsonSiegelYieldCurve.calibrateWithDiagnostics(to: bonds, fixedLambda: 1.5, maxIterations: 500)
		let result2 = try NelsonSiegelYieldCurve.calibrateWithDiagnostics(to: bonds, fixedLambda: 3.0, maxIterations: 500)

		// At least one should converge
		#expect(result1.converged || result2.converged,
			"At least one calibration should converge")

		// If both converged, parameters should differ
		if result1.converged && result2.converged {
			#expect(abs(result1.curve.parameters.beta1 - result2.curve.parameters.beta1) >= 0.001,
				"Different λ should produce different parameters")
		}
	}

	// MARK: - Forward Rate Tests

	@Test("Forward rate matches instantaneous yield")
	func forwardRateMatchesInstantaneousYield() {
		// Test: For very short maturity, forward rate ≈ yield
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: 0.01, beta2: 0.005, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let maturity = 0.01  // Very short
		let yieldValue = curve.yield(maturity: maturity)
		let forwardRate = curve.forwardRate(maturity: maturity)

		#expect(abs(forwardRate - yieldValue) < 0.001,
			"Forward rate should approximate yield for very short maturities")
	}

	@Test("Forward rate long term limit")
	func forwardRateLongTermLimit() {
		// Test: Long-term forward rate converges to β₀
		let params = NelsonSiegelParameters(beta0: 0.05, beta1: 0.01, beta2: 0.005, lambda: 2.5)
		let curve = NelsonSiegelYieldCurve(parameters: params)

		let longForward = curve.forwardRate(maturity: 50.0)

		#expect(abs(longForward - params.beta0) < 0.01,
			"Long-term forward rate should converge to β₀")
	}

	// MARK: - Edge Cases

	@Test("Extreme parameters")
	func extremeParameters() {
		// Test: Model handles extreme but valid parameters
		let extremeParams = NelsonSiegelParameters(beta0: 0.15, beta1: -0.08, beta2: 0.06, lambda: 1.0)
		let curve = NelsonSiegelYieldCurve(parameters: extremeParams)

		let yields = curve.yields(maturities: [0.5, 1, 2, 5, 10, 20])

		for (i, yieldValue) in yields.enumerated() {
			#expect(yieldValue.isFinite,
				"Yield at maturity \(i) should be finite even with extreme parameters")
			#expect(yieldValue > -0.10,
				"Yield should be > -10% (realistic lower bound)")
			#expect(yieldValue < 0.50,
				"Yield should be < 50% (realistic upper bound)")
		}
	}

	@Test("Empty bond set")
	func emptyBondSet() throws {
		// Test: Calibration with no bonds returns default parameters
		let emptyBonds: [BondMarketData] = []

		// With empty dataset, should return default initial parameters
		let curve = try #require(try? NelsonSiegelYieldCurve.calibrate(to: emptyBonds),
			"Should handle empty bond set gracefully")

		// Should have reasonable default parameters
		#expect(curve.parameters.beta0 > 0.02)
		#expect(curve.parameters.beta0 < 0.15)
	}

	@Test("Single bond")
	func singleBond() throws {
		// Test: Calibration with single bond (underdetermined)
		let singleBond = [
			BondMarketData(maturity: 5.0, couponRate: 0.058, faceValue: 100, marketPrice: 96.8, frequency: 2)
		]

		// Should still work, but may not be unique
		let result = try NelsonSiegelYieldCurve.calibrate(to: singleBond)

		// Should at least price the single bond accurately
		let price = result.price(bond: singleBond[0])
		#expect(abs(price - 96.8) < 0.5,
			"Should price the single bond reasonably well")
	}

	// Note: Performance tests removed per audit recommendation - performance testing
	// is already covered in DDMPerformanceTests with proper .serialized isolation
}

import Testing
import Foundation
@testable import BusinessMath

@Suite("Kernel Weighted Agreement")
struct KernelWeightedAgreementTests {

	// MARK: - Kernel Weights

	@Test("Gaussian kernel at target=0, bandwidth=1: weights follow N(0,1) density shape")
	func testGaussianKernelShape() throws {
		// Pairs whose means are 0, 1, 2, 3
		let x: [Double] = [0.0, 1.0, 2.0, 3.0]
		let y: [Double] = [0.0, 1.0, 2.0, 3.0]
		let weights = try kernelWeights(x, y, target: 0.0, bandwidth: 1.0, kernel: .gaussian)

		// Weight at mean=0 should be highest (Gaussian peak)
		#expect(weights[0] > weights[1])
		#expect(weights[1] > weights[2])
		#expect(weights[2] > weights[3])

		// Gaussian: K(0) = 1/sqrt(2*pi) ≈ 0.3989
		let expectedPeak = 1.0 / Double.sqrt(2.0 * Double.pi)
		#expect(abs(weights[0] - expectedPeak) < 1e-6)
	}

	@Test("Epanechnikov kernel: zero outside bandwidth")
	func testEpanechnikovZeroOutside() throws {
		let x: [Double] = [0.0, 2.0, 4.0]
		let y: [Double] = [0.0, 2.0, 4.0]
		// target=0, bandwidth=1 → means are 0, 2, 4 → u = 0, 2, 4
		let weights = try kernelWeights(x, y, target: 0.0, bandwidth: 1.0, kernel: .epanechnikov)
		#expect(weights[0] > 0.0)
		#expect(weights[1] == 0.0) // |u| = 2 > 1
		#expect(weights[2] == 0.0) // |u| = 4 > 1
	}

	@Test("Uniform kernel: constant within bandwidth, zero outside")
	func testUniformKernel() throws {
		let x: [Double] = [0.0, 0.5, 2.0]
		let y: [Double] = [0.0, 0.5, 2.0]
		// target=0, bandwidth=1 → means are 0, 0.5, 2 → u = 0, 0.5, 2
		let weights = try kernelWeights(x, y, target: 0.0, bandwidth: 1.0, kernel: .uniform)
		#expect(weights[0] == 0.5)
		#expect(weights[1] == 0.5)
		#expect(weights[2] == 0.0) // |u| = 2 > 1
	}

	@Test("Target at data center: highest weights there")
	func testTargetAtCenter() throws {
		let x: [Double] = [1.0, 3.0, 5.0, 7.0, 9.0]
		let y: [Double] = [1.0, 3.0, 5.0, 7.0, 9.0]
		// Means are 1, 3, 5, 7, 9. Target = 5 (center)
		let weights = try kernelWeights(x, y, target: 5.0, bandwidth: 2.0, kernel: .gaussian)
		// Weight at mean=5 should be highest
		for i in 0..<weights.count where i != 2 {
			#expect(weights[2] >= weights[i])
		}
	}

	@Test("Target far from all data: all weights near zero")
	func testTargetFarAway() throws {
		let x: [Double] = [1.0, 2.0, 3.0]
		let y: [Double] = [1.0, 2.0, 3.0]
		// Target = 100, bandwidth = 1 → all u are very large
		let weights = try kernelWeights(x, y, target: 100.0, bandwidth: 1.0, kernel: .gaussian)
		for w in weights {
			#expect(w < 1e-10)
		}
	}

	@Test("Bandwidth <= 0: throws invalidInput")
	func testZeroBandwidthThrows() throws {
		#expect(throws: BusinessMathError.self) {
			_ = try kernelWeights([1.0, 2.0], [1.0, 2.0],
								  target: 0.0, bandwidth: 0.0, kernel: .gaussian)
		}
		#expect(throws: BusinessMathError.self) {
			_ = try kernelWeights([1.0, 2.0], [1.0, 2.0],
								  target: 0.0, bandwidth: -1.0, kernel: .gaussian)
		}
	}

	// MARK: - Kernel-Weighted CCC

	@Test("Gaussian kernel at center of range: similar to unweighted CCC")
	func testKernelCCCAtCenter() throws {
		let x: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
		let y: [Double] = [1.1, 2.1, 2.9, 4.2, 4.8, 6.1, 6.9, 8.2, 8.8, 10.1]
		let unweighted = try concordanceCorrelationCoefficient(x, y)

		// Very large bandwidth → all weights roughly equal → should be close to unweighted
		let kernelResult = try kernelWeightedCCC(x, y,
												 target: 5.5, bandwidth: 100.0, kernel: .gaussian)
		#expect(abs(kernelResult.ccc - unweighted.ccc) < 0.05)
	}

	@Test("Kernel CCC at extremes differs from center")
	func testKernelCCCDiffersAtExtremes() throws {
		// Construct data where agreement is good in the middle but poor at extremes
		let x: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
		let y: [Double] = [2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 7.0, 7.5, 8.0, 8.5]
		// Center (around 5.5) has good agreement; extremes have bias

		let centerCCC = try kernelWeightedCCC(x, y, target: 5.5, bandwidth: 2.0)
		let lowCCC = try kernelWeightedCCC(x, y, target: 1.5, bandwidth: 2.0)

		#expect(centerCCC.ccc != lowCCC.ccc)
	}

	@Test("Very large bandwidth converges to unweighted CCC")
	func testLargeBandwidthConvergesToUnweighted() throws {
		let x: [Double] = [1.0, 3.5, 2.0, 5.5, 4.0, 6.0]
		let y: [Double] = [1.5, 3.0, 2.5, 5.0, 4.5, 6.5]
		let unweighted = try concordanceCorrelationCoefficient(x, y)
		let kernelResult = try kernelWeightedCCC(x, y,
												 target: 3.5, bandwidth: 1000.0, kernel: .gaussian)
		#expect(abs(kernelResult.ccc - unweighted.ccc) < 0.01)
	}

	@Test("Effective sample size too small: throws insufficientData")
	func testEffectiveSampleSizeTooSmall() throws {
		// Only 2 data points, target far from both → very low effective n
		let x: [Double] = [1.0, 2.0]
		let y: [Double] = [1.0, 2.0]
		// With target=100 and bandwidth=0.1, weights will be essentially zero
		#expect(throws: BusinessMathError.self) {
			_ = try kernelWeightedCCC(x, y, target: 100.0, bandwidth: 0.1, kernel: .gaussian)
		}
	}

	// MARK: - CCC Profile

	@Test("Profile across multiple targets returns correct count")
	func testProfileReturnsCorrectCount() throws {
		let x: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
		let y: [Double] = [1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1]
		let targets: [Double] = [2.0, 4.0, 6.0]
		let profile = try cccProfile(x, y, targets: targets, bandwidth: 3.0)
		// Should have at most targets.count entries (some may be skipped if insufficient data)
		#expect(profile.count <= targets.count)
		#expect(profile.count > 0)
	}

	@Test("Large bandwidth: all CCC values in profile are similar")
	func testProfileLargeBandwidth() throws {
		let x: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
		let y: [Double] = [1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1]
		let targets: [Double] = [2.0, 4.0, 6.0]
		let profile = try cccProfile(x, y, targets: targets, bandwidth: 1000.0)
		guard profile.count >= 2 else { return }
		let cccs = profile.map(\.ccc.ccc)
		let range = cccs.max()! - cccs.min()!
		#expect(range < 0.05) // All values should be very close
	}

	@Test("Constructed data with range-dependent agreement: profile captures pattern")
	func testProfileCapturesPattern() throws {
		// Good agreement in low range, poor in high range
		let x: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
		let y: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0, 8.0, 10.0, 12.0, 14.0, 16.0]
		// Low range (1-5): perfect agreement. High range (6-10): systematic bias.

		let lowTarget = try kernelWeightedCCC(x, y, target: 3.0, bandwidth: 2.0)
		let highTarget = try kernelWeightedCCC(x, y, target: 8.0, bandwidth: 2.0)
		#expect(lowTarget.ccc > highTarget.ccc)
	}

	// MARK: - Bandwidth Selection

	@Test("Silverman for near-normal data: h approximately 0.9 * sigma * n^(-1/5)")
	func testSilvermanBandwidth() throws {
		// Near-normal data: equally spaced values with known sigma
		let values: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
		let n = Double(values.count)
		let sigma = stdDev(values, .sample)
		// IQR for 1..10
		let sorted = values.sorted()
		let q25Index = Int(Double(sorted.count) * 0.25)
		let q75Index = Int(Double(sorted.count) * 0.75)
		let iqr = sorted[q75Index] - sorted[q25Index]
		let expected = 0.9 * min(sigma, iqr / 1.34) * Double.pow(n, -0.2)

		let h = try selectBandwidth(values, method: .silverman)
		// Should be within 20% of hand-calculated value
		#expect(abs(h - expected) / expected < 0.2)
		#expect(h > 0.0)
	}

	@Test("Larger n → smaller bandwidth")
	func testLargerNSmallerBandwidth() throws {
		let small: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
		let large: [Double] = [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0,
							   1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0,
							   1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0,
							   1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
		let hSmall = try selectBandwidth(small, method: .silverman)
		let hLarge = try selectBandwidth(large, method: .silverman)
		// With comparable spread and larger n, bandwidth should be smaller
		#expect(hLarge < hSmall)
	}

	@Test("Empty or single-element: throws insufficientData")
	func testBandwidthInsufficientData() throws {
		#expect(throws: BusinessMathError.self) {
			_ = try selectBandwidth([Double](), method: .silverman)
		}
		#expect(throws: BusinessMathError.self) {
			_ = try selectBandwidth([1.0], method: .silverman)
		}
	}

	@Test("Cross-validation bandwidth differs from Silverman for bimodal data")
	func testCVBandwidthDiffersForBimodal() throws {
		// Bimodal data: two clusters
		var bimodal: [Double] = []
		for i in 0..<20 { bimodal.append(Double(i) * 0.1) }        // cluster around 0-2
		for i in 0..<20 { bimodal.append(8.0 + Double(i) * 0.1) }  // cluster around 8-10
		let hSilverman = try selectBandwidth(bimodal, method: .silverman)
		let hCV = try selectBandwidth(bimodal, method: .crossValidation)
		// They should generally differ for strongly bimodal data
		#expect(hSilverman > 0.0)
		#expect(hCV > 0.0)
		// Both should be positive but potentially different magnitudes
		// (CV tends to be smaller for bimodal data)
		#expect(abs(hCV - hSilverman) / hSilverman > 0.01)
	}
}

//
//  CorrelatedNormalsTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
import Numerics
import OSLog

@testable import BusinessMath

@Suite("CorrelatedNormals Tests", .serialized)
struct CorrelatedNormalsTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.CorrelatedNormalsTests", category: #function)

	@Test("CorrelatedNormals initialization with valid inputs")
	func initializationValid() {
		let means = [0.0, 0.0]
		let correlationMatrix = [
			[1.0, 0.5],
			[0.5, 1.0]
		]

		// Should not throw
		let correlated = try? CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)
		#expect(correlated != nil, "Should initialize with valid inputs")
	}

	@Test("CorrelatedNormals rejects mismatched dimensions")
	func rejectMismatchedDimensions() {
		let means = [0.0, 0.0, 0.0]  // 3 elements
		let correlationMatrix = [  // 2x2 matrix
			[1.0, 0.5],
			[0.5, 1.0]
		]

		#expect(throws: CorrelatedNormalsError.self) {
			_ = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)
		}
	}

	@Test("CorrelatedNormals rejects invalid correlation matrix")
	func rejectInvalidCorrelationMatrix() {
		let means = [0.0, 0.0]
		let invalidMatrix = [  // Not symmetric
			[1.0, 0.5],
			[0.3, 1.0]
		]

		#expect(throws: CorrelatedNormalsError.self) {
			_ = try CorrelatedNormals(means: means, correlationMatrix: invalidMatrix)
		}
	}

	@Test("CorrelatedNormals sample() generates correct dimensions")
	func sampleDimensions() throws {
		let means = [10.0, 20.0, 30.0]
		let correlationMatrix = [
			[1.0, 0.0, 0.0],
			[0.0, 1.0, 0.0],
			[0.0, 0.0, 1.0]
		]

		let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)
		let sample = correlated.sample()

		#expect(sample.count == 3, "Sample should have same dimension as means vector")
	}

	@Test("CorrelatedNormals with zero correlation (independent variables)")
	func zeroCorrelation() throws {
		let means = [100.0, 200.0]
		let correlationMatrix = [  // Identity = no correlation
			[1.0, 0.0],
			[0.0, 1.0]
		]

		let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

		// Generate many samples
		var samples1: [Double] = []
		var samples2: [Double] = []

		for _ in 0..<5000 {
			let sample = correlated.sample()
			samples1.append(sample[0])
			samples2.append(sample[1])
		}

		// Check means
		let mean1 = samples1.reduce(0, +) / Double(samples1.count)
		let mean2 = samples2.reduce(0, +) / Double(samples2.count)

		#expect(abs(mean1 - 100.0) < 2.0, "Mean of first variable should be close to 100")
		#expect(abs(mean2 - 200.0) < 2.0, "Mean of second variable should be close to 200")

		// Check correlation (should be near 0)
		let empiricalCorr = correlationCoefficient(samples1, samples2)
		#expect(abs(empiricalCorr) < 0.1, "Correlation should be close to 0")
	}

	@Test("CorrelatedNormals with positive correlation")
	func positiveCorrelation() throws {
		let means = [0.0, 0.0]
		let targetCorr = 0.7
		let correlationMatrix = [
			[1.0, targetCorr],
			[targetCorr, 1.0]
		]

		let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

		// Generate many samples
		var samples1: [Double] = []
		var samples2: [Double] = []

		for _ in 0..<10000 {
			let sample = correlated.sample()
			samples1.append(sample[0])
			samples2.append(sample[1])
		}

		// Check empirical correlation
		let empiricalCorr = correlationCoefficient(samples1, samples2)
		let tolerance = 0.05

		#expect(abs(empiricalCorr - targetCorr) < tolerance, "Empirical correlation should match target")
	}

	@Test("CorrelatedNormals with negative correlation")
	func negativeCorrelation() throws {
		let means = [50.0, 50.0]
		let targetCorr = -0.6
		let correlationMatrix = [
			[1.0, targetCorr],
			[targetCorr, 1.0]
		]

		let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

		// Generate many samples
		var samples1: [Double] = []
		var samples2: [Double] = []

		for _ in 0..<10000 {
			let sample = correlated.sample()
			samples1.append(sample[0])
			samples2.append(sample[1])
		}

		// Check empirical correlation
		let empiricalCorr = correlationCoefficient(samples1, samples2)
		let tolerance = 0.05

		#expect(abs(empiricalCorr - targetCorr) < tolerance, "Empirical negative correlation should match target")
	}

	@Test("CorrelatedNormals with three variables")
	func threeVariables() throws {
		let means = [10.0, 20.0, 30.0]
		let correlationMatrix = [
			[1.0, 0.5, 0.3],
			[0.5, 1.0, 0.4],
			[0.3, 0.4, 1.0]
		]

		let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

		// Generate samples
		var samples1: [Double] = []
		var samples2: [Double] = []
		var samples3: [Double] = []

		for _ in 0..<10000 {
			let sample = correlated.sample()
			samples1.append(sample[0])
			samples2.append(sample[1])
			samples3.append(sample[2])
		}

		// Check means
		let mean1 = samples1.reduce(0, +) / Double(samples1.count)
		let mean2 = samples2.reduce(0, +) / Double(samples2.count)
		let mean3 = samples3.reduce(0, +) / Double(samples3.count)

		#expect(abs(mean1 - 10.0) < 1.0, "Mean 1 should be close to 10")
		#expect(abs(mean2 - 20.0) < 1.0, "Mean 2 should be close to 20")
		#expect(abs(mean3 - 30.0) < 1.0, "Mean 3 should be close to 30")

		// Check correlation between variables 1 and 2
		let corr12 = correlationCoefficient(samples1, samples2)
		#expect(abs(corr12 - 0.5) < 0.05, "Correlation 1-2 should be close to 0.5")

		// Check correlation between variables 2 and 3
		let corr23 = correlationCoefficient(samples2, samples3)
		#expect(abs(corr23 - 0.4) < 0.05, "Correlation 2-3 should be close to 0.4")
	}

	@Test("CorrelatedNormals generates different samples")
	func generatesDifferentSamples() throws {
		let means = [0.0, 0.0]
		let correlationMatrix = [
			[1.0, 0.5],
			[0.5, 1.0]
		]

		let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

		// Generate two samples
		let sample1 = correlated.sample()
		let sample2 = correlated.sample()

		// They should be different (with very high probability)
		let areDifferent = (sample1[0] != sample2[0]) || (sample1[1] != sample2[1])
		#expect(areDifferent, "Consecutive samples should be different")
	}

	@Test("CorrelatedNormals with non-zero means")
	func nonZeroMeans() throws {
		let means = [100.0, -50.0]
		let correlationMatrix = [
			[1.0, 0.3],
			[0.3, 1.0]
		]

		let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

		// Generate samples
		var samples1: [Double] = []
		var samples2: [Double] = []

		for _ in 0..<5000 {
			let sample = correlated.sample()
			samples1.append(sample[0])
			samples2.append(sample[1])
		}

		let mean1 = samples1.reduce(0, +) / Double(samples1.count)
		let mean2 = samples2.reduce(0, +) / Double(samples2.count)

		#expect(abs(mean1 - 100.0) < 2.0, "Mean should be close to 100")
		#expect(abs(mean2 - (-50.0)) < 2.0, "Mean should be close to -50")
	}

	@Test("CorrelatedNormals variance approximately 1 with identity correlation")
	func varianceCheck() throws {
		let means = [0.0, 0.0]
		let correlationMatrix = [
			[1.0, 0.0],
			[0.0, 1.0]
		]

		let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

		// Generate samples
		var samples1: [Double] = []

		for _ in 0..<5000 {
			let sample = correlated.sample()
			samples1.append(sample[0])
		}

		let mean = samples1.reduce(0, +) / Double(samples1.count)
		let squaredDiffs = samples1.map { pow($0 - mean, 2) }
		let variance = squaredDiffs.reduce(0, +) / Double(samples1.count - 1)

		// Variance should be close to 1.0
		#expect(abs(variance - 1.0) < 0.1, "Variance should be close to 1.0")
	}
}

@Suite("CorrelatedNormals – Additional", .serialized)
struct CorrelatedNormalsAdditionalTests {

	@Test("Single variable case (1D)")
	func singleVariable() throws {
		let means = [5.0]
		let corr = [[1.0]]
		let correlated = try CorrelatedNormals(means: means, correlationMatrix: corr)

		var samples: [Double] = []
		for _ in 0..<5000 {
			samples.append(correlated.sample()[0])
		}
		let mean = samples.reduce(0, +) / Double(samples.count)
		let varSample = samples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(samples.count - 1)

		#expect(abs(mean - 5.0) < 0.2, "Mean should be close to 5")
		#expect(abs(varSample - 1.0) < 0.15, "Unit variance expected when corr matrix is identity")
	}

	@Test("3×3 correlations: check 1–3 as well")
	func threeByThreeCheck13() throws {
		let means = [0.0, 0.0, 0.0]
		let corr = [
			[1.0, 0.5, 0.25],
			[0.5, 1.0, 0.4],
			[0.25, 0.4, 1.0]
		]
		let correlated = try CorrelatedNormals(means: means, correlationMatrix: corr)

		var s1: [Double] = []
		var s2: [Double] = []
		var s3: [Double] = []

		for _ in 0..<12000 {
			let s = correlated.sample()
			s1.append(s[0]); s2.append(s[1]); s3.append(s[2])
		}

		let c13 = correlationCoefficient(s1, s3)
		#expect(abs(c13 - 0.25) < 0.06, "Correlation 1–3 should be close to 0.25")
	}
}

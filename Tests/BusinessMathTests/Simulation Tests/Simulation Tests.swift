//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import Testing
import Numerics
#if canImport(OSLog)
import OSLog
#endif
@testable import BusinessMath


@Suite("SimulationTests") struct SimulationTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.SimulationTests", category: #function)
	
	@Test("DistributionNormal") func LDistributionNormal() {
		var array: [Double] = []
		for _ in 0..<1000 {
			array.append(distributionNormal(mean: 0, stdDev: 1))
		}
		let mu = (mean(array) * 10).rounded() / 10
		let sd = (stdDev(array) * 10).rounded() / 10
		#expect(mu < 0.125)
		#expect(mu > -0.125)
		#expect(sd > 0.975)
		#expect(sd < 1.025)
	}

	@Test("TriangularZero") func LTriangularZero() {
		let a = 0.6
		let b = 1.0
		let c = 0.7
		
		var testBed: [Double] = []
		for _ in stride(from: 0.0, to: 1.0, by: 0.0001) {
			testBed.append(triangularDistribution(low: a, high: b, base: c, distributionUniform()))
		}
		let countUnderC = testBed.filter({$0 <= c}).count
		let roundedCount = (Double(countUnderC) / 10.0).rounded() * 10.0
		let roundedLow = Int(roundedCount * 0.975)
		let roundedHigh = Int(roundedCount * 1.025)
//		let expectedObservations = Int(((c - a) * (2 / (b - a)) * (1 / 2) * 10000).rounded())
//		logger.info("\t\t\tExpected: \(expectedObservations)\nApprox Count Under C: \(countUnderC)\n\t  Expected Range: \(Int(roundedLow)) - \(Int(roundedHigh)) \(countUnderC >= Int(roundedLow) && countUnderC <= Int(roundedHigh) ? "✅" : "❌")")
		
		//TODO: Should be sliced, with the highest count as base
		
		#expect(countUnderC > roundedLow)
		#expect(countUnderC < roundedHigh)
    }
    
    @Test("UniformDistribution") func LUniformDistribution() {
        let resultZero = distributionUniform(min: 0, max: 0)
        #expect(resultZero == 0)
        let resultOne = distributionUniform(min: 1, max: 1)
        #expect(resultOne == 1)
        let min = 2.0
        let max = 40.0
        let result = distributionUniform(min: min, max: max)
        #expect(result <= max, "Value must be below \(max)")
        #expect(result >= min)
    }

	@Test("DistributionRayleighFunction") func LDistributionRayleighFunction() {
		// Test the function variant
		// Note: The parameter is the scale parameter σ, not the distribution mean
		// The actual mean of a Rayleigh(σ) distribution is σ × sqrt(π/2) ≈ 1.253σ
		let sigma = 5.0
		let result: Double = distributionRayleigh(mean: sigma)

		// Rayleigh distribution should produce non-negative values
		#expect(result >= 0.0, "Rayleigh values must be non-negative")

		// Test multiple samples to ensure reasonable distribution
		var samples: [Double] = []
		for _ in 0..<1000 {
			let sample: Double = distributionRayleigh(mean: sigma)
			samples.append(sample)
			#expect(sample >= 0.0)
		}

		// Verify all samples are non-negative and within a reasonable range
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		// For Rayleigh, mean ≈ 1.253σ, so for σ=5, expect mean ≈ 6.265
		let expectedMean = sigma * 1.253
		let tolerance = expectedMean * 0.20  // Allow 20% deviation due to sampling variance
		#expect(empiricalMean > expectedMean - tolerance)
		#expect(empiricalMean < expectedMean + tolerance)
	}

	@Test("DistributionRayleighStruct") func LDistributionRayleighStruct() {
		// Test the struct variant
		let sigma = 10.0
		let distribution = DistributionRayleigh(mean: sigma)

		// Test random() method
		let result1 = distribution.random()
		#expect(result1 >= 0.0)

		// Test next() method
		let result2 = distribution.next()
		#expect(result2 >= 0.0)

		// Verify multiple samples have reasonable distribution
		var samples: [Double] = []
		for _ in 0..<1000 {
			samples.append(distribution.next())
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		// For Rayleigh, mean ≈ 1.253σ
		let expectedMean = sigma * 1.253
		let tolerance = expectedMean * 0.20
		#expect(empiricalMean > expectedMean - tolerance)
		#expect(empiricalMean < expectedMean + tolerance)
	}

	@Test("DistributionRayleighSmallMean") func LDistributionRayleighSmallMean() {
		// Test with small mean value
		let mean = 0.5
		let distribution = DistributionRayleigh(mean: mean)

		var samples: [Double] = []
		for _ in 0..<500 {
			let sample = distribution.next()
			samples.append(sample)
			#expect(sample >= 0.0)
		}

		// All samples should be non-negative
		#expect(samples.filter({ $0 >= 0 }).count == 500)
	}
}

// Helpers
private func mean(_ xs: [Double]) -> Double {
	guard !xs.isEmpty else { return .nan }
	return xs.reduce(0, +) / Double(xs.count)
}

private func stdDev(_ xs: [Double]) -> Double {
	let m = mean(xs)
	let v = xs.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(xs.count - 1)
	return sqrt(v)
}

@Suite("Normal distribution")
struct NormalDistributionTests_SwiftTesting {

	@Test("Standard normal moments within reasonable tolerance")
	func standardNormalMoments() {
		let n = 5_000
		var xs = [Double]()
		xs.reserveCapacity(n)
		for _ in 0..<n {
			xs.append(distributionNormal(mean: 0, stdDev: 1))
		}
		let m = mean(xs)
		let s = stdDev(xs)

		// For mean: 3σ bound ≈ 3 / sqrt(n)
		let meanTol = 3.0 / sqrt(Double(n)) // ~0.042
		#expect(abs(m - 0.0) <= meanTol)

		// For std dev: accept ±10% to avoid flakiness without a seed
		#expect(abs(s - 1.0) <= 0.10)
	}

	@Test("Non-standard normal parameters honored")
	func shiftedScaledNormal() {
		let n = 5_000
		let mu = 2.5
		let sd = 3.0
		var xs = [Double]()
		for _ in 0..<n {
			xs.append(distributionNormal(mean: mu, stdDev: sd))
		}
		let m = mean(xs)
		let s = stdDev(xs)

		let meanTol = 3.0 * sd / sqrt(Double(n)) // 3σ bound on mean
		#expect(abs(m - mu) <= meanTol)

		// sd estimate tolerance (10%) for unseeded tests
		#expect(abs(s - sd) <= 0.10 * sd)
	}

	@Test("Degenerate normal with stdDev = 0 returns the mean")
	func degenerateNormal() {
		for mu in [-10.0, 0.0, 1.2345] {
			let x = distributionNormal(mean: mu, stdDev: 0)
			#expect(x == mu)
		}
	}
}

@Suite("Uniform distribution")
struct UniformDistributionTests {

	@Test("Uniform(min==max) returns that bound")
	func degenerateUniform() {
		#expect(distributionUniform(min: 0, max: 0) == 0)
		#expect(distributionUniform(min: 1, max: 1) == 1)
	}

	@Test("Uniform(min,max) stays within bounds and moments are reasonable")
	func boundedUniformBasic() {
		let minVal = 2.0, maxVal = 40.0
		let n = 10_000
		var xs = [Double]()
		xs.reserveCapacity(n)

		for _ in 0..<n {
			let x = distributionUniform(min: minVal, max: maxVal)
			#expect(x >= minVal && x <= maxVal)
			xs.append(x)
		}

		// Moment checks
		let expectedMean = (minVal + maxVal) / 2.0
		let expectedStd = (maxVal - minVal) / sqrt(12.0)

		let m = mean(xs)
		let s = stdDev(xs)

		// 3σ bound on mean: 3*σ/sqrt(n)
		let meanTol = 3.0 * expectedStd / sqrt(Double(n))
		#expect(abs(m - expectedMean) <= meanTol)

		// Accept ±10% on sd without a seed
		#expect(abs(s - expectedStd) <= 0.10 * expectedStd)
	}

	@Test("Default uniform() produces values in [0,1]")
	func defaultUniformRange() {
		let n = 5_000
		for _ in 0..<n {
			let x: Double = distributionUniform()
			#expect(x >= 0.0 && x <= 1.0)
		}
	}
}

@Suite("Triangular distribution")
struct TriangularDistributionTests_Additional {

	@Test("Probability of X ≤ c equals (c − a) / (b − a)")
	func cdfAtModeMatchesTheory() {
		let a = 0.6, b = 1.0, c = 0.7
		let n = 20_000
		var countUnderC = 0

		for _ in 0..<n {
			let x = triangularDistribution(low: a, high: b, base: c, distributionUniform())
			if x <= c { countUnderC += 1 }
		}

		let p = (c - a) / (b - a)
		let observed = Double(countUnderC) / Double(n)

		// Binomial normal approximation: ±3 sqrt(p(1-p)/n)
		let tol = 3.0 * sqrt(p * (1 - p) / Double(n))
		#expect(abs(observed - p) <= tol)
	}

	@Test("Mean equals (a + b + c) / 3")
	func meanMatchesTheory() {
		let a = 0.6, b = 1.0, c = 0.7
		let n = 20_000
		var xs = [Double]()
		xs.reserveCapacity(n)
		for _ in 0..<n {
			xs.append(triangularDistribution(low: a, high: b, base: c, distributionUniform()))
		}

		let expectedMean = (a + b + c) / 3.0
		let m = mean(xs)

		// Tolerance: rough 1% of range, to avoid flakiness without a seed
		let tol = 0.01 * (b - a)
		#expect(abs(m - expectedMean) <= tol)
	}

	@Test("Edge modes c == a and c == b produce valid samples in [a,b]")
	func edgeModesProduceValidSamples() {
		let a = 0.0, b = 1.0

		for c in [a, b] {
			for _ in 0..<5_000 {
				let x = triangularDistribution(low: a, high: b, base: c, distributionUniform())
				#expect(x >= a && x <= b)
			}
		}
	}
}

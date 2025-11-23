//
//  Dispersion Around the Mean Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import Testing
import Testing
import Numerics
import OSLog
@testable import BusinessMath

@Suite("DispersionAroundtheMeanTests") struct DispersionAroundtheMeanTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.DispersionAroundtheMeanTests", category: #function)
	

	@Test("CoefficientOfVariation") func LCoefficientOfVariation() {
		let array: [Double] = [0, 1, 2, 3, 4]
		let stdDev = stdDev(array)
		let mean = mean(array)
		let result = try! coefficientOfVariation(stdDev, mean: mean)
		#expect(result == (Double.sqrt(2.5) / 2) * 100)
	}
	
	@Test("IndexOfDispersion")
	func LIndexOfDispersion() throws {
		// Positive result
		let poissonLike: [Double] = [4, 5, 6, 5, 4, 6, 5, 4, 5, 6]
		let r1 = try indexOfDispersion(poissonLike)
		#expect(r1 > 0.0)

		// Known values
		let values: [Double] = [2, 4, 6, 8, 10]
		let dispersionIndex = try indexOfDispersion(values)

		// Use the same variance flavor your implementation uses:
		let meanVal = mean(values)
		let varVal = varianceS(values)        // sample variance = 10
		let expectedIndex = varVal / meanVal  // 10 / 6 ≈ 1.6667

		#expect(abs(dispersionIndex - expectedIndex) < 0.001)

		// Throws the right error when mean is zero
		let thrown = #expect(throws: MathError.self) {
			try indexOfDispersion([0.0, 0.0, 0.0])
		}
		#expect(thrown == .divisionByZero)
	}

	@Test("StdDevP") func LStdDevP() {
	 let result = stdDevP([0, 1, 2, 3, 4])
	 #expect(result == Double.sqrt(2))
	 }

	 @Test("StdDevS") func LStdDevS() {
		 let result = (stdDevS([96, 13, 84, 59, 92, 24, 68, 80, 89, 88, 37, 27, 44, 66, 14, 15, 87, 34, 36, 48, 64, 26, 79, 53]) * 10000.0).rounded(.up) / 10000
		 #expect(result == 27.7243)
	 }

	 @Test("StdDev") func LStdDev() {
		 let result = stdDev([0, 1, 2, 3, 4])
		 #expect(result == Double.sqrt(2.5))
	 }

    @Test("SumOfSquaredAvgDiff") func LSumOfSquaredAvgDiff() {
        let doubleArray: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0]
        let result = sumOfSquaredAvgDiff(doubleArray)
        #expect(result == 10)
    }

	@Test("TStatistic") func LTStatistic() {
		let result = tStatistic(x: 1)
		#expect(result == 1)
	}

    @Test("VarianceP") func LVarianceP() {
        let doubleArray: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0]
        let result = varianceP(doubleArray)
        #expect(result == 2)
    }

    @Test("VarianceS") func LVarianceS() {
        let doubleArray: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0]
        let result = varianceS(doubleArray)
        #expect(result == 2.5)
    }
	
	@Test("VarianceTDist") func LVarianceTDist() {
		// Test theoretical variance of Student's t-distribution: Var(T) = df/(df-2) for df > 2
		
		// Test 1: df = 10
		// Expected theoretical variance: 10/(10-2) = 10/8 = 1.25
		let df10 = 10
		let theoreticalVariance10 = Double(df10) / Double(df10 - 2)
		#expect(abs(theoreticalVariance10 - 1.25) < 0.001, "Theoretical variance for df=10 should be 1.25")
		
		// Test 2: df = 30 (approaches standard normal)
		// Expected theoretical variance: 30/(30-2) = 30/28 ≈ 1.0714
		let df30 = 30
		let theoreticalVariance30 = Double(df30) / Double(df30 - 2)
		#expect(abs(theoreticalVariance30 - 1.0714) < 0.001, "Theoretical variance for df=30 should be ~1.0714")
		
		// Test 3: df = 5 (lower df, higher variance)
		// Expected theoretical variance: 5/(5-2) = 5/3 ≈ 1.6667
		let df5 = 5
		let theoreticalVariance5 = Double(df5) / Double(df5 - 2)
		#expect(abs(theoreticalVariance5 - 1.6667) < 0.001, "Theoretical variance for df=5 should be ~1.6667")
		
		// Test 4: df = 100 (very close to standard normal variance of 1)
		// Expected theoretical variance: 100/(100-2) = 100/98 ≈ 1.0204
		let df100 = 100
		let theoreticalVariance100 = Double(df100) / Double(df100 - 2)
		#expect(abs(theoreticalVariance100 - 1.0204) < 0.001, "Theoretical variance for df=100 should be ~1.0204")
		
		// Test 5: Verify empirical variance matches theoretical for df=20
		let df20 = 20
		let sampleCount = 10000
		let theoreticalVariance20 = Double(df20) / Double(df20 - 2) // 20/18 ≈ 1.1111
		
		// Helper to generate deterministic seeds (similar to StudentTDistributionTests)
		struct SeededRNG {
			var state: UInt64
			mutating func next() -> Double {
				state = state &* 6364136223846793005 &+ 1
				let upper = Double((state >> 32) & 0xFFFFFFFF)
				return upper / Double(UInt32.max)
			}
		}
		
		var rng = SeededRNG(state: 12345)
		var samples: [Double] = []
		
		for _ in 0..<sampleCount {
			var seeds: [Double] = []
			for _ in 0..<10 {
				var seed = rng.next()
				seed = max(0.0001, min(0.9999, seed))
				seeds.append(seed)
			}
			let sample: Double = distributionT(degreesOfFreedom: df20, seeds: seeds)
			samples.append(sample)
		}
		
		// Calculate empirical variance
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let squaredDiffs = samples.map { pow($0 - empiricalMean, 2) }
		let empiricalVariance = squaredDiffs.reduce(0, +) / Double(samples.count - 1)
		
		// Empirical variance should be close to theoretical variance
		let tolerance = 0.1
		#expect(abs(empiricalVariance - theoreticalVariance20) < tolerance,
					   "Empirical variance should match theoretical variance for df=20 (expected: \(theoreticalVariance20), got: \(empiricalVariance))")
		
		// Test 6: Verify variance increases as df decreases (for df > 2)
		let variance4 = Double(4) / Double(4 - 2)  // 2.0
		let variance6 = Double(6) / Double(6 - 2)  // 1.5
		let variance8 = Double(8) / Double(8 - 2)  // 1.333...
		
		#expect(variance4 > variance6, "Lower df should have higher variance")
		#expect(variance6 > variance8, "Lower df should have higher variance")
		
		// Test 7: df = 3 (minimum df for finite variance)
		// Expected theoretical variance: 3/(3-2) = 3
		let df3 = 3
		let theoreticalVariance3 = Double(df3) / Double(df3 - 2)
		#expect(abs(theoreticalVariance3 - 3.0) < 0.001, "Theoretical variance for df=3 should be 3.0")
	}
}

@Suite("Dispersion - Invariants and Edge Cases")
struct DispersionProperties {

	@Test("StdDev translation and scale invariance (population)")
	func stdDev_population_invariance() {
		let x = [0.0, 1.0, 2.0, 3.0, 4.0]
		let s = stdDevP(x)
		let xShift = x.map { $0 + 10.0 }
		let xScaled = x.map { -3.0 * $0 } // scale by -3

		#expect(close(stdDevP(xShift), s, accuracy: 1e-12))
		#expect(close(stdDevP(xScaled), 3.0 * s, accuracy: 1e-12))
	}

	@Test("StdDev translation and scale invariance (sample)")
	func stdDev_sample_invariance() {
		let x = [1.0, 4.0, 9.0, 16.0, 25.0]
		let s = stdDevS(x)
		let xShift = x.map { $0 - 100.0 }
		let xScaled = x.map { 2.5 * $0 }
		#expect(close(stdDevS(xShift), s, accuracy: 1e-12))
		#expect(close(stdDevS(xScaled), 2.5 * s, accuracy: 1e-12))
	}

	@Test("Coefficient of variation non-negative and throws at zero mean")
	func coefficient_of_variation_properties() throws {
		let x = [1.0, 2.0, 3.0, 4.0]
		let cv = try coefficientOfVariation(stdDev(x), mean: mean(x))
		#expect(cv >= 0.0)

		// Throws when mean is zero
		#expect(throws: MathError.self) {
			_ = try coefficientOfVariation(stdDev([ -1.0, 0.0, 1.0 ]), mean: 0.0)
		}
	}
}

//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import Numerics
@testable import BusinessMath

final class SimulationTests: XCTestCase {

	func testDistributionLogNormal() {
		// Shape can be evaluated in Excel via histogram
		//        var array: [Double] = []
		//        for _ in 0..<10000 {
		//            array.append(distributionLogNormal(mean: 0, variance: 1))
		//        }
		// print(array)
		XCTAssert(true)
	}
	
	func testDistributionNormal() {
		var array: [Double] = []
		for _ in 0..<1000 {
			array.append(distributionNormal(mean: 0, stdDev: 1))
		}
		let mu = (mean(array) * 10).rounded() / 10
		let sd = (stdDev(array) * 10).rounded() / 10
		XCTAssertEqual(mu, 0)
		XCTAssertGreaterThan(sd, 0.975)
		XCTAssertLessThan(sd, 1.025)
	}

	func testTriangularZero() {
		let a = 0.6
		let b = 1.0
		let c = 0.7
		
		var testBed: [Double] = []
		for _ in stride(from: 0.0, to: 1.0, by: 0.0001) {
			testBed.append(triangularDistribution(low: a, high: b, base: c))
		}
		let countUnderC = testBed.filter({$0 <= c}).count
		let roundedCount = (Double(countUnderC) / 10.0).rounded() * 10.0
		let roundedHigh = roundedCount * 1.025
		let roundedLow = roundedCount * 0.975
		let expectedObservations = ((c - a) * (2 / (b - a)) * (1 / 2) * 10000).rounded()
		print("Approx Count Under C \(countUnderC): Expected: \(expectedObservations)")
		
		//TODO: Should be sliced, with the highest count as base
		
		XCTAssertGreaterThan(expectedObservations, roundedLow)
		XCTAssertLessThan(expectedObservations, roundedHigh)
    }
    
    func testUniformDistribution() {
        let resultZero = distributionUniform(min: 0, max: 0)
        XCTAssertEqual(resultZero, 0)
        let resultOne = distributionUniform(min: 1, max: 1)
        XCTAssertEqual(resultOne, 1)
        let min = 2.0
        let max = 40.0
        let result = distributionUniform(min: min, max: max)
        XCTAssertLessThanOrEqual(result, max, "Value must be below \(max)")
        XCTAssertGreaterThanOrEqual(result, min)
    }

	func testDistributionRayleighFunction() {
		// Test the function variant
		// Note: The parameter is the scale parameter σ, not the distribution mean
		// The actual mean of a Rayleigh(σ) distribution is σ × sqrt(π/2) ≈ 1.253σ
		let sigma = 5.0
		let result: Double = distributionRayleigh(mean: sigma)

		// Rayleigh distribution should produce non-negative values
		XCTAssertGreaterThanOrEqual(result, 0.0, "Rayleigh values must be non-negative")

		// Test multiple samples to ensure reasonable distribution
		var samples: [Double] = []
		for _ in 0..<1000 {
			let sample: Double = distributionRayleigh(mean: sigma)
			samples.append(sample)
			XCTAssertGreaterThanOrEqual(sample, 0.0)
		}

		// Verify all samples are non-negative and within a reasonable range
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		// For Rayleigh, mean ≈ 1.253σ, so for σ=5, expect mean ≈ 6.265
		let expectedMean = sigma * 1.253
		let tolerance = expectedMean * 0.20  // Allow 20% deviation due to sampling variance
		XCTAssertGreaterThan(empiricalMean, expectedMean - tolerance)
		XCTAssertLessThan(empiricalMean, expectedMean + tolerance)
	}

	func testDistributionRayleighStruct() {
		// Test the struct variant
		let sigma = 10.0
		let distribution = DistributionRayleigh(mean: sigma)

		// Test random() method
		let result1 = distribution.random()
		XCTAssertGreaterThanOrEqual(result1, 0.0)

		// Test next() method
		let result2 = distribution.next()
		XCTAssertGreaterThanOrEqual(result2, 0.0)

		// Verify multiple samples have reasonable distribution
		var samples: [Double] = []
		for _ in 0..<1000 {
			samples.append(distribution.next())
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		// For Rayleigh, mean ≈ 1.253σ
		let expectedMean = sigma * 1.253
		let tolerance = expectedMean * 0.20
		XCTAssertGreaterThan(empiricalMean, expectedMean - tolerance)
		XCTAssertLessThan(empiricalMean, expectedMean + tolerance)
	}

	func testDistributionRayleighSmallMean() {
		// Test with small mean value
		let mean = 0.5
		let distribution = DistributionRayleigh(mean: mean)

		var samples: [Double] = []
		for _ in 0..<500 {
			let sample = distribution.next()
			samples.append(sample)
			XCTAssertGreaterThanOrEqual(sample, 0.0)
		}

		// All samples should be non-negative
		XCTAssertEqual(samples.filter({ $0 >= 0 }).count, 500)
	}
}


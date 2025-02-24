//
//  DistributionNormal.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2/24/25.
//


struct DistributionNormal: RandomNumberGenerator {
	var x: Double = 0.0
	var mean: Double = 0.0
	var stdev: Double = 1.0
	
	init(x: Double, mean: Double, stdev: Double) {
		self.x = x
		self.mean = mean
		self.stdev = stdev
	}
	
	init(x: Double, mean: Double, variance: Double) {
		self.x = x
		self.mean = mean
		self.stdev = Double.sqrt(variance)
	}
	
	
	func random() -> Double {
		return normalCDF(x: x, mean: mean, stdDev: stdev)
	}
	
	func next() -> UInt64 {
		return UInt64(random())
	}
}

//
//  DistributionPoisson.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2/24/25.
//

import Foundation


struct DistributionPoisson: RandomNumberGenerator {
	var x: Int
	var µ: Double // LIVE: Poisson rate parameter used by random() and next()

	func random() -> Double { // LIVE: public sampling API for Poisson distribution
		poisson(x, µ: Double(x))
	}
	
	func next() -> UInt64 {
		UInt64(poisson(x, µ: Double(x)))
	}
}

	
//
//  distributionTriangular.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics
import OSLog

// Triangular Distribution function
// From https://en.wikipedia.org/wiki/Triangular_distribution#Generating_triangular-distributed_random_variates
public func triangularDistribution<T: Real>(low a: T, high b: T, base c: T) -> T {
	if #available(macOS 11.0, *) {
		let triangularDistributionLogger = Logger(subsystem: "BusinessMath > Sources > BusinessMath > Simulation > DistributionTriangular", category: "triangularDistribution")
	} else {
		// Fallback on earlier versions
	}
    let fc = (c - a) / (b - a)
    let u = T(Int(drand48() * 1_000_000_000)) / T(1_000_000_000)
    if u > 0 && u < fc {
        let s = u * (b - a) * (c - a)
        return a + sqrt(s)
    } else {
        let s = (1 - u) * (b - a) * (b - c)
        return b - sqrt(s)
    }
}

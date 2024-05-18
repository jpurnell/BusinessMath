//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/18/24.
//

import Foundation
import Numerics

public func poissonCDF<T: Real>(_ x: Int, µ: T) -> T {
	if x < 0 { return T(0) } else {
//		var accumulator: [T] = []
//		let first = T.exp(-1 * µ)
		return T.exp(-1 * µ) * (0..<x).map({T.pow(µ, T($0)) / T($0.factorial())}).reduce(T(0), +)
//		for i in 0..<x {
//			let numerator = T.pow(µ, T(i))
//			let denominator = i.factorial()
//			let value = numerator / T(denominator)
//			accumulator.append(value)
//		}
//		return first * accumulator.reduce(0, +)
	}
}

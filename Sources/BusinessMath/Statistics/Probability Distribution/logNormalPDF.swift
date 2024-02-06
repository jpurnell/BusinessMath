//
//  logNormalPDF.swift
//  
//
//  Created by Justin Purnell on 2/2/24.
//

import Foundation
import Numerics

func g<T: Real>(_ x: T, mean µ: T = T(0), stdDev: T = T(1)) -> T {
	let e = T(1) / (stdDev * T.sqrt(2 * .pi))
	let f = T.exp( (T(-1) / T(2)) * T.pow((x - µ), T(2))) / T.pow(stdDev, T(2))
	return e * f
}

func logNormal<T: Real>(_ x: T, mean µ: T = T(0), stdDev: T = T(1)) -> T {
	return T.exp(g(x))
}

func logNormalPDF<T: Real>(_ x: T, mean µ: T = T(0), stdDev: T = T(1)) -> T {
	let bot = T.sqrt(2 * .pi) * stdDev * x
	let exponent = -T.pow((T.log(x) - µ), T(2)) / (T(2) * T.pow(stdDev, T(2)))
	let probAtX = T.exp(exponent) / bot
	print("\(x):\t\(probAtX)")
	return probAtX
}

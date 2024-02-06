//
//  arithmeticHarmonicMean.swift
//  
//
//  Created by Justin Purnell on 5/17/23.
//

import Foundation
import Numerics

//public func arithmeticHarmonicMean<T: Real>(_ x: T, _ y: T, _ tolerance: Int = 10000) -> T {
//    var tempX = mean([x, y])
//    var tempY = harmonicMean([x, y])
//    while abs(tempX - tempY) > (T(1) / T(tolerance)) {
//        let newTempX = mean([tempX, tempY])
//        tempY = harmonicMean([tempX, tempY])
//        tempX = newTempX
//    }
//    return tempX
//}

public func arithmeticHarmonicMean<T: Real>(_ values: [T], _ tolerance: Int = 10000) -> T {
	var tempX = mean(values)
	var tempY = harmonicMean(values)
	while abs(tempX - tempY) > (T(1) / T(tolerance)) {
		let newTempX = mean([tempX, tempY])
		tempY = harmonicMean([tempX, tempY])
		tempX = newTempX
	}
	return tempX
}

//
//  distributionGeometric.swift
//  
//
//  Created by Justin Purnell on 5/18/24.
//

import Foundation
import Numerics


// From https://personal.utdallas.edu/~pankaj/3341/SP07/NOTES/lecture_week_8.pdf
public func distributionGeometric<T: Real>(_ p: T) -> T {
	var x: T = T(0)
	var u: T = distributionUniform()
	while u <= p {
		x = x + 1
	}
	return x
}

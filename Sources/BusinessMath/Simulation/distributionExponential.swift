//
//  distributionExponential.swift
//
//
//  Created by Justin Purnell on 5/18/24.
//

import Foundation
import Numerics

// From https://personal.utdallas.edu/~pankaj/3341/SP07/NOTES/lecture_week_8.pdf
public func distributionExponential<T: Real>(λ: T) -> T {
	let u: T = distributionUniform()
	return T(-1) * (T(1) / λ) * T.log(1 - u)
}

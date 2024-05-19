//
//  distributionGamma.swift
//  
//
//  Created by Justin Purnell on 5/18/24.
//

import Foundation
import Numerics

// From https://personal.utdallas.edu/~pankaj/3341/SP07/NOTES/lecture_week_8.pdf
public func distributionGamma<T: Real>(r: Int, λ: T) -> T {
	return (0..<r).map({_ in distributionExponential(λ: λ) }).reduce(T(0), +)
}

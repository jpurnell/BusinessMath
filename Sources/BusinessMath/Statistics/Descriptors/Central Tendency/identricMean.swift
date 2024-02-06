//
//  identricMean.swift
//  
//
//  Created by Justin Purnell on 1/6/24.
//

import Foundation
import Numerics

/// Provides the identric mean: https://www.johndcook.com/blog/2024/01/06/integral-representations-of-means/
public func identricMean<T: Real>(_ x: T, _ y: T) -> T {
	return (1 / .exp(1)) * T.pow((T.pow(y, y) / T.pow(x, x)), (T(1) / (y - x)))
}


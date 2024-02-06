//
//  logarithmicMean.swift
//  
//
//  Created by Justin Purnell on 1/6/24.
//

import Foundation
import Numerics

/// Provides the logarithmic mean: https://www.johndcook.com/blog/2024/01/06/integral-representations-of-means/
public func logarithmicMean<T: Real>(_ x: T, _ y: T) -> T {
	return (y - x) / (T.log(y) - T.log(x))
}

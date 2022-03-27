//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import Foundation
import Numerics

// MARK: - Excel Compatibility: Equivalent of Excel's STANDARDIZE function
public func standardize<T: Real>(x: T, mean: T, stdev: T) -> T {
    return zStatistic(x: x, mean: mean, stdDev: stdev)
}

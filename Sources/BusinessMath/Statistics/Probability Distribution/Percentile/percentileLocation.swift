//
//  percentileLocation.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func PercentileLocation<T: Comparable>(_ percentile: Int, values: [T]) -> T {
    return values.sorted()[(values.count + 1)*(percentile / 100)]
}

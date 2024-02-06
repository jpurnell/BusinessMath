//
//  Katz's Statistic.swift
//  
//
//  Created by Justin Purnell on 1/19/24.
//

import Foundation
import Numerics

// From Katz L (1965) United treatment of a broad class of discrete probability distributions. in Proceedings of the International Symposium on Discrete Distributions. Montreal
public func katzsStatistic<T: Real>(_ values: [T]) -> T {
	return T.sqrt(T(values.count) / T(2)) * (variance(values) - mean(values)) / mean(values)
}

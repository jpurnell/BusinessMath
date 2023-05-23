//
//  sumOfSquared.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// MARK:
/// Sum of Squared Average Difference
/// - Parameter values: A set of Values of a single type
/// - Returns: The Sum of Squared Average Difference
/// - Variance summarizes the how wide the differences are between observations and the mean. This is just a step towards the standard deviation, which is more useful mathematically. Once we have the mean (average), we square the difference of each observation that we used to calculate the mean from the mean. We then add those all up to get the Sum of Squared Average Difference. We use the square here so that the negative differences don't offset the positive differences and just give us 0. This Sum of Squared Average Difference is then averaged itself to give us the Variance.
public func sumOfSquaredAvgDiff<T: Real>(_ values: [T]) -> T {
    return values.map{ T.pow($0 - mean(values), 2)}.reduce(T(0), {$0 + $1})
}


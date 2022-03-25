//
//  stdDev.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

//MARK: - Standard Deviation helps us understand the dispersion of our observations. This is critical, because if we have a mean observation of 100, that could be because we have 1000 observations that are between 95 and 105, or it could be because we have 1000 observations between 80 and 120. This allows us to know when a single observation is outside of what we should expect to be the "natural" range, given the data we've already collected. If we saw a "110" come through in the first scenario (a typical range between 95 - 105), we might have some questions, but if it were in the second scenario (80-120), we probably wouldn't care.

// Standard deviation for a sample, used when you do not have all observations of the population,
// e.g. last 30 day calculations is the square root of the *sample* variance calculated above.
// Equivalent of Excel STDEV(xx:xx)
public func stdDevS<T: Real>(_ values: [T]) -> T {
    return T.sqrt(varianceS(values))
}

// Standard deviation for a population, used when you have all observations of a set, is just the square root of the population variance calculated above.
// Equivalent of Excel STDEVP(xx:xx)
public func stdDevP<T: Real>(_ values: [T]) -> T {
    return T.sqrt(varianceP(values))
}

public func stdDev<T: Real>(_ values: [T], _ pop: Population = .sample) -> T {
    switch pop {
        case .population:
            return stdDevP(values)
        default:
            return stdDevS(values)
    }
}

//public func stdDevTDist<T: Real>(_ values: [T]) -> T {
//    return T.sqrt(varianceTDist(values))
//}

//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// MARK: - Advanced Descriptors
// Advanced Descriptors give us a better sense of the "shape" of the overall data, helping us understand if outliers are making our basic descriptors not tell the whole story. Skew helps us identify cases where maybe most results are on one side of the average, but a really big outlier on the other side of the average is changing the numbers (e.g. 999 observations of 1, but one observation of 100,000 makes your average 1,001)
public func coefficientOfSkew<T: Real>(mean: T, median: T, stdDev: T) -> T {
    return (T(3) * (mean - median))/stdDev
}

public func coefficientOfSkew<T: Real>(_ values: [T]) -> T {
    return coefficientOfSkew(mean: mean(values), median: median(values), stdDev: stdDev(values))
}

//
//  skew.swift
//  
//
//  Created by Justin Purnell on 3/24/22.
//

import Foundation
import Numerics

/// Computes the skewness of a population dataset.
///
/// Skewness is a measure of the asymmetry of the probability distribution of a real-valued random variable about its mean.
/// The skewness of a normal distribution is zero, while the skewness of distributions that are more weighted on the left or right will be negative or positive, respectively.
///
/// - Parameters:
///   - values: An array of values representing the population dataset.
/// - Returns: The skewness of the dataset. The skewness is positive if the data are skewed to the right (longer tail on the right side), negative if the data are skewed to the left (longer tail on the left side), and zero if the data are symmetrically distributed.
///
/// - Note: The function computes the skewness using the formula:
///   \[ \text{skewness} = \frac{1}{n} \sum_{i=1}^{n} \left(\frac{x_i - \mu}{\sigma}\right)^3 \]
///   where \( n \) is the number of values, \( \mu \) is the mean of the values, and \( \sigma \) is the standard deviation of the values.
///
/// - Example:
///   ```swift
///   let values: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
///   let result = skewP(values)
///   // result should be the skewness of the dataset `values`
///   
public func skew<T: Real>(_ values:[T], _ pop: Population = .sample) -> T {
    switch pop {
        case .population:
            return skewP(values)
        default:
            return skewS(values)
    }
}

// Sample Skewness – This is the Excel default.
public func skewS<T: Real>(_ values: [T]) -> T {
    let n = T(values.count)
    let mean = average(values)
    let s: T = stdDev(values)
    let x = values.map({T.pow((($0 - mean) / s), 3) }).reduce(0, +)
    return (n / ((n - T(1)) * (n - T(2)))) * x
}


// Excel does not have a formula for population Skew
public func skewP<T: Real>(_ values: [T]) -> T {
    let n = T(values.count)
    let µ = average(values)
    let s = stdDevP(values)
    let x = values.map({T.pow((($0 - µ) / s), 3)}).reduce(0, +)
    return (T(1) / n) * x
}

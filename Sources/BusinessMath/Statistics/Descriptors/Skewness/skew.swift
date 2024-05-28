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

/**
 Computes the sample skewness for a given set of values.

 Sample skewness is a measure of the asymmetry of the probability distribution of a real-valued random variable about its mean for sample data. A skewness value greater than 0 indicates a distribution with a longer right tail, while a value less than 0 indicates a distribution with a longer left tail.

 - Parameters:
	- values: An array of values for which the sample skewness is to be calculated.

 - Returns: The sample skewness of the given dataset.

 - Note:
   - This function uses the sample standard deviation (denoted as `stdDev(_:)`), which differs slightly from the population standard deviation.
   - Ensure the dataset has at least three values as the formula for sample skewness is undefined for fewer values.

 - Requires:
   - Implementation of the `average(_:)` function to compute the mean of an array of values.
   - Implementation of the `stdDev(_:)` function to compute the sample standard deviation of an array of values.

 - Example:
   ```swift
   let data: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
   let skewness = skewS(data)
   print("Sample skewness of the data: \(skewness)")
   ```

 - Important:
   - Ensure that the `values` array contains at least three elements to perform the sample skewness calculation as the formula relies on having a sufficient sample size.
   - Sample Skewness – This is the Excel default.
 */
public func skewS<T: Real>(_ values: [T]) -> T {
    let n = T(values.count)
    let mean = average(values)
    let s: T = stdDev(values)
    let x = values.map({T.pow((($0 - mean) / s), 3) }).reduce(0, +)
    return (n / ((n - T(1)) * (n - T(2)))) * x
}


/**
 Computes the population skewness for a given set of values.

 Population skewness is a measure of the asymmetry of the probability distribution of a real-valued random variable about its mean. A skewness value greater than 0 indicates a distribution with a longer right tail, while a value less than 0 indicates a distribution with a longer left tail.

 - Parameters:
	- values: An array of values for which the population skewness is to be calculated.

 - Returns: The population skewness of the given dataset.

 - Note:
   - This function uses the population standard deviation (denoted as `stdDevP(_:)`), which differs slightly from the sample standard deviation.

 - Requires:
   - Implementation of the `average(_:)` function to compute the mean of an array of values.
   - Implementation of the `stdDevP(_:)` function to compute the population standard deviation of an array of values.

 - Example:
   ```swift
   let data: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
   let skewness = skewP(data)
   print("Population skewness of the data: \(skewness)")
   ```

 - Important:
   - Ensure that the `values` array is not empty, as the computations rely on knowing the count and having valid values to compute statistical measures.
   - Excel does not have a formula for population Skew
 */
public func skewP<T: Real>(_ values: [T]) -> T {
    let n = T(values.count)
    let µ = average(values)
    let s = stdDevP(values)
    let x = values.map({T.pow((($0 - µ) / s), 3)}).reduce(0, +)
    return (T(1) / n) * x
}

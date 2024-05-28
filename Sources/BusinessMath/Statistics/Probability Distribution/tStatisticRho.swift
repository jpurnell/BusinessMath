//
//  tStatistic.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the t-statistic given a correlation coefficient `rho` and degrees of freedom `dFr`.
///
/// The t-statistic measures the size of the difference relative to the variation in your sample data. It is used to tell if the difference is large enough to reject a null hypothesis.
/// In this case, the t-statistic is used to measure the greatest standardized difference between the observed correlation coefficient `rho` and its population value when the population value is expected to be zero under the null hypothesis.
///
/// - Parameters:
///    - rho: The correlation coefficient.
///    - dFr: The degrees of freedom.
///
/// - Returns: The computed t-statistic.
///
/// - Precondition: `rho` must be a value between `-1` and `1` (inclusive), `rho` can't be `1` if used with `dFr` of value `0`.
///
/// - Complexity: O(1), since the operations performed is constant.
///
///    let rho: Double = 0.8
///    let dFr: Double = 10.0
///    let t_statistic = tStatistic(rho, dFr: dFr)
///    print(t_statistic)
///
/// Use this function when you are trying to determine the confidence or significance of your correlations in your statistical hypothesis testing.
public func tStatistic<T: Real>(_ rho: T, dFr: T) -> T {
    let tStatistic = rho * T.sqrt(dFr / (1 - (rho *  rho)))
    return tStatistic
}

/// Computes the t-statistic given two data arrays: `independent` and `variable`.
///
/// This function calculates the t-statistic, which is a type of a test statistic, using a correlation coefficient calculated by the `spearmanRho` method from two input arrays `independent` and `variable`. The t-statistic assesses whether the means of two groups are statistically different from each other.
///
/// - Parameters:
///    - independent: The first array of `Real` type data points.
///    - variable: The second array of `Real` type data points.
///
/// - Returns: The computed t-statistic.
///
/// - Precondition: `independent` and `variable` must be arrays of the same length greater than 2.
///
/// - Complexity: O(n), where n is the number of items in `independent` or `variable`.
///
///    let independent: [Double] = [8.0, 2.0, 11.0, 6.0, 5.0]
///    let variable: [Double] = [3.0, 10.0, 3.0, 6.0, 8.0]
///    let t_statistic = tStatistic(independent, variable)
///    print(t_statistic)
///
/// Use this function when you are examining a continuous variable in relation to a binary variable and you don't assume any particular distribution for the data.
public func tStatistic<T: Real>(_ independent: [T], _ variable: [T]) throws -> T {
	guard independent.count == variable.count else { throw ArrayError.mismatchedLengths }
    return try tStatistic(spearmansRho(independent, vs: variable), dFr: T(independent.count - 2))
}

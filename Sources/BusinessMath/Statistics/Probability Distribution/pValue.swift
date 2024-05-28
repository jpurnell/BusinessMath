//
//  pValue.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the p-value for a given independent variable and dependent variable.
///
/// The p-value is a statistical metric that helps scientists determine whether or not their hypotheses are correct.
/// It represents the probability that the results of your test happened at random. If the p-value is low enough,
/// we reject the null hypothesis and accept the alternative hypothesis.
///
/// - Parameters:
///     - independent: An array of values representing the independent variable.
///                    Each element should adhere to the `Real` protocol (a protocol in the
///                    Swift Standard Library defining a common API for all types that can represent real numbers).
///     - variable: An array of values representing the dependent variable.
///
/// - Returns: The p-value (a `Real` number) representing the statistical significance of the test.
///
/// - Precondition: `independent` and `variable` arrays should have equal size and should not be empty.
/// - Complexity: O(n), where n is the number of elements in the `independent` and `variable` arrays.
///
///     let independent = [1.0, 2.0, 3.0, 4.0, 5.0]
///     let variable = [5.0, 4.0, 3.0, 2.0, 1.0]
///     let result = pValue(independent, variable)
///     print(result)
///
/// Use this function when you need to compute the p-value to test the statistical significance of your hypothesis.
public func pValue<T: Real>(_ independent: [T], _ variable: [T]) throws -> T {
	guard independent.count == variable.count else { throw ArrayError.mismatchedLengths }
    return try pValueStudent(tStatistic(independent, variable), dFr: T(independent.count - 2))
}

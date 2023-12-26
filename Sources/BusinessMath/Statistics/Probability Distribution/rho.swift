//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Converts the Fisher's z-score to the correlation coefficient (rho, ρ).
///
/// This function applies the Fisher’s z-transformation to transform the Fisher's z-score back to the original correlation coefficient, which measures the strength and direction of association between two continuous variables.
///
/// - Parameter fisherR: The Fisher's z-score, which is the amount of standard deviations a data point is from the mean. Fisher's Z is used to test the hypothesis that two correlation coefficients are equal.
///
/// - Returns: The correlation coefficient (rho, ρ). This value lies between -1 and +1, where +1 stands for a perfect direct (or positive) correlation, -1 stands for a perfect inverse (or negative) correlation, and 0 stands for no correlation.
///
/// - Complexity: O(1), since it uses a constant number of operations.
///
///     let fisherR = 1.1
///     let result = rho(from: fisherR)
///     print(result) // Prints the rho value.
///
/// Use this function when you need to convert Fisher's z-score back to a correlation coefficient.
public func rho<T: Real>(from fisherR: T) -> T {
    return (T.exp(2 * fisherR) - 1) / (T.exp(2 * fisherR) + 1)
}

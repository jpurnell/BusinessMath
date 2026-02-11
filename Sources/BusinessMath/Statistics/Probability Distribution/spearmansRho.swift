//
//  spearmansRho.swift
//
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes Spearman's rank correlation coefficient (rho) for two datasets.
///
/// Spearman's rank correlation coefficient is a nonparametric measure of rank correlation (statistical dependence between the rankings of two variables). It assesses how well the relationship between two variables can be described using a monotonic function.
///
/// - Parameters:
///	- independent: An array of independent values to be ranked and compared.
///	- variable: An array of dependent values to be ranked and compared.
///
/// - Returns: Spearman's rank correlation coefficient (rho) for the given datasets.
///
/// - Note:
///   - This function assumes the existence of the `rank()` and `tauAdjustment()` methods for the arrays of type `[T]`. These methods should compute the ranks of the elements in the array and the tie adjustments respectively.
///   - Ensure that both input arrays have the same length to calculate the correlation coefficient meaningfully.
///
/// - Requires:
///   - Implementation of the `rank()` method for arrays to compute ranks of values.
///   - Implementation of the `tauAdjustment()` method for arrays to adjust for ties in the ranking.
///
/// - Example:
///   ```swift
///   let xVals: [Double] = [10, 20, 30, 40, 50]
///   let yVals: [Double] = [15, 25, 35, 45, 55]
///   let rho = spearmansRho(xVals, vs: yVals)
///   print("Spearman's rank correlation coefficient: \(rho)")
///   ```
///
/// - Important:
///   - Ensure that `independent` and `variable` arrays have the same length.
///   - Ensure that both arrays are not empty to avoid computation errors.
///   - Ensure that the `rank()` and `tauAdjustment()` methods are correctly implemented for the computations.
public func spearmansRho<T: Real>(_ independent: [T], vs variable: [T]) throws -> T {
	guard independent.count == variable.count else { throw ArrayError.mismatchedLengths }
    var sigmaD = T(0)
    let sigmaX = (T.pow(T(independent.count), T(3)) - T(independent.count)) / T(12) - independent.tauAdjustment()
    let sigmaY = (T.pow(T(variable.count), T(3)) - T(variable.count)) / T(12) - variable.tauAdjustment()
    
    let independentRank = independent.rank()
    let variableRank = variable.rank()
    
    for i in 0..<independent.count {
        sigmaD += ((independentRank[i] - variableRank[i]) * (independentRank[i] - variableRank[i]))
    }
    
    let rho = (sigmaX + sigmaY - sigmaD) / (T(2) * T.sqrt((sigmaX * sigmaY)))
    return rho
}

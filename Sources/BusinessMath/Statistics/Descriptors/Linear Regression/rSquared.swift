//
//  rSquared.swift
//  
//
//  Created by Justin Purnell on 10/20/22.
//

import Foundation
import Numerics

/// Computes the coefficient of determination (R²) for two datasets.
///
/// The coefficient of determination, denoted as R², measures the proportion of the variance in the dependent variable
/// that is predictable from the independent variable. It is the square of the correlation coefficient.
///
/// - Parameters:
///   - x: An array of values representing the independent variable.
///   - y: An array of values representing the dependent variable.
///   - population: A `Population` enumeration value indicating whether the calculation is for a population or a sample. Defaults to `.sample`.
/// - Returns: The coefficient of determination, which is the square of the correlation coefficient. It is a value between 0 and 1, with 1 indicating perfect predictability.
///
/// - Note: The function relies on the `correlationCoefficient` function to compute the correlation between `x` and `y`, and then squares this correlation to get the R² value.
///
/// - Example:
///   ```swift
///   let xValues: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
///   let yValues: [Double] = [2.0, 4.0, 6.0, 8.0, 10.0]
///   let result = rSquared(xValues, yValues)
///   // result should be the R² value for the datasets `xValues` and `yValues`

public func rSquared<T: Real>(_ x: [T], _ y: [T], _ population: Population = .sample) -> T {
    let correlation = correlationCoefficient(x, y, population)
    return correlation * correlation
}

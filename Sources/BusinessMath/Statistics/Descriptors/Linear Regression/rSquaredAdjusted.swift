//
//  File.swift
//  
//
//  Created by Justin Purnell on 10/22/22.
//

import Foundation
import Numerics

/// Computes the adjusted coefficient of determination (Adjusted R²) for two datasets.
///
/// The adjusted R² accounts for the number of predictors (descriptors) in the model and adjusts the coefficient of determination (R²) accordingly to prevent overfitting. This measure is particularly useful in multiple regression models.
///
/// - Parameters:
///   - x: An array of values representing the independent variable.
///   - y: An array of values representing the dependent variable.
///   - population: A `Population` enumeration value indicating whether the calculation is for a population or a sample. Defaults to `.population`.
///   - descriptors: The number of descriptive terms (or predictors) in the regression model. Defaults to `1`.
/// - Returns: The adjusted coefficient of determination, R² Adjusted, which adjusts for the number of predictors in the model. Returns `0` if the lengths of `x` and `y` are not equal.
///
/// - Note: The function follows the formula for the adjusted R²:
///   \[ R^2_{\text{Adjusted}} = 1 - \left( \frac{1 - R^2}{n - k - 1} \right) (n - 1) \]
///   where \( n \) is the number of observations, \( k \) is the number of descriptors, and \( R^2 \) is the coefficient of determination.
///
/// - Example:
///   ```swift
///   let xValues: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
///   let yValues: [Double] = [2.0, 4.0, 6.0, 8.0, 10.0]
///   let result = rSquaredAdjusted(xValues, yValues, .sample, 1)
///   // result should be the adjusted R² value for the datasets `xValues` and `yValues`

public func rSquaredAdjusted<T: Real>(_ x: [T], _ y: [T], _ population: Population = .population, _ descriptors: T = T(1)) -> T {
    if (x.count == y.count) == false { return T(0) }
    let observations = T(x.count)
    let baseL = T(1) - rSquared(x, y, population)
    let baseC = observations - T(1)
    let baseR = observations - descriptors - T(1)
    let base = (baseL * baseC) / baseR
    return T(1) - base
}

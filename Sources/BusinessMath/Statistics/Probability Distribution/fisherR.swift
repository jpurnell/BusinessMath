//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Transforms the given correlation coefficient using Fisher's Z transformation.
///
/// Fisher's Z transformation, also known as Fisher's hyperbolic arctangent transformation, is used to convert Pearson's product-moment correlation coefficient to a normally distributed variable. It's often used to perform statistical tests or compute confidence intervals.
///
/// - Parameter r: The Pearson correlation coefficient.
///
/// - Returns: The transformed coefficient.
///
/// - Precondition: `r` must be a value between `-1` and `1` (exclusive).
/// - Complexity: O(1), as this function uses a constant number of operations.
///
///     let r = 0.5  // correlation coefficient for a dataset
///     let result = fisher(r)
///     print(result) // Prints "0.5493"
///
/// Use this function when you have a correlation coefficient and want to perform tests or compute confidence intervals around it.
public func fisher<T: Real>(_ r: T) -> T {
    return (T.log((1 + r) / (1 - r)) / 2)
}
